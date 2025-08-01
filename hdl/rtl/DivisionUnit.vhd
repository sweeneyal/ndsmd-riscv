library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

entity DivisionUnit is
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;
        i_en     : in std_logic;
        i_signed : in std_logic;
        i_num    : in std_logic_vector(31 downto 0);
        i_denom  : in std_logic_vector(31 downto 0);
        o_div    : out std_logic_vector(31 downto 0);
        o_rem    : out std_logic_vector(31 downto 0);
        o_error  : out std_logic;
        o_valid  : out std_logic
    );
end entity DivisionUnit;

architecture rtl of DivisionUnit is
    constant cConstOne : unsigned(63 downto 0) := x"0000000100000000";
    constant cConstTwo : unsigned(63 downto 0) := x"0000000200000000";

    signal num_product    : unsigned(127 downto 0) := (others => '0');
    signal den_product    : unsigned(127 downto 0) := (others => '0');
    signal num_product_s0 : unsigned(127 downto 0) := (others => '0');
    signal den_product_s0 : unsigned(127 downto 0) := (others => '0');
    signal num_product_s1 : unsigned(127 downto 0) := (others => '0');
    signal den_product_s1 : unsigned(127 downto 0) := (others => '0');

    signal valid       : std_logic := '0';
    signal valid_s0    : std_logic := '0';
    signal valid_s1    : std_logic := '0';
    signal stage1_done : std_logic := '0';

    type state_t is (IDLE, EXTEND, STAGE0, STAGE1, POST_PROCESS, DONE);
    type gdu_engine_t is record
        state  : state_t;
        num    : unsigned(63 downto 0);
        snum   : std_logic;
        denom  : unsigned(63 downto 0);
        sden   : std_logic;
        cnum   : unsigned(31 downto 0);
        cdenom : unsigned(31 downto 0);
        remdr  : unsigned(31 downto 0);
        fval   : unsigned(63 downto 0);
        iter   : natural range 0 to 4;
    end record gdu_engine_t;
    signal gdu_engine : gdu_engine_t;

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
begin
    
    Multiplier: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                num_product_s0 <= (others => '0');
                den_product_s0 <= (others => '0');

                -- num_product_s1 <= (others => '0');
                -- den_product_s1 <= (others => '0');

                num_product <= (others => '0');
                den_product <= (others => '0');
            else
                valid_s0       <= valid;
                num_product_s0 <= gdu_engine.num * gdu_engine.fval;
                den_product_s0 <= gdu_engine.denom * gdu_engine.fval;

                -- Uncomment these if we plan to use a three stage
                -- multiplier instead of a two stage.
                
                -- valid_s1       <= valid_s0;
                -- num_product_s1 <= num_product_s0;
                -- den_product_s1 <= den_product_s0;

                -- stage1_done <= valid_s1;
                -- num_product <= num_product_s1;
                -- den_product <= den_product_s1;

                stage1_done <= valid_s0;
                num_product <= num_product_s0;
                den_product <= den_product_s0;
            end if;
        end if;
    end process Multiplier;

    DivisionAlgorithm: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                gdu_engine.state <= IDLE;
                gdu_engine.iter  <= 0;
                gdu_engine.fval  <= (others => '0');
                o_error          <= '0';
                valid            <= '0';
            else
                case gdu_engine.state is
                    when IDLE =>
                        -- If enable is high, start the calculation process.
                        if (i_en = '1') then
                            gdu_engine.state <= EXTEND;
    
                            -- If we're provided signed numbers, convert them to their unsigned numbers.
                            if (i_signed = '1' and i_num(31) = '1') then
                                gdu_engine.num  <= unsigned(-signed(i_num)) & x"00000000";
                                gdu_engine.snum <= '1';
    
                                -- Preserve original numerator for remainder calculation.
                                gdu_engine.cnum <= unsigned(-signed(i_num));
                            else
                                gdu_engine.num  <= unsigned(i_num) & x"00000000";
                                gdu_engine.snum <= '0';
    
                                -- Preserve original numerator for remainder calculation.
                                gdu_engine.cnum <= unsigned(i_num);
                            end if;
        
                            if (i_signed = '1' and i_denom(31) = '1') then
                                gdu_engine.denom <= unsigned(-signed(i_denom)) & x"00000000";
                                gdu_engine.sden  <= '1';
        
                                -- Preserve original denominator for remainder calculation.
                                gdu_engine.cdenom <= unsigned(-signed(i_denom));
                            else
                                gdu_engine.denom <= unsigned(i_denom) & x"00000000";
                                gdu_engine.sden  <= '0';
        
                                -- Preserve original denominator for remainder calculation.
                                gdu_engine.cdenom <= unsigned(i_denom);
                            end if;
                        end if;
    
                        -- Reset the iteration and fval signals.
                        gdu_engine.iter  <= 0;
                        gdu_engine.fval  <= (others => '0');
                        o_error <= '0';
    
                    when EXTEND =>
                        -- If we're attempting to divide by zero, dont, and error.
                        if (gdu_engine.denom = 0) then
                            gdu_engine.state <= IDLE;
                            o_error <= '1';
                        else
                            gdu_engine.state <= STAGE0;
                        end if;
    
                        -- Shift the numerator and denominator right to get them in the bound of 0 to 1.
                        gdu_engine.num <= shift_right(gdu_engine.num, 
                                            find_first_high_bit(std_logic_vector(gdu_engine.denom(63 downto 32))));
                        gdu_engine.denom <= shift_right(gdu_engine.denom, 
                                            find_first_high_bit(std_logic_vector(gdu_engine.denom(63 downto 32))));
    
                    when STAGE0 =>
                        -- If we're not at iter 4, calcuate a new fval number and use that to calculate a
                        -- new numerator and denominator.
                        if (gdu_engine.iter < 4) then
                            valid <= '1';
    
                            gdu_engine.fval  <= cConstTwo - gdu_engine.denom;
                            gdu_engine.state <= STAGE1;
                            gdu_engine.iter  <= gdu_engine.iter + 1;
                        else
                            gdu_engine.state <= POST_PROCESS;
                            -- Do remainder calculation here.
                            gdu_engine.remdr <= gdu_engine.cnum - shape(gdu_engine.num(63 downto 32) * gdu_engine.cdenom, 31, 0);
                        end if;
                        
                    when STAGE1 =>
                        valid <= '0';
    
                        if (stage1_done = '1') then
                            gdu_engine.state <= STAGE0;
                            gdu_engine.num   <= num_product(95 downto 32);
                            gdu_engine.denom <= den_product(95 downto 32);
                        end if;
    
                    when POST_PROCESS =>
                        -- If the input signs were both negative or both positive, the numbers stay as is.
                        -- Otherwise, convert back to signed, make them negative, and then cast as unsigned.
                        gdu_engine.state <= DONE;
                        if gdu_engine.snum /= gdu_engine.sden then
                            gdu_engine.num <= unsigned(-signed(gdu_engine.num));
                            gdu_engine.remdr <= unsigned(-signed(gdu_engine.remdr));
                        end if;
                        
                    when DONE =>
                        -- Wait until the enable signal is lifted to avoid recalculating.
                        if (i_en = '0') then
                            gdu_engine.state <= IDLE;
                        end if;
    
                    when others =>
                        gdu_engine.state <= IDLE;
                        
                end case;
            end if;
        end if;
    end process DivisionAlgorithm;

    o_rem   <= std_logic_vector(gdu_engine.remdr);
    o_div   <= std_logic_vector(gdu_engine.num(63 downto 32));
    o_valid <= bool2bit(gdu_engine.state = DONE);
    
    
end architecture rtl;