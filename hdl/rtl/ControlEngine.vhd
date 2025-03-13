-----------------------------------------------------------------------------------------------------------------------
-- entity: ControlEngine
--
-- library: ndsmd_riscv
-- 
-- signals:
--      i_clk    : system clock frequency
--      i_resetn : active low reset synchronous to the system clock
--      
--      o_cpu_ready : indicator that processor is ready to run next available instruction
--      i_pc    : program counter of instruction
--      i_instr : instruction data decomposed and recomposed as a record
--      i_valid : indicator that pc and instr are both valid
--      
--      i_pc    : target program counter of a jump or branch
--      i_pcwen : indicator that target pc is valid
--
-- description:
--       The ControlEngine takes in instructions and depending on the state of the datapath,
--       will either issue the instruction or produce a stall. It monitors the datapath,
--       including instructions in flight, hazard detection, and (in the future) the utilization
--       of different functional units and reservation stations in a Tomasulo OOO implementation.
--
-----------------------------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library universal;
    use universal.CommonFunctions.all;
    use universal.CommonTypes.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.DatapathUtility.all;

entity ControlEngine is
    port (
        -- system clock frequency
        i_clk    : in std_logic;
        -- active low reset synchronous to the system clock
        i_resetn : in std_logic;
        
        -- indicator that processor is ready to run next available instruction
        o_cpu_ready : out std_logic;
        -- program counter of instruction
        i_pc        : in unsigned(31 downto 0);
        -- instruction data decomposed and recomposed as a record
        i_instr     : in instruction_t;
        -- indicator that pc and instr are both valid        
        i_valid     : in std_logic;

        i_status : in datapath_status_t;
        o_pc     : out unsigned(31 downto 0);
        o_instr  : out decoded_instr_t;
        o_valid  : out std_logic
    );
end entity ControlEngine;

architecture rtl of ControlEngine is
    
begin
    
    
    
end architecture rtl;