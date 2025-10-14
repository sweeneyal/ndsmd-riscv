library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use std.textio.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    
entity SimpleCache is
    generic (
        cCacheType         : string  := "Direct";
        cAddressWidth_b    : positive := 32;
        cCachelineSize_B   : positive := 16;
        cCacheSize_entries : positive := 1024;
        cCache_NumSets     : positive := 1;
        cNumCacheMasks     : positive := 4;
        cCacheMasks        : std_logic_matrix_t
            (0 to cNumCacheMasks - 1)(cAddressWidth_b - 1 downto 0)
    );
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_cache_addr   : in std_logic_vector(cAddressWidth_b - 1 downto 0);
        i_cache_en     : in std_logic;
        i_cache_wen    : in std_logic_vector(cCachelineSize_B - 1 downto 0);
        i_cache_wdata  : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_cache_rdata  : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_cache_valid : out std_logic;

        o_cache_hit  : out std_logic;
        o_cache_miss : out std_logic;

        o_mem_addr   : out std_logic_vector(cAddressWidth_b - 1 downto 0);
        o_mem_en     : out std_logic;
        o_mem_wen    : out std_logic_vector(cCachelineSize_B - 1 downto 0);
        o_mem_wdata  : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        i_mem_rdata  : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        i_mem_valid : in std_logic
    );
end entity SimpleCache;

architecture rtl of SimpleCache is
    
begin
    
    gDirectMapped: if str_eq(cCacheType, "Direct") generate

        eCache : entity ndsmd_riscv.CacheDirectMapped
        generic map (
            cAddressWidth_b    => cAddressWidth_b,
            cCachelineSize_B   => cCachelineSize_B,
            cCacheSize_entries => cCacheSize_entries,
            cNumCacheMasks     => cNumCacheMasks,
            cCacheMasks        => cCacheMasks
        ) port map (
            i_clk    => i_clk,
            i_resetn => i_resetn,

            i_cache_addr  => i_cache_addr,
            i_cache_en    => i_cache_en,
            i_cache_wen   => i_cache_wen,
            i_cache_wdata => i_cache_wdata,
            o_cache_rdata => o_cache_rdata,
            o_cache_valid => o_cache_valid,

            o_cache_hit  => o_cache_hit,
            o_cache_miss => o_cache_miss,

            o_mem_addr  => o_mem_addr,
            o_mem_en    => o_mem_en,
            o_mem_wen   => o_mem_wen,
            o_mem_wdata => o_mem_wdata,
            i_mem_rdata => i_mem_rdata,
            i_mem_valid => i_mem_valid
        );

    end generate gDirectMapped;
    
    
    
end architecture rtl;