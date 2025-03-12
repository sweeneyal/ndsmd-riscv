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

package InstructionUtility is
    
    type instruction_t is record
        opcode : std_logic_vector(6 downto 0);
        rs1    : std_logic_vector(4 downto 0);
        rs2    : std_logic_vector(4 downto 0);
        rd     : std_logic_vector(4 downto 0);
        funct3 : std_logic_vector(2 downto 0);
        funct7 : std_logic_vector(6 downto 0);
        itype  : std_logic_vector(11 downto 0);
        stype  : std_logic_vector(11 downto 0);
        btype  : std_logic_vector(12 downto 0);
        utype  : std_logic_vector(19 downto 0);
        jtype  : std_logic_vector(20 downto 0);
    end record instruction_t;

    function get_opcode(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function get_rd(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function get_rs1(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function get_rs2(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function get_funct3(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function get_funct7(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function get_itype(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function get_stype(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function get_utype(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function get_btype(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function get_jtype(instr : std_logic_vector(31 downto 0)) return std_logic_vector;
    function decode(instr : std_logic_vector(31 downto 0)) return instruction_t;

    constant cBranchOpcode    : std_logic_vector(6 downto 0) := "1100011";
    constant cLoadOpcode      : std_logic_vector(6 downto 0) := "0000011";
    constant cStoreOpcode     : std_logic_vector(6 downto 0) := "0100011";
    constant cAluOpcode       : std_logic_vector(6 downto 0) := "0110011";
    constant cAluImmedOpcode  : std_logic_vector(6 downto 0) := "0010011";
    constant cJumpOpcode      : std_logic_vector(6 downto 0) := "1101111";
    constant cJumpRegOpcode   : std_logic_vector(6 downto 0) := "1100111";
    constant cLoadUpperOpcode : std_logic_vector(6 downto 0) := "0110111";
    constant cAuipcOpcode     : std_logic_vector(6 downto 0) := "0010111";
    constant cFenceOpcode     : std_logic_vector(6 downto 0) := "0001111";
    constant cEcallOpcode     : std_logic_vector(6 downto 0) := "1110011";
    constant cMulDivOpcode    : std_logic_vector(6 downto 0) := "0110011";

    constant cMulFunct3    : std_logic_vector(2 downto 0) := "000";
    constant cMulhFunct3   : std_logic_vector(2 downto 0) := "001";
    constant cMulhsuFunct3 : std_logic_vector(2 downto 0) := "010";
    constant cMulhuFunct3  : std_logic_vector(2 downto 0) := "011";
    constant cDivFunct3    : std_logic_vector(2 downto 0) := "100";
    constant cDivuFunct3   : std_logic_vector(2 downto 0) := "101";
    constant cRemFunct3    : std_logic_vector(2 downto 0) := "110";
    constant cRemuFunct3   : std_logic_vector(2 downto 0) := "111";
    
end package InstructionUtility;

package body InstructionUtility is
    
    function get_opcode(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return instr(6 downto 0);
    end function;

    function get_rd(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return instr(11 downto 7);
    end function;

    function get_rs1(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable temp : std_logic_vector(4 downto 0);
    begin
        temp := instr(19 downto 15);
        return temp;
    end function;

    function get_rs2(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable temp : std_logic_vector(4 downto 0);
    begin
        temp := instr(24 downto 20);
        return temp;
    end function;

    function get_funct3(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable temp : std_logic_vector(2 downto 0);
    begin
        temp := instr(14 downto 12);
        return temp;
    end function;

    function get_funct7(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable temp : std_logic_vector(6 downto 0);
    begin
        temp := instr(31 downto 25); 
        return temp;
    end function;

    function get_itype(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return instr(31 downto 20);
    end function;

    function get_stype(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return get_funct7(instr) & get_rd(instr);
    end function;

    function get_utype(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return get_funct7(instr) & get_rs2(instr) & get_rs1(instr) & get_funct3(instr);
    end function;

    function get_btype(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return instr(31) & instr(7) & instr(30 downto 25) & instr(11 downto 8) & '0';
    end function;

    function get_jtype(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return instr(31) & instr(19 downto 12) & instr(20) & instr(30 downto 21) & '0';
    end function;

    function decode(instr : std_logic_vector(31 downto 0)) return instruction_t is
        variable i : instruction_t;
    begin
        i.opcode := get_opcode(instr);
        i.rs1    := get_rs1(instr);
        i.rs2    := get_rs2(instr);
        i.rd     := get_rd(instr);
        i.funct3 := get_funct3(instr);
        i.funct7 := get_funct7(instr);
        i.itype  := get_itype(instr);
        i.stype  := get_stype(instr);
        i.btype  := get_btype(instr);
        i.utype  := get_utype(instr);
        i.jtype  := get_jtype(instr);
        return i;
    end function;
    
end package body InstructionUtility;