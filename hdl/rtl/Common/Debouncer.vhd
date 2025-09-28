library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity Debouncer is
    generic (
        cDebounceTime_cc : natural := 100000
    );
    port (
        i_clk : in std_logic;
        i_sig : in std_logic;
        o_sig : out std_logic
    );
end entity Debouncer;

architecture rtl of Debouncer is
    signal sig : std_logic_vector(1 downto 0);
begin
    
    StateMachine: process(i_clk)
        variable counter : natural range 0 to cDebounceTime_cc;
    begin
        if rising_edge(i_clk) then
            sig(0) <= i_sig;
            sig(1) <= sig(0);
            if (sig(0) = sig(1)) then
                if (counter = cDebounceTime_cc) then
                    o_sig <= sig(0);
                else
                    counter := counter + 1;
                end if;
            else
                counter := 0;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;