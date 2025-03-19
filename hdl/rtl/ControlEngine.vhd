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

    -- Enumification attempts to recode instructions into a set of human-readable enums that will be handled
    -- by the synthesis tool and further optimized during synthesis. This helps make downstream RTL easier to
    -- read, and therefore easier to debug.
    function enumify_instr(instr : instruction_t; res : decoded_instr_t) return decoded_instr_t is
        variable decoded : decoded_instr_t;
    begin
        decoded := res;

        ----------------------------------------------------------------------------------------
        --                            DECODE INSTRUCTION INTO ENUMS
        ----------------------------------------------------------------------------------------

        -- Generally speaking, instructions that use regs[rs1] and either regs[rs2] or an immediate
        -- are destined for the ALU.

        -- Other instructions that need to use the PC, or a hardcoded zero will use an external unit.
        -- These instructions include JAL, Bxx, AUIPC, and LUI. JAL and AUIPC use the same
        -- operation with slightly different operands, LUI uses the same operation but instead of the PC
        -- it uses all zeros.
        -- Bxx uses the same operation but uses the immediate with the PC.

        case instr.opcode is
            when cAluImmedOpcode =>
                -- ALU Immediate Operations are encoded where only
                -- two commands depend on an additional funct7 operation,
                -- so this is relatively simple.

                -- Indicate the functional unit required for this operation.
                decoded.unit := ALU;

                -- Indicate the operation performed by the functional unit.
                -- This converts the funct3 and funct7 into an internal, 
                -- tool-generated encoding that should be more optimized for the
                -- target architecture.
                case instr.funct3 is
                    when "000" =>
                        decoded.operation := ADD;
                    when "001" =>
                        decoded.operation := SHIFT_LL;
                    when "010" =>
                        decoded.operation := SLT;
                    when "011" =>
                        decoded.operation := SLTU;
                    when "100" =>
                        decoded.operation := BITWISE_XOR;
                    when "101" =>
                        if (instr.funct7 = "0100000") then
                            decoded.operation := SHIFT_RA;    
                        elsif (instr.funct7 = "0000000") then
                            decoded.operation := SHIFT_RL;
                        else
                            assert false report "ControlEngine::contextual_decode: Malformed Shift Right Instruction" severity failure;
                        end if;
                    when "110" =>
                        decoded.operation := BITWISE_OR;
                    when "111" =>
                        decoded.operation := BITWISE_AND;
                    when others =>
                        assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                end case;

            when cAluOpcode =>
                -- Indicate the functional unit required for this operation.
                decoded.unit := ALU;
                -- This opcode has an overloading that allows it to encode for
                -- multiplication and division operations. However, these types of
                -- operations use a different functional unit in this implementation.
                if (instr.funct7 = "0000001") then
                    decoded.unit := MEXT;
                end if;

                -- Indicate the operation performed by the functional unit.
                -- This converts the funct3 and funct7 into an internal, 
                -- tool-generated encoding that should be more optimized for the
                -- target architecture.
                -- Generally:
                -- If funct7 = 7b0, we're doing a normal ALU operation
                -- If funct7 = 7b1, we're doing a MEXT operation
                -- Some instructions have additional overloadings.
                case instr.funct3 is
                    when "000" =>
                        if (instr.funct7 = "0000000") then
                            decoded.operation := ADD;
                        elsif (instr.funct7 = "0100000") then
                            decoded.operation := SUBTRACT;
                        elsif (instr.funct7 = "0000001") then
                            decoded.operation := MULTIPLY;
                        else
                            assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                        end if;
                    when "001" =>
                        if (instr.funct7 = "0000000") then
                            decoded.operation := SHIFT_LL;
                        elsif (instr.funct7 = "0000001") then
                            decoded.operation := MULTIPLY_UPPER;
                        else
                            assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                        end if;
                    when "010" =>
                        if (instr.funct7 = "0000000") then
                            decoded.operation := SLT;
                        elsif (instr.funct7 = "0000001") then
                            decoded.operation := MULTIPLY_UPPER_SU;
                        else
                            assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                        end if;
                    when "011" =>
                        if (instr.funct7 = "0000000") then
                            decoded.operation := SLTU;
                        elsif (instr.funct7 = "0000001") then
                            decoded.operation := MULTIPLY_UPPER_UNS;
                        else
                            assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                        end if;
                    when "100" =>
                        if (instr.funct7 = "0000000") then
                            decoded.operation := BITWISE_XOR;
                        elsif (instr.funct7 = "0000001") then
                            decoded.operation := DIVIDE;
                        else
                            assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                        end if;
                    when "101" =>
                        if (instr.funct7 = "0100000") then
                            decoded.operation := SHIFT_RA;    
                        elsif (instr.funct7 = "0000000") then
                            decoded.operation := SHIFT_RL;
                        elsif (instr.funct7 = "0000001") then
                            decoded.operation := DIVIDE_UNS;
                        else
                            assert false report "ControlEngine::contextual_decode: Malformed Shift Right Instruction" severity failure;
                        end if;
                    when "110" =>
                        if (instr.funct7 = "0000000") then
                            decoded.operation := BITWISE_OR;
                        elsif (instr.funct7 = "0000001") then
                            decoded.operation := REMAINDER;
                        else
                            assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                        end if;
                    when "111" =>
                        if (instr.funct7 = "0000000") then
                            decoded.operation := BITWISE_AND;
                        elsif (instr.funct7 = "0000001") then
                            decoded.operation := REMAINDER_UNS;
                        else
                            assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                        end if;
                    when others =>
                        assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                end case;
                
            when cStoreOpcode | cLoadOpcode =>
                -- Indicate the functional unit required for this operation.
                decoded.unit := ALU;
                -- For loads and stores, we're using the ALU to add the immediate to
                -- regs[rs1], so we use the ADD operation.
                decoded.operation := ADD;

            when cBranchOpcode =>
                -- Indicate the functional unit required for this operation.
                decoded.unit := ALU;
                -- For branches, we're using the ALU to check the comparison of 
                -- regs[rs1] and regs[rs2], so we use the SLT or SLTU operation.
                if (instr.funct3 = "000" or instr.funct3 = "001" or 
                        instr.funct3 = "100" or instr.funct3 = "101") then
                    decoded.operation := SLT;
                elsif (instr.funct3 = "110" or instr.funct3 = "111") then
                    decoded.operation := SLTU;
                else
                    assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                end if;

            when cJumpRegOpcode =>
                -- Indicate the functional unit required for this operation.
                decoded.unit := ALU;
                -- For indirect jumps, we're using the ALU to add the immediate to
                -- regs[rs1], so we use the ADD operation.
                decoded.operation := ADD;

            when cJumpOpcode | cAuipcOpcode | cLoadUpperOpcode =>
                -- How do we want to populate these?
                assert false report "ControlEngine::contextual_decode: I'm still thinking about this!" severity failure;

            when others =>
                assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                
        end case;
        
        return decoded;
    end function;

    -- Contextual decoding performs more laborious decoding of the instruction into enums, as well as looks at the
    -- context of what is currently occuring on the datapath before it issues the instruction. This allows data 
    -- hazards to be identified early, functional units to be stalled for, etc.
    function contextual_decode(instr : instruction_t; status : datapath_status_t) return decoded_instr_t is
        variable decoded : decoded_instr_t;
    begin
        -- Decode instruction into enums and booleans
        decoded.base := instr;
        decoded.is_immed := is_immed(instr.opcode);
        decoded := enumify_instr(instr, decoded);

        -- Identify data hazards amongst in-flight instructions
        -- Note: this version is assuming that we are not operating as a tomasulo processor with numerous
        -- available functional units. We're also assuming that any instruction that stalls the processor
        -- (e.g. division) will therefore force the entire CPU to stall. Hence, why adding support for 
        -- tomasulo is invaluable.




        return decoded;
    end function;
begin
    
    
    
end architecture rtl;