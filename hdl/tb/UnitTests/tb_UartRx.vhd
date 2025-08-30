library vunit_lib;
context vunit_lib.vunit_context;

use std.env.finish;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library osvvm;
    use osvvm.TbUtilPkg.all;

library ndsmd_riscv;

entity tb_UartRx is
    generic(runner_cfg : string);
end entity tb_UartRx;

architecture rtl of tb_UartRx is
    procedure OpenLoopTransmit (
        signal Clock             : in  std_logic;
        signal Tx                : in  std_logic;
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
        assert (Tx = '1')      report "ERROR: Tx needs to be 1 at startup." severity error;
        wait for 4.5 * cBitPeriod;
        assert (TxReady = '1') report "WARNING: TxReady needs to be 1 at startup." severity warning;
        assert (Tx = '1')      report "ERROR: Tx needs to be 1 at startup." severity error;
        vTxData := "10101010";
        TxData <= vTxData;
        Send   <= '1';
        wait until rising_edge(Clock);
        wait for 1.5 * cClockPeriod;
        Send   <= '0';
        assert (Tx = '0') report "ERROR: Start bit needs to be 0" severity error;
        wait for cBitPeriod + cClockPeriod; -- Depending on the baud rate, the extra clock period included here is a rounding error.
        for ii in 0 to 7 loop
            assert (Tx = vTxData(ii)) report "ERROR: Tx did not match expected: " &
                std_logic'image(vTxData(ii)) & " Actual: " & std_logic'image(Tx) severity error;
            wait for cBitPeriod + cClockPeriod; -- Depending on the baud rate, the extra clock period included here is a rounding error.
        end loop;
        assert (Tx = '1') report "ERROR: Stop bit needs to be 1" severity error;
        wait for cBitPeriod;
    end procedure;

    procedure OpenLoopReceive(
        signal Clock  : in  std_logic;
        signal Rx     : out std_logic;
        signal Done   : in  std_logic;
        signal RxData : in  std_logic_vector(7 downto 0);
        constant cClockFrequency : in  natural;
        constant cClockPeriod    : in  time;
        constant cUartBaudRate   : in  natural
    ) is
        constant cClocksPerBit : natural := cClockFrequency / cUartBaudRate;
        constant cBitPeriod    : time := cClocksPerBit * cClockPeriod;
        variable vRxData       : std_logic_vector(7 downto 0);
    begin
        Rx      <= '1';
        vRxData := "10101010";
        wait for 4.5 * cBitPeriod;
        Rx <= '0';
        wait for cBitPeriod;

        for ii in 0 to 7 loop
            Rx <= vRxData(ii);
            wait for cBitPeriod;
        end loop;

        Rx <= '1';
        assert Done = '1' report "ERROR: Done must be high when a correct transmission occurs" severity warning;
        assert vRxData = RxData report "ERROR: Data must be the same" severity error;
    end procedure;

    procedure Nominal_TransmitByte(
        signal Clock             : in  std_logic;
        signal Tx                : in  std_logic;
        signal TxData            : out std_logic_vector(7 downto 0);
        signal Send              : out std_logic;
        signal TxReady           : in  std_logic;
        constant cClockFrequency : in  natural;
        constant cClockPeriod    : in  time;
        constant cUartBaudRate   : in  natural
    ) is
    begin
        OpenLoopTransmit(Clock=>Clock, Tx=>Tx, TxData=>TxData, 
            Send=>Send, TxReady=>TxReady, cClockFrequency=>cClockFrequency,
            cClockPeriod=>cClockPeriod, cUartBaudRate=>cUartBaudRate);
    end procedure;

    procedure Nominal_ReceiveByte(
        signal Clock  : in  std_logic;
        signal Rx     : out  std_logic;
        signal Done   : in std_logic;
        signal RxData : in std_logic_vector(7 downto 0);
        constant cClockFrequency : in  natural;
        constant cClockPeriod    : in  time;
        constant cUartBaudRate   : in  natural
    ) is
    begin
        OpenLoopReceive(Clock=>Clock, Rx=>Rx, Done=>Done, 
            RxData=>RxData, cClockFrequency=>cClockFrequency,
            cClockPeriod=>cClockPeriod, cUartBaudRate=>cUartBaudRate);
    end procedure;

    signal clk    : std_logic := '0';
    signal rxData : std_logic_vector(7 downto 0) := (others => '0');
    signal done   : std_logic := '0';
    signal rx     : std_logic := '1';
begin
    
    CreateClock(
        clk    => clk,
        period => 10 ns
    );

    eDut : entity ndsmd_riscv.UartRx 
    generic map(
        cClockFrequency_Hz => 100e6,
        cBaudRate_bps      => 115200
    ) port map(
        i_clk   => clk,
        i_rx    => rx, 
        o_byte  => rxData,
        o_valid => done
    );

    TestBench: process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Nominal_ReceiveByte") then
                Nominal_ReceiveByte(
                    Clock  => clk,
                    Rx     => rx, 
                    Done   => done,
                    RxData => rxData,
                    cClockFrequency => 100e6,
                    cClockPeriod    => 10 ns,
                    cUartBaudRate   => 115200
                );
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process TestBench;

    test_runner_watchdog(runner, 10 ms);
end architecture rtl;