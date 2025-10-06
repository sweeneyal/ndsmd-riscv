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
    use ndsmd_riscv.InstructionUtility.all;

entity tb_DoubleMultiplier is
    generic (runner_cfg : string);
end entity tb_DoubleMultiplier;

architecture tb of tb_DoubleMultiplier is
    -- https://weitz.de/ieee/
    constant cPeriod : time := 10 ns;
    signal clk      : std_logic := '0';
    signal resetn   : std_logic := '0';
    signal func     : operation_t := NULL_OP;
    signal fmt      : fp_format_t := SINGLE_PRECISION;
    signal opA      : std_logic_vector(63 downto 0) := (others => '0');
    signal opB      : std_logic_vector(63 downto 0) := (others => '0');
    signal valid_i  : std_logic := '0';
    signal res      : std_logic_vector(63 downto 0) := (others => '0');
    signal valid_o  : std_logic := '0';
begin
    
    CreateClock(clk=>clk, period=>cPeriod);

    eDut : entity ndsmd_riscv.DoubleMultiplier
    port map (
        i_clk    => clk,
        i_resetn => resetn,

        i_func  => func,
        i_fmt   => fmt,
        i_opA   => opA,
        i_opB   => opB,
        i_valid => valid_i,

        o_res   => res,
        o_valid => valid_o
    );

    TestRunner : process
        variable v : natural := 0;
    begin
        test_runner_setup(runner, runner_cfg);
  
        while test_suite loop
            if run("t_multiplier_demonstration") then
                info("Running basic demonstration.");
                resetn <= '0';
                wait until rising_edge(clk);
                wait for 100 ps;
                resetn <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;
                opA     <= x"3FF23D70A3D70A3D";
                opB     <= x"BFF428F5C28F5C29";
                valid_i <= '1';
                func    <= FP_MUL;
                fmt     <= DOUBLE_PRECISION;

                wait until rising_edge(clk);
                wait for 100 ps;
                valid_i <= '0';

                wait until valid_o = '1';
                wait for 100 ps;
                check(res = x"BFF6FB7E90FF9724");
            elsif run("t_single_precision_demo") then
                check(false);
            end if;
        end loop;
    
        test_runner_cleanup(runner);
    end process;
    
    test_runner_watchdog(runner, 10 us);

end architecture tb;

