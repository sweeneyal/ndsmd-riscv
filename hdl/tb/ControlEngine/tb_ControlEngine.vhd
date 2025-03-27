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
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.DatapathUtility.all;

library tb_ndsmd_riscv;
    use tb_ndsmd_riscv.ControlEngine_Utility.all;

entity tb_ControlEngine is
    generic (runner_cfg : string);
end entity tb_ControlEngine;

architecture tb of tb_ControlEngine is
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

    eStimuli : entity tb_ndsmd_riscv.ControlEngine_Stimuli
    generic map (
        nested_runner_cfg => runner_cfg
    ) port map (
        o_stimuli   => stimuli,
        i_responses => responses
    );
    
    eDut : entity ndsmd_riscv.ControlEngine
    port map (
        i_clk    => stimuli.clk,
        i_resetn => stimuli.resetn,
        
        o_cpu_ready => responses.cpu_ready,
        i_pc        => stimuli.pc,
        i_instr     => stimuli.instr,
        i_valid     => stimuli.valid,

        i_status => stimuli.status,
        o_issued => responses.issued,

        i_slt_eq => stimuli.slt_eq,
        o_pc     => responses.pc,
        o_pcwen  => responses.pcwen
    );

    eChecker : entity tb_ndsmd_riscv.ControlEngine_Checker
    port map (
        i_stimuli   => stimuli,
        i_responses => responses
    );
    
end architecture tb;