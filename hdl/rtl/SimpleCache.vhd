library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use std.textio.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    
entity SimpleCache is
    generic (
        cAddrWidth_b     : natural := 32;
        cCachelineSize_B : natural := 16
    );
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_cache_addr   : in std_logic_vector(cAddrWidth_b - 1 downto 0);
        i_cache_en     : in std_logic;
        i_cache_wen    : in std_logic_vector(cCachelineSize_B - 1 downto 0);
        i_cache_wdata  : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_cache_rdata  : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_cache_rvalid : out std_logic;

        i_mem_addr   : in std_logic_vector(cAddrWidth_b - 1 downto 0);
        i_mem_en     : in std_logic;
        i_mem_wen    : in std_logic_vector(cCachelineSize_B - 1 downto 0);
        i_mem_wdata  : in std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_mem_rdata  : out std_logic_vector(8 * cCachelineSize_B - 1 downto 0);
        o_mem_rvalid : out std_logic
    );
end entity SimpleCache;

architecture rtl of SimpleCache is
    
begin
    
    
    
end architecture rtl;