library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.FpUtility.all;

entity DoubleDivider is
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
end entity DoubleDivider;

architecture rtl of DoubleDivider is
    signal opA          : double_precision_t;
    signal opB          : double_precision_t;
    signal fmt          : fp_format_t;
    signal func         : operation_t;
    signal div_valid    : std_logic := '0';
    signal valid        : std_logic := '0';
    signal fracA        : std_logic_vector(55 downto 0) := (others => '0');
    signal fracB        : std_logic_vector(55 downto 0) := (others => '0');
    signal div          : std_logic_vector(55 downto 0) := (others => '0');

    type state_t is (IDLE, PERFORM_DIVISION, WAIT_FOR_DIV_DONE, APPLY_ROUNDING, DONE);
    signal state : state_t := IDLE;
begin
    
    eDivider : entity ndsmd_riscv.DivisionUnit
    generic map (
        cDataWidth_b => 56,
        cIsIntegerDivision => false
    ) port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,
        i_en     => div_valid,
        i_signed => '0',
        i_num    => fracA,
        i_denom  => fracB,
        o_div    => div,
        o_rem    => open,
        o_error  => open,
        o_valid  => valid
    );

    StateMachine: process(i_clk)
        variable exponent : unsigned(10 downto 0) := (others => '0');
        variable shift    : integer range -1 to 1 := 0;
        variable frac     : unsigned(55 downto 0) := (others => '0');
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
                        if (i_valid = '1' and (i_func = FP_DIV)) then
                            fmt  <= i_fmt;
                            func <= i_func;
                            if (i_fmt = SINGLE_PRECISION) then
                                opA <= convert_single_to_double(to_single_precision(i_opA(31 downto 0)));
                                opB <= convert_single_to_double(to_single_precision(i_opB(31 downto 0)));
                            elsif (i_fmt = DOUBLE_PRECISION) then
                                opA <= to_double_precision(i_opA);
                                opB <= to_double_precision(i_opB);
                            end if;

                            state <= PERFORM_DIVISION;
                        end if;

                    when PERFORM_DIVISION =>
                        if (opA.signb = opB.signb) then
                            opA.signb <= '0';
                        else
                            opA.signb <= '1';
                        end if;

                        if (opA.fraction < opB.fraction) then
                            opA.exponent <= (opA.exponent - 1023) - (opB.exponent - 1023) + 1023 - 1;
                        else
                            opA.exponent <= (opA.exponent - 1023) - (opB.exponent - 1023) + 1023;
                        end if;


                        fracA     <= std_logic_vector(opA.implicit & opA.fraction & opA.rounding);
                        fracB     <= std_logic_vector(opB.implicit & opB.fraction & opB.rounding);
                        div_valid <= '1';

                        state <= WAIT_FOR_DIV_DONE;

                    when WAIT_FOR_DIV_DONE =>
                        -- the input range is ~1.0000 to ~1.9999, so we will 
                        -- see results anywhere from ~0.5000 to ~1.9999 
                        div_valid <= '0';
                        if (valid = '1') then
                            shift := find_first_high_bit(div(55 downto 54)) - 1;
                            if (shift < 0) then
                                frac := shift_left_mantissa(unsigned(div), 1);
                                opA.exponent <= opA.exponent - 1;
                            else
                                frac := unsigned(div);
                            end if;
                            -- This may not be correct rounding. Figure out how floating point
                            -- rounding actually works.
                            opA.fraction <= frac(54 downto 3);
                            state        <= APPLY_ROUNDING;
                        end if;

                    when APPLY_ROUNDING =>
                        -- if rm = RNE
                        -- Rounding done according to guard-round-sticky
                        -- https://drilian.com/posts/2023.01.10-floating-point-numbers-and-rounding/
                        opA.fraction <= opA.fraction + (opA.rounding(2) and (opA.rounding(1) or opA.rounding(0)));
                        state <= DONE;

                    when DONE =>
                        if (fmt = SINGLE_PRECISION) then
                            exponent := opA.exponent - 1023 + 127;
                            o_res <= cNegativeQuietNaN_float & 
                                opA.signb & 
                                std_logic_vector(exponent(7 downto 0)) & 
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