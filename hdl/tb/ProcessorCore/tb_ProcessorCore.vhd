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
    signal stimuli   : stimuli_t;
    signal responses : responses_t;
begin
    
    eStimuli : entity tb_ndsmd_riscv.ProcessorCore_Stimuli
    generic map (
        nested_runner_cfg => runner_cfg
    ) port map (
        o_stimuli   => stimuli,
        i_responses => responses
    );

    eDut : entity ndsmd_riscv.ProcessorCore
    port map (
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

        o_data_awaddr  => open,
        o_data_awprot  => open,
        o_data_awvalid => open,
        i_data_awready => '0',

        o_data_wdata  => open,
        o_data_wstrb  => open,
        o_data_wvalid => open,
        i_data_wready => '0',

        i_data_bresp  => (others => '0'),
        i_data_bvalid => '0',
        o_data_bready => open,

        o_data_araddr  => open,
        o_data_arprot  => open,
        o_data_arvalid => open,
        i_data_arready => '0',

        i_data_rdata  => (others => '0'),
        i_data_rresp  => (others => '0'),
        i_data_rvalid => '0',
        o_data_rready => open
    );


    
end architecture tb;