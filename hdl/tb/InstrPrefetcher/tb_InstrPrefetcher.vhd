library vunit_lib;
    context vunit_lib.vunit_context;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library osvvm;
    use osvvm.TbUtilPkg.all;
    use osvvm.RandomPkg.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;
    use nsfrtu_riscv.InstructionUtility.all;

library simtools;

entity Tb_InstrPrefetcher is
    generic (
        -- Default runner configuration for VUnit
        runner_cfg     : string; 
        -- Encoded runner configuration for simple generics
        encoded_tb_cfg : string;
        -- Cachetype generic, string by default
        cachetype      : string;
        -- Masks generic, an array of std_logic_vectors
        masks          : string
    );
end entity Tb_InstrPrefetcher;

architecture tb of Tb_InstrPrefetcher is
    constant cPeriod : time := 10 ns;
    signal clk : std_logic := '0';

    type tb_cfg_t is record
        linesize_B : positive;
        enabled    : boolean;
        entries    : positive;
        numsets    : positive;
        nummasks   : positive;
    end record tb_cfg_t;

    impure function decode(enc : string) return tb_cfg_t is
    begin
        return (linesize_B => positive'value(get(enc, "linesize_B")),
                enabled    => boolean'value(get(enc, "enabled")),
                entries    => positive'value(get(enc, "entries")),
                numsets    => positive'value(get(enc, "numsets")),
                nummasks   => positive'value(get(enc, "nummasks")));
    end function;

    constant tb_cfg : tb_cfg_t := decode(encoded_tb_cfg);

    impure function decode_masks(m : string) return std_logic_matrix_t is
        variable parts : lines_t := split(m, ", ");
        variable ret   : std_logic_matrix_t(parts'range)(31 downto 0);
    begin
        for i in parts'range loop
            ret(i) := to_slv(parts(i).all);
        end loop;
        return ret;
    end function;

    constant cache_masks : std_logic_matrix_t(0 to tb_cfg.nummasks - 1)(31 downto 0) := decode_masks(masks);

    type stimuli_t is record
        clk          : std_logic;
        resetn       : std_logic;

        instr_arready : std_logic;

        instr_rresp   : std_logic_vector(1 downto 0);
        instr_rdata   : std_logic_vector(tb_cfg.linesize_B * 8 - 1 downto 0);
        instr_rvalid  : std_logic;

        cpu_ready     : std_logic;

        pc           : unsigned(31 downto 0);
        pcwen        : std_logic;
    end record stimuli_t;
    
    type responses_t is record
        ready        : std_logic;

        instr_araddr  : std_logic_vector(31 downto 0);
        instr_arvalid : std_logic;
        instr_arprot  : std_logic_vector(2 downto 0);
        instr_rready  : std_logic;
        
        pc         : unsigned(31 downto 0);
        instr      : instruction_t;
        valid      : std_logic;
    end record responses_t;

    type transaction_t is record
        pc        : unsigned(31 downto 0);
        requested : boolean;
        issued    : boolean;
        dropped   : boolean;
    end record transaction_t;

    signal stimuli   : stimuli_t;
    signal responses : responses_t;

    package TransactionPackage is new simtools.GenericListPkg
        generic map (element_t => transaction_t);
    shared variable transactions : TransactionPackage.list;
begin
    
    -- Generate the clock for the overall simulation. Everything will be synchronized to this clock.
    CreateClock(clk=>clk, period=>cPeriod);
    stimuli.clk <= clk;

    eDut : entity nsfrtu_riscv.InstrPrefetcher
    generic map (
        cCachelineSize_B   => tb_cfg.linesize_B,
        cGenerateCache     => tb_cfg.enabled,
        cCacheType         => cachetype,
        cCacheSize_entries => tb_cfg.entries,
        cCache_NumSets     => tb_cfg.numsets,
        cNumCacheMasks     => tb_cfg.nummasks,
        cCacheMasks        => cache_masks
    )port map (
        i_clk    => stimuli.clk,
        i_resetn => stimuli.resetn,
        o_ready  => responses.ready,

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

    -- This Checker process is intended to verify that we do not skip the 
    -- issuance of instructions regardless of the state of the inputs or
    -- outputs. However, this does not work for caches, though a cache model
    -- can be attached to this that identifies when the right response is 
    -- issued in the right order.
    Checker: process(stimuli.clk)
        variable cycle       : natural := 0;
        variable transaction : transaction_t;
    begin
        if rising_edge(stimuli.clk) then
            if (stimuli.resetn = '0') then
                
            else
                if ((stimuli.instr_arready and responses.instr_arvalid) = '1') then
                    report "InstrPrefetcher::Checker: New transaction initiated at cycle " 
                        & integer'image(cycle);
                    transactions.append(
                        transaction_t'(
                            pc        => unsigned(responses.instr_araddr),
                            requested => true,
                            issued    => false,
                            dropped   => false
                        ));
                end if;

                -- if ((stimuli.cpu_ready and responses.valid) = '1') then
                --     report "InstrPrefetcher::Checker: Transaction issued to CPU at cycle "
                --         & integer'image(cycle);
                --     transaction := transactions.get(0);
                --     report "InstrPrefetcher::Checker: transaction pc: " & to_hstring(transaction.pc);
                --     report "InstrPrefetcher::Checker: issued pc: " & to_hstring(responses.pc);
                --     check_equal(transaction.pc, responses.pc, "Transactions need to be issued in order.");
                --     transactions.delete(0);
                -- end if;
            end if;
            cycle := cycle + 1;
        end if;
    end process Checker;

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
        test_runner_setup(runner, runner_cfg);
  
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

                wait until responses.ready = '1';

                wait until rising_edge(clk);
                wait for 100 ps;

                stimuli.instr_arready <= '1';
                stimuli.cpu_ready     <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;

                wait until rising_edge(clk);
                wait for 100 ps;

                for ii in 0 to 100 loop
                    if (ii mod 2 = 0) then
                        -- Waiting until this is 1 when it is already 1 is 
                        -- a surefire way to trigger the WDT. Probably a VHDL feature?
                        -- check(responses.instr_rready = '1');
                        stimuli.instr_rdata  <= to_slv(ii, 8 * tb_cfg.linesize_B);
                        stimuli.instr_rvalid <= '1';
                        stimuli.instr_rresp  <= "00";
                        wait until rising_edge(clk);
                        wait for 100 ps;
                    else
                        -- check(responses.instr_rready = '0');
                        stimuli.instr_rdata  <= to_slv(ii, 8 * tb_cfg.linesize_B);
                        stimuli.instr_rvalid <= '1';
                        stimuli.instr_rresp  <= "00";
                        wait until rising_edge(clk);
                        wait for 100 ps;
                    end if;
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

                    check(responses.instr_rready = '1');
                    stimuli.instr_rdata  <= to_slv(ii, 8 * tb_cfg.linesize_B);
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
                        if (responses.instr_rready = '1') then
                            stimuli.instr_rdata  <= to_slv(idx, 8 * tb_cfg.linesize_B);
                            stimuli.instr_rvalid <= '1';
                            stimuli.instr_rresp  <= "00";
                            idx := idx + 1;
                        end if;
                    end loop;
                    rand_wait := rand.RandInt(0, 10);

                    stimuli.cpu_ready <= '1';
                    wait until rising_edge(clk);
                    wait for 100 ps;
                    if (responses.instr_rready = '1') then
                        stimuli.instr_rdata  <= to_slv(idx, 8 * tb_cfg.linesize_B);
                        stimuli.instr_rvalid <= '1';
                        stimuli.instr_rresp  <= "00";
                        idx := idx + 1;
                    end if;
                end loop;
                
            elsif run("t_rand_mem_stall") then
                info("Running maxthroughput delay with random stall");
                check(false);
                -- stimuli.resetn <= '0';
                -- stimuli.instr_arready <= '0';
                -- stimuli.instr_rresp   <= "00";
                -- stimuli.instr_rdata   <= (others => '0');
                -- stimuli.instr_rvalid  <= '0';
                -- stimuli.cpu_ready     <= '0';
                -- stimuli.pc            <= (others => '0');
                -- stimuli.pcwen         <= '0';

                -- wait until rising_edge(clk);
                -- wait for 100 ps;
                -- stimuli.resetn <= '1';

                -- wait until rising_edge(clk);
                -- wait for 100 ps;

                -- stimuli.cpu_ready     <= '1';

                -- for ii in 0 to 10 loop
                --     wait until rising_edge(clk);
                --     wait for 100 ps;
                -- end loop;

                -- idx       := 0;
                -- rand_wait := rand.RandInt(0, 10);
                -- while idx < 100 loop
                --     stimuli.instr_arready <= not stimuli.instr_arready;
                --     for jj in 1 to rand_wait loop
                --         if (transactions.length > 0) then
                --             stimuli.instr_rdata  <= to_slv(idx, 32);
                --             stimuli.instr_rvalid <= '1';
                --             stimuli.instr_rresp  <= "00";
                --             idx := idx + 1;

                --             transactions.delete(0);
                --         else
                --             stimuli.instr_rvalid <= '0';
                --         end if;

                --         wait until rising_edge(clk);
                --         wait for 100 ps;

                --         if ((stimuli.instr_arready and responses.instr_arvalid) = '1') then
                --             transactions.append(
                --                 transaction_t'(
                --                     pc        => unsigned(responses.instr_araddr),
                --                     requested => true,
                --                     issued    => false,
                --                     dropped   => false
                --                 ));
                --         end if;
                --     end loop;
                --     rand_wait := rand.RandInt(0, 10);
                -- end loop;
                
            elsif run("t_rand_delay_rand_cpu_mem_stall") then
                info("Running random delay with random stall");
                check(false);
                
            end if;
        end loop;
    
        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 2 ms);
    
end architecture tb;