library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package FpUtility is
    
    type single_precision_t is record
        signb    : std_logic;
        exponent : unsigned(7 downto 0);
        fraction : unsigned(22 downto 0);
        implicit : std_logic;
    end record single_precision_t;

    type double_precision_t is record
        signb    : std_logic;
        exponent : unsigned(10 downto 0);
        fraction : unsigned(51 downto 0);
        implicit : std_logic;
    end record double_precision_t;

    function to_single_precision(s : std_logic_vector(31 downto 0)) return single_precision_t;
    function to_double_precision(s : std_logic_vector(63 downto 0)) return double_precision_t;

    function convert_single_to_double(s : single_precision_t) return double_precision_t;

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
        return v;
    end function;

    function to_double_precision(s : std_logic_vector(63 downto 0)) return double_precision_t is
        variable d : double_precision_t;
    begin
        d.signb    := s(63);
        d.exponent := unsigned(s(62 downto 52));
        d.fraction := unsigned(s(51 downto 0));
        d.implicit := '1';
        return d;
    end function;

    function convert_single_to_double(s : single_precision_t) return double_precision_t is
        variable d : double_precision_t;
    begin
        d.signb    := s.signb;
        d.exponent := resize(s.exponent, 11) - 127 + 1023;
        d.fraction := s.fraction & (29 downto 0 => '0');
        d.implicit := s.implicit;
        return d;
    end function;
    
end package body FpUtility;