library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;

package DatapathUtility is
    
    constant cMaxId : integer := 63;
    subtype issue_id_t is integer range -1 to cMaxId;
    type stall_reason_t is (NOT_STALLED, MEMORY_STALL, HAZARD_STALL, EXECUTION_STALL);

    type stage_status_t is record
        -- issued instruction id, indicating the order of
        -- the instructions issued
        id : issue_id_t;
        -- program counter of the instruction
        pc : unsigned(31 downto 0);
        -- decoded content of the instruction
        instr : decoded_instr_t;
        -- indicator that the entire stage status valid
        valid : std_logic;
        -- stall status of the instruction
        stall_reason : stall_reason_t;
        -- instruction id containing rs1 hazard, -1 if none
        rs1_hzd : issue_id_t;
        -- instruction id containing rs2 hazard, -1 if none
        rs2_hzd : issue_id_t;
    end record stage_status_t;

    type datapath_status_t is record
        decode    : stage_status_t;
        execute   : stage_status_t;
        memaccess : stage_status_t;
        writeback : stage_status_t;
    end record datapath_status_t;
    
end package DatapathUtility;