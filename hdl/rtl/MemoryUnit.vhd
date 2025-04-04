library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library universal;
    use universal.CommonFunctions.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.DatapathUtility.all;

entity MemoryUnit is
    generic (
        cAddressWidth_b  : natural := 32;
        cCachelineSize_B : natural := 16
    );
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_decoded : in  decoded_instr_t;
        i_addr    : in  std_logic_vector(31 downto 0);
        i_data    : in  std_logic_vector(31 downto 0);
        o_res     : out std_logic_vector(31 downto 0);
        o_valid   : out std_logic;

        -- AXI-like interface to allow for easier implementation
        -- address bus for requesting an address
        o_data_awaddr : out std_logic_vector(cAddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        o_data_awprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_data_awvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_data_awready : in std_logic;

        -- write data bus
        o_data_wdata  : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        -- write data strobe
        o_data_wstrb : out std_logic_vector(cCachelineSize_B - 1 downto 0);
        -- write valid
        o_data_wvalid : out std_logic;
        -- write ready
        i_data_wready : in std_logic;

        -- response indicating error occurred, if any
        i_data_bresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that write response data is valid
        i_data_bvalid : in std_logic;
        -- ready to receive write response data
        o_data_bready : out std_logic;

        -- address bus for requesting an address
        o_data_araddr : out std_logic_vector(cAddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        o_data_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_data_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_data_arready : in std_logic;

        -- returned instruction data bus
        i_data_rdata  : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        -- response indicating error occurred, if any
        i_data_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        i_data_rvalid : in std_logic;
        -- ready to receive instruction data
        o_data_rready : out std_logic
    );
end entity MemoryUnit;

architecture rtl of MemoryUnit is
    constant cCachelineIndexWidth_b : natural := clog2(cCachelineSize_B);

    type state_t is (IDLE, PERFORM_AXI_WRITE, PERFORM_AXI_READ);
    signal state : state_t := IDLE;
    signal stored_data : std_logic_vector(31 downto 0) := (others => '0');
    signal stored_decoded : decoded_instr_t;
begin
    
    StateMachine: process(i_clk)
        variable lsb : natural range 0 to cCachelineSize_B - 1 := 0;
        variable misaligned : std_logic := '0';
        variable axi_transactions : std_logic_vector(2 downto 0) := "000";
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                
            else
                case state is
                    when IDLE =>
                        o_data_wstrb   <= (others => '0');
                        o_data_wvalid  <= '0';
                        o_data_arvalid <= '0';
                        o_data_awvalid <= '0';
                        o_data_bready  <= '0';
                        o_data_rready  <= '0';

                        if (i_decoded.mem_operation /= NULL_OP) then
                            -- If we're not a NULL_OP, we're doing a memory access of some kind.

                            stored_data <= i_data;
                            stored_decoded <= i_decoded;

                            lsb := to_natural(i_addr(cCachelineIndexWidth_b - 1 downto 0));

                            misaligned := '0';

                            case (i_decoded.mem_access) is
                                when BYTE_ACCESS | UBYTE_ACCESS =>
                                    -- We don't need to check the alignment of the address, just get
                                    -- the bottom byte.
                                    o_data_wdata(8* (lsb + 1) - 1 downto 8 * lsb) <= i_data(7 downto 0);
                                    o_data_wstrb(lsb) <= bool2bit(i_decoded.mem_operation = STORE);
                                    
                                when HALF_WORD_ACCESS | UHALF_WORD_ACCESS | WORD_ACCESS =>
                                    -- We do need to check the alignment of the address. 
                                    -- If misaligned, we will stall and attempt two accesses.
                                    if (lsb = cCachelineSize_B - 1) then
                                        -- We're misaligned, and will need to perform two accesses.
                                        misaligned := '1';
                                        -- Get the bottom byte for the first access.
                                        o_data_wdata(8* (lsb + 1) - 1 downto 8 * lsb) <= i_data(7 downto 0);
                                        o_data_wstrb(lsb) <= bool2bit(i_decoded.mem_operation = STORE);
                                    elsif (lsb > cCachelineSize_B - 4 and i_decoded.mem_access = WORD_ACCESS) then
                                        -- We're misaligned, and will need to perform two accesses.
                                        misaligned := '1';
                                        -- Since this is a word access, we need to get the bottom bytes according
                                        -- to however much can be stored in the outgoing bus.
                                        o_data_wdata(8 * cCachelineSize_B - 1 downto 8 * lsb) <= i_data(8 * (cCachelineSize_B - lsb) - 1 downto 0);
                                        if (i_decoded.mem_operation = STORE) then
                                            o_data_wstrb(cCachelineSize_B - 1 downto lsb) <= (others => '1');
                                        end if;

                                    else

                                        if (i_decoded.mem_access = WORD_ACCESS) then
                                            -- Write the whole word to the wdata bus
                                            o_data_wdata(8 * (lsb + 4) - 1 downto 8 * lsb) <= i_data;

                                            -- If we're storing, indicate we're storing the whole thing
                                            if (i_decoded.mem_operation = STORE) then
                                                o_data_wstrb(lsb + 3 downto lsb) <= "1111";
                                            end if;
                                        else
                                            -- Write the half word to the wdata bus
                                            o_data_wdata(8 * (lsb + 2) - 1 downto 8 * lsb) <= i_data(15 downto 0);

                                            -- If we're storing, we're only storing two bytes.
                                            if (i_decoded.mem_operation = STORE) then
                                                o_data_wstrb(lsb + 1 downto lsb) <= "11";
                                            end if;
                                        end if;

                                    end if;
                            
                            end case;

                        end if;

                        if (i_decoded.mem_operation = STORE) then
                            state <= PERFORM_AXI_WRITE;
                            o_data_awaddr(cCachelineIndexWidth_b - 1 downto 0) <= (others => '0');
                            o_data_awaddr(cAddressWidth_b - 1 downto cCachelineIndexWidth_b) 
                                <= i_addr(cAddressWidth_b - 1 downto cCachelineIndexWidth_b);
                            o_data_awvalid <= '1';

                            -- We would have already put the wdata and wstrb on the busses above, so we can set the wvalid
                            o_data_wvalid <= '1';

                            -- And since we're hoping for a quick response to all three transactions in the transfer, 
                            -- go ahead and set bready high as well.
                            o_data_bready <= '1';
                        end if;

                        if (i_decoded.mem_operation = LOAD) then
                            state <= PERFORM_AXI_READ;
                            o_data_araddr(cCachelineIndexWidth_b - 1 downto 0) <= (others => '0');
                            o_data_araddr(cAddressWidth_b - 1 downto cCachelineIndexWidth_b) 
                                <= i_addr(cAddressWidth_b - 1 downto cCachelineIndexWidth_b);
                            o_data_arvalid <= '1';

                            -- And since we're hoping for a quick response to both transactions in the transfer, 
                            -- go ahead and set rready high as well.
                            o_data_rready <= '1';
                        end if;
                
                    when PERFORM_AXI_WRITE =>
                        if (i_data_awready = '1') then
                            o_data_awvalid <= '0';
                            axi_transactions(0) := '1';
                        end if;

                        if (i_data_wready = '1') then
                            o_data_wvalid <= '0';
                            -- Be sure to clear wstrb in case we initiate another transfer
                            -- (i.e. we were misaligned.)
                            o_data_wstrb  <= (others => '0');
                            axi_transactions(1) := '1';
                        end if;

                        if (i_data_bvalid = '1') then
                            o_data_bready <= '0';
                            axi_transactions(2) := '1';
                        end if;

                        if (axi_transactions = "111") then
                            if (misaligned = '1') then
                                
                                -- Clear the misaligned flag, and all the axi transactions registers
                                -- since we will repeat this state for the second axi transfer of the
                                -- upper bytes.
                                misaligned       := '0';
                                axi_transactions := "000";
                                state <= PERFORM_AXI_WRITE;

                                case (stored_decoded.mem_access) is
                                    when BYTE_ACCESS | UBYTE_ACCESS =>
                                        -- We shouldn't be here! There is no such thing as a misaligned byte access.
                                        assert false 
                                            report "MemoryUnit::StateMachine: Should not be misaligned and performing a byte access." 
                                            severity failure;
                                        
                                    when HALF_WORD_ACCESS | UHALF_WORD_ACCESS =>
                                        -- Get the top byte for the second access. This will always be the 
                                        -- 15 downto 8 slice and the first byte in wstrb.
                                        o_data_wdata(7 downto 0) <= stored_data(15 downto 8);
                                        o_data_wstrb(0) <= '1';
                                    
                                    when WORD_ACCESS =>
                                        -- Since this is a word access, we need to get the upper bytes according
                                        -- to however much can be stored in the outgoing bus.
                                        o_data_wdata(8 * (4 - (cCachelineSize_B - lsb)) - 1 downto 0) <= stored_data(31 downto 8 * (cCachelineSize_B - lsb));
                                        o_data_wstrb((4 - (cCachelineSize_B - lsb)) - 1 downto 0) <= (others => '1');
                                
                                end case;

                            else
                                -- If we don't have any more outstanding reads, go to idle.
                                state <= IDLE;
                            end if;
                        end if;

                    when others =>
                        
                
                end case;
            end if;
        end if;
    end process StateMachine;

    -- Integrate L1dCache here. This needs to do the following:
    -- 1. Read/Write to a BRAM in a single cycle that contains:
    --      - valid bit
    --      - dirty bit
    --      - tag
    --      - cacheline
    -- For first iteration, use a direct mapped cache. Other architectures
    -- will be evaluated later.

    -- Hot take, but could we also integrate memory mapped peripherals
    -- here? Specifically high performance ones, like timers and stuff that
    -- would otherwise have to be placed on the AXI bus?
    
end architecture rtl;