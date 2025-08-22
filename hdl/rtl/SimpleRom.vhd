library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use std.textio.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    
entity SimpleRom is
    generic (
        cAddrWidth_b : natural := 13;
        cDataWidth_b : natural := 32;
        cRomFileName : string
    );
    port (
        i_clk  : in std_logic;
        i_addr : in std_logic_vector(cAddrWidth_b - 1 downto 0);
        i_en   : in std_logic;
        o_data : out std_logic_vector(cDataWidth_b - 1 downto 0)
    );
end entity SimpleRom;

architecture rtl of SimpleRom is
    type rom_t is array (0 to 2 ** cAddrWidth_b - 1) of bit_vector(cDataWidth_b - 1 downto 0);
    impure function initialize_rom(fname : string) return rom_t is
        file romFile : text open read_mode is fname;
        variable romFileLine : line;
        variable rom : rom_t := (others => (others => '0'));
    begin
        for ii in rom_t'range loop
            readline (romFile, romFileLine);
            read (romFileLine, rom(ii));
        end loop;
        return rom;
    end function;
    signal rom : rom_t := initialize_rom(cRomFileName);
begin
    
    RomInference: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_en = '1') then
                o_data <= to_stdlogicvector(rom(to_natural(i_addr(cAddrWidth_b - 1 downto 2))));
            end if;
        end if;
    end process RomInference;
    
end architecture rtl;