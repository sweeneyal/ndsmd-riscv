library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.FpUtility.all;

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

    type state_t is (IDLE, SHIFT_LOWEST, ADD_FRACTIONS, POST_PROCESS, DONE);
    signal state : state_t := IDLE;
begin

    StateMachine: process(i_clk)
        variable shift        : unsigned(10 downto 0) := (others => '0');
        variable frac_shifted : unsigned(52 downto 0) := (others => '0');
        variable frac         : signed(53 downto 0) := (others => '0');
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                opA   <= to_double_precision(x"0000000000000000");
                opB   <= to_double_precision(x"0000000000000000");
                fmt   <= SINGLE_PRECISION;
                func  <= NULL_OP;
                state <= IDLE;
            else
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
                            frac_shifted := shift_right(opB.implicit & opB.fraction, to_integer(shift));
                            opB.fraction <= frac_shifted(51 downto 0);
                            opB.exponent <= opA.exponent;

                            if (shift > 0) then
                                opB.implicit <= '0';
                            end if;
                        else
                            shift := opB.exponent - opA.exponent;
                            frac_shifted := shift_right(opA.implicit & opA.fraction, to_integer(shift));
                            opA.fraction <= frac_shifted(51 downto 0);
                            opA.exponent <= opB.exponent;

                            if (shift > 0) then
                                opA.implicit <= '0';
                            end if;
                        end if;

                        state <= ADD_FRACTIONS;

                    when ADD_FRACTIONS =>
                        if (opA.signb = '1') then
                            frac := -signed('0' & opA.implicit & opA.fraction);
                        else
                            frac := signed('0' & opA.implicit & opA.fraction);
                        end if;

                        if (func = FP_ADD) then
                            if (opB.signb = '1') then
                                frac := frac - signed('0' & opB.implicit & opB.fraction);
                            else
                                frac := frac + signed('0' & opB.implicit & opB.fraction);
                            end if;
                        elsif (func = FP_SUB) then
                            if (opB.signb = '1') then
                                frac := frac + signed('0' & opB.implicit & opB.fraction);
                            else
                                frac := frac - signed('0' & opB.implicit & opB.fraction);
                            end if;
                        end if;

                        state <= POST_PROCESS;

                    when POST_PROCESS =>
                        -- If the sign bit is '1', meaning negative:
                        opA.signb <= frac(53);
                        if (frac(53) = '1') then
                            -- Negate the fraction to make it positive again
                            frac := -(frac);
                            -- if the implicit one bit is '0', we need to shift the exponent 
                            -- to get the implicit one back.
                            if (frac(52) = '0') then
                                shift := to_unsigned(52 - find_first_high_bit(frac(51 downto 0)), 11);
                                opA.exponent <= opA.exponent - shift;
                            end if;
                            opA.fraction <= shift_left(unsigned(frac(51 downto 0)), to_integer(shift));
                        end if;

                        state <= DONE;

                    when DONE =>
                        if (fmt = SINGLE_PRECISION) then
                            shift := opA.exponent - 1023 + 127;
                            o_res <= cNegativeQuietNaN_float & 
                                opA.signb & 
                                std_logic_vector(shift(7 downto 0)) & 
                                std_logic_vector(opA.fraction(51 downto 29));
                        elsif (fmt = DOUBLE_PRECISION) then
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