-----------------------------------------------------------------------------------------------------------------------
-- entity: ControlEngine
--
-- library: ndsmd_riscv
-- 
-- signals:
--      i_clk    : system clock frequency
--      i_resetn : active low reset synchronous to the system clock
--      
--      o_cpu_ready : indicator that processor is ready to run next available instruction
--      i_pc    : program counter of instruction
--      i_instr : instruction data decomposed and recomposed as a record
--      i_valid : indicator that pc and instr are both valid
--      
--      i_pc    : target program counter of a jump or branch
--      i_pcwen : indicator that target pc is valid
--
-- description:
--       The ControlEngine takes in instructions and depending on the state of the datapath,
--       will either issue the instruction or produce a stall. It monitors the datapath,
--       including instructions in flight, hazard detection, and (in the future) the utilization
--       of different functional units and reservation stations in a Tomasulo OOO implementation.
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
    use ndsmd_riscv.DatapathUtility.all;

entity Datapath is
    port (
        i_clk : in std_logic;
        i_resetn : in std_logic;

        o_status : out datapath_status_t;
        i_issued : in stage_status_t;

        -- AXI-like interface to allow for easier implementation
        -- address bus for requesting an address
        o_data_awaddr : out std_logic_vector(31 downto 0);
        -- protection level of the transaction
        o_data_awprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_data_awvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_data_awready : in std_logic;

        -- write data bus
        o_data_wdata  : out std_logic_vector(31 downto 0);
        -- write data strobe
        o_data_wstrb : out std_logic_vector(3 downto 0);
        -- write valid
        o_data_wvalid : out std_logic;
        -- write ready
        i_data_wready : in std_logic;

        -- response indicating error occurred, if any
        i_data_bresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that write response data is valid
        i_data_bvalid : in std_logic;
        -- ready to receive write response data
        o_data_bready : out std_logic;

        -- address bus for requesting an address
        o_data_araddr : out std_logic_vector(31 downto 0);
        -- protection level of the transaction
        o_data_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_data_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_data_arready : in std_logic;

        -- returned instruction data bus
        i_data_rdata  : in std_logic_vector(31 downto 0);
        -- response indicating error occurred, if any
        i_data_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        i_data_rvalid : in std_logic;
        -- ready to receive instruction data
        o_data_rready : out std_logic
    );
end entity Datapath;

architecture rtl of Datapath is
    signal opA        : std_logic_vector(31 downto 0) := (others => '0');
    signal opB        : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_res    : std_logic_vector(31 downto 0) := (others => '0');
    signal eq_res     : std_logic := '0';
    signal slt_res    : std_logic := '0';
    signal mext_res   : std_logic_vector(31 downto 0) := (others => '0');
    signal mext_valid : std_logic := '0';

    type execute_stage_t is record
        status   : stage_status_t;
        alu_res  : std_logic_vector(31 downto 0);
        mext_res : std_logic_vector(31 downto 0);
    end record execute_stage_t;
    signal exec : execute_stage_t;
begin
    
    eRegisters : entity ndsmd_riscv.RegisterFile
    port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        i_rs1 => i_issued.instr.base.rs1,
        o_opA => opA,

        i_rs2 => i_issued.instr.base.rs2,
        o_opB => opB,

        i_rd    => "00000",
        i_res   => x"00000000",
        i_valid => '0'
    );

    eAlu : entity ndsmd_riscv.IntegerAlu
    port map (
        i_decoded => i_issued.instr,
        i_opA     => opA,
        i_opB     => opB,

        o_res => alu_res,
        o_eq  => eq_res
    );

    slt_res <= alu_res(0);

    eMext : entity ndsmd_riscv.MExtension
    port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        i_decoded => i_issued.instr,
        i_opA     => opA,
        i_opB     => opB,

        o_res   => mext_res,
        o_valid => mext_valid
    );

    ExecuteStage: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                exec.alu_res  <= (others => '0');
                exec.mext_res <= (others => '0');
                exec.status.valid        <= '0';
                exec.status.stall_reason <= NOT_STALLED;
            else
                -- If the issued instruction is valid, and we're not stalled, 
                -- then we can accept a new instruction.
                if (i_issued.valid = '1' and exec.status.stall_reason = NOT_STALLED) then
                    exec.status <= i_issued;

                    -- If it's the ALU, the instruction is done already, so grab the ALU
                    -- result and move on.
                    if (i_issued.instr.unit = ALU) then
                        exec.alu_res <= alu_res;
                    elsif (i_issued.instr.unit = MEXT) then
                        -- However, if it's the MEXT, we need to stall until the MEXT is done.
                        exec.status.stall_reason <= EXECUTION_STALL;
                    end if;
                elsif (exec.status.stall_reason = EXECUTION_STALL) then
                    -- We would only be here if there's an MEXT instruction running. Wait until the
                    -- MEXT instruction finishes.
                    if (mext_valid = '1') then
                        exec.mext_res <= mext_res;
                        exec.status.stall_reason <= NOT_STALLED;
                    end if;
                end if;
            end if;
        end if;
    end process ExecuteStage;

    -- eMemoryUnit : entity ndsmd_riscv.MemoryAccessUnit
    -- port map (

    -- );

    -- eZiCsr : entity ndsmd_riscv.ZiCsrExtension
    -- port map (

    -- );

    -- For the eventual tomasulo, leverage a FIFO that allows me to 
    -- keep track of the issued instructions. For example, we can issue
    -- ids 0 thru 63, but when 0 needs to be reissued, we need to make sure
    -- we get thru the previously issued ids before we complete 0.
    
    
end architecture rtl;