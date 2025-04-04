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

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.DatapathUtility.all;

entity ProcessorCore is
    generic (
        -- the number of buffered transactions
        cPrefetch_NumTransactions : natural := 2;
        -- the severity of the error caused by pc update not aligned to a multiple of 4;
        -- this normally is a failure, but during testing with random instruction generation,
        -- this is downgraded to a warning.
        cPrefetch_PcMisalignmentSeverity : severity_level := failure;

        -- the width of of the address bus
        cMemoryUnit_AddressWidth_b  : natural := 32;
        -- the size of the cache line (aka cache block size)
        cMemoryUnit_CachelineSize_B : natural := 16
    );
    port (
        -- system clock frequency
        i_clk : in std_logic;
        -- active low reset synchronous to the system clock
        i_resetn : in std_logic;

        -------------------------------------------------------
        -- AXI4 LITE Instruction Ports
        -------------------------------------------------------
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

        -------------------------------------------------------
        -- AXI4 LITE Data Ports
        -------------------------------------------------------
        -- AXI-like interface to allow for easier implementation
        -- address bus for requesting an address
        o_data_awaddr : out std_logic_vector(cMemoryUnit_AddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        o_data_awprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_data_awvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_data_awready : in std_logic;

        -- write data bus
        o_data_wdata  : out std_logic_vector(8 * cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- write data strobe
        o_data_wstrb : out std_logic_vector(cMemoryUnit_CachelineSize_B - 1 downto 0);
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
        o_data_araddr : out std_logic_vector(cMemoryUnit_AddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        o_data_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_data_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_data_arready : in std_logic;

        -- returned instruction data bus
        i_data_rdata  : in std_logic_vector(8 * cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- response indicating error occurred, if any
        i_data_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        i_data_rvalid : in std_logic;
        -- ready to receive instruction data
        o_data_rready : out std_logic
    );
end entity ProcessorCore;

architecture rtl of ProcessorCore is
    signal cpu_ready : std_logic := '0';
    signal pc        : unsigned(31 downto 0) := (others => '0');
    signal instr     : instruction_t;
    signal valid     : std_logic := '0';

    signal new_pc : unsigned(31 downto 0) := (others => '0');
    signal pcwen  : std_logic := '0';
    
    signal status : datapath_status_t;
    signal issued : stage_status_t;
begin
    
    ePrefetcher : entity ndsmd_riscv.InstrPrefetcher
    generic map (
        cNumTransactions        => cPrefetch_NumTransactions,
        cPcMisalignmentSeverity => cPrefetch_PcMisalignmentSeverity
    ) port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        o_instr_araddr  => o_instr_araddr,
        o_instr_arprot  => o_instr_arprot,
        o_instr_arvalid => o_instr_arvalid,
        i_instr_arready => i_instr_arready,

        i_instr_rdata  => i_instr_rdata,
        i_instr_rresp  => i_instr_rresp,
        i_instr_rvalid => i_instr_rvalid,
        o_instr_rready => o_instr_rready,
        
        i_cpu_ready => cpu_ready,
        o_pc        => pc,
        o_instr     => instr,
        o_valid     => valid,

        i_pc    => new_pc,
        i_pcwen => pcwen
    );

    eControl : entity ndsmd_riscv.ControlEngine
    port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        o_cpu_ready => cpu_ready,
        i_pc        => pc,
        i_instr     => instr,
        i_valid     => valid,

        i_status => status,
        o_issued => issued,
        i_pcwen  => pcwen
    );

    eDatapath : entity ndsmd_riscv.Datapath
    port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        o_status => status,
        i_issued => issued,

        o_pc    => new_pc,
        o_pcwen => pcwen,

        o_data_awaddr  => o_data_awaddr,
        o_data_awprot  => o_data_awprot,
        o_data_awvalid => o_data_awvalid,
        i_data_awready => i_data_awready,

        o_data_wdata  => o_data_wdata,
        o_data_wstrb  => o_data_wstrb,
        o_data_wvalid => o_data_wvalid,
        i_data_wready => i_data_wready,

        i_data_bresp  => i_data_bresp,
        i_data_bvalid => i_data_bvalid,
        o_data_bready => o_data_bready,

        o_data_araddr  => o_data_araddr,
        o_data_arprot  => o_data_arprot,
        o_data_arvalid => o_data_arvalid,
        i_data_arready => i_data_arready,

        i_data_rdata  => i_data_rdata,
        i_data_rresp  => i_data_rresp,
        i_data_rvalid => i_data_rvalid,
        o_data_rready => o_data_rready
    );
    
end architecture rtl;