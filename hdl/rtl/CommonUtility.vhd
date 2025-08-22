library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

package CommonUtility is

    subtype byte is std_logic_vector(7 downto 0);
    type std_logic_matrix_t is array (natural range <>) of std_logic_vector;
    
    function clog2(intVal : integer) return integer;
    function reverse (a: in std_logic_vector) return std_logic_vector;

    function to_slv(intVal : integer; size : natural) return std_logic_vector;
    function to_integer(vector : std_logic_vector) return integer;
    function to_natural(vector : std_logic_vector) return natural;
    function to_byte(char : character) return byte;
    function to_char(by : byte) return character;

    function divide(lhs : unsigned; rhs : unsigned) return unsigned;
    function divide(lhs : signed; rhs : signed) return signed;

    function str_eq(str1 : string; str2 : string) return boolean;

    function bool2bit(value: boolean) return std_logic;
    function any(a : std_logic_vector) return std_logic;
    function shape(slv : std_logic_vector; lhdx : natural; rhdx : natural) return std_logic_vector;
    function shape(slv : unsigned; lhdx : natural; rhdx : natural) return unsigned;
    function shape(slv : signed; lhdx : natural; rhdx : natural) return signed;
    
    function cond_select(condition : boolean; if_true : std_logic_vector; if_false : std_logic_vector) return std_logic_vector;
    function cond_select(condition : boolean; if_true : integer; if_false : integer) return integer;

    function find_first_high_bit(slv : std_logic_vector) return natural;
    function find_first_high_bit(slv : unsigned) return natural;
    function find_first_high_bit(slv : signed) return natural;
    
end package CommonUtility;

package body CommonUtility is
    
    function clog2(intVal : integer) return integer is
    begin 
        return integer(ceil(log2(real(intVal))));
    end function;

    function reverse (a: in std_logic_vector) return std_logic_vector is
        variable result: std_logic_vector(a'RANGE);
        alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
    begin
        for i in aa'RANGE loop
            result(i) := aa(i);
        end loop;
        return result;
    end;


    function to_slv(intVal : integer; size : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(intVal, size));
    end function;

    function to_integer(vector : std_logic_vector) return integer is
    begin
        return to_integer(signed(vector));
    end function;

    function to_natural(vector : std_logic_vector) return natural is
    begin
        return to_integer(unsigned(vector));
    end function;

    function str_eq(str1 : string; str2 : string) return boolean is
    begin
        if str1'length /= str2'length then
            return false;
        else
            return (str1 = str2);
        end if;
    end function;

    function to_byte(char : character) return byte is
    begin
        return byte(to_unsigned(character'pos(char), 8));
    end function;

    function to_char(by : byte) return character is
    begin
        return character'val(to_integer(unsigned(by)));
    end function;

    function bool2bit(value : boolean) return std_logic is
    begin
        if value then
            return '1';
        else
            return '0';
        end if;
    end function;

    function any(a : std_logic_vector) return std_logic is
        variable ret : std_logic := '0';
    begin
        for ii in a'range loop
            if (a(ii) = '1') then
                return '1';
            end if;
        end loop;
        return '0';
    end function;

    function shape(slv : std_logic_vector; lhdx : natural; rhdx : natural) return std_logic_vector is
        variable res : std_logic_vector(lhdx downto rhdx);
    begin
        if slv'ascending then
            res := slv(lhdx to rhdx);
        else
            res := slv(lhdx downto rhdx);
        end if;
        return res;
    end function;

    function shape(slv : unsigned; lhdx : natural; rhdx : natural) return unsigned is
        variable res : unsigned(lhdx downto rhdx);
    begin
        if slv'ascending then
            res := slv(lhdx to rhdx);
        else
            res := slv(lhdx downto rhdx);
        end if;
        return res;
    end function;

    function shape(slv : signed; lhdx : natural; rhdx : natural) return signed is
        variable res : signed(lhdx downto rhdx);
    begin
        if slv'ascending then
            res := slv(lhdx to rhdx);
        else
            res := slv(lhdx downto rhdx);
        end if;
        return res;
    end function;

    function cond_select(condition : boolean; if_true : std_logic_vector; if_false : std_logic_vector) return std_logic_vector is
    begin
        if condition then
            return if_true;
        else
            return if_false;
        end if;
    end function;

    function cond_select(condition : boolean; if_true : integer; if_false : integer) return integer is
    begin
        if condition then
            return if_true;
        else
            return if_false;
        end if;
    end function;

    function find_first_high_bit(slv : std_logic_vector) return natural is
        variable slv_v : std_logic_vector(slv'length - 1 downto 0);
    begin
        slv_v := slv;
        for ii in slv_v'length - 1 downto 0 loop
            if slv_v(ii) = '1' then
                return ii;
            end if;
        end loop;
        return 0;
    end function;

    function find_first_high_bit(slv : unsigned) return natural is
        variable slv_v : unsigned(slv'length - 1 downto 0);
    begin
        slv_v := slv;
        for ii in slv_v'length - 1 downto 0 loop
            if slv_v(ii) = '1' then
                return ii;
            end if;
        end loop;
        return 0;
    end function;

    function find_first_high_bit(slv : signed) return natural is
        variable slv_v : signed(slv'length - 1 downto 0);
    begin
        slv_v := slv;
        for ii in slv_v'length - 1 downto 0 loop
            if slv_v(ii) = '1' then
                return ii;
            end if;
        end loop;
        return 0;
    end function;

    function divide(lhs : unsigned; rhs : unsigned) return unsigned is
        variable lhs_ext : unsigned(2 * lhs'length - 1 downto 0) := (others => '0');
        variable rhs_ext : unsigned(2 * rhs'length - 1 downto 0) := (others => '0');
        variable first_set_bit : natural;
        variable fval : unsigned(2 * lhs'length - 1 downto 0) := (others => '0');
        variable two : unsigned(2 * lhs'length - 1 downto 0);
    begin
        -- Convert to 2*LEN for resolution
        lhs_ext(2 * lhs'length - 1 downto lhs'length) := lhs;
        rhs_ext(2 * lhs'length - 1 downto lhs'length) := rhs;

        -- Shift right by MSB to make values easier
        first_set_bit := find_first_high_bit(rhs);
        lhs_ext := shift_right(lhs_ext, first_set_bit);
        rhs_ext := shift_right(rhs_ext, first_set_bit);

        -- Implement Goldschmidt division.
        two := to_unsigned(2, lhs'length) & (lhs'length - 1 downto 0 => '0');
        for ii in 0 to natural(ceil(log2(real(lhs_ext'length)/(log2(17.0))))) loop
            fval    := two - rhs_ext;
            lhs_ext := shape(lhs_ext * fval, lhs_ext'length + lhs'length - 1, lhs'length);
            rhs_ext := shape(rhs_ext * fval, lhs_ext'length + lhs'length - 1, lhs'length);
        end loop;

        -- Return numerator
        return lhs_ext(lhs_ext'length - 1 downto lhs'length);
    end function;

    function divide(lhs : signed; rhs : signed) return signed is
        variable lhs_int : unsigned(lhs'length - 1 downto 0);
        variable rhs_int : unsigned(rhs'length - 1 downto 0);
        variable res : unsigned(rhs'length - 1 downto 0);
    begin
        -- Convert back to unsigned absolute value
        if (lhs(lhs'length - 1) = '1') then
            lhs_int := unsigned(-lhs);
        else
            lhs_int := unsigned(lhs);
        end if;

        if (rhs(lhs'length - 1) = '1') then
            rhs_int := unsigned(-rhs);
        else
            rhs_int := unsigned(rhs);
        end if;

        -- Perform unsigned division
        res := divide(lhs_int, rhs_int);

        -- Pick sign based on if signs are different.
        if (lhs(lhs'length - 1) = '1' xor rhs(lhs'length - 1) = '1') then
            return -signed(res);
        else
            return signed(res);
        end if;
    end function;

    
end package body CommonUtility;