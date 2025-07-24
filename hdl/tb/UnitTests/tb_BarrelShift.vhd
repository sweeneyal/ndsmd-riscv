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

entity tb_BarrelShift is
    generic (runner_cfg : string);
end entity tb_BarrelShift;

architecture tb of tb_BarrelShift is
    signal right_i : std_logic := '0';
    signal arith_i : std_logic := '0';
    signal opA_i   : std_logic_vector(31 downto 0) := (others => '0');
    signal shamt_i : std_logic_vector(4 downto 0) := (others => '0');
    signal res_o   : std_logic_vector(31 downto 0) := (others => '0');
begin
    
    eDut : entity ndsmd_riscv.BarrelShift
    port map (
        i_right => right_i,
        i_arith => arith_i,
        i_opA   => opA_i,
        i_shamt => shamt_i,
        o_res   => res_o
    );

    Stimuli: process
        variable opA_int : integer;
        variable opB_int : integer;
        variable res     : std_logic_vector(31 downto 0);
        variable RandData : RandomPType;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("t_basic_shift") then
                wait for 100 ps;
                
                for ii in 0 to 99 loop
                    opA_i   <= RandData.RandSlv(x"00000000", x"FFFFFFFF");
                    shamt_i <= RandData.RandSlv("00000", "11111");
                    wait for 100 ps;
                    opA_int := to_integer(opA_i);
                    opB_int := to_natural(shamt_i);
                    res     := std_logic_vector(shift_left(unsigned(opA_i), opB_int));
    
                    check(res = res_o);
                end loop;

                right_i <= '1';
                for ii in 0 to 99 loop
                    opA_i   <= RandData.RandSlv(x"00000000", x"FFFFFFFF");
                    shamt_i <= RandData.RandSlv("00000", "11111");
                    wait for 100 ps;
                    opA_int := to_integer(opA_i);
                    opB_int := to_natural(shamt_i);
                    res     := std_logic_vector(shift_right(unsigned(opA_i), opB_int));
    
                    check(res = res_o);
                end loop;

                arith_i <= '1';
                for ii in 0 to 99 loop
                    opA_i   <= RandData.RandSlv(x"00000000", x"FFFFFFFF");
                    shamt_i <= RandData.RandSlv("00000", "11111");
                    wait for 100 ps;
                    opA_int := to_integer(opA_i);
                    opB_int := to_natural(shamt_i);
                    res     := std_logic_vector(shift_right(signed(opA_i), opB_int));
    
                    check(res = res_o);
                end loop;

                right_i <= '0';
                for ii in 0 to 99 loop
                    opA_i   <= RandData.RandSlv(x"00000000", x"FFFFFFFF");
                    shamt_i <= RandData.RandSlv("00000", "11111");
                    wait for 100 ps;
                    opA_int := to_integer(opA_i);
                    opB_int := to_natural(shamt_i);
                    res     := std_logic_vector(shift_left(signed(opA_i), opB_int));
    
                    check(res = res_o);
                end loop;
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process Stimuli;
    
end architecture tb;