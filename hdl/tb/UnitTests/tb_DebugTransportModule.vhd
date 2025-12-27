library vunit_lib;
    context vunit_lib.vunit_context;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library osvvm;
    use osvvm.TbUtilPkg.all;
    use osvvm.RandomPkg.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;
    use nsfrtu_riscv.DebugUtility.all;

entity tb_DebugTransportModule is
    generic (runner_cfg : string);
end entity tb_DebugTransportModule;

architecture tb of tb_DebugTransportModule is
    signal clk    : std_logic := '0';
    signal resetn : std_logic := '0';

    constant cJtagPeriod_ns : real := 35.0;

    type jtag_i_t is record
        tck : std_logic;
        tms : std_logic;
        tdi : std_logic;
    end record jtag_i_t;

    type jtag_o_t is record
        tdo : std_logic;
    end record jtag_o_t;

    signal jtag_i : jtag_i_t := jtag_i_t'(
        tck => '0',
        tms => '0',
        tdi => '0'
    );

    signal jtag_o : jtag_o_t := jtag_o_t'(
        tdo => '0'
    );

    type dmi_dbg_t is record
        en    : std_logic;
        op    : dmi_op_t;
        addr  : std_logic_vector(6 downto 0);
        wdata : std_logic_vector(31 downto 0);
        rdata : std_logic_vector(31 downto 0);
        valid : std_logic;
    end record dmi_dbg_t;

    signal dmi : dmi_dbg_t := dmi_dbg_t'(
        en    => '0',
        op    => NULL_OP,
        addr  => (others => '0'),
        wdata => (others => '0'),
        rdata => (others => '0'),
        valid => '0'
    );

    procedure jtag_transaction (
        signal   jtag_o    : out jtag_i_t;
        signal   jtag_i    : in jtag_o_t;
        variable instr_i   : in std_logic_vector;
        variable data_i    : in std_logic_vector;
        variable data_o    : out std_logic_vector;
        constant period_ns : in real
    ) is
        type jtag_state_t is (
            TEST_LOGIC_RESET, RUN_TEST_IDLE, 
            SEL_DR_SCAN, CAPTURE_DR, SHIFT_DR, EXIT_1_DR, PAUSE_DR, EXIT_2_DR, UPDATE_DR,
            SEL_IR_SCAN, CAPTURE_IR, SHIFT_IR, EXIT_1_IR, PAUSE_IR, EXIT_2_IR, UPDATE_IR);
        variable state : jtag_state_t := TEST_LOGIC_RESET;
    begin
        state := RUN_TEST_IDLE;
        jtag_o.tck <= '0';
        jtag_o.tms <= '1';
        jtag_o.tdi <= '0';

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '1';
        jtag_o.tms <= '1';
        state := SEL_DR_SCAN;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '1';
        jtag_o.tms <= '1';
        state := SEL_IR_SCAN;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '1';
        jtag_o.tms <= '0';
        state := CAPTURE_IR;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '1';
        jtag_o.tms <= '0';
        state := SHIFT_IR;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';

        for ii in instr_i'reverse_range loop
            wait for 0.5 * period_ns * 1 ns;
            jtag_o.tck <= '1';
            jtag_o.tms <= bool2bit(ii = instr_i'left);
            jtag_o.tdi <= instr_i(ii);
            state := SHIFT_IR when ii < instr_i'left else EXIT_1_IR;

            wait for 0.5 * period_ns * 1 ns;
            jtag_o.tck <= '0';
        end loop;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '1';
        jtag_o.tms <= '0';
        state := UPDATE_IR;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '1';
        jtag_o.tms <= '1';
        state := SEL_DR_SCAN;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '1';
        jtag_o.tms <= '0';
        state := CAPTURE_DR;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '1';
        jtag_o.tms <= '0';
        state := SHIFT_DR;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';

        for ii in data_i'reverse_range loop
            wait for 0.5 * period_ns * 1 ns;
            if (ii > 0) then
                data_o(ii - 1) := jtag_i.tdo;
            end if;
            jtag_o.tck <= '1';
            jtag_o.tms <= bool2bit(ii = data_i'left);
            jtag_o.tdi <= data_i(ii);
            state := SHIFT_DR when ii < data_i'left else EXIT_1_IR;
            
            wait for 0.5 * period_ns * 1 ns;
            jtag_o.tck <= '0';
        end loop;
            
        wait for 0.5 * period_ns * 1 ns;
        data_o(data_i'left) := jtag_i.tdo;
        jtag_o.tck <= '1';
        jtag_o.tms <= '0';
        state := UPDATE_DR;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '1';
        jtag_o.tms <= '0';
        state := RUN_TEST_IDLE;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '1';
        jtag_o.tms <= '0';
        state := RUN_TEST_IDLE;

        wait for 0.5 * period_ns * 1 ns;
        jtag_o.tck <= '0';
    end procedure;
begin

    CreateClock(clk=>clk, period=>5 ns);
    
    eDut : entity nsfrtu_riscv.DebugTransportModule 
    generic map (
        cIdcode_Version => x"1",
        cIdcode_PartId  => x"0001",
        cIdcode_ManId   => (others => '0')
    ) port map (
        i_clk    => clk,
        i_resetn => resetn,

        i_tck => jtag_i.tck,
        i_tms => jtag_i.tms,
        i_tdi => jtag_i.tdi,
        o_tdo => jtag_o.tdo,

        o_dmi_en    => dmi.en,
        o_dmi_op    => dmi.op,
        o_dmi_addr  => dmi.addr,
        o_dmi_wdata => dmi.wdata,
        i_dmi_rdata => dmi.rdata,
        i_dmi_valid => dmi.valid
    );

    Stimuli: process
        variable instr  : std_logic_vector(4 downto 0);
        variable idcode : std_logic_vector(31 downto 0);
        variable dtmcs  : std_logic_vector(31 downto 0);
        variable dmid   : std_logic_vector(40 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("t_test_jtag") then
                resetn <= '0';
                
                wait until rising_edge(clk);
                resetn <= '1';
                jtag_i.tck <= '0';

                wait for 0.5 * cJtagPeriod_ns * 1 ns;
                jtag_i.tck <= '1';

                wait for 0.5 * cJtagPeriod_ns * 1 ns;
                jtag_i.tck <= '0';

                instr  := "00001";
                idcode := (others => '0');
                dmid   := (others => '0');

                jtag_transaction(
                    jtag_o    => jtag_i,
                    jtag_i    => jtag_o,
                    instr_i   => instr,
                    data_i    => idcode,
                    data_o    => dmid,
                    period_ns => cJtagPeriod_ns
                );

                check(dmid(31 downto 0) = x"10001001");

                wait for 0.5 * cJtagPeriod_ns * 1 ns;
                jtag_i.tck <= '1';

                wait for 0.5 * cJtagPeriod_ns * 1 ns;
                jtag_i.tck <= '0';

                instr  := "10000";
                idcode := (others => '0');
                dmid   := (others => '0');

                jtag_transaction(
                    jtag_o    => jtag_i,
                    jtag_i    => jtag_o,
                    instr_i   => instr,
                    data_i    => idcode,
                    data_o    => dtmcs,
                    period_ns => cJtagPeriod_ns
                );

                check(dtmcs = x"00000071");

                wait for 0.5 * cJtagPeriod_ns * 1 ns;
                jtag_i.tck <= '1';

                wait for 0.5 * cJtagPeriod_ns * 1 ns;
                jtag_i.tck <= '0';

                instr  := "10001";
                idcode := (others => '0');
                dmid   := (others => '0');

                jtag_transaction(
                    jtag_o    => jtag_i,
                    jtag_i    => jtag_o,
                    instr_i   => instr,
                    data_i    => dmid,
                    data_o    => dmid,
                    period_ns => cJtagPeriod_ns
                );

                check(dmid = '0' & x"0000000000");

                check(dmi.en'stable(3 us));
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process Stimuli;
    
end architecture tb;