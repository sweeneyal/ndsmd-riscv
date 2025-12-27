library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;

entity Bus2Axi is
    generic (
        cAddressWidth_b    : positive := 32;
        cCachelineSize_B   : positive := 16
    );
    port (
        i_clk : in std_logic;
        i_resetn : in std_logic;

        i_bus_addr   : in std_logic_vector(cAddressWidth_b - 1 downto 0);
        i_bus_en     : in std_logic;
        i_bus_wen    : in std_logic_vector(cCachelineSize_B - 1 downto 0);
        i_bus_wdata  : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_bus_rdata  : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_bus_valid : out std_logic;

        -- AXI-like interface to allow for easier implementation
        -- address bus for requesting an address
        o_axi_awaddr : out std_logic_vector(cAddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        o_axi_awprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_axi_awvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_axi_awready : in std_logic;

        -- write data bus
        o_axi_wdata  : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        -- write data strobe
        o_axi_wstrb : out std_logic_vector(cCachelineSize_B - 1 downto 0);
        -- write valid
        o_axi_wvalid : out std_logic;
        -- write ready
        i_axi_wready : in std_logic;

        -- response indicating error occurred, if any
        i_axi_bresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that write response data is valid
        i_axi_bvalid : in std_logic;
        -- ready to receive write response data
        o_axi_bready : out std_logic;

        -- address bus for requesting an address
        o_axi_araddr : out std_logic_vector(cAddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        o_axi_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_axi_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_axi_arready : in std_logic;

        -- returned instruction data bus
        i_axi_rdata  : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        -- response indicating error occurred, if any
        i_axi_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        i_axi_rvalid : in std_logic;
        -- ready to receive instruction data
        o_axi_rready : out std_logic
    );
end entity Bus2Axi;

architecture rtl of Bus2Axi is
    type state_t is (IDLE, PERFORM_AXI_WRITE, PERFORM_AXI_READ);
    signal state : state_t := IDLE;

    signal dbg_axi_transactions : std_logic_vector(2 downto 0) := "000";
    signal dbg_misaligned : std_logic := '0';
    signal dbg_prev_misaligned : std_logic := '0';
begin
    
    StateMachine: process(i_clk)
        variable lsb : natural range 0 to cCachelineSize_B - 1 := 0;
        variable misaligned : std_logic := '0';
        variable prev_misaligned : std_logic := '0';
        variable axi_transactions : std_logic_vector(2 downto 0) := "000";
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                -- Possibly set ready signals to allow pre-reset but still-incoming 
                -- transactions to pretend like they're accepted?
                o_axi_wstrb   <= (others => '0');
                o_axi_wvalid  <= '0';
                o_axi_arvalid <= '0';
                o_axi_awvalid <= '0';
                o_axi_bready  <= '0';
                o_axi_rready  <= '0';
                o_axi_wdata   <= (others => '0');
                o_axi_arprot  <= (others => '0');
                o_axi_awprot  <= (others => '0');
            else
                case state is
                    when IDLE =>
                        o_axi_awvalid <= '0';
                        o_axi_wvalid  <= '0';
                        o_axi_bready  <= '0';
                        o_axi_awprot  <= (others => '0');
                        
                        o_axi_arvalid <= '0';
                        o_axi_rready  <= '0';
                        o_axi_arprot  <= (others => '0');

                        o_axi_awaddr <= i_bus_addr;
                        o_axi_araddr <= i_bus_addr;
                        o_axi_wdata  <= i_bus_wdata;
                        o_axi_wstrb  <= i_bus_wen;

                        o_bus_valid <= '0';

                        if (i_bus_en = '1') then
                            if (any(i_bus_wen) = '1') then
                                state <= PERFORM_AXI_WRITE;
                                o_axi_awvalid <= '1';
                                o_axi_wvalid  <= '1';
                                o_axi_bready  <= '1';
                            else
                                state <= PERFORM_AXI_READ;
                                o_axi_arvalid <= '1';
                                o_axi_rready  <= '1';
                            end if;
                        end if;
                
                    when PERFORM_AXI_WRITE =>
                        if (i_axi_awready = '1') then
                            o_axi_awvalid <= '0';
                            axi_transactions(0) := '1';
                        end if;

                        if (i_axi_wready = '1') then
                            o_axi_wvalid <= '0';
                            -- Be sure to clear wstrb in case we initiate another transfer
                            -- (i.e. we were misaligned.)
                            o_axi_wstrb  <= (others => '0');
                            axi_transactions(1) := '1';
                        end if;

                        if (i_axi_bvalid = '1') then
                            o_axi_bready <= '0';
                            axi_transactions(2) := '1';
                        end if;

                        if (axi_transactions = "111") then
                            axi_transactions := "000";

                            o_bus_rdata <= (others => '0');
                            o_bus_valid <= '1';
                            state     <= IDLE;
                        end if;

                    when PERFORM_AXI_READ =>
                        if (i_axi_arready = '1') then
                            o_axi_arvalid <= '0';
                            axi_transactions(0) := '1';
                        end if;

                        if (i_axi_rvalid = '1') then
                            o_bus_rdata <= i_axi_rdata;

                            o_axi_rready <= '0';
                            axi_transactions(1) := '1';
                        end if;

                        if (axi_transactions = "011") then
                            axi_transactions := "000";

                            o_bus_valid <= '1';
                            state <= IDLE;
                        end if;

                end case;
            end if;
            dbg_axi_transactions <= axi_transactions;
            dbg_misaligned       <= misaligned;
            dbg_prev_misaligned  <= prev_misaligned;
        end if;
    end process StateMachine;
    
end architecture rtl;