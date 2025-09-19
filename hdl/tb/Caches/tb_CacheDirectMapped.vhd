-----------------------------------------------------------------------------------------------------------------------
-- entity: tb_CacheDirectMapped
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

library osvvm;
    use osvvm.TbUtilPkg.all;
    use osvvm.RandomPkg.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;

entity tb_CacheDirectMapped is
    generic (runner_cfg : string);
end entity tb_CacheDirectMapped;

architecture tb of tb_CacheDirectMapped is
    constant cPeriod : time := 10 ns;
    constant cAddressWidth_b    : positive := 32;
    constant cCachelineSize_B   : positive := 16;
    constant cCacheSize_entries : positive := 1024; 

    type access_port_t is record
        addr  : std_logic_vector(cAddressWidth_b - 1 downto 0);
        en    : std_logic;
        wen   : std_logic_vector(cCachelineSize_B - 1 downto 0);
        wdata : std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        rdata : std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        valid : std_logic;
    end record access_port_t;

    signal cache  : access_port_t;
    signal memory : access_port_t;

    signal clk        : std_logic := '0';
    signal resetn     : std_logic := '0';
    signal cache_hit  : std_logic := '0';
    signal cache_miss : std_logic := '0';
begin

    CreateClock(clk=>clk, period=>cPeriod);

    eDut : entity ndsmd_riscv.CacheDirectMapped
    generic map (
        cAddressWidth_b    => cAddressWidth_b,
        cCachelineSize_B   => cCachelineSize_B,
        cCacheSize_entries => cCacheSize_entries
    ) port map (
        i_clk    => clk, 
        i_resetn => resetn, 

        i_cache_addr  => cache.addr,
        i_cache_en    => cache.en,
        i_cache_wen   => cache.wen,
        i_cache_wdata => cache.wdata,
        o_cache_rdata => cache.rdata,
        o_cache_valid => cache.valid,

        o_cache_hit  => cache_hit,
        o_cache_miss => cache_miss,

        o_mem_addr  => memory.addr,
        o_mem_en    => memory.en,
        o_mem_wen   => memory.wen,
        o_mem_wdata => memory.wdata,
        i_mem_rdata => memory.rdata,
        i_mem_valid => memory.valid
    );
    
    TestRunner : process
        variable v : std_logic_vector(31 downto 0) := (others => '0');
    begin
        test_runner_setup(runner, runner_cfg);
  
        while test_suite loop
            -- types of tests needed:
            --  verification of specific behaviors of registers
            --    e.g., event counters, timer, instret, etc.
            --  verification of interrupt performance
            --    e.g., for a given set of interrupts, which one takes priority, 
            --     whats the target address, behavior that occurs on mret
            if run("t_cache_demonstration") then
                info("Running basic cache demonstration.");
                resetn <= '0';
                wait until rising_edge(clk);
                wait for 100 ps;
                resetn <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;
                info("Demonstration of read miss behavior.");
                for ii in 0 to cCacheSize_entries - 1 loop
                    cache.addr  <= std_logic_vector(to_unsigned(ii * cCachelineSize_B, cAddressWidth_b));
                    cache.en    <= '1';
                    cache.wen   <= (others => '0');
                    cache.wdata <= (others => '0');

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    check(cache_miss = '1');

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    check(cache_miss = '0');
                    check(memory.addr = cache.addr);
                    check(memory.en   = cache.en);
                    check(memory.wen  = cache.wen);
                    
                    memory.rdata <= std_logic_vector(to_unsigned(ii, 8 * cCachelineSize_B));
                    memory.valid <= '1';

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    memory.rdata <= std_logic_vector(to_unsigned(ii, 8 * cCachelineSize_B));
                    memory.valid <= '0';

                    check(cache.rdata = memory.rdata);
                    check(cache.valid = '1');
                    cache.en <= '0';
                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;

                info("Demonstration of read hit behavior.");
                for ii in 0 to cCacheSize_entries - 1 loop
                    cache.addr  <= std_logic_vector(to_unsigned(ii * cCachelineSize_B, cAddressWidth_b));
                    cache.en    <= '1';
                    cache.wen   <= (others => '0');
                    cache.wdata <= (others => '0');

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    check(cache_miss = '0');
                    check(cache_hit = '1');
                    check(cache.rdata = std_logic_vector(to_unsigned(ii, 8 * cCachelineSize_B)));
                    check(cache.valid = '1');
                    cache.en <= '0';

                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;

                info("Demonstration of write hit behavior.");
                for ii in 0 to cCacheSize_entries - 1 loop
                    cache.addr  <= std_logic_vector(to_unsigned(ii * cCachelineSize_B, cAddressWidth_b));
                    cache.en    <= '1';
                    cache.wen   <= (others => '1');
                    cache.wdata <= std_logic_vector(to_unsigned(ii, 8 * cCachelineSize_B));

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    check(cache_miss = '0');
                    check(cache_hit = '1');

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    check(cache.rdata = std_logic_vector(to_unsigned(ii, 8 * cCachelineSize_B)));
                    check(cache.valid = '1');
                    cache.en <= '0';

                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;

                info("Demonstration of write miss behavior with dirty cache.");
                for ii in 0 to cCacheSize_entries - 1 loop
                    cache.addr  <= std_logic_vector(to_unsigned((cCacheSize_entries + ii) * cCachelineSize_B, cAddressWidth_b));
                    cache.en    <= '1';
                    cache.wen   <= (others => '1');
                    cache.wdata <= std_logic_vector(to_unsigned(ii, 8 * cCachelineSize_B));

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    check(cache_miss = '1');
                    check(cache_hit = '0');

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    check(cache_miss = '0');
                    check(memory.addr = std_logic_vector(to_unsigned(ii * cCachelineSize_B, cAddressWidth_b)));
                    check(memory.en   = '1');
                    check(memory.wen  = (cCachelineSize_B - 1 downto 0 => '1'));
                    
                    memory.rdata <= (others => '0');
                    memory.valid <= '1';

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    check(memory.addr = cache.addr);
                    check(memory.en   = '1');
                    check(memory.wen  = (cCachelineSize_B - 1 downto 0 => '0'));
                    
                    memory.rdata <= (others => '0');
                    memory.valid <= '1';

                    wait until rising_edge(clk);
                    wait for 100 ps;
                    
                    check(cache.rdata = std_logic_vector(to_unsigned(ii, 8 * cCachelineSize_B)));
                    check(cache.valid = '1');
                    cache.en <= '0';

                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;
            end if;
        end loop;
    
        test_runner_cleanup(runner);
    end process;
    
end architecture tb;