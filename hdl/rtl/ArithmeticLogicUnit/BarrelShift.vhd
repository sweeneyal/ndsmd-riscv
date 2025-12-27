library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;

entity BarrelShift is
    port (
        i_right  : in std_logic;
        i_arith  : in std_logic;
        i_opA    : in std_logic_vector(31 downto 0);
        i_shamt  : in std_logic_vector(4 downto 0);
        o_res    : out std_logic_vector(31 downto 0)
    );
end entity BarrelShift;

architecture rtl of BarrelShift is
    constant cXlen : natural := 32;
    constant cNumStages : natural := clog2(cXlen);
    signal bs_level : std_logic_matrix_t(0 to cNumStages)(31 downto 0);
    signal bs_sign  : std_logic;
begin
    
    -- Barrel shifter is taken from rktcpu, which I got working the first time,
    -- I'm not prepared at this time to make this use the new instruction
    -- record and its enums.

    -- bs_sign     <= i_opA(31) and i_arith;
    -- bs_level(0) <= cond_select(i_right = '1', i_opA, reverse(i_opA));

    -- gBarrelShifter: for g_ii in 0 to cNumStages - 1 generate
    --     bs_level(g_ii + 1)((cXlen - 1) downto cXlen - (2 ** g_ii)) <= 
    --         cond_select(i_shamt(g_ii) = '1', 
    --             ((cXlen - 1) downto cXlen-(2** g_ii) => bs_sign), 
    --             bs_level(g_ii)((cXlen - 1) downto cXlen-(2** g_ii)));

    --     bs_level(g_ii + 1)((cXlen - (2 ** g_ii)) - 1 downto 0) <= 
    --         cond_select(i_shamt(g_ii) = '1', 
    --             bs_level(g_ii)((cXlen - 1) downto 2 ** g_ii), 
    --             bs_level(g_ii)((cXlen - (2** g_ii))-1 downto 0));
    -- end generate gBarrelShifter;

    ShiftImplementation: process(i_right, i_arith, i_opA, i_shamt)
    begin
        if (i_right = '1') then
            if (i_arith = '1') then
                o_res <= std_logic_vector(shift_right(signed(i_opA), to_natural(i_shamt)));
            else
                o_res <= std_logic_vector(shift_right(unsigned(i_opA), to_natural(i_shamt)));
            end if;
        else
            o_res <= std_logic_vector(shift_left(unsigned(i_opA), to_natural(i_shamt)));
        end if;
    end process ShiftImplementation;
    
end architecture rtl;