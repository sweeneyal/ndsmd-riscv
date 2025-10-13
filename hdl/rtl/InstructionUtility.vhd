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
    
    -- This and the supporting functions slices the instruction into the basic blocks of bits
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
        utype  : std_logic_vector(31 downto 0);
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

    function is_immed(opcode : std_logic_vector(6 downto 0)) return boolean;

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

    -- This applies a second layer of decoding, allowing more elaborate decoration
    -- of the instruction, e.g. indicating the functional unit type it uses, the particular
    -- operation it performs, etc.

    -- Firstly, we need to indicate what functional unit is required for the operation. 
    -- the ALU is the integer arithmatic logic unit, and the MEXT is the M-Extension functional
    -- unit that adds integer multiplication, division, and remainder operations.
    type functional_unit_t is (ALU, MEXT, FPU);

    -- For each functional unit, there are a set of possible operations that can occur.
    -- The ALU operations are standard RISC-V instructions with the operand types abstracted,
    -- and the MEXT operations are the M-extension instructions. The functional units and 
    -- operations cannot cross over, and this is handled in the contextual_decode in the control unit.
    type operation_t is (
        -- ALU operations
        ADD, SUBTRACT, SHIFT_LL, SHIFT_RL, SHIFT_RA, BITWISE_OR, BITWISE_XOR, BITWISE_AND, SLT, SLTU,
        -- MEXT operations
        MULTIPLY, MULTIPLY_UPPER, MULTIPLY_UPPER_SU, MULTIPLY_UPPER_UNS,
        DIVIDE, DIVIDE_UNS, REMAINDER, REMAINDER_UNS,
        -- FPU operations
        FP_ADD, FP_SUB, FP_MUL, FP_DIV, FP_MADD, FP_MSUB, FP_NMSUB, FP_NMADD, 
        FP_SQRT, FP_SGNJ, FP_MIN, FP_MAX, FP_CVT, FP_MV, 
        FP_EQ, FP_LT, FP_LE, FP_CLASS,
        -- Default, null operation
        NULL_OP
    );

    -- FPU Format specifiers
    type fp_format_t is (NULL_FORMAT, SINGLE_PRECISION, DOUBLE_PRECISION);

    -- Qualifiers for deviating similar instructions, namely:
    -- FCVT, FMV, FSGNJ/N/X
    type fp_qualifier_t is (
        SGNJN, SGNJX,
        WORD_FROM_FP, FP_FROM_WORD, UWORD_FROM_FP, FP_FROM_UWORD,
        MOVE_RD_FROM_FP_RS1, MOVE_FP_RD_FROM_RS1,
        NULL_QUALIFIER
    );

    -- Memory operations are kept separate from ALU/MEXT, because the ALU is used to compute the 
    -- address of the memory operation, and the memory operation is completed in the mem access stage.
    type mem_operation_t is (NULL_OP, LOAD, STORE);
    type mem_access_t is (
        BYTE_ACCESS, HALF_WORD_ACCESS, WORD_ACCESS, UBYTE_ACCESS, UHALF_WORD_ACCESS,
        FP_WORD_ACCESS, FP_DOUBLE_ACCESS
    );

    -- Since we can either use a register operand, the program counter, or 
    -- another hardcoded zero for the first source, indicate the correct source.
    -- Typically, this is just the registers, but AUIPC, JAL, and LUI are the exception.
    type source_t is (REGISTERS, PROGRAM_COUNTER, ZERO, IMMEDIATE);

    -- The new address is resolved during decoding, and as such needs to be tracked 
    -- through the datapath. Issuance is also tracked through a pipeline queue.
    type jump_type_t is (NOT_JUMP, JAL, JALR, BRANCH, MRET);
    type condition_t is (NO_COND, LESS_THAN, EQUAL, NOT_EQUAL, GREATER_THAN_EQ);

    -- CSR operations
    type csr_operation_t is (NULL_OP, ECALL, EBREAK, MRET, WFI, CSRROP);
    type csr_access_t is (NULL_OP, CSRRW, CSRRS, CSRRC);

    -- The destination of the instruction is either a register, memory, or it is a branch
    -- instruction where there is no destination.
    type destination_t is (REGISTERS, MEMORY, BRANCH);

    type decoded_instr_t is record
        -- the base decoded instruction, including all fields relevant or not
        base : instruction_t;
        -- the functional unit used during this operation
        unit : functional_unit_t;
        -- the specific operation performed for the functional unit
        operation : operation_t;

        -- operand fields
        source1   : source_t;
        source2   : source_t;
        immediate : std_logic_vector(31 downto 0);

        -- memory specific fields
        mem_operation : mem_operation_t;
        mem_access    : mem_access_t;

        -- jump/branch specific fields
        jump_branch : jump_type_t;
        condition   : condition_t;
        new_pc      : unsigned(31 downto 0);

        -- floating point/double specific fields
        fp_format     : fp_format_t;
        fp_qualifiers : fp_qualifier_t;

        -- zicsr specific fields
        csr_operation : csr_operation_t;
        csr_access    : csr_access_t;

        -- result definition field
        destination : destination_t;
    end record decoded_instr_t;
    
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
        return get_funct7(instr) & get_rs2(instr) & get_rs1(instr) & get_funct3(instr) & (11 downto 0 => '0');
    end function;

    function get_btype(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return instr(31) & instr(7) & instr(30 downto 25) & instr(11 downto 8) & '0';
    end function;

    function get_jtype(instr : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        return instr(31) & instr(19 downto 12) & instr(20) & instr(30 downto 21) & '0';
    end function;

    function is_immed(opcode : std_logic_vector(6 downto 0)) return boolean is
    begin
        return opcode = cLoadUpperOpcode or 
               opcode = cAuipcOpcode or
               opcode = cJumpOpcode or
               opcode = cJumpRegOpcode or
               opcode = cBranchOpcode or
               opcode = cLoadOpcode or
               opcode = cStoreOpcode or
               opcode = cAluImmedOpcode; 
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