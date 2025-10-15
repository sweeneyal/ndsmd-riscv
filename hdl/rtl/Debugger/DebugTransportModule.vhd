library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

entity DebugTransportModule is
    port (        
        i_tck   : in std_logic;
        i_reset : in std_logic;
        i_tdi   : in std_logic;
        o_tdo   : out std_logic;
        i_tms   : in std_logic;

        i_capture : in std_logic;
        i_shift   : in std_logic;
        i_sel     : in std_logic;
        i_drck    : in std_logic;
        i_runtest : in std_logic;
        i_update  : in std_logic;

        i_clk : in std_logic

    );
end entity DebugTransportModule;

architecture rtl of DebugTransportModule is
    
begin
    
    
    
end architecture rtl;