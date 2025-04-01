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

library osvvm;
    use osvvm.TbUtilPkg.all;
    use osvvm.RandomPkg.all;
    use osvvm.RandomBasePkg.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.DatapathUtility.all;

package ControlEngine_Utility is
    
    type stimuli_t is record
        clk    : std_logic;
        resetn : std_logic;

        pc    : unsigned(31 downto 0);
        instr : instruction_t;
        valid : std_logic;

        status : datapath_status_t;
    end record stimuli_t;
    
    type responses_t is record
        cpu_ready : std_logic;
        issued    : stage_status_t;
    end record responses_t;
    
end package ControlEngine_Utility;