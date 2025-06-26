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
    use tb_ndsmd_riscv.ZiCsr_Utility.all;

entity Tb_ZiCsr is
    generic (runner_cfg : string);
end entity Tb_ZiCsr;

architecture tb of Tb_ZiCsr is
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

    eStimuli : entity tb_ndsmd_riscv.ZiCsr_Stimuli
    generic map (
        nested_runner_cfg => runner_cfg
    ) port map (
        o_stimuli   => stimuli,
        i_responses => responses
    );
    
    eDut : entity ndsmd_riscv.ZiCsr
    generic map (
        cTrapBaseAddress => x"FFFF0000"
    ) port map (
        i_clk    => stimuli.clk,
        i_resetn => stimuli.resetn,

        -- CSRR operations interface
        i_decoded => stimuli.decoded,
        i_opA     => stimuli.opA,
        o_res     => responses.res,
        
        -- Event counter signaling
        i_instret => stimuli.instret,
        
        -- Interrupt Signals
        -- General purpose lower-priority interrupts
        i_irpt_gen   => stimuli.irpt_gen,
        -- External interrupt signal
        i_irpt_ext   => stimuli.irpt_ext,
        -- Software interrupt signal
        i_irpt_sw    => stimuli.irpt_sw,
        -- Timer interrupt signal
        i_irpt_timer => stimuli.irpt_timer,
        
        -- Interupt Control Interface
        -- Last Completed PC serving as bookmark
        i_irpt_bkmkpc => stimuli.irpt_bkmkpc,
        -- PC of interrupt handler selected by active interrupt
        o_irpt_pc     => responses.irpt_pc,
        -- Indicator signal that indicates o_irpt_pc is valid
        o_irpt_valid  => responses.irpt_valid,
        -- PC of return instruction that occurs at MRET
        o_irpt_mepc   => responses.irpt_mepc
    );

    eChecker : entity tb_ndsmd_riscv.ZiCsr_Checker
    port map (
        i_stimuli   => stimuli,
        i_responses => responses
    );
    
end architecture tb;