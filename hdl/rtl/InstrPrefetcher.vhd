-----------------------------------------------------------------------------------------------------------------------
-- entity: InstrPrefetcher
--
-- library: ndsmd_riscv
-- 
-- signals:
--      i_clk    : system clock frequency
--      i_resetn : active low reset synchronous to the system clock
--    
--      o_instr_araddr : address bus for requesting an address
--      o_instr_arprot : protection level of the transaction
--      o_instr_arvalid : read enable signal indicating address bus request is valid
--      i_instr_arready : indicator that memory interface is ready to receive a request
--
--      i_instr_rdata  : returned instruction data bus
--      i_instr_rresp : response indicating error occurred, if any
--      i_instr_rvalid : valid signal indicating that instruction data is valid
--      o_instr_rready : ready to receive instruction data
--      
--      i_cpu_ready : indicator that processor is ready to run next available instruction
--      o_pc    : program counter of instruction
--      o_instr : instruction data decomposed and recomposed as a record
--      o_valid : indicator that pc and instr are both valid
--      
--      i_pc    : target program counter of a jump or branch
--      i_pcwen : indicator that target pc is valid
--
-- description:
--      This IP is designed to fetch instructions sequentially with maximum single-cycle
--      throughput. It handles stalls caused by both the memory unit and the downstream
--      processor. It is designed to the following specifications:
--          1. Under no stall conditions, i.e. no PC updates, no CPU stalls, and no 
--             memory stalls, it maintains a throughput of 1 instruction/cycle.
--          2. When CPU stalls occur, the stall lasts as long as the CPU stall, but returns
--             to designed throughput after stall.
--          3. When memory stalls occur, the stall lasts as long as the memory stall,
--             but returns to designed throughput after the stall.
--          4. Instructions will always be requested, received, and issued in order
--             based on the PC, barring PC updates.
--          5. When PC updates occur, the prefetcher itself will stall until all
--             dropped transactions have been received. 
--
-----------------------------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;

entity InstrPrefetcher is
    generic (
        cNumTransactions : natural := 2
    );
    port (
        -- system clock frequency
        i_clk : in std_logic;
        -- active low reset synchronous to the system clock
        i_resetn : in std_logic;

        -- AXI-like interface to allow for easier implementation
        -- address bus for requesting an address
        o_instr_araddr : out std_logic_vector(31 downto 0);
        -- protection level of the transaction
        o_instr_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_instr_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_instr_arready : in std_logic;

        -- returned instruction data bus
        i_instr_rdata  : in std_logic_vector(31 downto 0);
        -- response indicating error occurred, if any
        i_instr_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        i_instr_rvalid : in std_logic;
        -- ready to receive instruction data
        o_instr_rready : out std_logic;
        
        -- indicator that processor is ready to run next available instruction
        i_cpu_ready : in std_logic;
        -- program counter of instruction
        o_pc        : out unsigned(31 downto 0);
        -- instruction data decomposed and recomposed as a record
        o_instr     : out instruction_t;
        -- indicator that pc and instr are both valid
        o_valid     : out std_logic;

        -- target program counter of a jump or branch
        i_pc    : in unsigned(31 downto 0);
        -- indicator that target pc is valid
        i_pcwen : in std_logic
    );
end entity InstrPrefetcher;

architecture rtl of InstrPrefetcher is
    type prefetch_request_t is record
        pc      : unsigned(31 downto 0);
        valid   : std_logic;
        dropped : std_logic;
    end record prefetch_request_t;
    
    type stall_buffer_t is record
        pc    : unsigned(31 downto 0);
        instr : std_logic_vector(31 downto 0);
        valid : std_logic;
    end record stall_buffer_t;

    type prefetch_shift_t is array (0 to cNumTransactions - 1) of prefetch_request_t;

    signal pc             : unsigned(29 downto 0) := (others => '0');
    signal prefetch       : prefetch_shift_t;
    signal stalled        : stall_buffer_t;
    signal num_prefetches : natural range 0 to cNumTransactions := 0;

    signal instr_araddr  : std_logic_vector(31 downto 0) := (others => '0');
    signal instr_arvalid : std_logic := '0';
    signal instr_rready  : std_logic := '0';
begin

    o_instr_araddr  <= instr_araddr;
    o_instr_arvalid <= instr_arvalid;
    -- Hardcoding arprot for now.
    o_instr_arprot  <= "000";

    o_instr_rready <= instr_rready;

    StateMachine: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                instr_rready <= '0';

                stalled.valid <= '0';
                for ii in 0 to cNumTransactions - 1 loop
                    prefetch(ii).dropped <= '1';
                end loop;

                o_pc    <= (others => '0');
                o_valid <= '0';

                instr_araddr  <= (others => '0');
                instr_arvalid <= '0';
            else
                if (i_pcwen = '1') then
                    instr_rready <= '0';

                    stalled.valid <= '0';

                    pc <= i_pc(31 downto 2);
                    assert i_pc(1 downto 0) = "00" 
                        report "InstrPrefetcher::StateMachine: i_pc is not a multiple of 4." 
                            severity failure;

                    -- A future feature here would be to check if the sequence PC, 
                    -- PC + 4, PC + 8 are contained in the prefetch at all,
                    -- which could save some additional cycles for prefetches.
                    -- However, a napkin analysis of this would indicate that this is probably
                    -- a rare behavior, and violates the principle of "common case fast".
                    if ((i_instr_arready and instr_arvalid) = '1') then
                        -- Forward propagate prefetch
                        for ii in 1 to cNumTransactions - 1 loop
                            prefetch(ii) <= prefetch(ii - 1);
                        end loop;

                        prefetch(0).pc <= pc & "00";
                        prefetch(0).valid <= '1';
                        prefetch(0).dropped <= '1';
                    end if;

                    instr_araddr  <= std_logic_vector(i_pc(31 downto 2)) & "00";
                    instr_arvalid <= '1';

                    for ii in 0 to cNumTransactions - 1 loop
                        prefetch(ii).dropped <= '1';
                    end loop;
                else
                    instr_rready <= i_cpu_ready and not stalled.valid;
    
                    -- We're assuming the rresp is always OKAY.
                    if ((i_instr_rvalid and instr_rready) = '1') then
                        if (i_cpu_ready = '1') then
                            if (stalled.valid = '1') then
                                -- Provide stalled instruction
                                o_pc    <= stalled.pc;
                                o_instr <= decode(stalled.instr);
                                o_valid <= '1';
    
                                -- Move different instruction into stalled slot
                                for ii in cNumTransactions - 1 downto 0 loop
                                    if (prefetch(ii).valid = '1') then
                                        stalled.pc    <= prefetch(ii).pc;
                                        stalled.instr <= i_instr_rdata;
                                        stalled.valid <= not prefetch(ii).dropped;
    
                                        exit;
                                    end if;
                                end loop;
    
                            else
                                -- Take deepest prefetch and provide it to CPU.
                                for ii in cNumTransactions - 1 downto 0 loop
                                    if (prefetch(ii).valid = '1') then
                                        o_pc    <= prefetch(ii).pc;
                                        o_instr <= decode(i_instr_rdata);
                                        o_valid <= not prefetch(ii).dropped;
    
                                        exit;
                                    end if;
                                end loop;
                            end if;

                            if ((i_instr_arready and instr_arvalid) = '1') then
                                -- Forward propagate prefetch
                                for ii in 1 to cNumTransactions - 1 loop
                                    prefetch(ii) <= prefetch(ii - 1);
                                end loop;
    
                                prefetch(0).pc      <= pc & "00";
                                prefetch(0).valid   <= '1';
                                prefetch(0).dropped <= '0';
    
                                pc            <= pc + 1;
                                instr_araddr  <= std_logic_vector(pc + 1) & "00";
                                instr_arvalid <= '1';
                            else
                                instr_araddr  <= std_logic_vector(pc) & "00";
                                instr_arvalid <= '1';
                            end if;
                        else
                            -- Store it as a stalled instruction
                            assert (stalled.valid = '0') report "InstrPrefetcher::StateMachine: stalled.valid " & 
                                "is high when getting new instruction data and the CPU is stalled" severity failure;
    
                            -- Move deepest prefetch instruction into stalled slot
                            for ii in cNumTransactions - 1 downto 0 loop
                                if (prefetch(ii).valid = '1') then
                                    stalled.pc    <= prefetch(ii).pc;
                                    stalled.instr <= i_instr_rdata;
                                    stalled.valid <= not prefetch(ii).dropped;
    
                                    exit;
                                end if;
                            end loop;
                        end if;
    
                    else
                        if (i_cpu_ready = '1') then
                            if (stalled.valid = '1') then
                                -- Provide stalled instruction
                                o_pc    <= stalled.pc;
                                o_instr <= decode(stalled.instr);
                                o_valid <= '1';
                            end if;
                        end if;

                        if ((i_instr_arready and instr_arvalid) = '1' and num_prefetches < cNumTransactions) then
                            -- Forward propagate prefetch
                            for ii in 1 to cNumTransactions - 1 loop
                                prefetch(ii) <= prefetch(ii - 1);
                            end loop;

                            prefetch(0).pc      <= pc & "00";
                            prefetch(0).valid   <= '1';
                            prefetch(0).dropped <= '0';

                            pc            <= pc + 1;
                            instr_araddr  <= std_logic_vector(pc + 1) & "00";
                            instr_arvalid <= '1';

                            num_prefetches <= num_prefetches + 1;
                        else
                            instr_araddr  <= std_logic_vector(pc) & "00";
                            instr_arvalid <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;