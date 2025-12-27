library vunit_lib;
context vunit_lib.vunit_context;

use std.env.finish;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library osvvm;
    use osvvm.TbUtilPkg.all;

library nsfrtu_riscv;

entity tb_UartTx is
    generic(runner_cfg : string);
end entity tb_UartTx;

architecture rtl of tb_UartTx is
    procedure ReceiveData (
        signal Clock             : in  std_logic;
        signal Rx                : in  std_logic;
        variable Data            : in  std_logic_vector(7 downto 0);
        signal TxData            : out std_logic_vector(7 downto 0);
        signal Send              : out std_logic;
        signal TxReady           : in std_logic;
        constant cClockFrequency : in  natural;
        constant cClockPeriod    : in  time;
        constant cUartBaudRate   : in  natural
    ) is
        constant cClocksPerBit : natural := cClockFrequency / cUartBaudRate;
        constant cBitPeriod    : time := cClocksPerBit * cClockPeriod;
        variable vTxData       : std_logic_vector(7 downto 0);
    begin
        assert (TxReady = '1') report "WARNING: TxReady needs to be 1 at startup." severity warning;
        assert (Rx = '1')      report "ERROR: Tx needs to be 1 at startup." severity error;
        wait for 4.5 * cBitPeriod;
        assert (TxReady = '1') report "WARNING: TxReady needs to be 1 at startup." severity warning;
        assert (Rx = '1')      report "ERROR: Tx needs to be 1 at startup." severity error;
        vTxData := Data;
        TxData <= Data;
        Send   <= '1';
        wait until rising_edge(Clock);
        wait for 1.5 * cClockPeriod;
        Send   <= '0';
        wait for 0.5 * cBitPeriod + cClockPeriod; -- Depending on the baud rate, the extra clock period included here is a rounding error.
        assert (Rx = '0') report "ERROR: Start bit needs to be 0" severity error;
        for ii in 0 to 7 loop
            wait for cBitPeriod + cClockPeriod; -- Depending on the baud rate, the extra clock period included here is a rounding error.
            assert (Rx = vTxData(ii)) report "ERROR: Tx did not match expected: " &
                std_logic'image(vTxData(ii)) & " Actual: " & std_logic'image(Rx) severity warning;
        end loop;
        wait for cBitPeriod + cClockPeriod; -- Depending on the baud rate, the extra clock period included here is a rounding error.
        assert (Rx = '1') report "ERROR: Stop bit needs to be 1" severity error;
        wait for cBitPeriod;
    end procedure;

    signal clk     : std_logic := '0';
    signal resetn  : std_logic := '0';
    signal byte    : std_logic_vector(7 downto 0) := (others => '0');
    signal valid   : std_logic := '0';
    signal busy    : std_logic := '0';
    signal tx      : std_logic := '0';
    signal txReady : std_logic := '0';
begin
    
    CreateClock(
        clk    => clk,
        period => 10 ns
    );

    eDut : entity nsfrtu_riscv.UartTx 
    generic map(
        cClockFrequency_Hz => 100e6,
        cBaudRate_bps      => 115200
    ) port map(
        i_clk    => clk,
        i_resetn => resetn, 
        i_byte   => byte,
        i_valid  => valid,
        o_busy   => busy,
        o_tx     => tx
    );

    txReady <= not busy;

    Stimuli: process
        variable data : std_logic_vector(7 downto 0) := (others => '0');
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Nominal_ReceiveByte") then
                resetn <= '0';
                wait until rising_edge(clk);
                resetn <= '1';
                wait until rising_edge(clk);

                for ii in 0 to 255 loop
                    data := std_logic_vector(to_unsigned(ii, 8));

                    ReceiveData(
                        Clock           => clk,
                        Data            => data,
                        Rx              => tx,
                        TxData          => byte,
                        Send            => valid,
                        TxReady         => txReady,
                        cClockFrequency => 100e6,
                        cClockPeriod    => 10 ns,
                        cUartBaudRate   => 115200
                    );
                end loop;
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process Stimuli;

    test_runner_watchdog(runner, 35 ms);
end architecture rtl;