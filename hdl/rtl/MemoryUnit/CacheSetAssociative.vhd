library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    use ndsmd_riscv.CacheUtility.all;

entity CacheSetAssociative is
    generic (
        cAddrWidth_b       : positive := 32;
        cCachelineSize_B   : positive := 16;
        cCacheSize_entries : positive := 1024;
        cCache_NumSets     : positive := 4
    );
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_cache_addr  : in std_logic_vector(cAddrWidth_b - 1 downto 0);
        i_cache_en    : in std_logic;
        i_cache_wen   : in std_logic_vector(cCachelineSize_B - 1 downto 0);
        i_cache_wdata : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_cache_rdata : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_cache_valid : out std_logic;

        o_cache_hit  : out std_logic;
        o_cache_miss : out std_logic;

        o_mem_addr  : out std_logic_vector(cAddrWidth_b - 1 downto 0);
        o_mem_en    : out std_logic;
        o_mem_wen   : out std_logic_vector(cCachelineSize_B - 1 downto 0);
        o_mem_wdata : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        i_mem_rdata : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        i_mem_valid : in std_logic
    );
end entity CacheSetAssociative;

architecture rtl of CacheSetAssociative is
    
begin
    
    -- assert is_pow_of_2(cCachelineSize_B) and is_pow_of_2(cCacheSize_entries) 
    --     report "Cache parameters must be powers of 2." severity error;

    -- -- Index the cacheline address out of the input address
    -- cacheline_addr <= i_cache_addr(
    --     clog2(cCacheSize_entries) + clog2(cCachelineSize_B) - 1 downto clog2(cCachelineSize_B));
    -- -- Index the upper address out of the input address
    -- upper_memaddr <= i_cache_addr(
    --     cAddrWidth_b - 1 downto clog2(cCacheSize_entries) + clog2(cCachelineSize_B));

    -- -- Since we don't allow back-to-back accesses, we disallow that by filtering one cycle after.
    -- cache_en  <= i_cache_en and not en_reg;
    -- -- Since we're not doing byte addressable caching, we just check if any of them need to be written.
    -- cache_wen <= any(i_cache_wen);

    -- gSetAssociative: for g_ii in 0 to cCache_NumSets - 1 generate

    --     -- TODO: Add a round-robin cache mechanism (its cheaper than LRU so ¯\_(ツ)_/¯)
    --     --       the round-robin cache indexing mechanism would essentially index the cache_wen and
    --     --       valid signals

    --     eBram : entity ndsmd_riscv.DualPortBram
    --     generic map (
    --         cAddressWidth_b => cCacheAddrWidth_b,
    --         cMaxAddress     => 2 ** cCacheAddrWidth_b,
    --         cDataWidth_b    => 8 * cCachelineSize_B
    --     ) port map (
    --         i_clk => i_clk,
    
    --         i_addra  => cacheline_addr,
    --         i_ena    => cache_en,
    --         i_wena   => cache_wen(g_ii),
    --         i_wdataa => i_cache_wdata,
    --         o_rdataa => cache_rdata(g_ii),
    
    --         i_addrb  => cacheline_addr_b,
    --         i_enb    => valid(g_ii),
    --         i_wenb   => valid(g_ii),
    --         i_wdatab => rdata,
    --         o_rdatab => open
    --     );
    
    --     eMetadata : entity ndsmd_riscv.DualPortBram
    --     generic map (
    --         cAddressWidth_b => cCacheAddrWidth_b,
    --         cMaxAddress     => 2 ** cCacheAddrWidth_b,
    --         cDataWidth_b    => cMetadataWidth_b
    --     ) port map (
    --         i_clk => i_clk,
    
    --         i_addra  => cacheline_addr,
    --         i_ena    => cache_en,
    --         i_wena   => '0',
    --         i_wdataa => (others => '0'),
    --         o_rdataa => meta_rdata(g_ii),
    
    --         i_addrb  => cacheline_addr_b,
    --         i_enb    => valid(g_ii),
    --         i_wenb   => valid(g_ii),
    --         i_wdatab => meta_wdata,
    --         o_rdatab => open
    --     );

    -- end generate gSetAssociative;

    -- metadata   <= slv_to_metadata(meta_rdata);
    -- meta_wdata <= metadata_to_slv(metadata_w);

    -- is_read <= bool2bit(
    --     -- we're accessing the bram
    --     (en_reg = '1') and 
    --     -- but not writing anything
    --     (any(wen_reg) = '0'));

    -- is_write <= bool2bit(
    --     -- we're accessing the bram
    --     (en_reg = '1') and 
    --     -- and writing something
    --     (any(wen_reg) = '1'));

    -- is_hit <= bool2bit(
    --     -- and the data is valid
    --     (metadata.valid = '1') and
    --     -- and the address is the same 
    --     (metadata.upper_address = upper_addr_reg));

    -- read_hit  <= is_read and is_hit;
    -- read_miss <= is_read and not is_hit;

    -- write_hit  <= is_write and is_hit;
    -- write_miss <= is_write and not is_hit;

    -- -- read hits take 1 cc, write hits take 2 cc because we have to write back to the cache
    -- -- misses take the penalty of the read or write side.
    -- o_cache_valid <= valid or read_hit;
    -- o_cache_rdata <= rdata;

    -- StateMachine: process(i_clk)
    -- begin
    --     if rising_edge(i_clk) then
    --         if (i_resetn = '0') then
    --             en_reg             <= '0';
    --             wen_reg            <= (others => '0');
    --             upper_addr_reg     <= (others => '0');
    --             cacheline_addr_reg <= (others => '0');
    --             cache_wdata_reg    <= (others => '0');

    --             -- Preserve the status so we know our state we need to transition to
    --             status.is_write <= '0';
    --             status.is_hit   <= '0';
    --             valid           <= '0';

    --         else
    --             valid <= '0';

    --             case state is
    --                 when RESET =>
    --                     -- TODO: Entirely empty the metadata of the cache to an invalid state
    --                     state <= IDLE;

    --                 when IDLE =>
    --                     -- preserve whether an access was performed
    --                     en_reg             <= i_cache_en;
    --                     -- preserve what bytes need to be written
    --                     wen_reg            <= i_cache_wen;
    --                     -- preserve what the metadata requires
    --                     upper_addr_reg     <= upper_address;
    --                     -- preserve the cacheline so we know where to write to later
    --                     cacheline_addr_reg <= cacheline_addr;
    --                     -- preserve the write data in case we need it for writeback
    --                     cache_wdata_reg    <= i_cache_wdata;

    --                     -- Preserve the status so we know our state we need to transition to
    --                     status.is_write <= is_write;
    --                     status.is_hit   <= is_hit;

    --                     if (write_miss = '1') then
    --                         if (metadata.dirty = '1') then
    --                             -- need to write memory, read memory, edit and writeback to cache while returning valid
    --                             state       <= REQUEST_MEM_WRITE;
    --                             o_mem_addr  <= metadata.upper_address & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
    --                             o_mem_en    <= '1';
    --                             o_mem_wen   <= (others => '1');
    --                             o_mem_wdata <= cache_rdata;
    --                         else
    --                             -- need to read memory, edit and writeback to cache while returning valid
    --                             state      <= REQUEST_MEM_READ;
    --                             o_mem_addr <= upper_addr_reg & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
    --                             o_mem_en   <= '1';
    --                             o_mem_wen  <= (others => '0');
    --                         end if;

    --                     elsif (write_hit = '1') then
    --                         -- need to read cache, edit and writeback to cache while returning valid
    --                         state <= IDLE;
    --                         for ii in 0 to cCachelineSize_B - 1 loop
    --                             if (wen_reg(ii) = '1') then
    --                                 rdata(8 * ii + 7 downto 8 * ii) <= cache_wdata_reg(8 * ii + 7 downto 8 * ii);
    --                             else
    --                                 rdata(8 * ii + 7 downto 8 * ii) <= cache_rdata(8 * ii + 7 downto 8 * ii);
    --                             end if;
    --                         end loop;

    --                         cacheline_addr_b <= cacheline_addr_reg;
    --                         valid            <= '1';
    --                         metadata_w.dirty <= '1';
    --                         metadata_w.valid <= '1';
    --                         metadata_w.upper_address <= upper_addr_reg;
    --                     elsif (read_hit = '1') then
    --                         -- read hit, no change
    --                         state <= IDLE;
    --                     elsif (read_miss = '1') then
    --                         if (metadata.dirty = '1') then
    --                             -- need to write memory, read memory, then writeback to cache while returning valid
    --                             state       <= REQUEST_MEM_WRITE;
    --                             o_mem_addr  <= metadata.upper_address & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
    --                             o_mem_en    <= '1';
    --                             o_mem_wen   <= (others => '1');
    --                             o_mem_wdata <= cache_rdata;
    --                         else
    --                             -- need to read memory and then writeback to cache while returning valid
    --                             state      <= REQUEST_MEM_READ;
    --                             o_mem_addr <= upper_addr_reg & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
    --                             o_mem_en   <= '1';
    --                             o_mem_wen  <= (others => '0');
    --                         end if;
    --                     end if;
                
    --                 when REQUEST_MEM_WRITE =>
    --                     o_mem_en <= '0';
    --                     if (i_mem_valid = '1') then
    --                         -- Now we need to request a mem read
    --                         state      <= REQUEST_MEM_READ;
    --                         o_mem_addr <= upper_addr_reg & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
    --                         o_mem_en   <= '1';
    --                         o_mem_wen  <= (others => '0');
    --                     end if;

    --                 when REQUEST_MEM_READ =>
    --                     o_mem_en <= '0';
    --                     if (i_mem_valid = '1') then
    --                         for ii in 0 to cCachelineSize_B - 1 loop
    --                             if (wen_reg(ii) = '1') then
    --                                 rdata(8 * ii + 7 downto 8 * ii) <= cache_wdata_reg(8 * ii + 7 downto 8 * ii);
    --                             else
    --                                 rdata(8 * ii + 7 downto 8 * ii) <= i_mem_rdata(8 * ii + 7 downto 8 * ii);
    --                             end if;
    --                         end loop;
                            
    --                         cacheline_addr_b <= cacheline_addr_reg;
    --                         valid            <= '1';
    --                         metadata_w.dirty <= '0';
    --                         metadata_w.valid <= '1';
    --                         metadata_w.upper_address <= upper_addr_reg;

    --                         state <= IDLE;
    --                     end if;

    --             end case;
    --         end if;
    --     end if;
    -- end process StateMachine;
    
end architecture rtl;