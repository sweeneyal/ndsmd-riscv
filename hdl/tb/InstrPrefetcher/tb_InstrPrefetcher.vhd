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
    use tb_ndsmd_riscv.InstrPrefetcher_Utility.all;

entity Tb_InstrPrefetcher is
    generic (runner_cfg : string);
end entity Tb_InstrPrefetcher;

architecture tb of Tb_InstrPrefetcher is
    signal stimuli   : stimuli_t;
    signal responses : responses_t;
begin

    -- Basic abstracted testbench style. I chose not to implement a 
    -- monitor/translation level since it would already need to know/
    -- understand the stimuli in order to make any sense of the responses,
    -- so the checker here translates the stimuli into in-flight PC requests/
    -- stalled instructions, and keeps track of what's been dropped or not.

    -- This testbench does not verify if instruction data is meaningful,
    -- yet. The main qualities needing to be tested here are throughput
    -- and accuracy, ensuring we can get instructions in lockstep with the
    -- downstream processor and that we do not miss an instruction/use a
    -- dropped instruction.

    eStimuli : entity tb_ndsmd_riscv.InstrPrefetcher_Stimuli
    generic map (
        nested_runner_cfg => runner_cfg
    ) port map (
        o_stimuli   => stimuli,
        i_responses => responses
    );
    
    eDut : entity ndsmd_riscv.InstrPrefetcher
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
        
        i_cpu_ready => stimuli.cpu_ready,
        o_pc        => responses.pc,
        o_instr     => responses.instr,
        o_valid     => responses.valid,

        i_pc    => stimuli.pc,
        i_pcwen => stimuli.pcwen
    );

    eChecker : entity tb_ndsmd_riscv.InstrPrefetcher_Checker
    port map (
        i_stimuli   => stimuli,
        i_responses => responses
    );
    
end architecture tb;