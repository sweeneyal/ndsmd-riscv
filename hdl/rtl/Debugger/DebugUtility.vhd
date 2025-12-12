library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

package DebugUtility is
    
    constant cBypass0 : std_logic_vector(4 downto 0) := "00000";
    constant cIdCode  : std_logic_vector(4 downto 0) := "00001";
    constant cDtmcs   : std_logic_vector(4 downto 0) := "10000";
    constant cDmi     : std_logic_vector(4 downto 0) := "10001";
    constant cBypass1 : std_logic_vector(4 downto 0) := "11111";

    -- Constant sizes for the DREG field according to Debug Spec
    constant cIdcode_size : positive := 32;
    constant cDtmcs_size  : positive := 32;
    constant cDmi_size    : positive := 41;
    constant cBypass_size : positive := 1;

    constant cDtmHardReset_bit : natural := 17;
    constant cDmiReset_bit     : natural := 16;

    type idcode_t is record
        version : std_logic_vector(3 downto 0);
        partno  : std_logic_vector(15 downto 0);
        manufid : std_logic_vector(10 downto 0);
    end record idcode_t;

    type dtmcs_t is record
        errinfo      : std_logic_vector(2 downto 0);
        dtmhardreset : std_logic;
        dmireset     : std_logic;
        idle         : std_logic_vector(2 downto 0);
        dmistat      : std_logic_vector(1 downto 0);
        abits        : std_logic_vector(5 downto 0);
        version      : std_logic_vector(3 downto 0);
    end record dtmcs_t;

    type dmi_t is record
        address : std_logic_vector(6 downto 0);
        data    : std_logic_vector(31 downto 0);
        op      : std_logic_vector(1 downto 0);
    end record dmi_t;

    -------------------------------------------------------------------------

    type dmstatus_t is record
        ndmresetpending : std_logic;
        stickyunavail   : std_logic;
        impebreak       : std_logic;
        allhavereset    : std_logic;
        anyhavereset    : std_logic;
        allresumeack    : std_logic;
        anyresumeack    : std_logic;
        allnonexistent  : std_logic;
        anynonexistent  : std_logic;
        allunavail      : std_logic;
        anyunavail      : std_logic;
        allrunning      : std_logic;
        anyrunning      : std_logic;
        allhalted       : std_logic;
        anyhalted       : std_logic;
        authenticated   : std_logic;
        authbusy        : std_logic;
        hasresethaltreq : std_logic;
        confstrptrvalid : std_logic;
        version         : std_logic_vector(3 downto 0);
    end record dmstatus_t;

    type dmcontrol_t is record
        haltreq         : std_logic;
        resumereq       : std_logic;
        hartreset       : std_logic;
        ackhavereset    : std_logic;
        ackunavail      : std_logic;
        hasel           : std_logic;
        hartsello       : std_logic_vector(9 downto 0);
        hartselhi       : std_logic_vector(9 downto 0);
        setkeepalive    : std_logic;
        clrkeepalive    : std_logic;
        setresethaltreq : std_logic;
        clrresethaltreq : std_logic;
        ndmreset        : std_logic;
        dmactive        : std_logic;
    end record dmcontrol_t;
    
    type hartinfo_t is record
        nscratch   : std_logic_vector(3 downto 0);
        dataaccess : std_logic;
        datasize   : std_logic_vector(3 downto 0);
        dataaddr   : std_logic_vector(11 downto 0);
    end record hartinfo_t;

    type abstractcs_t is record
        progbufsize : std_logic_vector(5 downto 0);
        busy        : std_logic;
        relaxedpriv : std_logic;
        cmderr      : std_logic_vector(2 downto 0);
        datacount   : std_logic_vector(3 downto 0);
    end record abstractcs_t;

    type command_t is record
        cmdtype : std_logic_vector(7 downto 0);
        control : std_logic_vector(23 downto 0);
    end record command_t;

    type abstractauto_t is record
        autoexecprogbuf : std_logic_vector(15 downto 0);
        autoexecdata    : std_logic_vector(11 downto 0);
    end record abstractauto_t;
    
    type dmcs2_t is record
        grouptype    : std_logic;
        dmexttrigger : std_logic_vector(3 downto 0);
        dmgroup      : std_logic_vector(4 downto 0);
        hgwrite      : std_logic;
        hgselect     : std_logic;
    end record dmcs2_t;

    type sbcs_t is record
        sbversion       : std_logic_vector(2 downto 0);
        sbbusyerror     : std_logic;
        sbbusy          : std_logic;
        sbreadonaddr    : std_logic;
        sbaccess        : std_logic_vector(2 downto 0);
        sbautoincrement : std_logic;
        sbreadondata    : std_logic;
        sberror         : std_logic_vector(2 downto 0);
        sbasize         : std_logic_vector(6 downto 0);
        sbaccess128     : std_logic;
        sbaccess64      : std_logic;
        sbaccess32      : std_logic;
        sbaccess16      : std_logic;
        sbaccess8       : std_logic;
    end record sbcs_t;

    type dmi_op_t is (NULL_OP, READ_OP, WRITE_OP);
    function to_op(s : std_logic_vector(1 downto 0)) return dmi_op_t;

end package DebugUtility;

package body DebugUtility is
    
    function to_op(s : std_logic_vector(1 downto 0)) return dmi_op_t is
    begin
        case s is
            when "00" => return NULL_OP;
            when "01" => return READ_OP;
            when "10" => return WRITE_OP;
            when others => 
                assert false report "DebugUtility::to_op: Invalid input" severity error;
                return NULL_OP;
        end case;
    end function;
    
end package body DebugUtility;