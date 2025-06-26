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
    use tb_ndsmd_riscv.ZiCsr_Utility.all;

entity ZiCsr_Checker is
    port (
        i_stimuli   : stimuli_t;
        i_responses : responses_t
    );
end entity ZiCsr_Checker;

architecture rtl of ZiCsr_Checker is
begin
    
    -- Checker: process(i_stimuli.clk)
    --     variable cycle       : natural := 0;
    --     variable transaction : transaction_t;
    -- begin
    --     if rising_edge(i_stimuli.clk) then
    --         if (i_stimuli.resetn = '0') then
                
    --         else
    --             if ((i_stimuli.instr_arready and i_responses.instr_arvalid) = '1') then
    --                 report "InstrPrefetcher_Checker::Checker: New transaction initiated at cycle " 
    --                     & integer'image(cycle);
    --                 transactions.append(
    --                     transaction_t'(
    --                         pc        => unsigned(i_responses.instr_araddr),
    --                         requested => true,
    --                         issued    => false,
    --                         dropped   => false
    --                     ));
    --             end if;

    --             if ((i_stimuli.cpu_ready and i_responses.valid) = '1') then
    --                 report "InstrPrefetcher_Checker::Checker: Transaction issued to CPU at cycle "
    --                     & integer'image(cycle);
    --                 transaction := transactions.get(0);
    --                 report "InstrPrefetcher_Checker::Checker: transaction pc: " & to_hstring(transaction.pc);
    --                 report "InstrPrefetcher_Checker::Checker: issued pc: " & to_hstring(i_responses.pc);
    --                 check_equal(transaction.pc, i_responses.pc, "Transactions need to be issued in order.");
    --                 transactions.delete(0);
    --             end if;
    --         end if;
    --         cycle := cycle + 1;
    --     end if;
    -- end process Checker;
    
end architecture rtl;