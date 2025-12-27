library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;

entity CachePipedDirectMapped is
    generic (
        cAddressWidth_b    : positive := 32;
        cCachelineSize_B   : positive := 16;
        cCacheSize_entries : positive := 1024;
        cNumCacheMasks     : positive := 4;
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

        o_cache_ready : out std_logic;
        o_cache_hit   : out std_logic;
        o_cache_miss  : out std_logic;

        o_mem_addr  : out std_logic_vector(cAddressWidth_b - 1 downto 0);
        o_mem_en    : out std_logic;
        o_mem_wen   : out std_logic_vector(cCachelineSize_B - 1 downto 0);
        o_mem_wdata : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        i_mem_rdata : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        i_mem_valid : in std_logic
    );
end entity CachePipedDirectMapped;

architecture rtl of CachePipedDirectMapped is
    constant cCacheAddrWidth_b : positive := clog2(cCacheSize_entries);
    constant cUpperAddrWidth_b : positive := cAddressWidth_b - clog2(cCacheSize_entries) - clog2(cCachelineSize_B);
    constant cMetadataWidth_b  : positive := cUpperAddrWidth_b + 2;

    type metadata_t is record
        upper_address : std_logic_vector;
        dirty         : std_logic;
        valid         : std_logic;
    end record metadata_t;

    function slv_to_metadata(s : std_logic_vector) return metadata_t is
        variable m : metadata_t(upper_address(s'length - 3 downto 0));
    begin
        m.upper_address := s(s'length - 3 downto 0);
        m.dirty         := s(s'length - 2);
        m.valid         := s(s'length - 1);
        return m;
    end function;

    function metadata_to_slv(m : metadata_t) return std_logic_vector is
    begin
        return m.valid & m.dirty & m.upper_address;
    end function;

    type cache_status_t is record
        is_hit       : std_logic;
        is_write     : std_logic;
        is_read      : std_logic;
        is_cacheable : std_logic;
    end record cache_status_t;

    type cache_stage_t is record
        access_enable  : std_logic;
        write_enable   : std_logic_vector(cCachelineSize_B - 1 downto 0);
        upper_addr     : std_logic_vector(cUpperAddrWidth_b - 1 downto 0);
        cacheline_addr : std_logic_vector(cCacheAddrWidth_b - 1 downto 0);
        wdata          : std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        rdata          : std_logic_vector(8 * cCachelineSize_B - 1 downto 0);

        status         : cache_status_t;
    end record cache_stage_t;

    type cache_pipeline_t is array (0 to 2) of cache_stage_t;
    
    constant cInputStage  : natural := 0;
    constant cLookupStage : natural := 1;
    constant cDataStage   : natural := 2;
    constant cAccessStage : natural := 3;

    signal cache_pipeline : cache_pipeline_t;
    signal stall_bus : std_logic_vector(cAccessStage downto cInputStage) := (others => '0');

    signal cacheline_addr   : std_logic_vector(cCacheAddrWidth_b - 1 downto 0) := (others => '0');
    signal upper_memaddr    : std_logic_vector(cUpperAddrWidth_b - 1 downto 0) := (others => '0');
    signal is_cacheable     : std_logic := '0';

    signal cache_wen        : std_logic := '0';
    signal cache_rdata      : std_logic_vector(8 * cCachelineSize_B - 1 downto 0) := (others => '0');
    signal rdata            : std_logic_vector(8 * cCachelineSize_B - 1 downto 0) := (others => '0');
    signal meta_rdata       : std_logic_vector(cMetadataWidth_b - 1 downto 0) := (others => '0');
    signal meta_wdata       : std_logic_vector(cMetadataWidth_b - 1 downto 0) := (others => '0');
    signal metadata         : metadata_t(upper_address(cUpperAddrWidth_b - 1 downto 0));
    signal metadata_w       : metadata_t(upper_address(cUpperAddrWidth_b - 1 downto 0));

    signal is_read          : std_logic := '0';
    signal is_write         : std_logic := '0';
    signal is_hit           : std_logic := '0';
    signal read_hit         : std_logic := '0';
    signal read_miss        : std_logic := '0';
    signal write_hit        : std_logic := '0';
    signal write_miss       : std_logic := '0';
    signal write_valid      : std_logic := '0';

    type state_t is (RESET, IDLE, REQUEST_MEM_READ, REQUEST_MEM_WRITE, DONE);
    signal state : state_t := RESET;

begin
    
    assert is_pow_of_2(cCachelineSize_B) and is_pow_of_2(cCacheSize_entries) 
        report "Cache parameters must be powers of 2." severity error;

    -- Index the cacheline address out of the input address
    cacheline_addr <= i_cache_addr(
        clog2(cCacheSize_entries) + clog2(cCachelineSize_B) - 1 downto clog2(cCachelineSize_B));
    -- Index the upper address out of the input address
    upper_memaddr <= i_cache_addr(
        cAddressWidth_b - 1 downto clog2(cCacheSize_entries) + clog2(cCachelineSize_B));

    -- Check the input address against all masks to see if it is cacheable
    MaskChecking: process(i_cache_addr)
        variable v : std_logic := '0';
    begin
        v := '0';
        for ii in 0 to cNumCacheMasks - 1 loop
            v := v or bool2bit((cCacheMasks(ii) or i_cache_addr) = cCacheMasks(ii));
        end loop;
        is_cacheable <= v;
    end process MaskChecking;

    -- We're stalled if the later stages have a stall, or if the input is not being used.
    stall_bus(cInputStage) <= stall_bus(cLookupStage) or not i_cache_en;

    InputCacheStage: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                cache_pipeline(0).access_enable <= '0';
            else
                if (stall_bus(cLookupStage downto cInputStage) = "00") then
                    -- We're full steam ahead, since neither the later stages, nor the input are stalled.
                    cache_pipeline(0).access_enable  <= i_cache_en;
                    cache_pipeline(0).write_enable   <= i_cache_wen;
                    cache_pipeline(0).cacheline_addr <= cacheline_addr;
                    cache_pipeline(0).upper_addr     <= upper_memaddr;
                    cache_pipeline(0).wdata          <= i_cache_wdata;
                    cache_pipeline(0).status.is_cacheable <= is_cacheable;
                elsif (stall_bus(cLookupStage downto cInputStage) = "01") then
                    -- Since the input is stalled, but not the later stages, we need to clear this stage.
                    cache_pipeline(0).access_enable       <= '0';
                    cache_pipeline(0).status.is_cacheable <= is_cacheable;
                end if;
            end if;
        end if;
    end process InputCacheStage;

    -- Now we do any writes depending on if there is supposed to be a write and the address is a cacheable.
    cache_wen <= any(cache_pipeline(0).write_enable) and cache_pipeline(0).status.is_cacheable;

    eBram : entity nsfrtu_riscv.DualPortBram
    generic map (
        cAddressWidth_b => cCacheAddrWidth_b,
        cMaxAddress     => 2 ** cCacheAddrWidth_b,
        cDataWidth_b    => 8 * cCachelineSize_B
    ) port map (
        i_clk => i_clk,

        i_addra  => cache_pipeline(0).cacheline_addr,
        i_ena    => cache_pipeline(0).access_enable,
        i_wena   => cache_wen,
        i_wdataa => cache_pipeline(0).wdata,
        o_rdataa => cache_rdata,

        i_addrb  => cache_pipeline(2).cacheline_addr,
        i_enb    => write_valid,
        i_wenb   => write_valid,
        i_wdatab => cache_pipeline(2).rdata,
        o_rdatab => open
    );

    eMetadata : entity nsfrtu_riscv.DualPortBram
    generic map (
        cAddressWidth_b => cCacheAddrWidth_b,
        cMaxAddress     => 2 ** cCacheAddrWidth_b,
        cDataWidth_b    => cMetadataWidth_b
    ) port map (
        i_clk => i_clk,

        i_addra  => cache_pipeline(0).cacheline_addr,
        i_ena    => cache_pipeline(0).access_enable,
        i_wena   => '0',
        i_wdataa => (others => '0'),
        o_rdataa => meta_rdata,

        i_addrb  => cache_pipeline(2).cacheline_addr,
        i_enb    => cache_pipeline(2).access_enable,
        i_wenb   => cache_pipeline(2).access_enable,
        i_wdatab => meta_wdata,
        o_rdatab => open
    );

    stall_bus(cLookupStage) <= stall_bus(cDataStage);

    CacheStage1: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                cache_pipeline(1).access_enable <= '0';
            else
                if (stall_bus(cDataStage downto cLookupStage) = "00") then
                    cache_pipeline(1) <= cache_pipeline(0);
                elsif (stall_bus(1 downto 0) = "01") then
                    cache_pipeline(1).access_enable <= '0';
                end if;
            end if;
        end if;
    end process CacheStage1;

    is_read <= bool2bit(
        -- we're accessing the bram
        (cache_pipeline(1).access_enable = '1') and 
        -- but not writing anything
        (any(cache_pipeline(1).write_enable) = '0'));

    is_write <= bool2bit(
        -- we're accessing the bram
        (cache_pipeline(1).access_enable = '1') and 
        -- and writing something
        (any(cache_pipeline(1).write_enable) = '1'));

    is_hit <= is_cacheable and bool2bit(
        -- and the data is valid
        (metadata.valid = '1') and
        -- and the address is the same 
        (metadata.upper_address = cache_pipeline(1).upper_addr));

    read_hit   <= is_read and is_hit;
    read_miss  <= is_read and not is_hit;
    write_hit  <= is_write and is_hit;
    write_miss <= is_write and not is_hit;

    o_cache_hit  <= (read_hit or write_hit) and bool2bit(state = IDLE);
    o_cache_miss <= (read_miss or write_miss) and bool2bit(state = IDLE);

    metadata   <= slv_to_metadata(meta_rdata);
    meta_wdata <= metadata_to_slv(metadata_w);

    -- read hits take 1 cc, write hits take 2 cc because we have to write back to the cache
    -- misses take the penalty of the read or write side.
    o_cache_valid <= cache_pipeline(2).access_enable or (read_hit and bool2bit(state = IDLE));
    write_valid   <= cache_pipeline(2).access_enable and cache_pipeline(2).status.is_cacheable;

    -- This seems like a bad idea in terms of clocking.
    DataMux: process(cache_pipeline(2).rdata, cache_pipeline(2).access_enable, cache_rdata)
    begin
        if (cache_pipeline(2).access_enable = '1') then
            o_cache_rdata <= cache_pipeline(2).rdata;
        else
            o_cache_rdata <= cache_rdata;
        end if;
    end process DataMux;

    stall_bus(2) <= bool2bit(state /= IDLE);

    o_cache_ready <= bool2bit(state = IDLE);

    CacheStage2: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                cache_pipeline(2).cacheline_addr <= (others => '0');
                cache_pipeline(2).access_enable  <= '1';
                metadata_w.dirty         <= '0';
                metadata_w.valid         <= '0';
                metadata_w.upper_address <= (others => '0');

                o_mem_en <= '0';
            else
                case state is
                    when RESET =>
                        cache_pipeline(2).access_enable <= '1';
                        metadata_w.dirty         <= '0';
                        metadata_w.valid         <= '0';
                        metadata_w.upper_address <= (others => '0');
                        if (unsigned(cache_pipeline(2).cacheline_addr) < cCacheSize_entries - 1) then
                            cache_pipeline(2).cacheline_addr <= 
                                std_logic_vector(unsigned(cache_pipeline(2).cacheline_addr) + 1);
                        else
                            state <= IDLE;
                        end if;
                        
                    when IDLE =>
                        
                        cache_pipeline(2) <= cache_pipeline(1);
                        cache_pipeline(2).access_enable   <= '0';
                        cache_pipeline(2).rdata           <= cache_rdata;
                        cache_pipeline(2).status.is_hit   <= is_hit;
                        cache_pipeline(2).status.is_write <= is_write;
                        cache_pipeline(2).status.is_read  <= is_read;

                        if (write_miss = '1') then

                            -- If a write miss occurs, and its a cacheable element, we need to load
                            -- it into the cache.
                            if (cache_pipeline(1).status.is_cacheable = '1') then
                                -- Check if the mapped cache location is dirty or not,
                                -- and if so, we need to perform a memory write with the cache data.
                                if (metadata.dirty = '1') then
                                    -- need to write memory, read memory, edit and writeback to cache while returning valid
                                    state       <= REQUEST_MEM_WRITE;
                                    o_mem_addr  <= metadata.upper_address & 
                                                    cache_pipeline(1).cacheline_addr & 
                                                    (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                    o_mem_en    <= '1';
                                    o_mem_wen   <= (others => '1');
                                    o_mem_wdata <= cache_rdata;
                                else
                                    -- Otherwise, we can simply drop the cache data and 
                                    -- overwrite it with a memory read.
                                    state      <= REQUEST_MEM_READ;
                                    o_mem_addr <= cache_pipeline(1).upper_addr & 
                                                    cache_pipeline(1).cacheline_addr & 
                                                    (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                    o_mem_en   <= '1';
                                    o_mem_wen  <= (others => '0');
                                end if;
                            else
                                -- However, if we're uncacheable, then it doesn't matter if the corresponding location is dirty or not.
                                -- We need to just write to memory.
                                state       <= REQUEST_MEM_WRITE;
                                o_mem_addr  <= cache_pipeline(1).upper_addr & 
                                                    cache_pipeline(1).cacheline_addr &
                                                    (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                o_mem_en    <= '1';
                                o_mem_wen   <= cache_pipeline(1).write_enable;
                                o_mem_wdata <= cache_pipeline(1).wdata;
                            end if;

                        elsif (write_hit = '1') then
                            -- If we have a write hit, this means we do not have an uncacheable.
                            -- Therefore, we need to read cache, edit and writeback to cache while 
                            -- returning valid.
                            state <= IDLE;
                            for ii in 0 to cCachelineSize_B - 1 loop
                                if (cache_pipeline(1).write_enable(ii) = '1') then
                                    cache_pipeline(2).rdata(8 * ii + 7 downto 8 * ii) <= cache_pipeline(1).wdata(8 * ii + 7 downto 8 * ii);
                                else
                                    cache_pipeline(2).rdata(8 * ii + 7 downto 8 * ii) <= cache_rdata(8 * ii + 7 downto 8 * ii);
                                end if;
                            end loop;

                            metadata_w.dirty <= '1';
                            metadata_w.valid <= '1';
                            metadata_w.upper_address <= cache_pipeline(1).upper_addr;
                            cache_pipeline(2).access_enable <= '1';
                        elsif (read_hit = '1') then
                            -- If we have a read hit, we do not have an uncacheable and otherwise
                            -- nothing changes.
                            state  <= IDLE;
                        elsif (read_miss = '1') then
                            if (cache_pipeline(1).status.is_cacheable = '1') then
                                -- If we have a cacheable read miss, once again we need to check if the 
                                -- location we're replacing is dirty, and if so, then we need to perform a write.
                                if (metadata.dirty = '1') then
                                    -- need to write memory, read memory, then writeback to cache while returning valid
                                    state       <= REQUEST_MEM_WRITE;
                                    o_mem_addr  <= metadata.upper_address & 
                                                    cache_pipeline(1).cacheline_addr & 
                                                    (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                    o_mem_en    <= '1';
                                    o_mem_wen   <= (others => '1');
                                    o_mem_wdata <= cache_rdata;
                                else
                                    -- Otherwise, we can simply drop the cache data and 
                                    -- overwrite it with a memory read.
                                    state      <= REQUEST_MEM_READ;
                                    o_mem_addr <= cache_pipeline(1).upper_addr & 
                                                    cache_pipeline(1).cacheline_addr & 
                                                    (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                    o_mem_en   <= '1';
                                    o_mem_wen  <= (others => '0');
                                end if;
                            else
                                -- If we have an uncacheable read miss, we need to complete the request as follows.
                                state      <= REQUEST_MEM_READ;
                                o_mem_addr <= cache_pipeline(1).upper_addr & 
                                                    cache_pipeline(1).cacheline_addr & 
                                                    (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                o_mem_en   <= '1';
                                o_mem_wen  <= (others => '0');
                            end if;
                        end if;

                    when REQUEST_MEM_WRITE => 
                        o_mem_en <= '0';
                        if (i_mem_valid = '1') then
                            -- Once memory responds, if we're cacheable we will request a read.
                            -- This is because to get to this state, a read or write miss occurred with
                            -- a dirty mapping so we needed to write the dirty data before we could read 
                            -- the clean data.
                            if (cache_pipeline(2).status.is_cacheable = '1') then
                                -- Now we need to request a mem read using the registered original request.
                                state      <= REQUEST_MEM_READ;
                                o_mem_addr <= cache_pipeline(2).upper_addr & 
                                                cache_pipeline(2).cacheline_addr & 
                                                (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                o_mem_en   <= '1';
                                o_mem_wen  <= (others => '0');
                            else
                                -- If we are not cacheable, we requested a write because of a write "miss".
                                -- Therefore, we're done because we did the operation as requested.

                                cache_pipeline(2).rdata <= (others => '0');
                                cache_pipeline(2).access_enable <= '1';
                                state <= IDLE;
                            end if;
                        end if;

                    when REQUEST_MEM_READ =>
                        o_mem_en <= '0';
                        if (i_mem_valid = '1') then
                            -- Once memory responds, if we're cacheable we will write back the 
                            -- necessary cacheable data, otherwise it will continue to be passed back
                            -- to the processor.
                            for ii in 0 to cCachelineSize_B - 1 loop
                                if (cache_pipeline(2).write_enable(ii) = '1') then
                                    cache_pipeline(2).rdata(8 * ii + 7 downto 8 * ii) <= cache_pipeline(2).wdata(8 * ii + 7 downto 8 * ii);
                                else
                                    cache_pipeline(2).rdata(8 * ii + 7 downto 8 * ii) <= i_mem_rdata(8 * ii + 7 downto 8 * ii);
                                end if;
                            end loop;
                            
                            cache_pipeline(2).access_enable <= '1';
                            metadata_w.dirty <= any(cache_pipeline(2).write_enable);
                            metadata_w.valid <= '1';
                            metadata_w.upper_address <= cache_pipeline(2).upper_addr;

                            state <= DONE;
                        end if;

                    when DONE =>
                        cache_pipeline(2).access_enable <= '0';
                        state <= IDLE;
                        
                    
                end case;
            end if;
        end if;
    end process CacheStage2;
    
end architecture rtl;