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
    use tb_ndsmd_riscv.InstrPrefetcher_Utility.all;

entity InstrPrefetcher_Stimuli is
    generic (nested_runner_cfg : string);
    port (
        o_stimuli : out stimuli_t;
        -- we have to see the responses to know when to respond to requests
        i_responses : in responses_t
    );
end entity InstrPrefetcher_Stimuli;

architecture rtl of InstrPrefetcher_Stimuli is
    constant cPeriod : time := 10 ns;

    signal clk : std_logic := '0';
    signal stimuli : stimuli_t;

    -- procedure stimulate_memory_interface is
    -- begin
    --     for ii in 0 to 10000 loop
    --         wait on i_responses;
    --         if (i_responses.instr_ren = '1') then
    --             -- For ease of testing, remap the requested PC as the data.
    --             stimuli.instr_rdata  <= transport i_responses.instr_addr after cPeriod;
    --             -- Set rvalid high after a clock cycle, then clear it the next clock cycle.
    --             stimuli.instr_rvalid <= transport '1' after cPeriod, '0' after 2 * cPeriod;
    --         end if;
    --     end loop;
    -- end procedure;

    package TransactionPackage is new simtools.GenericListPkg
        generic map (element_t => transaction_t);

    shared variable transactions : TransactionPackage.list;
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
        variable transaction : transaction_t;
    begin
        test_runner_setup(runner, nested_runner_cfg);
  
        while test_suite loop
            if run("t_max_throughput") then
                info("Running maxthroughput test");
                stimuli.resetn <= '0';
                stimuli.instr_arready <= '0';
                stimuli.instr_rresp   <= "00";
                stimuli.instr_rdata   <= (others => '0');
                stimuli.instr_rvalid  <= '0';
                stimuli.cpu_ready     <= '0';
                stimuli.pc            <= (others => '0');
                stimuli.pcwen         <= '0';

                wait until rising_edge(clk);
                wait for 100 ps;
                stimuli.resetn <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;

                stimuli.instr_arready <= '1';
                stimuli.cpu_ready     <= '1';

                for ii in 0 to 10 loop
                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;

                for ii in 0 to 100 loop
                    -- Waiting until this is 1 when it is already 1 is 
                    -- a surefire way to trigger the WDT. Probably a VHDL feature?
                    check(i_responses.instr_rready = '1');
                    stimuli.instr_rdata  <= to_slv(ii, 32);
                    stimuli.instr_rvalid <= '1';
                    stimuli.instr_rresp  <= "00";
                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;

            elsif run("t_rand_delay") then
                info("Running random delay with maxthroughput stall");
                stimuli.resetn <= '0';
                stimuli.instr_arready <= '0';
                stimuli.instr_rresp   <= "00";
                stimuli.instr_rdata   <= (others => '0');
                stimuli.instr_rvalid  <= '0';
                stimuli.cpu_ready     <= '0';
                stimuli.pc            <= (others => '0');
                stimuli.pcwen         <= '0';

                wait until rising_edge(clk);
                wait for 100 ps;
                stimuli.resetn <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;

                stimuli.instr_arready <= '1';
                stimuli.cpu_ready     <= '1';

                for ii in 0 to 10 loop
                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;

                for ii in 0 to 100 loop
                    stimuli.instr_rvalid <= '0';
                    for jj in 0 to rand.RandInt(0, 10) loop
                        wait until rising_edge(clk);
                        wait for 100 ps;
                    end loop;

                    check(i_responses.instr_rready = '1');
                    stimuli.instr_rdata  <= to_slv(ii, 32);
                    stimuli.instr_rvalid <= '1';
                    stimuli.instr_rresp  <= "00";

                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;
                
        
            elsif run("t_rand_cpu_stall") then
                info("Running maxthroughput delay with random stall");
                stimuli.resetn <= '0';
                stimuli.instr_arready <= '0';
                stimuli.instr_rresp   <= "00";
                stimuli.instr_rdata   <= (others => '0');
                stimuli.instr_rvalid  <= '0';
                stimuli.cpu_ready     <= '0';
                stimuli.pc            <= (others => '0');
                stimuli.pcwen         <= '0';

                wait until rising_edge(clk);
                wait for 100 ps;
                stimuli.resetn <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;

                stimuli.instr_arready <= '1';
                stimuli.cpu_ready     <= '1';

                for ii in 0 to 10 loop
                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;

                idx       := 0;
                rand_wait := rand.RandInt(0, 10);
                while idx < 100 loop
                    stimuli.cpu_ready <= '0';
                    for jj in 1 to rand_wait loop
                        wait until rising_edge(clk);
                        wait for 100 ps;
                        if (i_responses.instr_rready = '1') then
                            stimuli.instr_rdata  <= to_slv(idx, 32);
                            stimuli.instr_rvalid <= '1';
                            stimuli.instr_rresp  <= "00";
                            idx := idx + 1;
                        end if;
                    end loop;
                    rand_wait := rand.RandInt(0, 10);

                    stimuli.cpu_ready <= '1';
                    wait until rising_edge(clk);
                    wait for 100 ps;
                    if (i_responses.instr_rready = '1') then
                        stimuli.instr_rdata  <= to_slv(idx, 32);
                        stimuli.instr_rvalid <= '1';
                        stimuli.instr_rresp  <= "00";
                        idx := idx + 1;
                    end if;
                end loop;
                
            elsif run("t_rand_mem_stall") then
                info("Running maxthroughput delay with random stall");
                stimuli.resetn <= '0';
                stimuli.instr_arready <= '0';
                stimuli.instr_rresp   <= "00";
                stimuli.instr_rdata   <= (others => '0');
                stimuli.instr_rvalid  <= '0';
                stimuli.cpu_ready     <= '0';
                stimuli.pc            <= (others => '0');
                stimuli.pcwen         <= '0';

                wait until rising_edge(clk);
                wait for 100 ps;
                stimuli.resetn <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;

                stimuli.cpu_ready     <= '1';

                for ii in 0 to 10 loop
                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;

                idx       := 0;
                rand_wait := rand.RandInt(0, 10);
                while idx < 100 loop
                    stimuli.instr_arready <= not stimuli.instr_arready;
                    for jj in 1 to rand_wait loop
                        if (transactions.length > 0) then
                            stimuli.instr_rdata  <= to_slv(idx, 32);
                            stimuli.instr_rvalid <= '1';
                            stimuli.instr_rresp  <= "00";
                            idx := idx + 1;

                            transactions.delete(0);
                        else
                            stimuli.instr_rvalid <= '0';
                        end if;

                        wait until rising_edge(clk);
                        wait for 100 ps;

                        if ((stimuli.instr_arready and i_responses.instr_arvalid) = '1') then
                            transactions.append(
                                transaction_t'(
                                    pc        => unsigned(i_responses.instr_araddr),
                                    requested => true,
                                    issued    => false,
                                    dropped   => false
                                ));
                        end if;
                    end loop;
                    rand_wait := rand.RandInt(0, 10);
                end loop;
                
            elsif run("t_rand_delay_rand_cpu_mem_stall") then
                info("Running random delay with random stall");
                check(false);
                
            end if;
        end loop;
    
        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 2 ms);
    
end architecture rtl;