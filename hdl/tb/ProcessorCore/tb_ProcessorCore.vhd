-----------------------------------------------------------------------------------------------------------------------
-- entity: tb_InstrPrefetcher
--
-- library: tb_ndsmd_riscv
-- 
-- generics:
--      runner_cfg : configuration string for Vunit
--
-- description:
--      
-----------------------------------------------------------------------------------------------------------------------
library vunit_lib;
    context vunit_lib.vunit_context;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;

library tb_ndsmd_riscv;
    use tb_ndsmd_riscv.ProcessorCore_Utility.all;

entity tb_ProcessorCore is
    generic (runner_cfg : string);
end entity tb_ProcessorCore;

architecture tb of tb_ProcessorCore is
    -- the width of of the address bus
    constant cMemoryUnit_AddressWidth_b  : natural := 32;
    -- the size of the cache line (aka cache block size)
    constant cMemoryUnit_CachelineSize_B : natural := 16;

    signal stimuli   : stimuli_t;
    signal responses : responses_t;

    signal data_awaddr  : std_logic_vector(cMemoryUnit_AddressWidth_b - 1 downto 0);
    signal data_awprot  : std_logic_vector(2 downto 0);
    signal data_awvalid : std_logic;
    signal data_awready : std_logic;

    signal data_wdata  : std_logic_vector(8 * cMemoryUnit_CachelineSize_B - 1 downto 0);
    signal data_wstrb  : std_logic_vector(cMemoryUnit_CachelineSize_B - 1 downto 0);
    signal data_wvalid : std_logic;
    signal data_wready : std_logic;

    signal data_bresp  : std_logic_vector(1 downto 0);
    signal data_bvalid : std_logic;
    signal data_bready : std_logic;

    signal data_araddr  : std_logic_vector(cMemoryUnit_AddressWidth_b - 1 downto 0);
    signal data_arprot  : std_logic_vector(2 downto 0);
    signal data_arvalid : std_logic;
    signal data_arready : std_logic;

    signal data_rdata  : std_logic_vector(8 * cMemoryUnit_CachelineSize_B - 1 downto 0);
    signal data_rresp  : std_logic_vector(1 downto 0);
    signal data_rvalid : std_logic;
    signal data_rready : std_logic;
begin
    
    eStimuli : entity tb_ndsmd_riscv.ProcessorCore_Stimuli
    generic map (
        nested_runner_cfg => runner_cfg
    ) port map (
        o_stimuli   => stimuli,
        i_responses => responses
    );

    eDut : entity ndsmd_riscv.ProcessorCore
    generic map (
        cPrefetch_PcMisalignmentSeverity => warning,
        cMemoryUnit_AddressWidth_b       => 32,
        cMemoryUnit_CachelineSize_B      => 16
    ) port map (
        i_clk    => stimuli.clk,
        i_resetn => stimuli.resetn,

        o_instr_araddr  => responses.instr_araddr,
        o_instr_arprot  => responses.instr_arprot,
        o_instr_arvalid => responses.instr_arvalid,
        i_instr_arready => stimuli.instr_arready,

        i_instr_rdata  => stimuli.instr_rdata,
        i_instr_rresp  => stimuli.instr_rresp,
        i_instr_rvalid => stimuli.instr_rvalid,
        o_instr_rready => responses.instr_rready,

        o_data_awaddr  => data_awaddr,
        o_data_awprot  => data_awprot,
        o_data_awvalid => data_awvalid,
        i_data_awready => data_awready,

        o_data_wdata  => data_wdata,
        o_data_wstrb  => data_wstrb,
        o_data_wvalid => data_wvalid,
        i_data_wready => data_wready,

        i_data_bresp  => data_bresp,
        i_data_bvalid => data_bvalid,
        o_data_bready => data_bready,

        o_data_araddr  => data_araddr,
        o_data_arprot  => data_arprot,
        o_data_arvalid => data_arvalid,
        i_data_arready => data_arready,

        i_data_rdata  => data_rdata,
        i_data_rresp  => data_rresp,
        i_data_rvalid => data_rvalid,
        o_data_rready => data_rready
    );

    -- Need to make this RAM work with the cacheline generic too.
    -- eRam : entity tb_ndsmd_riscv.RandomAxiRam
    -- generic map (
    --     cCheckUninitialized => false,
    --     cVerboseMode => false
    -- ) port map (
    --     i_clk         => stimuli.clk,
    --     i_resetn      => stimuli.resetn,

    --     i_s_axi_awaddr  => data_awaddr,
    --     i_s_axi_awprot  => data_awprot,
    --     i_s_axi_awvalid => data_awvalid,
    --     o_s_axi_awready => data_awready,

    --     i_s_axi_wdata   => data_wdata,
    --     i_s_axi_wstrb   => data_wstrb,
    --     i_s_axi_wvalid  => data_wvalid,
    --     o_s_axi_wready  => data_wready,

    --     o_s_axi_bresp   => data_bresp,
    --     o_s_axi_bvalid  => data_bvalid,
    --     i_s_axi_bready  => data_bready,

    --     i_s_axi_araddr  => data_araddr,
    --     i_s_axi_arprot  => data_arprot,
    --     i_s_axi_arvalid => data_arvalid,
    --     o_s_axi_arready => data_arready,

    --     o_s_axi_rdata   => data_rdata,
    --     o_s_axi_rresp   => data_rresp,
    --     o_s_axi_rvalid  => data_rvalid,
    --     i_s_axi_rready  => data_rready
    -- );
    
end architecture tb;