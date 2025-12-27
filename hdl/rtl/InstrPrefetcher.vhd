library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;
    use nsfrtu_riscv.InstructionUtility.all;

entity InstrPrefetcher is
    generic (
        -------------------------------------------------------------------------
        -- L1iCache Configuration Generics
        -------------------------------------------------------------------------
        -- the size of the cache line (aka cache block size)
        cCachelineSize_B : positive := 16;
        -- whether or not to enable the L1i cache in the prefetcher
        cGenerateCache : boolean  := true;
        -- what type of cache is used in the L1i cache (direct, set-assoc)
        cCacheType : string   := "DirectPiped";
        -- number of entries in the cache
        cCacheSize_entries : positive := 1024;
        -- number of sets in the cache
        cCache_NumSets : positive := 1;
        -- number of masks used to identify cacheable address ranges
        cNumCacheMasks : positive := 1;
        -- masks used to identify cacheable address ranges
        cCacheMasks : std_logic_matrix_t
            (0 to cNumCacheMasks - 1)(31 downto 0) := (0 => x"0000FFFF");

        -- the severity of the error caused by pc update not aligned to a multiple of 4;
        -- this normally is a failure, but during testing with random instruction generation,
        -- this is downgraded to a warning.
        cPcMisalignmentSeverity : severity_level := failure
    );
    port (
        -- system clock frequency
        i_clk : in std_logic;
        -- active low reset synchronous to the system clock
        i_resetn : in std_logic;
        -- ready indicator that system is ready to run
        o_ready : out std_logic;

        -- AXI-like interface to allow for easier implementation
        -- address bus for requesting an address
        o_instr_araddr : out std_logic_vector(31 downto 0);
        -- protection level of the transaction
        o_instr_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_instr_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_instr_arready : in std_logic;

        -- returned instruction data bus
        i_instr_rdata  : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        -- response indicating error occurred, if any
        i_instr_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        i_instr_rvalid : in std_logic;
        -- ready to receive instruction data
        o_instr_rready : out std_logic;
        
        -- indicator that processor is ready to run next available instruction
        i_cpu_ready : in std_logic;
        -- program counter of instruction
        o_pc        : out unsigned(31 downto 0);
        -- instruction data decomposed and recomposed as a record
        o_instr     : out instruction_t;
        -- indicator that pc and instr are both valid
        o_valid     : out std_logic;

        -- target program counter of a jump or branch
        i_pc    : in unsigned(31 downto 0);
        -- indicator that target pc is valid
        i_pcwen : in std_logic
    );
end entity InstrPrefetcher;

architecture rtl of InstrPrefetcher is
    type prefetch_request_t is record
        pc      : unsigned(31 downto 0);
        valid   : std_logic;
        dropped : std_logic;
    end record prefetch_request_t;

    type prefetch_pipeline_t is array (0 to 2) of prefetch_request_t;

    function get_oldest(p : prefetch_pipeline_t) return integer is
    begin
        for ii in 2 downto 0 loop
            if (p(ii).valid = '1') then
                return ii;
            end if;
        end loop;
        return -1;
    end function;

    function any(p : prefetch_pipeline_t) return std_logic is
        variable v : std_logic := '0';
    begin
        v := '0';
        for ii in 2 downto 0 loop
            v := v or p(ii).valid;
        end loop;
        return v;
    end function;

    function count(p : prefetch_pipeline_t) return natural is
        variable v : natural := 0;
    begin
        v := 0;
        for ii in 2 downto 0 loop
            if (p(ii).valid = '1') then
                v := v + 1;
            end if;
        end loop;
        return v;
    end function;
    
    type stall_buffer_t is record
        pc    : unsigned(31 downto 0);
        instr : std_logic_vector(31 downto 0);
        valid : std_logic;
    end record stall_buffer_t;

    type stall_pipeline_t is array (0 to 2) of stall_buffer_t;

    function get_oldest(p : stall_pipeline_t) return integer is
    begin
        for ii in 2 downto 0 loop
            if (p(ii).valid = '1') then
                return ii;
            end if;
        end loop;
        return -1;
    end function;

    function any(p : stall_pipeline_t) return std_logic is
        variable v : std_logic := '0';
    begin
        v := '0';
        for ii in 2 downto 0 loop
            v := v or p(ii).valid;
        end loop;
        return v;
    end function;

    function count(p : stall_pipeline_t) return natural is
        variable v : natural := 0;
    begin
        v := 0;
        for ii in 2 downto 0 loop
            if (p(ii).valid = '1') then
                v := v + 1;
            end if;
        end loop;
        return v;
    end function;

    type state_t is (RESET, RUNNING, JUMP);

    signal pc      : unsigned(29 downto 0) := (others => '0');
    signal valid_o : std_logic := '0';
    
    signal cache_addr  : std_logic_vector(31 downto 0) := (others => '0');
    signal cache_en    : std_logic := '0';
    signal cache_wen   : std_logic_vector(cCachelineSize_B - 1 downto 0) := (others => '0');
    signal cache_wdata : std_logic_vector(8 * cCachelineSize_B - 1 downto 0) := (others => '0');
    signal cache_rdata : std_logic_vector(8 * cCachelineSize_B - 1 downto 0) := (others => '0');
    signal cache_valid : std_logic := '0';

    signal cache_ready : std_logic := '0';

    signal mem_addr  : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_en    : std_logic := '0';
    signal mem_wen   : std_logic_vector(cCachelineSize_B - 1 downto 0) := (others => '0');
    signal mem_wdata : std_logic_vector(8 * cCachelineSize_B - 1 downto 0) := (others => '0');
    signal mem_rdata : std_logic_vector(8 * cCachelineSize_B - 1 downto 0) := (others => '0');
    signal mem_valid : std_logic := '0';
    
    signal debug_prefetch : prefetch_pipeline_t;
    signal debug_stalled  : stall_pipeline_t;
    signal debug_state    : state_t;
begin
    
    o_valid <= valid_o;

    StateMachine: process(i_clk)
        variable n : integer := 0;

        variable prefetch : prefetch_pipeline_t;
        variable stalled  : stall_pipeline_t;
        variable state    : state_t := RESET;
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                valid_o <= '0';

                cache_en  <= '0';
                cache_wen <= (others => '0');

                for ii in 0 to 2 loop
                    prefetch(ii).valid   := '0';
                    prefetch(ii).dropped := '0';
                    stalled(ii).valid    := '0';
                end loop;

                state := RESET;
            else
                o_ready <= bool2bit(state /= RESET);

                -- In this process, state is a variable rather than a signal.
                -- This allows us to isolate the different operations into 
                -- different case statements, and also it allows us to interrupt
                -- the state.

                -- If there's a PC write, we need to go to the JUMP state.
                -- This state handles the clearing of bits and management of other components.
                if (i_pcwen = '1') then
                    state := JUMP;
                end if;

                -- The case block below helps group the different lines of code into sections without having
                -- to have nested IF loops, improving readability.
                case state is
                    when RESET =>
                        -- We need to wait for the cache to reach a default state
                        -- before we can start running.
                        if (cache_ready = '1' or not cGenerateCache) then
                            state := RUNNING;
                        end if;
                        
                    when RUNNING =>
                        -- Regardless of if the CPU is ready or not, we need to do some housekeeping.
                        -- Clear any cache requests immediately so as to prevent reissuing a cache request,
                        -- and clear any outgoing valid signals so as to prevent issuing another instruction.
                        cache_en <= '0';
                        valid_o  <= '0';

                        -- If the CPU is ready for an instruction, issue one
                        if (i_cpu_ready = '1') then
                            -- If we have a stalled instruction, issue that first.
                            if (any(stalled) = '1') then
                                n := get_oldest(stalled);
                                o_pc    <= stalled(n).pc;
                                o_instr <= decode(stalled(n).instr);
                                valid_o <= '1';

                                -- Be sure to clear the valid signal indicating we've given away this instruction.
                                stalled(n).valid := '0';

                                if (any(prefetch) = '1' and cache_valid = '1') then
                                    -- Store it as a stalled instruction
                                    assert (count(stalled) < 3) report "InstrPrefetcher::StateMachine: stalled.valid " & 
                                        "is high when getting new instruction data and the CPU is stalled" severity failure;

                                    for ii in 2 downto 1 loop
                                        stalled(ii) := stalled(ii - 1);
                                    end loop;

                                    n := get_oldest(prefetch);

                                    stalled(0).pc    := prefetch(n).pc;
                                    stalled(0).instr := cache_rdata(
                                        8 * to_integer(prefetch(n).pc(clog2(cCachelineSize_B) - 1 downto 0)) + 31 downto
                                        8 * to_integer(prefetch(n).pc(clog2(cCachelineSize_B) - 1 downto 0))
                                    );
                                    stalled(0).valid := not prefetch(n).dropped;

                                    prefetch(n).valid := '0';
                                end if;
                            elsif (any(prefetch) = '1' and cache_valid = '1') then
                                -- If we have an instruction we just got data back for, then issue that.
                                n := get_oldest(prefetch);

                                o_pc    <= prefetch(n).pc;
                                o_instr <= decode(cache_rdata(
                                    8 * to_integer(prefetch(n).pc(clog2(cCachelineSize_B) - 1 downto 0)) + 31 downto
                                    8 * to_integer(prefetch(n).pc(clog2(cCachelineSize_B) - 1 downto 0))
                                ));
                                valid_o <= not prefetch(n).dropped;

                                -- Be sure to clear the valid signal here as well.
                                prefetch(n).valid := '0';
                            end if;
                        else
                            -- If valid_o was set in the previous cycle, we need to keep it set until the cpu 
                            -- accepts the new instruction.
                            if (valid_o = '1') then
                                valid_o <= '1';
                            end if;

                            if (any(prefetch) = '1' and cache_valid = '1') then
                                -- Store it as a stalled instruction
                                assert (count(stalled) < 3) report "InstrPrefetcher::StateMachine: stalled.valid " & 
                                    "is high when getting new instruction data and the CPU is stalled" severity failure;

                                for ii in 2 downto 1 loop
                                    stalled(ii) := stalled(ii - 1);
                                end loop;

                                n := get_oldest(prefetch);

                                stalled(0).pc    := prefetch(n).pc;
                                stalled(0).instr := cache_rdata(
                                    8 * to_integer(prefetch(n).pc(clog2(cCachelineSize_B) - 1 downto 0)) + 31 downto
                                    8 * to_integer(prefetch(n).pc(clog2(cCachelineSize_B) - 1 downto 0))
                                );
                                stalled(0).valid := not prefetch(n).dropped;

                                prefetch(n).valid := '0';
                            end if;
                        end if;

                        -- If we have nothing currently waiting for data or to be sent to the processor, then 
                        -- initiate a request. This means only one instruction in-flight at a time.
                        if (((count(prefetch) + count(stalled)) < 3 and cache_ready = '1' and cGenerateCache) or 
                                ((count(prefetch) + count(stalled)) < 1 and not cGenerateCache)) then
                            cache_addr <= std_logic_vector(pc) & "00";
                            cache_en   <= '1';

                            for ii in 2 downto 1 loop
                                prefetch(ii) := prefetch(ii - 1);
                            end loop;

                            prefetch(0).valid   := '1';
                            prefetch(0).pc      := pc & "00";
                            prefetch(0).dropped := '0';

                            pc <= pc + 1;
                        elsif (cache_en = '1' and cache_ready = '0' and cGenerateCache) then
                            cache_en <= '1';
                        end if;

                    when JUMP =>
                        -- When a jump occurs, any unissued instructions we've received data for are no
                        -- longer valid.
                        for ii in 0 to 2 loop
                            stalled(ii).valid := '0';
                        end loop;
                        valid_o <= '0';

                        -- However if we got data back when we just dropped the instruction, we
                        -- can go ahead and clear the valid signal and the dropped signal.
                        if (cache_valid = '1') then
                            n := get_oldest(prefetch);
                            prefetch(n).valid   := '0';
                            prefetch(n).dropped := '0';
                        end if;


                        -- If we have an outstanding request, we still need to finish the transaction.
                        -- Set the dropped bit here until we get the data back.
                        for ii in 2 downto 0 loop
                            if (prefetch(ii).valid = '1') then
                                prefetch(ii).dropped := '1';
                            end if;
                        end loop;

                        -- We also need to make sure the PC maintains its IALIGN32 compatibility.
                        pc <= i_pc(31 downto 2);
                        assert i_pc(1 downto 0) = "00" 
                            report "InstrPrefetcher::StateMachine: i_pc is not a multiple of 4." 
                                severity cPcMisalignmentSeverity;

                        if (((count(prefetch) < 3) and cache_ready = '1' and cGenerateCache) or 
                                ((count(prefetch)) < 1 and not cGenerateCache)) then
                            -- If we were able to completely clear the prefetch, we can now
                            -- issue a new request.
                            cache_addr <= std_logic_vector(i_pc(31 downto 2)) & "00";
                            cache_en   <= '1';

                            for ii in 2 downto 1 loop
                                prefetch(ii) := prefetch(ii - 1);
                            end loop;

                            prefetch(0).valid   := '1';
                            prefetch(0).pc      := i_pc(31 downto 2) & "00";
                            prefetch(0).dropped := '0';

                            pc <= i_pc(31 downto 2) + 1;
                        end if;

                        -- After every jump, we can go straight back to RUNNING, because
                        -- the point of this state is to handle the odd cases.
                        state := RUNNING;
                end case;
                
            end if;

            debug_prefetch <= prefetch;
            debug_stalled  <= stalled;
            debug_state    <= state;
        end if;
    end process StateMachine;
    
    gCache: if cGenerateCache generate

        eCache : entity nsfrtu_riscv.SimpleCache
        generic map (
            cAddressWidth_b    => 32,
            cCacheType         => cCacheType,
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

            o_cache_ready => cache_ready,
            o_cache_hit   => open,
            o_cache_miss  => open,

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
        cAddressWidth_b  => 32,
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

        o_axi_awaddr  => open,
        o_axi_awprot  => open,
        o_axi_awvalid => open,
        i_axi_awready => '0',

        o_axi_wdata  => open,
        o_axi_wstrb  => open,
        o_axi_wvalid => open,
        i_axi_wready => '0',

        i_axi_bresp  => "00",
        i_axi_bvalid => '0',
        o_axi_bready => open,

        o_axi_araddr  => o_instr_araddr,
        o_axi_arprot  => o_instr_arprot,
        o_axi_arvalid => o_instr_arvalid,
        i_axi_arready => i_instr_arready,

        i_axi_rdata  => i_instr_rdata,
        i_axi_rresp  => i_instr_rresp,
        i_axi_rvalid => i_instr_rvalid,
        o_axi_rready => o_instr_rready
    );

end architecture rtl;