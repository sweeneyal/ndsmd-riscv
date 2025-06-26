library vunit_lib;
    context vunit_lib.vunit_context;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library osvvm;
    use osvvm.TbUtilPkg.all;
    use osvvm.RandomPkg.all;

library universal;
    use universal.CommonFunctions.all;

library simtools;

library tb_ndsmd_riscv;
    use tb_ndsmd_riscv.ZiCsr_Utility.all;

entity ZiCsr_Stimuli is
    generic (
        nested_runner_cfg : string
    );
    port (
        o_stimuli   : out stimuli_t;
        i_responses : in responses_t
    );
end entity ZiCsr_Stimuli;

architecture tb of ZiCsr_Stimuli is
    
begin
    
    TestRunner : process
    begin
        test_runner_setup(runner, nested_runner_cfg);
  
        while test_suite loop
            if run("t_default") then
                info("Running maxthroughput test");
            end if;
        end loop;
    
        test_runner_cleanup(runner);
    end process;
    
end architecture tb;