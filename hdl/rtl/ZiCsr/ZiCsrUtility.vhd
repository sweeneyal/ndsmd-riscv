library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

library nsfrtu_riscv;
    use nsfrtu_riscv.CommonUtility.all;

package ZicsrUtility is

    ------------------------------------------
    -- MIP and MIE Interrupt Enable Fields
    ------------------------------------------
    -- supervisor software interrupts
    constant cSSI : natural := 1;
    -- machine software interrupts
    constant cMSI : natural := 3;
    -- supervisor timer interrupts
    constant cSTI : natural := 5;
    -- machine timer interrupts
    constant cMTI : natural := 7;
    -- supervisor external interrupts
    constant cSEI : natural := 9;
    -- machine external interrupts
    constant cMEI : natural := 11;
    
    
    ---------------------------------
    -- MSTATUS FIELDS (RV32I)
    ---------------------------------
    -- global supervisor interrupt enable
    constant cSIE  : natural := 1;

    -- global machine interrupt enable
    constant cMIE  : natural := 3;

    -- holds interrupt enable bit prior to trap
    constant cSPIE : natural := 5;

    -- (User Byte Endianess), leave 0 as little endian
    constant cUBE  : natural := 6;

    -- holds interrupt enable bit prior to trap
    constant cMPIE : natural := 7;

    -- contains the previous privilege mode
    constant cSPP  : natural := 8;

    -- vector extension state
    -- leave 0 as not supported
    constant cVS_0 : natural := 9;
    constant cVS_1 : natural := 10;
    
    -- contains the previous privilege mode
    constant cMPP_0 : natural := 11;
    constant cMPP_1 : natural := 12;

    -- Floating state bits
    -- leave 0 as not supported
    constant cFS_0 : natural := 13;
    constant cFS_1 : natural := 14;

    -- additional user mode extensions state
    -- leave 0 as not supported
    constant cXS_0 : natural := 15;
    constant cXS_1 : natural := 16;

    -- this bit modifies the effective privilege mode (Modify PRiVilege)
    -- when 0, loads and stores behave as normal. Leave set to 0 if
    -- U mode is not supported.
    constant cMPRV : natural := 17;

    -- this bit modifies the privilege with which S mode loads and stores access
    -- virtual memory. When 0, S mode accesses to pages accessible by U 
    -- mode will fault. Leave 0 if S mode is not supported.
    -- (Supervisor User Memory access)
    constant cSUM  : natural := 18;

    -- this bit modifies the privilege with which loads access virtual memory
    -- when 0, only loads from pages marked readable will succeed.
    -- Leave 0 if S mode is not supported.
    -- (Make eXecutable Readable)
    constant cMXR  : natural := 19;

    -- this bit supports intercepting supervisor virtual memory management operations.
    -- Leave 0 if S-Mode not supported.
    -- (Trap Virtual Memory)
    constant cTVM  : natural := 20;
    -- this bit supports intercepting the WFI instruction. When 0, the WFI instruction
    -- can be executed in lower privileges. When 1, then if WFI is executed in any
    -- less-privileged mode and does not complete ithin a time limit, throw an illegal
    -- instruction exception. TW is 0 if no modes less privileged than M exist.
    -- (Timeout Wait)
    constant cTW   : natural := 21;
    -- this bit supports intercepting the supervisor exception return instruction, SRET.
    -- when 1, attempts to execute SRET while executing in S mode will raise an illegal
    -- instruction exception. Leave 0 if S-Mode is not supported.
    -- (Trap SRet)
    constant cTSR  : natural := 22;

    -- dirty state bit for FS, XS, and VS.
    -- leave 0
    constant cSD   : natural := 31;

    ---------------------------------
    -- MSTATUSH FIELDS (RV32I)
    ---------------------------------

    -- (Supervisor Byte Endianess), leave 0 as little endian
    constant cSBE : natural := 4;
    -- (Machine Byte Endianess), leave 0 as little endian
    constant cMBE : natural := 5;
    
end package ZicsrUtility;