-----------------------------------------------------------------------------------------------------------------------
-- entity: InstrPrefetcher_Checker
--
-- library: tb_ndsmd_riscv
-- 
-- signals:
--      i_stimuli   : 
--      i_responses :
--
-- description:
--      
-----------------------------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library tb_ndsmd_riscv;
    use tb_ndsmd_riscv.InstrPrefetcher_Utility.all;

entity InstrPrefetcher_Checker is
    port (
        i_stimuli   : stimuli_t;
        i_responses : responses_t
    );
end entity InstrPrefetcher_Checker;

architecture rtl of InstrPrefetcher_Checker is
    
begin
    
    
    
end architecture rtl;