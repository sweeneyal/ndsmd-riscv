library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;
    use nsfrtu_riscv.InstructionUtility.all;
    use nsfrtu_riscv.DatapathUtility.all;

entity MemoryUnit is
    generic (
        cAddressWidth_b    : positive := 32;
        cDataWidth_b       : positive := 32;
        cCachelineSize_B   : positive := 16;

        cGenerateCache     : boolean  := true;
        cCacheType         : string   := "Direct";
        cCacheSize_entries : positive := 1024;
        cCache_NumSets     : positive := 1;
        
        cNumCacheMasks     : positive := 1;
        cCacheMasks        : std_logic_matrix_t
            (0 to cNumCacheMasks - 1)(cAddressWidth_b - 1 downto 0) := (0 => x"0000FFFF")
    );
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_decoded : in  decoded_instr_t;
        i_valid   : in  std_logic;
        i_addr    : in  std_logic_vector(cAddressWidth_b - 1 downto 0);
        i_data    : in  std_logic_vector(cDataWidth_b - 1 downto 0);
        o_res     : out std_logic_vector(cDataWidth_b - 1 downto 0);
        o_valid   : out std_logic;

        --
        o_cache_hit : out std_logic;
        --
        o_cache_miss : out std_logic;

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

    type prestate_t is (IDLE, WAIT_FOR_RESPONSE);
    signal prestate : prestate_t := IDLE;
    signal stored_addr : std_logic_vector(cAddressWidth_b - 1 downto 0) := (others => '0');
    signal stored_data : std_logic_vector(31 downto 0) := (others => '0');
    signal stored_decoded : decoded_instr_t;

    signal cache_addr  : std_logic_vector(cAddressWidth_b - 1 downto 0);
    signal cache_en    : std_logic;
    signal cache_wen   : std_logic_vector(cCachelineSize_B - 1 downto 0);
    signal cache_wdata : std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
    signal cache_rdata : std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
    signal cache_valid : std_logic;

    signal mem_addr  : std_logic_vector(cAddressWidth_b - 1 downto 0);
    signal mem_en    : std_logic;
    signal mem_wen   : std_logic_vector(cCachelineSize_B - 1 downto 0);
    signal mem_wdata : std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
    signal mem_rdata : std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
    signal mem_valid : std_logic;
begin

    -----------------------------------------------------------------------------------------------------
    -- New: Separate out the IDLE state and the AXI performant states to allow a prestage here, before
    -- the cache so we can do misaligned or weirdly aligned accesses. Then, based on the if cGenerateCache
    -- check, we can either puppet the cache_* signals or the mem_* signals

    PreStage: process(i_clk)
        variable lsb             : natural range 0 to cCachelineSize_B - 1 := 0;
        variable misaligned      : std_logic := '0';
        variable prev_misaligned : std_logic := '0';
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                cache_en  <= '0';
                cache_wen <= (others => '0');
            else
                case prestate is
                    when IDLE =>
                        o_valid   <= '0';
                        cache_en  <= '0';
                        cache_wen <= (others => '0');

                        if (i_decoded.mem_operation /= NULL_OP and i_valid = '1') then
                            -- If we're not a NULL_OP, we're doing a memory access of some kind.

                            -- Preserve the parameters of the operation, in case theres a misalignment
                            stored_addr    <= i_addr;
                            stored_data    <= i_data;
                            stored_decoded <= i_decoded;

                            lsb := to_natural(i_addr(cCachelineIndexWidth_b - 1 downto 0));

                            -- Determine the type of access being performed
                            case (i_decoded.mem_access) is
                                when BYTE_ACCESS | UBYTE_ACCESS =>
                                    -- We don't need to check the alignment of the address, just get
                                    -- the bottom byte.
                                    cache_wdata(8* (lsb + 1) - 1 downto 8 * lsb) <= i_data(7 downto 0);
                                    cache_wen(lsb) <= bool2bit(i_decoded.mem_operation = STORE);
                                    
                                when HALF_WORD_ACCESS | UHALF_WORD_ACCESS | WORD_ACCESS =>
                                    -- We do need to check the alignment of the address. 
                                    -- If misaligned, we will stall and attempt two accesses.
                                    if (lsb = cCachelineSize_B - 1) then
                                        -- We're misaligned, and will need to perform two accesses.
                                        misaligned := '1';
                                        
                                        -- Get the bottom byte for the first access.
                                        cache_wdata(8* (lsb + 1) - 1 downto 8 * lsb) <= i_data(7 downto 0);
                                        cache_wen(lsb) <= bool2bit(i_decoded.mem_operation = STORE);
                                    elsif (lsb > cCachelineSize_B - 4 and i_decoded.mem_access = WORD_ACCESS) then
                                        -- We're misaligned, and will need to perform two accesses.
                                        misaligned := '1';

                                        -- Since this is a word access, we need to get the bottom bytes according
                                        -- to however much can be stored in the outgoing bus.
                                        cache_wdata(8 * cCachelineSize_B - 1 downto 8 * lsb) <= i_data(8 * (cCachelineSize_B - lsb) - 1 downto 0);
                                        if (i_decoded.mem_operation = STORE) then
                                            cache_wen(cCachelineSize_B - 1 downto lsb) <= (others => '1');
                                        end if;
                                    else
                                        -- Otherwise, we have no alignment issues and can therefore do one access.
                                        if (i_decoded.mem_access = WORD_ACCESS) then
                                            -- Write the whole word to the wdata bus
                                            cache_wdata(8 * (lsb + 4) - 1 downto 8 * lsb) <= i_data(31 downto 0);
                    
                                            -- If we're storing, indicate we're storing the whole thing
                                            if (i_decoded.mem_operation = STORE) then
                                                cache_wen(lsb + 3 downto lsb) <= "1111";
                                            end if;
                                        else
                                            -- Write the half word to the wdata bus
                                            cache_wdata(8 * (lsb + 2) - 1 downto 8 * lsb) <= i_data(15 downto 0);
                    
                                            -- If we're storing, we're only storing two bytes.
                                            if (i_decoded.mem_operation = STORE) then
                                                cache_wen(lsb + 1 downto lsb) <= "11";
                                            end if;
                                        end if;
                    
                                    end if;
                    
                                when others =>
                                    assert false report "MemoryUnit::PreStage: Floats and doubles are not implemented yet." severity error;
                            
                            end case;

                            -- Once the write aspect is complete, we need to indicate to the cache 
                            -- what address we're interested in.
                            -- The bottom bytes are zeroed because we don't care about them here.
                            cache_addr(cCachelineIndexWidth_b - 1 downto 0) <= (others => '0');
                            -- The upper bytes are assigned with the upper bytes of the address to be accessed.
                            cache_addr(cAddressWidth_b - 1 downto cCachelineIndexWidth_b) 
                                <= i_addr(cAddressWidth_b - 1 downto cCachelineIndexWidth_b);
                            -- Enable the cache access, and continue to the next state.
                            cache_en <= '1';

                            prestate <= WAIT_FOR_RESPONSE;
                        end if;
                        
                    when WAIT_FOR_RESPONSE =>
                        -- Clear the enable, as we don't want to keep it high.
                        cache_en <= '0';

                        -- Wait until the cache responds with a valid signal.
                        if (cache_valid = '1') then
                            -- Find the LSB again to identify the bytes we're interested in.
                            lsb := to_natural(stored_addr(cCachelineIndexWidth_b - 1 downto 0));
                            case (stored_decoded.mem_access) is
                                when BYTE_ACCESS =>
                                    -- No such thing as a misaligned byte, so just grab the byte we need and sign extend it
                                    o_res(31 downto 0) <= std_logic_vector(
                                        resize(signed(cache_rdata(8 * (lsb + 1) - 1 downto 8 * lsb)), 32)
                                        );
                                when UBYTE_ACCESS =>
                                    -- No such thing as a misaligned byte, so just grab the byte we need and zero pad it
                                    o_res(31 downto 0) <= std_logic_vector(
                                        resize(unsigned(cache_rdata(8 * (lsb + 1) - 1 downto 8 * lsb)), 32)
                                        );
                                when HALF_WORD_ACCESS =>
                                    if (misaligned = '1') then
                                        -- When misaligned, grab the bottom byte we can and throw it in the data bus.
                                        o_res(7 downto 0) <= cache_rdata(8 * (lsb + 1) - 1 downto 8 * lsb);
                                    elsif (prev_misaligned = '1') then
                                        -- On the second read to finish the misaligned access, grab the bottom byte and
                                        -- sign extend it, throwing it on the data bus.
                                        o_res(31 downto 8) <= std_logic_vector(
                                            resize(signed(cache_rdata(7 downto 0)), 24)
                                        );
                                    else
                                        -- When no misalignment occurs, we can just grab both bytes and sign extend them.
                                        report integer'image(lsb);
                                        report integer'image(cCachelineSize_B);
                                        o_res(31 downto 0) <= std_logic_vector(
                                            resize(signed(cache_rdata(8 * (lsb) + 15 downto 8 * lsb)), 32)
                                            );
                                    end if;
                                when UHALF_WORD_ACCESS =>
                                    if (misaligned = '1') then
                                        -- When misaligned, grab the byte we can and throw it in the data bus.
                                        o_res(7 downto 0) <= cache_rdata(8 * (lsb + 1) - 1 downto 8 * lsb);
                                    elsif (prev_misaligned = '1') then
                                        -- On the second read to finish the misaligned access, grab the bottom byte and
                                        -- zero pad it, throwing it on the data bus.
                                        o_res(31 downto 8) <= std_logic_vector(
                                            resize(unsigned(cache_rdata(7 downto 0)), 24)
                                            );
                                    else
                                        -- We can just grab both bytes and zero pad them.
                                        o_res(31 downto 0) <= std_logic_vector(
                                            resize(unsigned(cache_rdata(8 * (lsb + 2) - 1 downto 8 * lsb)), 32)
                                            );
                                    end if;
                                
                                when WORD_ACCESS =>
                                    if (misaligned = '1') then
                                        -- When misaligned, grab the bytes we can and throw them in the data bus.
                                        o_res(8 * (cCachelineSize_B - lsb) - 1 downto 0) <= cache_rdata(8 * cCachelineSize_B - 1 downto 8 * lsb);
                                    elsif (prev_misaligned = '1') then
                                        -- On the second access, we need to get the other bytes that we did not access the first time.
                                        o_res(31 downto 8 * (cCachelineSize_B - lsb)) <= cache_rdata(8 * (4 - (cCachelineSize_B - lsb)) - 1 downto 0);
                                    else
                                        -- We can just grab all four bytes.
                                        o_res(31 downto 0) <= cache_rdata(8 * (lsb + 4) - 1 downto 8 * lsb);
                                    end if;

                                when others =>
                                    -- We shouldn't be here! These are not implemented yet.
                                    assert false 
                                        report "MemoryUnit::StateMachine: Floating and double accesses are not implemented yet." 
                                        severity failure;
                            
                            end case;

                            if (misaligned = '1') then

                                -- Clear the misaligned flag, but set the prev_misaligned flag so we know
                                -- to do the second half of the alignment sequence.
                                misaligned      := '0';
                                prev_misaligned := '1';

                                case (stored_decoded.mem_access) is
                                    when BYTE_ACCESS | UBYTE_ACCESS =>
                                        -- We shouldn't be here! There is no such thing as a misaligned byte access.
                                        assert false 
                                            report "MemoryUnit::StateMachine: Should not be misaligned and performing a byte access." 
                                            severity failure;
                                        
                                    when HALF_WORD_ACCESS | UHALF_WORD_ACCESS =>
                                        -- Get the top byte for the second access. This will always be the 
                                        -- 15 downto 8 slice and the first byte in wstrb.
                                        cache_wdata(7 downto 0) <= stored_data(15 downto 8);
                                        cache_wen(0) <= '1';
                                    
                                    when WORD_ACCESS =>
                                        -- Since this is a word access, we need to get the upper bytes according
                                        -- to however much can be stored in the outgoing bus.
                                        cache_wdata(8 * (4 - (cCachelineSize_B - lsb)) - 1 downto 0) <= 
                                            stored_data(31 downto 8 * (cCachelineSize_B - lsb));
                                        cache_wen((4 - (cCachelineSize_B - lsb)) - 1 downto 0) <= (others => '1');

                                    when others =>
                                        -- We shouldn't be here! These are not implemented yet.
                                        assert false 
                                            report "MemoryUnit::StateMachine: Floating and double accesses are not implemented yet." 
                                            severity failure;
                                
                                end case;

                                -- Get the address of the next block up, which is the upper part of the address sliced,
                                -- cast to unsigned, incremented, and then padded with zeros.
                                cache_addr(cCachelineIndexWidth_b - 1 downto 0) <= (others => '0');
                                cache_addr(cAddressWidth_b - 1 downto cCachelineIndexWidth_b) 
                                    <= std_logic_vector(unsigned(stored_addr(cAddressWidth_b - 1 downto cCachelineIndexWidth_b)) + 1);
                                cache_en <= '1';
                                
                                prestate <= WAIT_FOR_RESPONSE;
                            else
                                -- Assuming we're all done with alignment issues, we now can indicate to the processor
                                -- the completion of the accesses. Make sure to clear any signals, and continue back to IDLE.
                                o_valid         <= '1';
                                prev_misaligned := '0';

                                prestate        <= IDLE;
                            end if;
                        end if;
                end case;
                
            end if;
        end if;
    end process PreStage;

    gCache: if cGenerateCache generate

        eCache : entity nsfrtu_riscv.SimpleCache
        generic map (
            cCacheType         => cCacheType,
            cAddressWidth_b    => cAddressWidth_b,
            cCachelineSize_B   => cCachelineSize_B,
            cCacheSize_entries => cCacheSize_entries,
            cCache_NumSets     => cCache_NumSets,
            cNumCacheMasks     => cNumCacheMasks,
            cCacheMasks        => cCacheMasks
        ) port map (
            i_clk    => i_clk,
            i_resetn => i_resetn,

            i_cache_addr   => cache_addr,
            i_cache_en     => cache_en,
            i_cache_wen    => cache_wen,
            i_cache_wdata  => cache_wdata,
            o_cache_rdata  => cache_rdata,
            o_cache_valid  => cache_valid,

            o_cache_hit  => o_cache_hit,
            o_cache_miss => o_cache_miss,

            o_mem_addr  => mem_addr,
            o_mem_en    => mem_en,
            o_mem_wen   => mem_wen,
            o_mem_wdata => mem_wdata,
            i_mem_rdata => mem_rdata,
            i_mem_valid => mem_valid
        );

    else generate

        mem_addr    <= cache_addr;
        mem_en      <= cache_en;
        mem_wen     <= cache_wen;
        mem_wdata   <= cache_wdata;
        cache_rdata <= mem_rdata;
        cache_valid <= mem_valid;
        
    end generate gCache;

    -- Hot take, but could we also integrate memory mapped peripherals
    -- here? Specifically high performance ones, like timers and stuff that
    -- would otherwise have to be placed on the AXI bus?

    eBus2Axi : entity nsfrtu_riscv.Bus2Axi
    generic map (
        cAddressWidth_b => cAddressWidth_b,
        cCachelineSize_B => cCachelineSize_B
    ) port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        i_bus_addr  => mem_addr,
        i_bus_en    => mem_en,
        i_bus_wen   => mem_wen,
        i_bus_wdata => mem_wdata,
        o_bus_rdata => mem_rdata,
        o_bus_valid => mem_valid,

        o_axi_awaddr  => o_data_awaddr,
        o_axi_awprot  => o_data_awprot,
        o_axi_awvalid => o_data_awvalid,
        i_axi_awready => i_data_awready,

        o_axi_wdata  => o_data_wdata,
        o_axi_wstrb  => o_data_wstrb,
        o_axi_wvalid => o_data_wvalid,
        i_axi_wready => i_data_wready,

        i_axi_bresp  => i_data_bresp,
        i_axi_bvalid => i_data_bvalid,
        o_axi_bready => o_data_bready,

        o_axi_araddr  => o_data_araddr,
        o_axi_arprot  => o_data_arprot,
        o_axi_arvalid => o_data_arvalid,
        i_axi_arready => i_data_arready,

        i_axi_rdata  => i_data_rdata,
        i_axi_rresp  => i_data_rresp,
        i_axi_rvalid => i_data_rvalid,
        o_axi_rready => o_data_rready
    );
    
end architecture rtl;