-----------------------------------------------------------------------------------------------------------------------
-- entity: InstrPrefetcher_Stimuli
--
-- library: tb_ndsmd_riscv
-- 
-- signals:
--      o_stimuli   : 
--
-- description:
--      
-----------------------------------------------------------------------------------------------------------------------
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
    use tb_ndsmd_riscv.ControlEngine_Utility.all;

entity ControlEngine_Stimuli is
    generic (nested_runner_cfg : string);
    port (
        o_stimuli : out stimuli_t;
        -- we have to see the responses to know when to respond to requests
        i_responses : in responses_t
    );
end entity ControlEngine_Stimuli;

architecture rtl of ControlEngine_Stimuli is
    constant cPeriod : time := 10 ns;

    signal clk : std_logic := '0';
    signal stimuli : stimuli_t;
begin
    
    o_stimuli <= stimuli;
    stimuli.clk <= clk;

    CreateClock(clk=>clk, period=>cPeriod);

    -- Create constrained random stimuli generator that:
    -- 1. generates instructions in response to requests
    -- 2. generates random delays of several clock cycles to requests (range 0 to 100+?)
    -- 3. generates random stalls of several clock cycles

    -- One idea is to use the name of the test run to generate stimuli.
    -- e.g. if it contains maxthroughput, then turn off random delays and random stalls
    -- e.g. if it contains randdelay in the test name, then vary the delay value over a range
    -- e.g. if it contains bathtubdelay, then bias the random delays to bathtub distribution (high no. of 0s and 100s)
    -- e.g. if it contains randstall, then vary the stall delay
    -- e.g. if it contains bathtubstall, then bias the random stalls to bathtub distribution (high no. of 0s and 100s)

    TestRunner : process
        variable rand : RandomPType;
        variable idx  : natural := 0;
        variable rand_wait : natural := 0;
    begin
        test_runner_setup(runner, nested_runner_cfg);
  
        while test_suite loop
            if run("t_nominal") then
                info("Running maxthroughput test");
                
            elsif run("t_offnominal") then
                info("Running bathtub delay with bathtub stall");
                
            end if;
        end loop;
    
        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 2 ms);
    
end architecture rtl;