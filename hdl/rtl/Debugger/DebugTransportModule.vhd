library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

library ndsmd_riscv;
    use ndsmd_riscv.DebugUtility.all;

entity DebugTransportModule is
    port (        
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_tck   : in std_logic;
        i_tms   : in std_logic;
        i_tdi   : in std_logic;
        o_tdo   : out std_logic;

        o_dmi_en    : out std_logic;
        o_dmi_op    : out dmi_op_t;
        o_dmi_addr  : out std_logic_vector(6 downto 0);
        o_dmi_wdata : out std_logic_vector(31 downto 0);
        i_dmi_rdata : in std_logic_vector(31 downto 0);
        i_dmi_valid : in std_logic
    );
end entity DebugTransportModule;

architecture rtl of DebugTransportModule is

begin
    
    
    
end architecture rtl;