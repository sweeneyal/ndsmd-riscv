library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.FpUtility.all;

entity FDExtension is
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_decoded : in decoded_instr_t;
        i_valid   : in std_logic;
        i_opA     : in std_logic_vector(63 downto 0);
        i_opB     : in std_logic_vector(63 downto 0);
        i_opC     : in std_logic_vector(63 downto 0);

        i_csr_rm     : in std_logic_vector(2 downto 0);
        o_csr_status : out fpu_status_t;

        o_res   : out std_logic_vector(63 downto 0);
        o_valid : out std_logic
    );
end entity FDExtension;

architecture rtl of FDExtension is
    
begin
    
    
    
end architecture rtl;