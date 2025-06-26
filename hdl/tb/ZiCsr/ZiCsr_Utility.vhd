library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;

package ZiCsr_Utility is
    
    type stimuli_t is record
        clk         : std_logic;
        resetn      : std_logic;
        decoded     : decoded_instr_t;
        opA         : std_logic_vector(31 downto 0);
        instret     : std_logic;
        irpt_gen    : std_logic_vector(15 downto 0);
        irpt_ext    : std_logic;
        irpt_sw     : std_logic;
        irpt_timer  : std_logic;
        irpt_bkmkpc : unsigned(31 downto 0);
    end record stimuli_t;

    type responses_t is record
        res         : std_logic_vector(31 downto 0);
        irpt_pc     : unsigned(31 downto 0);
        irpt_valid  : std_logic;
        irpt_mepc   : unsigned(31 downto 0);
    end record responses_t;
    
end package ZiCsr_Utility;