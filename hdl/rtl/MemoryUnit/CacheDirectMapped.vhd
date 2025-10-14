library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;

entity CacheDirectMapped is
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

        o_cache_hit  : out std_logic;
        o_cache_miss : out std_logic;

        o_mem_addr  : out std_logic_vector(cAddressWidth_b - 1 downto 0);
        o_mem_en    : out std_logic;
        o_mem_wen   : out std_logic_vector(cCachelineSize_B - 1 downto 0);
        o_mem_wdata : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        i_mem_rdata : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        i_mem_valid : in std_logic
    );
end entity CacheDirectMapped;

architecture rtl of CacheDirectMapped is
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

    signal cacheline_addr   : std_logic_vector(cCacheAddrWidth_b - 1 downto 0) := (others => '0');
    signal upper_memaddr    : std_logic_vector(cUpperAddrWidth_b - 1 downto 0) := (others => '0');
    signal cache_en         : std_logic := '0';
    signal cache_wen        : std_logic := '0';
    signal cache_rdata      : std_logic_vector(8 * cCachelineSize_B - 1 downto 0) := (others => '0');
    signal cacheline_addr_b : std_logic_vector(cCacheAddrWidth_b - 1 downto 0) := (others => '0');
    signal valid            : std_logic := '0';
    signal rdata            : std_logic_vector(8 * cCachelineSize_B - 1 downto 0) := (others => '0');
    signal meta_rdata       : std_logic_vector(cMetadataWidth_b - 1 downto 0) := (others => '0');
    signal meta_wdata       : std_logic_vector(cMetadataWidth_b - 1 downto 0) := (others => '0');
    signal metadata         : metadata_t(upper_address(cUpperAddrWidth_b - 1 downto 0));
    signal metadata_w       : metadata_t(upper_address(cUpperAddrWidth_b - 1 downto 0));
    signal is_read          : std_logic := '0';
    signal is_write         : std_logic := '0';
    signal is_hit           : std_logic := '0';
    signal is_cacheable     : std_logic := '0';
    signal read_hit         : std_logic := '0';
    signal read_miss        : std_logic := '0';
    signal write_hit        : std_logic := '0';
    signal write_miss       : std_logic := '0';

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
    cache_en  <= i_cache_en and bool2bit(state = IDLE);
    -- Since we're not doing byte addressable caching, we just check if any of them need to be written.
    cache_wen <= any(i_cache_wen);

    eBram : entity ndsmd_riscv.DualPortBram
    generic map (
        cAddressWidth_b => cCacheAddrWidth_b,
        cMaxAddress     => 2 ** cCacheAddrWidth_b,
        cDataWidth_b    => 8 * cCachelineSize_B
    ) port map (
        i_clk => i_clk,

        i_addra  => cacheline_addr,
        i_ena    => cache_en,
        i_wena   => cache_wen,
        i_wdataa => i_cache_wdata,
        o_rdataa => cache_rdata,

        i_addrb  => cacheline_addr_b,
        i_enb    => write_valid,
        i_wenb   => write_valid,
        i_wdatab => rdata,
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
        o_rdataa => meta_rdata,

        i_addrb  => cacheline_addr_b,
        i_enb    => write_valid,
        i_wenb   => write_valid,
        i_wdatab => meta_wdata,
        o_rdatab => open
    );

    metadata   <= slv_to_metadata(meta_rdata);
    meta_wdata <= metadata_to_slv(metadata_w);

    MaskChecking: process(i_cache_addr)
        variable v : std_logic := '0';
    begin
        v := '0';
        for ii in 0 to cNumCacheMasks - 1 loop
            v := v or bool2bit((cCacheMasks(ii) or i_cache_addr) = cCacheMasks(ii));
        end loop;
        is_cacheable <= v;
    end process MaskChecking;

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

    is_hit <= is_cacheable and bool2bit(
        -- and the data is valid
        (metadata.valid = '1') and
        -- and the address is the same 
        (metadata.upper_address = upper_addr_reg));

    read_hit  <= is_read and is_hit;
    read_miss <= is_read and not is_hit;

    write_hit  <= is_write and is_hit;
    write_miss <= is_write and not is_hit;

    o_cache_hit  <= (read_hit or write_hit) and bool2bit(state = IDLE);
    o_cache_miss <= (read_miss or write_miss) and bool2bit(state = IDLE);

    -- read hits take 1 cc, write hits take 2 cc because we have to write back to the cache
    -- misses take the penalty of the read or write side.
    o_cache_valid <= valid or read_hit;
    write_valid   <= valid and status.is_cacheable;
    -- This seems like a bad idea in terms of clocking.
    DataMux: process(rdata, valid, cache_rdata)
    begin
        if (valid = '1') then
            o_cache_rdata <= rdata;
        else
            o_cache_rdata <= cache_rdata;
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
                status.is_write     <= '0';
                status.is_hit       <= '0';
                status.is_cacheable <= '0';
                valid               <= '0';
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

                        -- Preserve the status so we know our state we need to transition to
                        status.is_write     <= is_write;
                        status.is_hit       <= is_hit;
                        status.is_cacheable <= is_cacheable;
                        
                        valid <= '0';

                        if (write_miss = '1') then
                            if (metadata.dirty = '1') then
                                -- need to write memory, read memory, edit and writeback to cache while returning valid
                                state       <= REQUEST_MEM_WRITE;
                                o_mem_addr  <= metadata.upper_address & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                o_mem_en    <= '1';
                                o_mem_wen   <= (others => '1');
                                o_mem_wdata <= cache_rdata;
                            else
                                -- need to read memory, edit and writeback to cache while returning valid
                                state      <= REQUEST_MEM_READ;
                                o_mem_addr <= upper_addr_reg & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                o_mem_en   <= '1';
                                o_mem_wen  <= (others => '0');
                            end if;

                        elsif (write_hit = '1') then
                            -- need to read cache, edit and writeback to cache while returning valid
                            en_reg <= '0';
                            state  <= IDLE;
                            for ii in 0 to cCachelineSize_B - 1 loop
                                if (wen_reg(ii) = '1') then
                                    rdata(8 * ii + 7 downto 8 * ii) <= cache_wdata_reg(8 * ii + 7 downto 8 * ii);
                                else
                                    rdata(8 * ii + 7 downto 8 * ii) <= cache_rdata(8 * ii + 7 downto 8 * ii);
                                end if;
                            end loop;

                            cacheline_addr_b <= cacheline_addr_reg;
                            valid            <= '1';
                            metadata_w.dirty <= '1';
                            metadata_w.valid <= '1';
                            metadata_w.upper_address <= upper_addr_reg;
                        elsif (read_hit = '1') then
                            -- read hit, no change
                            en_reg <= '0';
                            state  <= IDLE;
                        elsif (read_miss = '1') then
                            if (metadata.dirty = '1') then
                                -- need to write memory, read memory, then writeback to cache while returning valid
                                state       <= REQUEST_MEM_WRITE;
                                o_mem_addr  <= metadata.upper_address & cacheline_addr & (clog2(cCachelineSize_B) - 1 downto 0 => '0');
                                o_mem_en    <= '1';
                                o_mem_wen   <= (others => '1');
                                o_mem_wdata <= cache_rdata;
                            else
                                -- need to read memory and then writeback to cache while returning valid
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
                            for ii in 0 to cCachelineSize_B - 1 loop
                                if (wen_reg(ii) = '1') then
                                    rdata(8 * ii + 7 downto 8 * ii) <= cache_wdata_reg(8 * ii + 7 downto 8 * ii);
                                else
                                    rdata(8 * ii + 7 downto 8 * ii) <= i_mem_rdata(8 * ii + 7 downto 8 * ii);
                                end if;
                            end loop;
                            
                            cacheline_addr_b <= cacheline_addr_reg;
                            valid            <= '1';
                            metadata_w.dirty <= '0';
                            metadata_w.valid <= '1';
                            metadata_w.upper_address <= upper_addr_reg;

                            en_reg <= '0';
                            state <= IDLE;
                        end if;

                    -- when DONE =>
                    --     -- Additional cycle since enables are maintained high as input into
                    --     -- this module, which means we can accidentally initiate multiple accesses
                    --     -- inappropriately back to back.
                    --     valid <= '0';
                    --     state <= IDLE;

                end case;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;