library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;

package DebugUtility is
    
    -- These currently implement the base required commands
    type debug_unit_command_t is (NULL_OP, READ_GENERAL_REGS, WRITE_GENERAL_REGS, READ_MEMORY, WRITE_MEMORY, STEP, CONTINUE);

    type debug_unit_control_t is record
        command : debug_unit_command_t;
        -- addr is dual-purpose for REG and MEM manipulation.
        addr    : unsigned(31 downto 0);
        data    : std_logic_vector(31 downto 0);
    end record debug_unit_control_t;

    -- The debug unit is either in an IDLE state, or is HALTED due to some signal.
    type debug_unit_state_t is (IDLE, HALTED);

    -- Only the most likely signals will be implemented, but they are
    -- shown here mostly for easy conversion between their ENUM and their
    -- index ID (e.g., SIGHUP <--> 1);
    type gdb_signals_t is (
        IDLE,    SIGHUP, SIGINT, 
        SIGQUIT, SIGILL, SIGTRAP, 
        SIGABRT, SIGEMT, SIGFPE, 
        SIGKILL, SIGBUS, SIGSEGV, 
        SIGSYS);

    type debug_unit_status_t is record
        state : debug_unit_state_t;
        pc    : unsigned(31 downto 0);
        sig   : gdb_signals_t;
    end record debug_unit_status_t;
    
end package DebugUtility;