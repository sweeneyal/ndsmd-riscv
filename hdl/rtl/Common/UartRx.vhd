library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

entity UartRx is
    generic (
        -- frequency of clock signal provided on i_clk
        cClockFrequency_Hz : natural;
        -- fixed baud rate of UART system
        cBaudRate_bps      : natural := 115200
    );
    port (
        --
        i_clk   : in std_logic;
        --
        i_rx    : in std_logic;
        --
        o_byte  : out std_logic_vector(7 downto 0);
        --
        o_valid : out std_logic
    );
end entity UartRx;

architecture rtl of UartRx is
    constant cClocksPerBit : natural := cClockFrequency_Hz / cBaudRate_bps;
    constant cBitIndexMax  : natural := 10;
    signal rxd : std_logic := '1';
    signal rxfilt : std_logic_vector(1 downto 0) := (others => '0');
    type state_t is (IDLE, READ_DATA);
    signal state : state_t := IDLE;
    signal rxDataReg : std_logic_vector(cBitIndexMax - 1 downto 0);
begin
    
    MetastableFilter: process(i_clk)
    begin
        if rising_edge(i_clk) then
            rxd       <= rxfilt(1);
            rxfilt(1) <= rxfilt(0);
            rxfilt(0) <= i_rx;
        end if;
    end process MetastableFilter;

    StateMachine: process(i_clk)
        variable bitIndex : natural range 0 to cBitIndexMax - 1 := 0;
        variable bitTimer : natural range 0 to cClocksPerBit := 0;
    begin
        if rising_edge(i_clk) then
            o_valid <= '0';
            case state is
                when IDLE =>
                    bitIndex := 0;
                    bitTimer := 0;
                    rxDataReg <= (others => '0');
                    if (rxd = '0') then
                        state    <= READ_DATA;
                        -- Set the timer to halfway
                        bitTimer := (cClocksPerBit / 2);
                    end if;

                when READ_DATA =>
                    if (bitTimer > 0) then
                        bitTimer := bitTimer - 1;
                    else
                        bitTimer := cClocksPerBit - 1;
                        rxDataReg(bitIndex) <= rxd;

                        if (bitIndex = 0 and rxd = '1') then
                            -- This bit was not cleared for the entire expected period, therefore we
                            -- need to ignore it and go back to idle.
                            state <= IDLE;
                        elsif (bitIndex = cBitIndexMax and rxd = '0') then
                            -- This bit was not set for the entire expected period, therefore we
                            -- need to ignore it and go back to idle.
                            state <= IDLE;
                        else
                            -- We are either receiving a data bit (and thus no errors are technically possible)
                            -- or we successfully received the framing bits, and are thus continuing to the next
                            -- bit or are done receiving.
                            if (bitIndex < cBitIndexMax - 1) then
                                bitIndex := bitIndex + 1;
                            else
                                bitIndex := 0;
                                state   <= IDLE;
                                o_valid <= '1';
                            end if;
                        end if;
                    end if;
            end case;
        end if;
    end process StateMachine;

    -- Only the middle 8 bits are data.
    o_byte <= rxDataReg(8 downto 1);
    
end architecture rtl;