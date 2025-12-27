library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;
    use nsfrtu_riscv.InstructionUtility.all;
    use nsfrtu_riscv.FpUtility.all;

entity DoubleAdder is
    port (
        i_clk : in std_logic;
        i_resetn : in std_logic;

        i_func  : in operation_t;
        i_fmt   : in fp_format_t;
        i_opA   : in std_logic_vector(63 downto 0);
        i_opB   : in std_logic_vector(63 downto 0);
        i_valid : in std_logic;

        o_res   : out std_logic_vector(63 downto 0);
        o_valid : out std_logic
    );
end entity DoubleAdder;

architecture rtl of DoubleAdder is
    signal opA  : double_precision_t;
    signal opB  : double_precision_t;
    signal fmt  : fp_format_t;
    signal func : operation_t;

    type state_t is (IDLE, SHIFT_LOWEST, ADD_FRACTIONS, POST_PROCESS, APPLY_ROUNDING, DONE);
    signal state : state_t := IDLE;
begin

    StateMachine: process(i_clk)
        variable shift        : unsigned(10 downto 0) := (others => '0');
        variable frac_shifted : unsigned(55 downto 0) := (others => '0');
        variable frac         : signed(56 downto 0) := (others => '0');
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                opA   <= to_double_precision(x"0000000000000000");
                opB   <= to_double_precision(x"0000000000000000");
                fmt   <= SINGLE_PRECISION;
                func  <= NULL_OP;
                state <= IDLE;
                o_valid <= '0';
            else
                o_valid <= '0';
                
                case state is
                    when IDLE =>
                        if (i_valid = '1' and (i_func = FP_ADD or i_func = FP_SUB)) then
                            fmt  <= i_fmt;
                            func <= i_func;
                            if (i_fmt = SINGLE_PRECISION) then
                                opA <= convert_single_to_double(to_single_precision(i_opA(31 downto 0)));
                                opB <= convert_single_to_double(to_single_precision(i_opB(31 downto 0)));
                            elsif (i_fmt = DOUBLE_PRECISION) then
                                opA <= to_double_precision(i_opA);
                                opB <= to_double_precision(i_opB);
                            end if;

                            state <= SHIFT_LOWEST;
                        end if;
                    
                    when SHIFT_LOWEST =>
                        -- This needs to be optimized for area. This implements two barrel shifters, 
                        -- one for A, and one for B. Having two barrel shifters will inflate the area 
                        -- utilization.

                        if (opA.exponent > opB.exponent) then
                            shift := opA.exponent - opB.exponent;
                            frac_shifted := shift_right_mantissa(opB.implicit & opB.fraction & opB.rounding, to_integer(shift));
                            opB.implicit <= frac_shifted(55);
                            opB.fraction <= frac_shifted(54 downto 3);
                            opB.rounding <= frac_shifted(2 downto 0);
                            opB.exponent <= opA.exponent;
                        else
                            shift := opB.exponent - opA.exponent;
                            frac_shifted := shift_right_mantissa(opA.implicit & opA.fraction & opA.rounding, to_integer(shift));
                            report to_hstring(std_logic_vector(frac_shifted));
                            opA.implicit <= frac_shifted(55);
                            opA.fraction <= frac_shifted(54 downto 3);
                            opA.rounding <= frac_shifted(2 downto 0);
                            opA.exponent <= opB.exponent;
                        end if;

                        state <= ADD_FRACTIONS;

                    when ADD_FRACTIONS =>
                        if (opA.signb = '1') then
                            frac := -signed('0' & opA.implicit & opA.fraction & opA.rounding);
                        else
                            frac := signed('0' & opA.implicit & opA.fraction & opA.rounding);
                        end if;

                        if (func = FP_ADD) then
                            if (opB.signb = '1') then
                                frac := frac - signed('0' & opB.implicit & opB.fraction & opB.rounding);
                            else
                                frac := frac + signed('0' & opB.implicit & opB.fraction & opB.rounding);
                            end if;
                        elsif (func = FP_SUB) then
                            if (opB.signb = '1') then
                                frac := frac + signed('0' & opB.implicit & opB.fraction & opB.rounding);
                            else
                                frac := frac - signed('0' & opB.implicit & opB.fraction & opB.rounding);
                            end if;
                        end if;

                        state <= POST_PROCESS;

                    when POST_PROCESS =>
                        -- If the sign bit is '1', meaning negative:
                        opA.signb <= frac(56);
                        if (frac(56) = '1') then
                            -- Negate the fraction to make it positive again
                            frac := -(frac);
                        end if;
                        
                        -- if the implicit one bit is '0', we need to shift the exponent 
                        -- to get the implicit one back.
                        report to_hstring(std_logic_vector(frac));
                        if (frac(55) = '0') then
                            shift := to_unsigned(55 - find_first_high_bit(frac(54 downto 0)), 11);
                            opA.exponent <= opA.exponent - shift;
                            frac_shifted := shift_left_mantissa(unsigned(frac(55 downto 0)), to_integer(shift));
                        end if;
                        report to_hstring(std_logic_vector(frac_shifted));
                        opA.implicit <= frac_shifted(55);
                        opA.fraction <= frac_shifted(54 downto 3);
                        opA.rounding <= frac_shifted(2 downto 0);

                        state <= APPLY_ROUNDING;

                    when APPLY_ROUNDING =>
                        -- if rm = RNE
                        -- Rounding done according to guard-round-sticky
                        -- https://drilian.com/posts/2023.01.10-floating-point-numbers-and-rounding/
                        opA.fraction <= opA.fraction + (opA.rounding(2) and (opA.rounding(1) or opA.rounding(0)));
                        state <= DONE;

                    when DONE =>
                        if (fmt = SINGLE_PRECISION) then
                            shift := opA.exponent - 1023 + 127;
                            o_res <= cNegativeQuietNaN_float & 
                                opA.signb & 
                                std_logic_vector(shift(7 downto 0)) & 
                                std_logic_vector(opA.fraction(51 downto 29));
                        else
                            o_res <= opA.signb & 
                                std_logic_vector(opA.exponent) & 
                                std_logic_vector(opA.fraction);
                        end if;
                        o_valid <= '1';
                        state   <= IDLE;

                end case;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;