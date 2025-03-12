-----------------------------------------------------------------------------------------------------------------------
-- entity: InstrPrefetcher_Utility
--
-- library: tb_ndsmd_riscv
-- 
-- signals:
--      i_stimuli   : 
--      i_responses :
--
-- description:
--      
-----------------------------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;

package InstrPrefetcher_Utility is
    
    type stimuli_t is record
        clk          : std_logic;
        resetn       : std_logic;

        instr_arready : std_logic;

        instr_rresp   : std_logic_vector(1 downto 0);
        instr_rdata   : std_logic_vector(31 downto 0);
        instr_rvalid  : std_logic;

        cpu_ready     : std_logic;

        pc           : unsigned(31 downto 0);
        pcwen        : std_logic;
    end record stimuli_t;
    
    type responses_t is record
        instr_araddr  : std_logic_vector(31 downto 0);
        instr_arvalid : std_logic;
        instr_arprot  : std_logic_vector(2 downto 0);
        instr_rready  : std_logic;
        
        pc         : unsigned(31 downto 0);
        instr      : instruction_t;
        valid      : std_logic;
    end record responses_t;

    type transaction_t is record
        pc        : unsigned(31 downto 0);
        requested : boolean;
        issued    : boolean;
        dropped   : boolean;
    end record transaction_t;

end package InstrPrefetcher_Utility;