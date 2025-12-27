library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;

package FpUtility is
    
    type single_precision_t is record
        signb    : std_logic;
        exponent : unsigned(7 downto 0);
        implicit : std_logic;
        fraction : unsigned(22 downto 0);
        rounding : unsigned(2 downto 0);
    end record single_precision_t;

    type double_precision_t is record
        signb    : std_logic;
        exponent : unsigned(10 downto 0);
        implicit : std_logic;
        fraction : unsigned(51 downto 0);
        rounding : unsigned(2 downto 0);
    end record double_precision_t;

    type rounding_mode_t is (RNE, RTZ, RDN, RUP, RMM, RES0, RES1, DYN);

    type fpu_status_t is record
        invalid_operation : std_logic;
        divide_by_zero    : std_logic;
        overflow          : std_logic;
        underflow         : std_logic;
        inexact           : std_logic;
    end record fpu_status_t;

    function to_single_precision(s : std_logic_vector(31 downto 0)) return single_precision_t;
    function to_double_precision(s : std_logic_vector(63 downto 0)) return double_precision_t;

    function convert_single_to_double(s : single_precision_t) return double_precision_t;

    function shift_left_mantissa(m : unsigned(55 downto 0); shamt : natural) return unsigned;
    function shift_right_mantissa(m : unsigned(55 downto 0); shamt : natural) return unsigned;

    constant cNegativeQuietNaN_float : std_logic_vector(31 downto 0) := "11111111101000000000000000000000";
    
end package FpUtility;

package body FpUtility is
    
    function to_single_precision(s : std_logic_vector(31 downto 0)) return single_precision_t is
        variable v : single_precision_t;
    begin
        v.signb    := s(31);
        v.exponent := unsigned(s(30 downto 23));
        v.fraction := unsigned(s(22 downto 0));
        v.implicit := '1';
        v.rounding := "000";
        return v;
    end function;

    function to_double_precision(s : std_logic_vector(63 downto 0)) return double_precision_t is
        variable d : double_precision_t;
    begin
        d.signb    := s(63);
        d.exponent := unsigned(s(62 downto 52));
        d.fraction := unsigned(s(51 downto 0));
        d.implicit := '1';
        d.rounding := "000";
        return d;
    end function;

    function convert_single_to_double(s : single_precision_t) return double_precision_t is
        variable d : double_precision_t;
    begin
        d.signb    := s.signb;
        d.exponent := resize(s.exponent, 11) - 127 + 1023;
        d.fraction := s.fraction & s.rounding & (26 downto 0 => '0');
        d.implicit := s.implicit;
        d.rounding := (others => '0');
        return d;
    end function;

    function shift_left_mantissa(m : unsigned(55 downto 0); shamt : natural) return unsigned is
        variable mprime : unsigned(55 downto 0);
    begin
        for ii in 55 downto 0 loop
            if ((ii - shamt) >= 0) then
                mprime(ii) := m(ii - shamt);
            else
                -- Preserve the sticky bit
                mprime(ii) := m(0);
            end if;
        end loop;
        return mprime;
    end function;

    function shift_right_mantissa(m : unsigned(55 downto 0); shamt : natural) return unsigned is
        variable mprime : unsigned(55 downto 0);
    begin
        mprime := (others => '0');
        mprime(55 - shamt downto 0) := m(55 downto shamt);
        mprime(0) := any(std_logic_vector(m(shamt - 1 downto 0)));
        return mprime;
    end function;
    
end package body FpUtility;