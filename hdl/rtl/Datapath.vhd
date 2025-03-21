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
        i_ivalid : in std_logic;

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
    
begin
    
    -- eRegisters : entity ndsmd_riscv.RegisterFile
    -- port map (

    -- );

    -- eAlu : entity ndsmd_riscv.IntegerAlu
    -- port map (

    -- );

    -- eMext : entity ndsmd_riscv.MExtension
    -- port map (

    -- );

    -- eMemoryUnit : entity ndsmd_riscv.MemoryAccessUnit
    -- port map (

    -- );

    -- eZiCsr : entity ndsmd_riscv.ZiCsrExtension
    -- port map (

    -- );
    
    
end architecture rtl;