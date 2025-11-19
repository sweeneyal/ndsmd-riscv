library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

entity UartTx is
    generic (
        -- frequency of clock signal provided on i_clk
        cClockFrequency_Hz : natural;
        -- fixed baud rate of UART system
        cBaudRate_bps      : natural := 115200
    );
    port (
        -- system clock
        i_clk    : in std_logic;
        -- active low reset synchronous to system clock
        i_resetn : in std_logic;
        -- byte to be transmitted
        i_byte   : in std_logic_vector(7 downto 0);
        -- indicator that the byte to be transmitted is available on i_byte
        i_valid  : in std_logic;
        -- indicator that a transmission is in progress
        o_busy   : out std_logic;
        -- outgoing transmission signal
        o_tx     : out std_logic
    );
end entity UartTx;

architecture rtl of UartTx is
    constant cClocksPerBit : natural := cClockFrequency_Hz / cBaudRate_bps;
    constant cBitIndexMax  : natural := 10;

    type state_t is (READY_STATE, LOAD_BIT, SEND_BIT);
    signal state : state_t := READY_STATE;
    
    signal txDataReg : std_logic_vector(cBitIndexMax - 1 downto 0);
begin
    
    StateMachine: process(i_clk)
        variable bitIndex : natural range 0 to cBitIndexMax := 0;
        variable bitTimer : natural range 0 to cClocksPerBit := 0;
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                state  <= READY_STATE;
                o_tx   <= '1';
                o_busy <= '1';

                bitTimer := 0;
                bitIndex := 0;
            else
                o_busy <= '1';

                case state is
                    when READY_STATE =>
                        o_busy   <= '0';
                        o_tx     <= '1';
                        bitTimer := 0;
                        bitIndex := 0;
                        if (i_valid = '1') then
                            txDataReg <= '1' & i_byte & '0';
                            state     <= LOAD_BIT;
                        end if;
                        
                    when LOAD_BIT =>
                        o_tx  <= txDataReg(bitIndex);
                        state <= SEND_BIT;
                        bitIndex := bitIndex + 1;
                        bitTimer := cClocksPerBit;

                    when SEND_BIT =>
                        if (bitTimer > 0) then
                            bitTimer := bitTimer - 1;
                        else
                            if (bitIndex = cBitIndexMax) then
                                state <= READY_STATE;
                            else
                                state <= LOAD_BIT;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;