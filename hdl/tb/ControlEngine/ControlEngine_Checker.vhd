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
library vunit_lib;
    context vunit_lib.vunit_context;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library simtools;

library tb_ndsmd_riscv;
    use tb_ndsmd_riscv.ControlEngine_Utility.all;

entity ControlEngine_Checker is
    port (
        i_stimuli   : stimuli_t;
        i_responses : responses_t
    );
end entity ControlEngine_Checker;

architecture rtl of ControlEngine_Checker is
    -- package TransactionPackage is new simtools.GenericListPkg
    --     generic map (element_t => transaction_t);

    -- shared variable transactions : TransactionPackage.list;
begin
    
    Checker: process(i_stimuli.clk)
        variable cycle       : natural := 0;
        -- variable transaction : transaction_t;
    begin
        if rising_edge(i_stimuli.clk) then
            if (i_stimuli.resetn = '0') then
                
            else
                
            end if;
            cycle := cycle + 1;
        end if;
    end process Checker;
    
end architecture rtl;