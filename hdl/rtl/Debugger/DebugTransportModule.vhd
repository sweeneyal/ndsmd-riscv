library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    use ndsmd_riscv.DebugUtility.all;

entity DebugTransportModule is
    generic (
        cIdcode_Version : std_logic_vector(3 downto 0);
        cIdcode_PartId  : std_logic_vector(15 downto 0);
        cIdcode_ManId   : std_logic_vector(10 downto 0)
    );
    port (        
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_tck : in std_logic;
        i_tms : in std_logic;
        i_tdi : in std_logic;
        o_tdo : out std_logic;

        o_dmi_en    : out std_logic;
        o_dmi_op    : out dmi_op_t;
        o_dmi_addr  : out std_logic_vector(6 downto 0);
        o_dmi_wdata : out std_logic_vector(31 downto 0);
        i_dmi_rdata : in std_logic_vector(31 downto 0);
        i_dmi_valid : in std_logic
    );
end entity DebugTransportModule;

architecture rtl of DebugTransportModule is
    -- Flop filtering of external signals into the processor clock domain
    signal tck_s : std_logic_vector(2 downto 0) := (others => '0');
    signal tms_s : std_logic_vector(2 downto 0) := (others => '0');
    signal tdi_s : std_logic_vector(2 downto 0) := (others => '0');

    signal tck    : std_logic := '0';
    signal tck_ff : std_logic := '0';
    signal tms    : std_logic := '0';
    signal tdi    : std_logic := '0';

    -- Standard JTAG state machine
    type state_t is (
        TEST_LOGIC_RESET, RUN_TEST_IDLE, 
        SEL_DR_SCAN, CAPTURE_DR, SHIFT_DR, EXIT_1_DR, PAUSE_DR, EXIT_2_DR, UPDATE_DR,
        SEL_IR_SCAN, CAPTURE_IR, SHIFT_IR, EXIT_1_IR, PAUSE_IR, EXIT_2_IR, UPDATE_IR);

    -- State variable and following state variable for update edge detection
    signal state      : state_t := TEST_LOGIC_RESET;
    signal prev_state : state_t := TEST_LOGIC_RESET;

    signal update : std_logic := '0';

    signal ireg : std_logic_vector(4 downto 0)  := (others => '0');
    signal dreg : std_logic_vector(40 downto 0) := (others => '0');

    -- Local struct for managing the address, data, and operation
    type dmi_t is record
        address : std_logic_vector(6 downto 0);
        data    : std_logic_vector(31 downto 0);
        op      : std_logic_vector(1 downto 0);
    end record dmi_t;
    signal dmi : dmi_t := dmi_t'(
        address => (others => '0'),
        data    => (others => '0'),
        op      => (others => '0')
    );

    signal busy      : std_logic := '0';
    signal err       : std_logic := '0';
    signal hardreset : std_logic := '0';
    signal dmireset  : std_logic := '0';
begin
    
    Sampler: process(i_clk)
    begin
        if rising_edge(i_clk) then
            tck_s(0) <= i_tck;
            tms_s(0) <= i_tms;
            tdi_s(0) <= i_tdi;

            for ii in 0 to 1 loop
                tck_s(ii + 1) <= tck_s(ii);
                tms_s(ii + 1) <= tms_s(ii);
                tdi_s(ii + 1) <= tdi_s(ii);
            end loop;

            tck_ff <= tck_s(2);
        end if;
    end process Sampler;

    tck <= tck_s(2);
    tms <= tms_s(2);
    tdi <= tdi_s(2);

    StateMachine: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                state      <= TEST_LOGIC_RESET;
                prev_state <= TEST_LOGIC_RESET;
            else
                prev_state <= state;
                if (tck = '1' and tck_ff = '0') then
                    case state is
                        when TEST_LOGIC_RESET => if (tms = '0') then state <= RUN_TEST_IDLE; else state <= TEST_LOGIC_RESET; end if;
                        when RUN_TEST_IDLE    => if (tms = '0') then state <= RUN_TEST_IDLE; else state <= SEL_DR_SCAN;      end if;
        
                        when SEL_DR_SCAN => if (tms = '0') then state <= CAPTURE_DR;    else state <= SEL_IR_SCAN; end if;
                        when CAPTURE_DR  => if (tms = '0') then state <= SHIFT_DR;      else state <= EXIT_1_DR;   end if;
                        when SHIFT_DR    => if (tms = '0') then state <= SHIFT_DR;      else state <= EXIT_1_DR;   end if;
                        when EXIT_1_DR   => if (tms = '0') then state <= UPDATE_DR;     else state <= PAUSE_DR;    end if;
                        when PAUSE_DR    => if (tms = '0') then state <= PAUSE_DR;      else state <= EXIT_2_DR;   end if;
                        when EXIT_2_DR   => if (tms = '0') then state <= SHIFT_DR;      else state <= UPDATE_DR;   end if;
                        when UPDATE_DR   => if (tms = '0') then state <= RUN_TEST_IDLE; else state <= SEL_DR_SCAN; end if;
        
                        when SEL_IR_SCAN => if (tms = '0') then state <= CAPTURE_IR;    else state <= TEST_LOGIC_RESET; end if;
                        when CAPTURE_IR  => if (tms = '0') then state <= SHIFT_IR;      else state <= EXIT_1_IR;        end if;
                        when SHIFT_IR    => if (tms = '0') then state <= SHIFT_IR;      else state <= EXIT_1_IR;        end if;
                        when EXIT_1_IR   => if (tms = '0') then state <= UPDATE_IR;     else state <= PAUSE_IR;         end if;
                        when PAUSE_IR    => if (tms = '0') then state <= PAUSE_IR;      else state <= EXIT_2_IR;        end if;
                        when EXIT_2_IR   => if (tms = '0') then state <= SHIFT_IR;      else state <= UPDATE_IR;        end if;
                        when UPDATE_IR   => if (tms = '0') then state <= RUN_TEST_IDLE; else state <= SEL_DR_SCAN;      end if;
                    end case;
                end if;
            end if;
        end if;
    end process StateMachine;

    update <= bool2bit(state = UPDATE_DR and prev_state /= UPDATE_DR);

    TapRegisters: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                ireg <= (others => '0');
                dreg <= (others => '0');
                o_tdo <= '0';            
            else 
                if (state = TEST_LOGIC_RESET or state = CAPTURE_IR) then
                    ireg <= cIdcode;
                elsif (state = SHIFT_IR and (tck = '1' and tck_ff = '0')) then
                    ireg <= tdi & ireg(ireg'left downto 1);
                end if;

                if (state = CAPTURE_DR) then
                    dreg <= (others => '0');
                    case ireg is
                        when cIdcode => dreg(dreg'left downto dreg'left - (cIdcode_size - 1)) <= cIdcode_Version & cIdcode_PartId & cIdcode_ManId & '1';
                        when cDtmcs  => dreg(dreg'left downto dreg'left - (cDtmcs_size  - 1)) <= x"00000071";
                        when cDmi    => dreg(dreg'left downto dreg'left - (cDmi_size    - 1)) <= dmi.address & dmi.data & err & err;
                        when others  => dreg(dreg'left downto dreg'left - (cBypass_size - 1)) <= (others => '0');
                    end case;
                elsif (state = SHIFT_DR and (tck = '1' and tck_ff = '0')) then
                    dreg <= tdi & dreg(dreg'left downto 1);
                end if;

                if (tck = '0' and tck_ff = '1') then
                    if (state = SHIFT_IR) then
                        o_tdo <= ireg(0);
                    elsif (state = SHIFT_DR) then
                        case ireg is
                            when cIdcode => o_tdo <= dreg(dreg'left - (cIdcode_size - 1));
                            when cDtmcs  => o_tdo <= dreg(dreg'left - (cDtmcs_size - 1));
                            when cDmi    => o_tdo <= dreg(dreg'left - (cDmi_size - 1));
                            when others  => o_tdo <= dreg(dreg'left - (cBypass_size - 1));
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process TapRegisters;

    hardreset <= bool2bit((update = '1') and (ireg = cDtmcs) and (dreg(cDtmHardReset_bit) = '1'));
    dmireset  <= bool2bit((update = '1') and (ireg = cDtmcs) and (dreg(cDmiReset_bit) = '1'));

    Controller: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                busy <= '0';
                err  <= '0';
                dmi  <= dmi_t'(
                    address => (others => '0'),
                    data    => (others => '0'),
                    op      => (others => '0')
                );
            else
                o_dmi_en <= '0';

                if ((dmireset = '1') or (hardreset = '1')) then
                    err <= '0';
                elsif ((update = '1') and (ireg = cDmi) and (busy = '1')) then
                    err <= '1';
                end if;

                dmi.op <= "00";
                if (busy = '0') then
                    if ((update = '1') and (ireg = cDmi)) then
                        o_dmi_en    <= bool2bit(dreg(1 downto 0) /= "00");
                        dmi.address <= dreg(40 downto 34);
                        dmi.data    <= dreg(33 downto 2);
                        dmi.op      <= dreg(1 downto 0);
                        busy        <= any(dreg(1 downto 0));
                    end if;
                elsif ((i_dmi_valid = '1') or (hardreset = '1')) then
                    dmi.data <= i_dmi_rdata;
                    busy     <= '0';
                end if;
            end if;
        end if;
    end process Controller;

    o_dmi_op    <= to_op(dmi.op);
    o_dmi_addr  <= dmi.address;
    o_dmi_wdata <= dmi.data;
    
end architecture rtl;