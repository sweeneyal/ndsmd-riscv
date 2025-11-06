library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

library ndsmd_riscv;
    use ndsmd_riscv.DebugUtility.all;

entity DebugModule is
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_dmi_en    : in std_logic;
        i_dmi_op    : in dmi_op_t;
        i_dmi_addr  : in std_logic_vector(6 downto 0);
        i_dmi_wdata : in std_logic_vector(31 downto 0);
        o_dmi_rdata : out std_logic_vector(31 downto 0);
        o_dmi_valid : out std_logic;

        o_reg_addr  : out std_logic_vector(8 downto 0);
        o_reg_en    : out std_logic;
        o_reg_wen   : out std_logic;
        o_reg_wdata : out std_logic_vector(31 downto 0);
        i_reg_rdata : in std_logic_vector(31 downto 0)
    );
end entity DebugModule;

architecture rtl of DebugModule is
    type dm_t is record
        dmcontrol    : dmcontrol_t;
        dmstatus     : dmstatus_t;
        hartinfo     : hartinfo_t;
        haltsum1     : std_logic_vector(31 downto 0);
        hawindowsel  : std_logic_vector(31 downto 0);
        hawindow     : std_logic_vector(31 downto 0);
        abstractcs   : abstractcs_t;
        command      : command_t;
        abstractauto : abstractauto_t;
        confstrptr0  : std_logic_vector(31 downto 0);
        nextdm       : std_logic_vector(31 downto 0);
        progbuf0     : std_logic_vector(31 downto 0);
        progbuf1     : std_logic_vector(31 downto 0);
        authdata     : std_logic_vector(31 downto 0);
        dmcs2        : dmcs2_t;
        sbcs         : sbcs_t;
        sbaddress0   : std_logic_vector(31 downto 0);
        sbdata0      : std_logic_vector(31 downto 0);
        sbdata1      : std_logic_vector(31 downto 0);
        sbdata2      : std_logic_vector(31 downto 0);
        sbdata3      : std_logic_vector(31 downto 0);
    end record dm_t;
begin
    
    
    
end architecture rtl;