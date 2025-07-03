library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.DatapathUtility.all;
    use ndsmd_riscv.ZicsrUtility.all;

entity ZiCsr is
    generic (
        cTrapBaseAddress : unsigned(31 downto 0)
    );
    port (
        i_clk : in std_logic;
        i_resetn : in std_logic;

        -- CSRR operations interface
        i_decoded : in decoded_instr_t;
        i_opA     : in std_logic_vector(31 downto 0);
        o_res     : out std_logic_vector(31 downto 0);
        
        -- Event counter signaling
        i_instret : in std_logic;
        
        -- Interrupt Signals
        -- General purpose lower-priority interrupts
        i_irpt_gen   : in std_logic_vector(15 downto 0);
        -- External interrupt signal
        i_irpt_ext   : in std_logic;
        -- Software interrupt signal
        i_irpt_sw    : in std_logic;
        -- Timer interrupt signal
        i_irpt_timer : in std_logic;
        
        -- Interupt Control Interface
        -- Last Completed PC serving as bookmark
        i_irpt_bkmkpc : in unsigned(31 downto 0);
        -- PC of interrupt handler selected by active interrupt
        o_irpt_pc     : out unsigned(31 downto 0);
        -- Indicator signal that indicates o_irpt_pc is valid
        o_irpt_valid  : out std_logic;
        -- PC of return instruction that occurs at MRET
        o_irpt_mepc   : out unsigned(31 downto 0)
    );
end entity ZiCsr;

architecture rtl of ZiCsr is
    -- MXL, 4 zeros, and 26 bits of extensions
    constant cMisa : std_logic_vector(31 downto 0) := "01" & "0000" & "00"&"0000"&"0000"&"0001"&"0001"&"0000"&"0000";

    type machine_csr_t is record
        -- register the reports the ISA supported by the hart 
        misa      : std_logic_vector(31 downto 0);
        -- register that contains the JEDEC code of the core provider
        mvendorid : std_logic_vector(31 downto 0);
        -- Read-only register encoding the base microarchitecture of the hart
        marchid   : std_logic_vector(31 downto 0);
        -- Unique encoding of the version of the processor implementation
        mimpid    : std_logic_vector(31 downto 0);
        -- Read-only register containing the integer ID of the hardware thread running the code
        mhartid   : std_logic_vector(31 downto 0);
        -- Register that keeps track of and controls the hart's current operating state
        mstatus   : std_logic_vector(63 downto 0);
        -- Register that holds trap vector configuration
        mtvec     : unsigned(31 downto 0);
        -- Register that indicates what interrupts are pending
        mip       : std_logic_vector(31 downto 0);
        -- Register that indicates what interrupts are enabled
        mie       : std_logic_vector(31 downto 0);

        -- register that counts the number of clock cycles elapsed 
        mcycle        : u64_t;
        -- register that counts the number of instructions retired
        minstret      : u64_t;
        -- registers that count the number of events in the corresponding hpm events
        mhpmcounters  : u64_array_t(3 to 31);
        -- registers that holds what event increments the hpm counters
        mhpmevents    : std_logic_matrix_t(3 to 31)(31 downto 0);
        -- register that controls which of the counters can be read
        mcounteren    : std_logic_vector(31 downto 0);
        -- register that controls which of the counters increment
        mcountinhibit : std_logic_vector(31 downto 0);
        
        -- register dedicated for use by machine mode, usually used to hold a pointer
        mscratch   : std_logic_vector(31 downto 0);
        -- register that is written with the exception address
        mepc       : unsigned(31 downto 0);
        -- register that is written with a code indicating the event that caused the trap
        mcause     : std_logic_vector(31 downto 0);
        --
        mtval      : std_logic_vector(31 downto 0);
        --
        mconfigptr : std_logic_vector(31 downto 0);
    end record machine_csr_t;

    signal mcsr : machine_csr_t;
    
    procedure read_machine_csr (
        signal   i_mcsr  : in machine_csr_t;
        signal   i_addr  : in std_logic_vector(11 downto 0);
        variable o_csr   : out std_logic_vector(31 downto 0)
        --variable o_fault : out std_logic
    ) is
        variable fault : std_logic;
        variable hpmaddr : natural;
    begin
        o_csr := (others => '0');

        case to_natural(i_addr) is
            when 16#300# =>
                o_csr := i_mcsr.mstatus(31 downto 0);

            when 16#301# =>
                o_csr := i_mcsr.misa;

            when 16#304# =>
                o_csr := i_mcsr.mie;

            when 16#305# =>
                o_csr := std_logic_vector(i_mcsr.mtvec);

            when 16#310# =>
                o_csr := i_mcsr.mstatus(63 downto 32);

            when 16#323# to 16#33F# =>
                hpmaddr := to_natural(i_addr) - 16#323#;
                o_csr := std_logic_vector(i_mcsr.mhpmevents(hpmaddr)(31 downto 0));

            when 16#340# =>
                o_csr := i_mcsr.mscratch;

            when 16#341# =>
                o_csr := std_logic_vector(i_mcsr.mepc);

            when 16#342# =>
                o_csr := i_mcsr.mcause;

            when 16#343# =>
                o_csr := i_mcsr.mtval;

            when 16#344# =>
                o_csr := i_mcsr.mip;

            when 16#B00# =>
                o_csr := std_logic_vector(i_mcsr.mcycle(31 downto 0));

            when 16#B02# =>
                o_csr := std_logic_vector(i_mcsr.minstret(31 downto 0));

            when 16#B03# to 16#B1F# =>
                hpmaddr := to_natural(i_addr) - 16#B00#;
                o_csr := std_logic_vector(i_mcsr.mhpmcounters(hpmaddr)(31 downto 0));

            when 16#B80# =>
                o_csr := std_logic_vector(i_mcsr.mcycle(63 downto 32));

            when 16#B82# =>
                o_csr := std_logic_vector(i_mcsr.minstret(63 downto 32));

            when 16#B83# to 16#B9F# =>
                hpmaddr := to_natural(i_addr) - 16#B80#;
                o_csr := std_logic_vector(i_mcsr.mhpmcounters(hpmaddr)(63 downto 32));

            -- For supervisor and user level CSR implementations, go to the respective 
            -- functions for it.

            when others =>
                
        
        end case;
    end procedure;

    procedure write_machine_csr (
        signal   o_mcsr  : out machine_csr_t;
        signal   i_addr  : in std_logic_vector(11 downto 0);
        variable i_res   : in std_logic_vector(31 downto 0)
        --variable o_fault : out std_logic
    ) is
        variable fault : std_logic;
        variable hpmaddr : natural;
    begin
        case to_natural(i_addr) is
            when 16#300# =>
                o_mcsr.mstatus(31 downto 0) <= i_res;

            -- when 16#301# =>
            --     o_mcsr.misa <= i_res;

            when 16#304# =>
                o_mcsr.mie <= i_res;

            when 16#305# =>
                o_mcsr.mtvec <= unsigned(i_res);

            when 16#310# =>
                o_mcsr.mstatus(63 downto 32) <= i_res;

            when 16#323# to 16#33F# =>
                hpmaddr := to_natural(i_addr) - 16#323#;
                o_mcsr.mhpmevents(hpmaddr)(31 downto 0) <= i_res;

            when 16#340# =>
                o_mcsr.mscratch <= i_res;

            when 16#341# =>
                o_mcsr.mepc <= unsigned(i_res);

            when 16#342# =>
                o_mcsr.mcause <= i_res;

            when 16#343# =>
                o_mcsr.mtval <= i_res;

            when 16#344# =>
                o_mcsr.mip <= i_res;

            when 16#B00# =>
                o_mcsr.mcycle(31 downto 0) <= unsigned(i_res);

            when 16#B02# =>
                o_mcsr.minstret(31 downto 0) <= unsigned(i_res);

            when 16#B03# to 16#B1F# =>
                hpmaddr := to_natural(i_addr) - 16#B00#;
                o_mcsr.mhpmcounters(hpmaddr)(31 downto 0) <= unsigned(i_res);

            when 16#B80# =>
                o_mcsr.mcycle(63 downto 32) <= unsigned(i_res);

            when 16#B82# =>
                o_mcsr.minstret(63 downto 32) <= unsigned(i_res);

            when 16#B83# to 16#B9F# =>
                hpmaddr := to_natural(i_addr) - 16#B80#;
                o_mcsr.mhpmcounters(hpmaddr)(63 downto 32) <= unsigned(i_res);

            -- For supervisor and user level CSR implementations, go to the respective 
            -- functions for it.

            when others =>
                
        
        end case;

        --o_fault := fault;
    end procedure;

    function get_highest_priority_irpt(pending_irpts : std_logic_vector) return std_logic_vector is
    begin
        for ii in 15 downto 0 loop
            if (pending_irpts(ii) = '1') then
                return to_slv(ii, 31);
            end if;
        end loop;
        for ii in pending_irpts'length - 1 downto 16 loop
            if (pending_irpts(ii) = '1') then
                return to_slv(ii, 31);
            end if;
        end loop;
        return to_slv(0, 31);
    end function;

    signal pending : std_logic_vector(31 downto 0) := (others => '0');
begin

    pending(31 downto 16) <= i_irpt_gen;
    pending(cMEI)         <= i_irpt_ext;
    pending(cMTI)         <= i_irpt_timer;
    pending(cMSI)         <= i_irpt_sw;

    o_irpt_mepc <= mcsr.mepc;
    
    RegisterImplementation: process(i_clk)
        variable csr        : std_logic_vector(31 downto 0) := (others => '0');
        variable mip        : std_logic_vector(31 downto 0) := (others => '0');
        variable mcause     : std_logic_vector(30 downto 0) := (others => '0');
        variable irpt_valid : std_logic := '0';
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                -- Machine CSRs
                mcsr.misa      <= cMisa;
                mcsr.mvendorid <= (others => '0');
                mcsr.marchid   <= (others => '0');
                mcsr.mimpid    <= (others => '0');
                mcsr.mhartid   <= (others => '0');
                mcsr.mstatus   <= (others => '0');
                mcsr.mtvec     <= cTrapBaseAddress(31 downto 2) & "00";
                -- mcsr.medeleg   <= (others => '0');
                -- mcsr.mideleg   <= (others => '0');
                mcsr.mip       <= (others => '0');
                mcsr.mie       <= (others => '0');

                mcsr.mcycle   <= (others => '0');
                mcsr.minstret <= (others => '0');
                for ii in 3 to 31 loop
                    mcsr.mhpmcounters(ii) <= (others => '0');
                    mcsr.mhpmevents(ii)   <= (others => '0');
                end loop;
                mcsr.mcounteren    <= (others => '0');
                mcsr.mcountinhibit <= (others => '0');
                
                mcsr.mscratch   <= (others => '0');
                mcsr.mepc       <= (others => '0');
                mcsr.mcause     <= (others => '0');
                mcsr.mtval      <= (others => '0');
                mcsr.mconfigptr <= (others => '0');
                -- mcsr.menvcfg    <= (others => '0');
                -- mcsr.mseccfg    <= (others => '0');
            else
                --------------------------------------------------------------------
                -- Counter Logic
                --------------------------------------------------------------------

                if (mcsr.mcountinhibit(0) = '0') then
                    mcsr.mcycle <= mcsr.mcycle + 1;
                end if;

                if (i_instret = '1' and mcsr.mcountinhibit(1) = '0') then
                    mcsr.minstret <= mcsr.minstret + 1;
                end if;

                -- Add logic to handle event counters here

                --------------------------------------------------------------------
                -- Interrupt Logic
                --------------------------------------------------------------------

                -- Compute mip for use with interrupt logic
                mip := mcsr.mie and (mcsr.mip or pending);
                -- Compute mcause based on highest priority interrupt
                mcause := get_highest_priority_irpt(mip);
                -- Indicate that interrupt is valid if mip is nonzero and global mie is enabled
                irpt_valid := bool2bit(mip /= x"00000000" and mcsr.mstatus(cMIE) = '1');

                mcsr.mip <= mip;
                -- Indicate the cause as active by the pending interrupt
                mcsr.mcause(31)          <= bool2bit(mip /= x"00000000");
                mcsr.mcause(30 downto 0) <= mcause;

                if (irpt_valid = '1') then
                    -- turn off mie
                    mcsr.mstatus(cMIE)  <= '0';
                    mcsr.mstatus(cMPIE) <= mcsr.mstatus(cMIE);
                    -- We will store the last uncompleted pc, that is, the pc of the last
                    -- in progress instruction (if any), or the last pc issued by the control that
                    -- did not complete.  
                    mcsr.mepc           <= i_irpt_bkmkpc;
                elsif (i_decoded.csr_operation = MRET) then
                    mcsr.mstatus(cMIE)  <= mcsr.mstatus(cMPIE);
                    mcsr.mstatus(cMPIE) <= '1';
                end if;

                -- Look up target PC via mtvec + 4x mcause
                o_irpt_pc    <= unsigned(mcsr.mtvec) + (unsigned(mcause(29 downto 0)) & "00");
                o_irpt_valid <= irpt_valid;

                --------------------------------------------------------------------
                --
                --------------------------------------------------------------------


                if (i_decoded.csr_operation = CSRROP) then
                    -- Add privilege checking and fault handling in here.

                    read_machine_csr(
                        i_mcsr => mcsr,
                        i_addr => i_decoded.base.itype,
                        o_csr  => csr
                    );

                    o_res <= csr;
                    case i_decoded.csr_access is
                        when CSRRW =>
                            csr := i_opA;
                        when CSRRS =>
                            if (i_decoded.base.rs1 /= "00000") then
                                csr := csr or i_opA;
                            end if;
                        when CSRRC =>
                            if (i_decoded.base.rs1 /= "00000") then
                                csr := csr and (not i_opA);
                            end if;
                    end case;

                    -- Need to add support for additional side effects
                    write_machine_csr(
                        o_mcsr  => mcsr,
                        i_addr  => i_decoded.base.itype,
                        i_res   => csr
                        --o_fault => open
                    );
                end if;
            end if;
        end if;
    end process RegisterImplementation;
    
end architecture rtl;