library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;

entity CacheSetAssociative is
    generic (
        cAddressWidth_b    : positive := 32;
        cCachelineSize_B   : positive := 16;
        cCacheSize_entries : positive := 1024;
        cCache_NumSets     : positive := 4;
        cNumCacheMasks     : positive := 4;
        cLruCounterWidth_b : positive := 4;
        cCacheMasks        : std_logic_matrix_t
            (0 to cNumCacheMasks - 1)(cAddressWidth_b - 1 downto 0)
    );
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_cache_addr  : in std_logic_vector(cAddressWidth_b - 1 downto 0);
        i_cache_en    : in std_logic;
        i_cache_wen   : in std_logic_vector(cCachelineSize_B - 1 downto 0);
        i_cache_wdata : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_cache_rdata : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_cache_valid : out std_logic;

        o_cache_hit  : out std_logic;
        o_cache_miss : out std_logic;

        o_mem_addr  : out std_logic_vector(cAddressWidth_b - 1 downto 0);
        o_mem_en    : out std_logic;
        o_mem_wen   : out std_logic_vector(cCachelineSize_B - 1 downto 0);
        o_mem_wdata : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        i_mem_rdata : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        i_mem_valid : in std_logic
    );
end entity CacheSetAssociative;

architecture rtl of CacheSetAssociative is
    constant cCacheAddrWidth_b  : positive := clog2(cCacheSize_entries/cCache_NumSets);
    constant cUpperAddrWidth_b  : positive := cAddressWidth_b - clog2(cCacheSize_entries/cCache_NumSets) - clog2(cCachelineSize_B);
    constant cMetadataWidth_b   : positive := cUpperAddrWidth_b + 2 + cLruCounterWidth_b;

    -- In this implementation, LRU works by incrementing the hit metadata while
    -- decrementing the miss metadata, within the range of 0 to 2**cLruCounterWidth_b - 1.
    -- This means that the set that is least recently used is the least incremented set,
    -- and also- means that the LRU bits are stored as metadata in a BRAM, which is less expensive
    -- than parallel registers.

    type metadata_t is record
        upper_address : std_logic_vector;
        lru           : unsigned;
        dirty         : std_logic;
        valid         : std_logic;
    end record metadata_t;

    function slv_to_metadata(s : std_logic_vector) return metadata_t is
        variable m : metadata_t(upper_address(s'length - 2 - cLruCounterWidth_b - 1 downto 0), lru(cLruCounterWidth_b - 1 downto 0));
    begin
        m.upper_address := s(s'length - 2 - cLruCounterWidth_b - 1 downto 0);
        m.lru           := unsigned(s(s'length - 3 downto s'length - 2 - cLruCounterWidth_b));
        m.dirty         := s(s'length - 2);
        m.valid         := s(s'length - 1);
        return m;
    end function;

    function metadata_to_slv(m : metadata_t) return std_logic_vector is
    begin
        return m.valid & m.dirty & std_logic_vector(m.lru) &  m.upper_address;
    end function;

    type set_metadata_t is array (0 to cCache_NumSets - 1) of 
        metadata_t(
            upper_address(cAddressWidth_b - 2 - cLruCounterWidth_b - 1 downto 0), 
            lru(cLruCounterWidth_b - 1 downto 0)
        );
    signal metadata : set_metadata_t;
    signal metadata_w : set_metadata_t;

    signal cacheline_addr   : std_logic_vector(cCacheAddrWidth_b - 1 downto 0) := (others => '0');
    signal upper_memaddr    : std_logic_vector(cUpperAddrWidth_b - 1 downto 0) := (others => '0');
    signal cache_en         : std_logic := '0';
    signal cache_wen        : std_logic := '0';
    signal cache_rdata      : std_logic_matrix_t
                                (0 to cCache_NumSets - 1)
                                (8 * cCachelineSize_B - 1 downto 0) := (others => (others => '0'));
    signal cacheline_addr_b : std_logic_vector(cCacheAddrWidth_b - 1 downto 0) := (others => '0');
    signal rdata_valid      : std_logic := '0';
    signal rdata            : std_logic_matrix_t
                                (0 to cCache_NumSets - 1)
                                (8 * cCachelineSize_B - 1 downto 0) := (others => (others => '0'));
    signal meta_rdata       : std_logic_matrix_t
                                (0 to cCache_NumSets - 1)
                                (cMetadataWidth_b - 1 downto 0) := (others => (others => '0'));
    signal meta_wdata       : std_logic_matrix_t
                                (0 to cCache_NumSets - 1)
                                (cMetadataWidth_b - 1 downto 0) := (others => (others => '0'));
    signal metadata_valid   : std_logic := '0';
    signal is_read          : std_logic := '0';
    signal is_write         : std_logic := '0';
    signal is_hit           : std_logic_vector(cCache_NumSets - 1 downto 0) := (others => '0');
    signal is_cacheable     : std_logic := '0';
    signal read_hit         : std_logic_vector(cCache_NumSets - 1 downto 0) := (others => '0');
    signal read_miss        : std_logic_vector(cCache_NumSets - 1 downto 0) := (others => '0');
    signal write_hit        : std_logic_vector(cCache_NumSets - 1 downto 0) := (others => '0');
    signal write_miss       : std_logic_vector(cCache_NumSets - 1 downto 0) := (others => '0');
    signal lru              : natural range 0 to cCache_NumSets - 1 := 0;
    signal hit              : natural range 0 to cCache_NumSets - 1 := 0;
    signal valids           : std_logic_vector(cCache_NumSets - 1 downto 0) := (others => '0');
    signal matches          : std_logic_vector(cCache_NumSets - 1 downto 0) := (others => '0');

    type state_t is (RESET, IDLE, REQUEST_MEM_READ, REQUEST_MEM_WRITE);
    signal state : state_t := RESET;

    type cache_status_t is record
        is_hit       : std_logic;
        is_write     : std_logic;
        is_cacheable : std_logic;
    end record cache_status_t;

    signal status : cache_status_t;

    signal en_reg             : std_logic := '0';
    signal wen_reg            : std_logic_vector(cCachelineSize_B - 1 downto 0) := (others => '0');
    signal cacheline_addr_reg : std_logic_vector(cCacheAddrWidth_b - 1 downto 0) := (others => '0');
    signal upper_addr_reg     : std_logic_vector(cUpperAddrWidth_b - 1 downto 0) := (others => '0');
    signal cache_wdata_reg    : std_logic_vector(8 * cCachelineSize_B - 1 downto 0) := (others => '0');
    signal cache_rdata_reg    : std_logic_matrix_t
                                    (0 to cCache_NumSets - 1)
                                    (8 * cCachelineSize_B - 1 downto 0) := (others => (others => '0'));
    signal lru_reg : natural range 0 to cCache_NumSets - 1 := 0;
    signal hit_reg : natural range 0 to cCache_NumSets - 1 := 0;

    signal write_valid : std_logic := '0';
begin
    
    assert is_pow_of_2(cCachelineSize_B) and is_pow_of_2(cCacheSize_entries) 
        report "Cache parameters must be powers of 2." severity error;

    -- Index the cacheline address out of the input address
    cacheline_addr <= i_cache_addr(
        clog2(cCacheSize_entries) + clog2(cCachelineSize_B) - 1 downto clog2(cCachelineSize_B));
    -- Index the upper address out of the input address
    upper_memaddr <= i_cache_addr(
        cAddressWidth_b - 1 downto clog2(cCacheSize_entries) + clog2(cCachelineSize_B));

    -- Since we don't allow back-to-back accesses, we disallow that by filtering one cycle after.
    cache_en  <= i_cache_en and not en_reg;
    -- Since we're not doing byte addressable caching, we just check if any of them need to be written.
    cache_wen <= any(i_cache_wen);

    gSetAssociative: for g_ii in 0 to cCache_NumSets - 1 generate

        -- Generate a pair of BRAMs and metadata BRAMs for each set.
        eBram : entity ndsmd_riscv.DualPortBram
        generic map (
            cAddressWidth_b => cCacheAddrWidth_b,
            cMaxAddress     => 2 ** cCacheAddrWidth_b,
            cDataWidth_b    => 8 * cCachelineSize_B
        ) port map (
            i_clk => i_clk,
    
            -- All will share the same external input busses,
            i_addra  => cacheline_addr,
            i_ena    => cache_en,
            i_wena   => cache_wen,
            i_wdataa => i_cache_wdata,
            -- But have unique output busses here.
            o_rdataa => cache_rdata(g_ii),
    
            i_addrb  => cacheline_addr_b,
            -- Further, each will share the valid signal but unique
            -- rdata signals. This is because we often need to writeback
            -- but have multiple unique things at the same address.
            i_enb    => rdata_valid,
            i_wenb   => rdata_valid,
            i_wdatab => rdata(g_ii),
            o_rdatab => open
        );
    
        eMetadata : entity ndsmd_riscv.DualPortBram
        generic map (
            cAddressWidth_b => cCacheAddrWidth_b,
            cMaxAddress     => 2 ** cCacheAddrWidth_b,
            cDataWidth_b    => cMetadataWidth_b
        ) port map (
            i_clk => i_clk,
    
            i_addra  => cacheline_addr,
            i_ena    => cache_en,
            i_wena   => '0',
            i_wdataa => (others => '0'),
            o_rdataa => meta_rdata(g_ii),
    
            i_addrb  => cacheline_addr_b,
            i_enb    => metadata_valid,
            i_wenb   => metadata_valid,
            i_wdatab => meta_wdata(g_ii),
            o_rdatab => open
        );

        metadata(g_ii)   <= slv_to_metadata(meta_rdata(g_ii));
        meta_wdata(g_ii) <= metadata_to_slv(metadata_w(g_ii));
    
        -- read hits take 1 cc, write hits take 2 cc because we have to write back to the cache
        -- misses take the penalty of the read or write side.
    end generate gSetAssociative;

    is_read <= bool2bit(
        -- we're accessing the bram
        (en_reg = '1') and 
        -- but not writing anything
        (any(wen_reg) = '0'));

    is_write <= bool2bit(
        -- we're accessing the bram
        (en_reg = '1') and 
        -- and writing something
        (any(wen_reg) = '1'));

    -- This finds the valid addresses and matching addresses in the parallel metadata.
    -- As well as identifies the LRU based on a counter stored with the data.
    Concatenation: process(metadata)
        variable lru_max : unsigned(cLruCounterWidth_b - 1 downto 0) := (others => '0');
    begin
        lru     <= 0;
        lru_max := (others => '0');
        for ii in 0 to cCache_NumSets - 1 loop
            valids(ii)  <= bool2bit(metadata(ii).valid = '1');
            matches(ii) <= bool2bit(metadata(ii).upper_address = upper_addr_reg);

            -- The least recently used is the index with the most misses,
            -- so whichever has the most number of misses is the first victim.
            if (lru_max < metadata(ii).lru) then
                lru     <= ii;
                lru_max := metadata(ii).lru;
            end if;
        end loop;
    end process Concatenation;

    -- hits are determined if the metadata is valid and matches
    -- and if its not a hit, its a miss. (i.e. is_hit(ii) = '0')
    is_hit  <= valids and matches;

    -- there is assumed to be only one hit.
    hit <= find_first_high_bit(is_hit);

    -- this identifies the individual hits and misses and their types
    IndividualHitsAndMisses: process(is_read, is_write, is_hit)
    begin
        for ii in 0 to cCache_NumSets - 1 loop
            read_hit(ii)  <= is_read and is_hit(ii);
            read_miss(ii) <= is_read and not is_hit(ii);
        
            write_hit(ii)  <= is_write and is_hit(ii);
            write_miss(ii) <= is_write and not is_hit(ii);
        end loop;
    end process IndividualHitsAndMisses;
        
    o_cache_valid <= rdata_valid or any(read_hit);
    DataMux: process(rdata, read_hit, lru_reg, cache_rdata)
    begin
        if (any(read_hit) = '1') then
            o_cache_rdata <= cache_rdata(hit);
        else
            o_cache_rdata <= rdata(lru_reg);
        end if;
    end process DataMux;

    StateMachine: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                en_reg             <= '0';
                wen_reg            <= (others => '0');
                upper_addr_reg     <= (others => '0');
                cacheline_addr_reg <= (others => '0');
                cache_wdata_reg    <= (others => '0');

                -- Preserve the status so we know our state we need to transition to
                status.is_write <= '0';
                status.is_hit   <= '0';
            else
                case state is
                    when RESET =>
                        -- TODO: Entirely empty the metadata of the cache to an invalid state
                        state <= IDLE;

                    when IDLE =>
                        -- preserve whether an access was performed
                        en_reg             <= i_cache_en;
                        -- preserve what bytes need to be written
                        wen_reg            <= i_cache_wen;
                        -- preserve what the metadata requires
                        upper_addr_reg     <= upper_memaddr;
                        -- preserve the cacheline so we know where to write to later
                        cacheline_addr_reg <= cacheline_addr;
                        -- preserve the write data in case we need it for writeback
                        cache_wdata_reg    <= i_cache_wdata;
                        -- preserve the cache data in case we need to write it back
                        cache_rdata_reg    <= cache_rdata;
                        -- preserve the lru in case we need it for writeback
                        lru_reg <= lru;
                        -- preserve the hit in case we need it for writeback
                        hit_reg <= hit;

                        -- Preserve the status so we know our state we need to transition to
                        status.is_write <= is_write;
                        status.is_hit   <= any(is_hit);

                        -- clear the data writing flags
                        rdata_valid    <= '0';
                        metadata_valid <= '0';

                        if (all_set(write_miss) = '1') then
                            if (metadata(lru).dirty = '1') then
                                -- need to write memory, read memory, edit and writeback to cache while returning valid
                                state       <= REQUEST_MEM_WRITE;
                                o_mem_addr  <= metadata(lru).upper_address & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                o_mem_en    <= '1';
                                o_mem_wen   <= (others => '1');
                                o_mem_wdata <= cache_rdata(lru);
                            else
                                -- need to read memory, edit and writeback to cache while returning valid
                                state      <= REQUEST_MEM_READ;
                                o_mem_addr <= upper_addr_reg & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                o_mem_en   <= '1';
                                o_mem_wen  <= (others => '0');
                            end if;

                        elsif (any(write_hit) = '1') then
                            -- need to read cache, edit and writeback to cache while returning valid
                            for ii in 0 to cCache_NumSets - 1 loop
                                if (ii = hit) then
                                    -- Modify the data in the hit set
                                    for jj in 0 to cCachelineSize_B - 1 loop
                                        if (wen_reg(jj) = '1') then
                                            rdata(hit)(8 * jj + 7 downto 8 * jj) <= cache_wdata_reg(8 * jj + 7 downto 8 * jj);
                                        else
                                            rdata(hit)(8 * jj + 7 downto 8 * jj) <= cache_rdata(hit)(8 * jj + 7 downto 8 * jj);
                                        end if;
                                    end loop;
                                else
                                    -- Preserve the data in the parallel sets
                                    rdata(ii) <= cache_rdata(ii);
                                end if;
                            end loop;

                            for ii in 0 to cCache_NumSets - 1 loop
                                if (is_hit(ii) = '0') then
                                    -- Maintain the same metadata state for the misses, except 
                                    -- increment the LRU counter for all parallel metadata.
                                    metadata_w(ii) <= metadata(ii);
                                    if (metadata(ii).lru < 2 ** cLruCounterWidth_b - 1) then
                                        metadata_w(ii).lru <= metadata(ii).lru + 1;
                                    end if;
                                else
                                    -- Modify the metadata to ensure we know it's dirty, valid, 
                                    -- recent, and has the specific upper address we've been using.
                                    metadata_w(ii).dirty <= '1';
                                    metadata_w(ii).valid <= '1';
                                    metadata_w(ii).lru   <= (others => '0');
                                    metadata_w(ii).upper_address <= upper_addr_reg;
                                end if;
                            end loop;

                            cacheline_addr_b <= cacheline_addr_reg;
                            -- Because rdata has been modified by both the initial write and the
                            -- above hit modification, we need to writeback all the parallel set data.
                            metadata_valid   <= '1';
                            rdata_valid      <= '1';
                            state            <= IDLE;
                        elsif (any(read_hit) = '1') then
                            -- read hit, no change except to increment metadata miss counters
                            for ii in 0 to cCache_NumSets - 1 loop
                                if (is_hit(ii) = '0') then
                                    metadata_w(ii) <= metadata(ii);
                                    if (metadata(ii).lru < 2 ** cLruCounterWidth_b - 1) then
                                        metadata_w(ii).lru <= metadata(ii).lru + 1;
                                    end if;
                                else
                                    metadata_w(ii) <= metadata(ii);
                                    metadata_w(ii).lru <= (others => '0');
                                end if;
                            end loop;

                            -- Don't even have to write back rdata since nothing has been
                            -- modified. Only need to writeback new metadata.
                            cacheline_addr_b <= cacheline_addr_reg;
                            metadata_valid   <= '1';
                            state            <= IDLE;
                        elsif (all_set(read_miss) = '1') then
                            if (metadata(lru).dirty = '1') then
                                -- need to write memory, read memory, edit and writeback to cache while returning valid
                                state       <= REQUEST_MEM_WRITE;
                                o_mem_addr  <= metadata(lru).upper_address & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                o_mem_en    <= '1';
                                o_mem_wen   <= (others => '1');
                                o_mem_wdata <= cache_rdata(lru);
                            else
                                -- need to read memory, edit and writeback to cache while returning valid
                                state      <= REQUEST_MEM_READ;
                                o_mem_addr <= upper_addr_reg & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                o_mem_en   <= '1';
                                o_mem_wen  <= (others => '0');
                            end if;
                        end if;
                
                    when REQUEST_MEM_WRITE =>
                        o_mem_en <= '0';
                        if (i_mem_valid = '1') then
                            -- Now we need to request a mem read
                            state      <= REQUEST_MEM_READ;
                            o_mem_addr <= upper_addr_reg & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                            o_mem_en   <= '1';
                            o_mem_wen  <= (others => '0');
                        end if;

                    when REQUEST_MEM_READ =>
                        o_mem_en <= '0';
                        if (i_mem_valid = '1') then
                            -- Because this state is last following any form of miss, read or write,
                            -- we need to ensure preservation of the orignal cache_rdata, while also
                            -- preserving any writes or reads.
                            for ii in 0 to cCache_NumSets - 1 loop
                                if (ii = lru_reg) then
                                    for jj in 0 to cCachelineSize_B - 1 loop
                                        if (wen_reg(jj) = '1') then
                                            rdata(lru_reg)(8 * jj + 7 downto 8 * jj) <= cache_wdata_reg(8 * jj + 7 downto 8 * jj);
                                        else
                                            rdata(lru_reg)(8 * jj + 7 downto 8 * jj) <= i_mem_rdata(8 * jj + 7 downto 8 * jj);
                                        end if;
                                    end loop;
                                else
                                    rdata(ii) <= cache_rdata(ii);
                                end if;
                            end loop;
                            
                            for ii in 0 to cCache_NumSets - 1 loop
                                if (ii = lru_reg) then
                                    metadata_w(ii).dirty <= any(wen_reg);
                                    metadata_w(ii).valid <= '1';
                                    metadata_w(ii).lru   <= (others => '0');
                                    metadata_w(ii).upper_address <= upper_addr_reg;
                                else
                                    metadata_w(ii) <= metadata(ii);
                                    if (metadata(ii).lru < 2 ** cLruCounterWidth_b - 1) then
                                        metadata_w(ii).lru <= metadata(ii).lru + 1;
                                    end if;
                                end if;
                            end loop;

                            cacheline_addr_b <= cacheline_addr_reg;
                            metadata_valid   <= '1';
                            rdata_valid      <= '1';
                            state            <= IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;