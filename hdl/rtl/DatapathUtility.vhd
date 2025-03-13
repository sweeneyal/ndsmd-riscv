library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;

package DatapathUtility is
    
    type stage_status_t is record
        pc      : unsigned(31 downto 0);
        instr   : decoded_instr_t;
        valid   : std_logic;
        stalled : std_logic;
    end record stage_status_t;

    type datapath_status_t is record
        execute   : stage_status_t;
        memaccess : stage_status_t;
        writeback : stage_status_t;
    end record datapath_status_t;
    
end package DatapathUtility;