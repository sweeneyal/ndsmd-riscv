library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;

entity FpRegisterFile is
    port (
        i_clk : in std_logic;
        i_resetn : in std_logic;

        i_rs1 : in std_logic_vector(4 downto 0);
        o_opA : out std_logic_vector(63 downto 0);

        i_rs2 : in std_logic_vector(4 downto 0);
        o_opB : out std_logic_vector(63 downto 0);

        i_rs3 : in std_logic_vector(4 downto 0);
        o_opC : out std_logic_vector(63 downto 0);

        i_rd    : in std_logic_vector(4 downto 0);
        i_res   : in std_logic_vector(63 downto 0);
        i_valid : in std_logic
    );
end entity FpRegisterFile;

architecture rtl of FpRegisterFile is
    signal registers : std_logic_matrix_t(0 to 31)(63 downto 0) := (others => (others => '0'));
begin
    
    RegisterImplementation: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                registers <= (others => (others => '0'));
            else
                if (i_valid = '1' and i_rd /= "00000") then
                    registers(to_natural(i_rd)) <= i_res;
                end if;
            end if;
        end if;
    end process RegisterImplementation;

    -- This naively hopes that indexing the registers won't be a critical path...
    -- I guess it's okay for people to have dreams.
    o_opA <= registers(to_natural(i_rs1));
    o_opB <= registers(to_natural(i_rs2));
    o_opC <= registers(to_natural(i_rs3));
    
end architecture rtl;