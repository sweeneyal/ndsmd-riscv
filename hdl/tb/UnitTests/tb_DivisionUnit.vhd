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
    use universal.CommonTypes.all;

library ndsmd_riscv;

entity tb_DivisionUnit is
    generic (runner_cfg : string);
end entity tb_DivisionUnit;

architecture tb of tb_DivisionUnit is
    signal clk      : std_logic := '0';
    signal resetn   : std_logic := '0';
    signal en       : std_logic := '0';
    signal issigned : std_logic := '0';
    signal opA      : std_logic_vector(31 downto 0) := (others => '0');
    signal opB      : std_logic_vector(31 downto 0) := (others => '0');
    signal funct3   : std_logic_vector(2 downto 0) := (others => '0');
    signal dresult  : std_logic_vector(31 downto 0) := (others => '0');
    signal rresult  : std_logic_vector(31 downto 0) := (others => '0');
    signal ddone    : std_logic := '0';
    signal error_o  : std_logic := '0';
begin
    
    CreateClock(clk=>clk, period=>5 ns);

    eDut : entity ndsmd_riscv.DivisionUnit
    port map (
        i_clk    => clk,
        i_resetn => resetn,
        i_en     => en,
        i_signed => issigned,
        i_num    => opA,
        i_denom  => opB,
        o_div    => dresult,
        o_rem    => rresult,
        o_error  => error_o,
        o_valid  => ddone
    );

    Stimuli: process
        variable opA_int : integer;
        variable opB_int : integer;
        variable div     : std_logic_vector(31 downto 0);
        variable rrem    : std_logic_vector(31 downto 0);
        variable RandData : RandomPType;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("t_basic_division") then
                wait until rising_edge(clk);
                wait for 100 ps;
                en      <= '1';
                resetn  <= '1';
                opA     <= RandData.RandSlv(x"00000001", x"0FFFFFFF");
                opB     <= RandData.RandSlv(x"00000001", x"0FFFFFFF");
                wait for 100 ps;
                opA_int := to_integer(opA);
                opB_int := to_integer(opB);
                div     := to_slv(opA_int/opB_int, 32);
                rrem    := to_slv(opA_int rem opB_int, 32);
                wait until ddone = '1';

                check(ddone = '1');
                -- Error occurs because these are not equal to the expected. Fix this;
                check(div   = dresult);
                check(rrem  = rresult);
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process Stimuli;
    
end architecture tb;