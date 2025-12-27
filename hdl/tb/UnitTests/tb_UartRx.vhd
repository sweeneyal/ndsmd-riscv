library vunit_lib;
context vunit_lib.vunit_context;

use std.env.finish;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library osvvm;
    use osvvm.TbUtilPkg.all;

library nsfrtu_riscv;

entity tb_UartRx is
    generic(runner_cfg : string);
end entity tb_UartRx;

architecture rtl of tb_UartRx is
    procedure TransmitData (
        signal Clock  : in  std_logic;
        variable Data : out std_logic_vector(7 downto 0);
        signal Tx     : out std_logic;
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
        Tx      <= '1';
        vRxData := Data;
        wait for 4.5 * cBitPeriod;
        Tx <= '0';
        wait for cBitPeriod;

        for ii in 0 to 7 loop
            Tx <= vRxData(ii);
            wait for cBitPeriod;
        end loop;

        Tx <= '1';
        wait until Done = '1';
        assert vRxData = RxData report "ERROR: Data must be the same" severity error;
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

    eDut : entity nsfrtu_riscv.UartRx 
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
        variable data : std_logic_vector(7 downto 0) := (others => '0');
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Nominal_ReceiveByte") then
                for ii in 0 to 255 loop
                    data := std_logic_vector(to_unsigned(ii, 8));
                    TransmitData(
                        Clock  => clk,
                        Data   => data,
                        Tx     => rx, 
                        Done   => done,
                        RxData => rxData,
                        cClockFrequency => 100e6,
                        cClockPeriod    => 10 ns,
                        cUartBaudRate   => 115200
                    );
                    check(rxData = data);
                end loop;
            end if;
        end loop;
        test_runner_cleanup(runner);
    end process TestBench;

    test_runner_watchdog(runner, 35 ms);
end architecture rtl;