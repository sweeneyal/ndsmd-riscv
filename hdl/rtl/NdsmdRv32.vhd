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

entity NdsmdRv32 is
    generic (
        -- the number of buffered transactions
        cPrefetch_NumTransactions : natural := 2;

        -- the width of of the address bus
        cMemoryUnit_AddressWidth_b  : natural := 32;
        -- the size of the cache line (aka cache block size)
        cMemoryUnit_CachelineSize_B : natural := 16;

        -- flag for generating the division unit
        cMExtension_GenerateDivisionUnit : boolean := false
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
        m_axi_instr_awaddr : out std_logic_vector(31 downto 0);
        -- protection level of the transaction
        m_axi_instr_awprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        m_axi_instr_awvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        m_axi_instr_awready : in std_logic;

        -- write data bus
        m_axi_instr_wdata  : out std_logic_vector(31 downto 0);
        -- write data strobe
        m_axi_instr_wstrb : out std_logic_vector(3 downto 0);
        -- write valid
        m_axi_instr_wvalid : out std_logic;
        -- write ready
        m_axi_instr_wready : in std_logic;

        -- response indicating error occurred, if any
        m_axi_instr_bresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that write response data is valid
        m_axi_instr_bvalid : in std_logic;
        -- ready to receive write response data
        m_axi_instr_bready : out std_logic;

        -- address bus for requesting an address
        m_axi_instr_araddr : out std_logic_vector(31 downto 0);
        -- protection level of the transaction
        m_axi_instr_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        m_axi_instr_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        m_axi_instr_arready : in std_logic;

        -- returned instruction data bus
        m_axi_instr_rdata  : in std_logic_vector(31 downto 0);
        -- response indicating error occurred, if any
        m_axi_instr_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        m_axi_instr_rvalid : in std_logic;
        -- ready to receive instruction data
        m_axi_instr_rready : out std_logic;

        -------------------------------------------------------
        -- AXI4 LITE Data Ports
        -------------------------------------------------------
        -- AXI-like interface to allow for easier implementation
        -- address bus for requesting an address
        m_axi_data_awaddr : out std_logic_vector(cMemoryUnit_AddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        m_axi_data_awprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        m_axi_data_awvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        m_axi_data_awready : in std_logic;

        -- write data bus
        m_axi_data_wdata  : out std_logic_vector(8 * cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- write data strobe
        m_axi_data_wstrb : out std_logic_vector(cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- write valid
        m_axi_data_wvalid : out std_logic;
        -- write ready
        m_axi_data_wready : in std_logic;

        -- response indicating error occurred, if any
        m_axi_data_bresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that write response data is valid
        m_axi_data_bvalid : in std_logic;
        -- ready to receive write response data
        m_axi_data_bready : out std_logic;

        -- address bus for requesting an address
        m_axi_data_araddr : out std_logic_vector(cMemoryUnit_AddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        m_axi_data_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        m_axi_data_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        m_axi_data_arready : in std_logic;

        -- returned instruction data bus
        m_axi_data_rdata  : in std_logic_vector(8 * cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- response indicating error occurred, if any
        m_axi_data_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        m_axi_data_rvalid : in std_logic;
        -- ready to receive instruction data
        m_axi_data_rready : out std_logic
    );
end entity NdsmdRv32;

architecture rtl of NdsmdRv32 is
begin
    
    eCore : entity ndsmd_riscv.ProcessorCore
    generic map (
        cPrefetch_NumTransactions   => cPrefetch_NumTransactions,
        cMemoryUnit_AddressWidth_b  => cMemoryUnit_AddressWidth_b,
        cMemoryUnit_CachelineSize_B => cMemoryUnit_CachelineSize_B,
        cMExtension_GenerateDivisionUnit => cMExtension_GenerateDivisionUnit
    ) port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        o_instr_araddr  => m_axi_instr_araddr,
        o_instr_arprot  => m_axi_instr_arprot,
        o_instr_arvalid => m_axi_instr_arvalid,
        i_instr_arready => m_axi_instr_arready,

        i_instr_rdata  => m_axi_instr_rdata,
        i_instr_rresp  => m_axi_instr_rresp,
        i_instr_rvalid => m_axi_instr_rvalid,
        o_instr_rready => m_axi_instr_rready,

        o_data_awaddr  => m_axi_data_awaddr,
        o_data_awprot  => m_axi_data_awprot,
        o_data_awvalid => m_axi_data_awvalid,
        i_data_awready => m_axi_data_awready,

        o_data_wdata  => m_axi_data_wdata,
        o_data_wstrb  => m_axi_data_wstrb,
        o_data_wvalid => m_axi_data_wvalid,
        i_data_wready => m_axi_data_wready,

        i_data_bresp  => m_axi_data_bresp,
        i_data_bvalid => m_axi_data_bvalid,
        o_data_bready => m_axi_data_bready,

        o_data_araddr  => m_axi_data_araddr,
        o_data_arprot  => m_axi_data_arprot,
        o_data_arvalid => m_axi_data_arvalid,
        i_data_arready => m_axi_data_arready,

        i_data_rdata  => m_axi_data_rdata,
        i_data_rresp  => m_axi_data_rresp,
        i_data_rvalid => m_axi_data_rvalid,
        o_data_rready => m_axi_data_rready
    );
    
    
end architecture rtl;