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

        abstractcs   : abstractcs_t;
        command      : command_t;
        abstractauto : abstractauto_t;
        
        confstrptr0  : std_logic_vector(31 downto 0);
        progbuf0     : std_logic_vector(31 downto 0);
        progbuf1     : std_logic_vector(31 downto 0);
        authdata     : std_logic_vector(31 downto 0);
        sbcs         : sbcs_t;
        sbaddress0   : std_logic_vector(31 downto 0);
        sbdata0      : std_logic_vector(31 downto 0);
    end record dm_t;

    signal dm : dm_t := dm_t'(
        dmcontrol => dmcontrol_t'(
            haltreq         => '0',
            resumereq       => '0',
            hartreset       => '0',
            ackhavereset    => '0',
            ackunavail      => '0',
            hasel           => '0',
            hartsello       => (others => '0'),
            hartselhi       => (others => '0'),
            setkeepalive    => '0',
            clrkeepalive    => '0',
            setresethaltreq => '0',
            clrresethaltreq => '0',
            ndmreset        => '0',
            dmactive        => '0'
        ),
        dmstatus  => dmstatus_t'(
            ndmresetpending => '0',
            stickyunavail   => '0',
            impebreak       => '0',
            allhavereset    => '0',
            anyhavereset    => '0',
            allresumeack    => '0',
            anyresumeack    => '0',
            allnonexistent  => '0',
            anynonexistent  => '0',
            allunavail      => '0',
            anyunavail      => '0',
            allrunning      => '0',
            anyrunning      => '0',
            allhalted       => '0',
            anyhalted       => '0',
            authenticated   => '0',
            authbusy        => '0',
            hasresethaltreq => '0',
            confstrptrvalid => '0',
            version         => x"3"
        ),

        hartinfo => hartinfo_t'(
            nscratch   => (others => '0'),
            dataaccess => '0',
            datasize   => (others => '0'),
            dataaddr   => (others => '0')
        ),
        haltsum1 => (others => '0'),

        abstractcs   => abstractcs_t'(
            progbufsize => (others => '0'),
            busy        => '0',
            relaxedpriv => '0',
            cmderr      => (others => '0'),
            datacount   => (others => '0')
        ),
        command      => command_t'(
            cmdtype => (others => '0'),
            control => (others => '0')
        ),
        abstractauto => abstractauto_t'(
            autoexecprogbuf => (others => '0'),
            autoexecdata    => (others => '0')
        ),

        confstrptr0 => (others => '0'),
        progbuf0    => (others => '0'),
        progbuf1    => (others => '0'),
        authdata    => (others => '0'),
        sbcs        => sbcs_t'(
            sbversion       => (others => '0'),
            sbbusyerror     => '0',
            sbbusy          => '0',
            sbreadonaddr    => '0',
            sbaccess        => (others => '0'),
            sbautoincrement => '0',
            sbreadondata    => '0',
            sberror         => (others => '0'),
            sbasize         => (others => '0'),
            sbaccess128     => '0',
            sbaccess64      => '0',
            sbaccess32      => '0',
            sbaccess16      => '0',
            sbaccess8       => '0'
        ),
        sbaddress0  => (others => '0'),
        sbdata0     => (others => '0')
    );

    type reg_state_t is (IDLE, READ_OP, WRITE_OP);
    signal reg_state : reg_state_t := IDLE;
begin
    
    StateMachine: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                dm <= dm_t'(
                    dmcontrol => dmcontrol_t'(
                        haltreq         => '0',
                        resumereq       => '0',
                        hartreset       => '0',
                        ackhavereset    => '0',
                        ackunavail      => '0',
                        hasel           => '0',
                        hartsello       => (others => '0'),
                        hartselhi       => (others => '0'),
                        setkeepalive    => '0',
                        clrkeepalive    => '0',
                        setresethaltreq => '0',
                        clrresethaltreq => '0',
                        ndmreset        => '0',
                        dmactive        => '0'
                    ),
                    dmstatus  => dmstatus_t'(
                        ndmresetpending => '0',
                        stickyunavail   => '0',
                        impebreak       => '0',
                        allhavereset    => '0',
                        anyhavereset    => '0',
                        allresumeack    => '0',
                        anyresumeack    => '0',
                        allnonexistent  => '0',
                        anynonexistent  => '0',
                        allunavail      => '0',
                        anyunavail      => '0',
                        allrunning      => '0',
                        anyrunning      => '0',
                        allhalted       => '0',
                        anyhalted       => '0',
                        authenticated   => '0',
                        authbusy        => '0',
                        hasresethaltreq => '0',
                        confstrptrvalid => '0',
                        version         => x"3"
                    ),

                    hartinfo => hartinfo_t'(
                        nscratch   => (others => '0'),
                        dataaccess => '0',
                        datasize   => (others => '0'),
                        dataaddr   => (others => '0')
                    ),
                    haltsum1 => (others => '0'),

                    abstractcs   => abstractcs_t'(
                        progbufsize => (others => '0'),
                        busy        => '0',
                        relaxedpriv => '0',
                        cmderr      => (others => '0'),
                        datacount   => (others => '0')
                    ),
                    command      => command_t'(
                        cmdtype => (others => '0'),
                        control => (others => '0')
                    ),
                    abstractauto => abstractauto_t'(
                        autoexecprogbuf => (others => '0'),
                        autoexecdata    => (others => '0')
                    ),

                    confstrptr0 => (others => '0'),
                    progbuf0    => (others => '0'),
                    progbuf1    => (others => '0'),
                    authdata    => (others => '0'),
                    sbcs        => sbcs_t'(
                        sbversion       => (others => '0'),
                        sbbusyerror     => '0',
                        sbbusy          => '0',
                        sbreadonaddr    => '0',
                        sbaccess        => (others => '0'),
                        sbautoincrement => '0',
                        sbreadondata    => '0',
                        sberror         => (others => '0'),
                        sbasize         => (others => '0'),
                        sbaccess128     => '0',
                        sbaccess64      => '0',
                        sbaccess32      => '0',
                        sbaccess16      => '0',
                        sbaccess8       => '0'
                    ),
                    sbaddress0  => (others => '0'),
                    sbdata0     => (others => '0')
                );
            else
                case reg_state is
                    when IDLE =>
                        if (i_dmi_en = '1') then
                            case "0" & i_dmi_addr is
                                when x"10" =>
                                    -- dmcontrol
                                when x"11" =>
                                    -- dmstatus
                                when x"12" =>
                                    -- hartinfo
                                when x"13" =>
                                    -- haltsum1
                                when x"16" =>
                                    -- abstractcs
                                when x"17" =>
                                    -- command
                                when x"18" =>
                                    -- abstractauto
                                when x"19" =>
                                    -- confstrptr0
                                when x"20" =>
                                    -- progbuf0
                                when x"21" =>
                                    -- progbuf1
                                when x"30" =>
                                    -- authdata
                                when x"38" =>
                                    -- sbcs
                                when x"39" =>
                                    -- sbaddress0
                                when x"3c" =>
                                    -- sbdata0
                                when others =>
                                    -- all others are not yet implemented
                            
                            end case;
                        end if;
                
                    when others =>
                        
                
                end case;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;