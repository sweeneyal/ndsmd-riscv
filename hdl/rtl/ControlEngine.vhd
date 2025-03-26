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

        -- current status of the entire datapath
        i_status : in datapath_status_t;
        -- next issued instruction
        o_issued : out stage_status_t;

        -- new jump/branch program counter
        o_pc : out unsigned(31 downto 0);
        -- indicator that jump/branch pc is valid
        o_pcwen : out std_logic
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

        decoded.unit := ALU;
        decoded.operation := NULL_OP;

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
                decoded.unit        := ALU;
                -- Since we can either use a register operand, the program counter, or 
                -- another hardcoded zero for the first source, indicate the correct source.
                decoded.source1     := REGISTERS;
                -- The destination of the instruction is either a register, memory, or it is a branch
                -- instruction where there is no destination.
                decoded.destination := REGISTERS;
                decoded.is_immed    := true;
                decoded.immediate   := std_logic_vector(resize(signed(instr.itype), 32));

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
                decoded.unit        := ALU;
                decoded.source1     := REGISTERS;
                decoded.destination := REGISTERS;
                -- This opcode has an overloading that allows it to encode for
                -- multiplication and division operations. However, these types of
                -- operations use a different functional unit in this implementation.
                if (instr.funct7 = "0000001") then
                    decoded.unit := MEXT;
                end if;

                decoded.is_immed  := false;
                decoded.immediate := (others => '0');

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
                decoded.unit      := ALU;
                decoded.source1   := REGISTERS;
                decoded.is_immed  := true;
                if (instr.opcode = cStoreOpcode) then
                    decoded.destination := MEMORY;
                    decoded.immediate   := std_logic_vector(resize(signed(instr.stype), 32));
                else
                    decoded.destination := REGISTERS;
                    decoded.immediate   := std_logic_vector(resize(signed(instr.itype), 32));
                end if;
                

                -- For loads and stores, we're using the ALU to add the immediate to
                -- regs[rs1], so we use the ADD operation.
                decoded.operation := ADD;

            when cBranchOpcode =>
                -- Indicate the functional unit required for this operation.
                decoded.unit := ALU;
                decoded.destination := BRANCH;

                -- Despite using the immediate anyway as part of the jump, from the 
                -- perspective of the ALU, this is not an is_immed because it functionally
                -- performs SLT, however, the branch does still use the immediate.
                decoded.is_immed  := false;
                decoded.immediate := std_logic_vector(resize(signed(instr.btype), 32));

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

            when cJumpRegOpcode | cJumpOpcode | cAuipcOpcode | cLoadUpperOpcode =>
                -- Indicate the functional unit required for this operation.

                -- Possibly could make an additional port into the register file to grab the 
                -- register needed for the JALR instruction. However, this has issues where
                -- hazards need to be respected.
                decoded.unit := ALU;
                decoded.destination := REGISTERS;

                decoded.is_immed  := true;
                if (instr.opcode = cJumpOpcode) then
                    decoded.source1   := PROGRAM_COUNTER;
                    decoded.immediate := std_logic_vector(resize(signed(instr.jtype), 32));
                elsif (instr.opcode = cJumpRegOpcode) then
                    decoded.source1   := REGISTERS;
                    decoded.immediate := std_logic_vector(resize(signed(instr.itype), 32));
                elsif (instr.opcode = cAuipcOpcode) then
                    decoded.source1   := PROGRAM_COUNTER;
                    decoded.immediate := std_logic_vector(resize(signed(instr.utype), 32));
                else
                    decoded.source1   := ZERO;
                    decoded.immediate := std_logic_vector(resize(signed(instr.utype), 32));
                end if;

                -- For indirect jumps, we're using the ALU to add the immediate to
                -- regs[rs1], so we use the ADD operation.
                decoded.operation := ADD;

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

    signal stalled : stage_status_t;
    signal cpu_ready : std_logic := '0';
begin
    
    -- An idea is to precompute the branch and jump PCs here (with the exception of JALR, not sure what to do here.)
    -- This same logic can be used for LUI and AUIPC.

    StateMachine: process(i_clk)
        variable id      : issue_id_t := 0;
        variable rs1_hzd : issue_id_t := -1;
        variable rs2_hzd : issue_id_t := -1;
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                stalled.valid  <= '0';
                cpu_ready      <= '0';
                o_issued.valid <= '0';
            else
                if (i_status.execute.stall_reason /= NOT_STALLED or 
                        i_status.memaccess.stall_reason /= NOT_STALLED or 
                            i_status.writeback.stall_reason /= NOT_STALLED) then
                    -- If anything in the status is stalled, we need to not accept any further instructions.
                    cpu_ready <= '0';
                    
                    -- However, if we said previously we were accepting instructions, and we now have a new
                    -- instruction, we cannot just drop this instruction. Store this stalled instruction in
                    -- a register, and we will provide it when the stall clears.
                    if (i_valid = '1' and cpu_ready = '1') then
                        stalled <= (
                            id           => id,
                            pc           => i_pc,
                            instr        => contextual_decode(i_instr, i_status),
                            valid        => '1',
                            stall_reason => NOT_STALLED,
                            rs1_hzd      => rs1_hzd,
                            rs2_hzd      => rs2_hzd
                        );

                        -- Be sure to increment the issued id, since even though we did
                        -- not issue yet, we did practically prepare the next issued instruction.
                        if (id < cMaxId) then
                            id := id + 1;
                        else
                            id := 0;
                        end if;
                    end if;
                else
                    -- If we have a stalled instruction, 
                    if (stalled.valid = '1') then
                        -- Since we have a stalled instruction, the cpu should never be ready since
                        -- that puts us at risk of dropping an instruction.
                        assert cpu_ready = '0' 
                            report "ControlEngine::StateMachine: We should have had the cpu indicated as not ready." 
                            severity failure;
                        stalled.valid <= '0';
                        cpu_ready     <= '1';
                        o_issued      <= stalled;
                    elsif (i_valid = '1' and cpu_ready = '1') then
                        o_issued <= stage_status_t'(
                            id           => id,
                            pc           => i_pc,
                            instr        => contextual_decode(i_instr, i_status),
                            valid        => '1',
                            stall_reason => NOT_STALLED,
                            rs1_hzd      => rs1_hzd,
                            rs2_hzd      => rs2_hzd
                        );
    
                        if (id < cMaxId) then
                            id := id + 1;
                        else
                            id := 0;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;