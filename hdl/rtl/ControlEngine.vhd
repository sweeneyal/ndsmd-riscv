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
        -- indicator that the program counter has changed
        i_pcwen : in std_logic
    );
end entity ControlEngine;

architecture rtl of ControlEngine is

    -- Enumification attempts to recode instructions into a set of human-readable enums that will be handled
    -- by the synthesis tool and further optimized during synthesis. This helps make downstream RTL easier to
    -- read, and therefore easier to debug.
    function enumify_instr(instr : instruction_t; pc : unsigned(31 downto 0); res : decoded_instr_t) return decoded_instr_t is
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
                decoded.source2     := IMMEDIATE;
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

                decoded.source2   := REGISTERS;
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
                decoded.source2   := IMMEDIATE;
                if (instr.opcode = cStoreOpcode) then
                    decoded.mem_operation := STORE;
                    decoded.destination   := MEMORY;
                    decoded.immediate     := std_logic_vector(resize(signed(instr.stype), 32));
                else
                    decoded.mem_operation := LOAD;
                    decoded.destination   := REGISTERS;
                    decoded.immediate     := std_logic_vector(resize(signed(instr.itype), 32));
                end if;
                
                case (instr.funct3) is
                    when "000" =>
                        decoded.mem_access := BYTE_ACCESS;
                    when "001" =>
                        decoded.mem_access := HALF_WORD_ACCESS;
                    when "010" =>
                        decoded.mem_access := WORD_ACCESS;
                    when "100" =>
                        decoded.mem_access := UBYTE_ACCESS;
                    when "101" =>
                        decoded.mem_access := UHALF_WORD_ACCESS;
                    when others =>
                        assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                        decoded.mem_access := BYTE_ACCESS;
                
                end case;

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
                decoded.source2   := REGISTERS;

                -- We precompute the new PC here since we have everything we need to do that.
                decoded.jump_branch := BRANCH;
                decoded.new_pc      := pc + unsigned(resize(signed(instr.btype), 32));
                -- Also, indicate the condition we're looking for for the branch.
                case instr.funct3 is
                    when "000" =>
                        decoded.condition := EQUAL;
                    when "001" =>
                        decoded.condition := NOT_EQUAL;
                    when "100" | "101" =>
                        decoded.condition := LESS_THAN;
                    when "110" | "111" =>
                        decoded.condition := GREATER_THAN_EQ;
                    when others =>
                        assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                end case;

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

                decoded.source2 := IMMEDIATE;
                if (instr.opcode = cJumpOpcode) then
                    -- We precompute the new PC here since we have everything we need to do that.
                    -- Meanwhile, since JAL also returns the post-jump PC, produce that by changing the source
                    -- and setting the immediate to 4, so that the ALU will produce this value.
                    decoded.source1     := PROGRAM_COUNTER;
                    decoded.new_pc      := pc + unsigned(resize(signed(instr.jtype), 32));
                    decoded.jump_branch := JAL;
                    decoded.immediate   := std_logic_vector(to_unsigned(4, 32));
                elsif (instr.opcode = cJumpRegOpcode) then
                    -- JALR is a thorn in my side. In this case, we need to use a register plus the itype
                    -- immediate to compute the new pc, but we also still need to compute the post-jump PC.
                    -- Compute the post-jump PC here, and configure the ALU to produce the new PC, and we'll
                    -- uncross the wires at the end of execute.

                    -- Note to self: we could add an additional port to the register file to index and grab rs1,
                    -- but we would need to be careful of hazards.
                    decoded.source1     := REGISTERS;
                    decoded.new_pc      := pc + 4;
                    decoded.jump_branch := JALR;
                    decoded.immediate   := std_logic_vector(resize(signed(instr.itype), 32));
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

            when cEcallOpcode =>
                if (instr.rd = "00000" and instr.rs1 = "00000" and instr.funct3 = "000") then
                    if (instr.itype = "000000000000") then
                        -- ECALL
                    elsif (instr.itype = "000000000001") then
                        -- EBREAK
                    elsif (instr.funct7 = "0011000" and instr.rs2 = "00010") then
                        -- MRET
                    elsif (instr.funct7 = "0001000" and instr.rs2 = "00101") then
                        -- WFI
                    else
                        -- Malformed instruction
                    end if;
                else
                    case (instr.funct3) is
                        when "001" =>
                            -- CSRRW

                        when "010" =>
                            -- CSRRS

                        when "011" =>
                            -- CSRRC

                        when "101" =>
                            -- CSRRWI
                            -- Note: for CSRROPs, if they are immediate type, use source1 <= IMMEDIATE;

                        when "110" =>
                            -- CSRRSI

                        when "111" =>
                            -- CSRRCI
                    
                        when others =>
                            -- Malformed instruction
                    
                    end case;
                end if;

            when others =>
                assert false report "ControlEngine::contextual_decode: Malformed Instruction" severity failure;
                
        end case;
        
        return decoded;
    end function;

    -- Contextual decoding performs more laborious decoding of the instruction into enums, as well as any downstream
    -- decoding.
    function contextual_decode(instr : instruction_t; pc : unsigned(31 downto 0)) return decoded_instr_t is
        variable decoded : decoded_instr_t;
    begin
        -- Decode instruction into enums and booleans
        decoded := decoded_instr_t'(
            base           => decode(x"00000000"),
            unit           => ALU,
            operation      => NULL_OP,
            source1        => REGISTERS,
            source2        => REGISTERS,
            immediate      => (others => '0'),
            mem_operation  => NULL_OP,
            mem_access     => BYTE_ACCESS,
            jump_branch    => NOT_JUMP,
            condition      => NO_COND,
            new_pc         => (others => '0'),
            csr_operation  => NULL_OP,
            csr_access     => CSRRW,
            destination    => REGISTERS
        );
        decoded.base := instr;
        decoded := enumify_instr(instr, pc, decoded);
        return decoded;
    end function;

    function find_hazards(opcode : std_logic_vector(6 downto 0); source : source_t; rsx : std_logic_vector(4 downto 0); status : datapath_status_t) return issue_id_t is
    begin
        -- Identify data hazards amongst in-flight instructions
        -- Note: this version is assuming that we are not operating as a tomasulo processor with numerous
        -- available functional units. We're also assuming that any instruction that stalls the processor
        -- (e.g. division) will therefore force the entire CPU to stall. Hence, why adding support for 
        -- tomasulo is invaluable.

        if ((source = REGISTERS or opcode = cStoreOpcode) and rsx /= "00000") then
            -- Check all stage statuses to see if another instruction
            -- has the destination = decoded.base.rs1.

            if ((status.decode.instr.base.rd = rsx) 
                    and status.decode.instr.destination = REGISTERS and status.decode.valid = '1') then
                return status.decode.id;
            elsif ((status.execute.instr.base.rd = rsx) 
                    and status.execute.instr.destination = REGISTERS and status.execute.valid = '1') then
                return status.execute.id;
            elsif ((status.memaccess.instr.base.rd = rsx) 
                    and status.memaccess.instr.destination = REGISTERS and status.memaccess.valid = '1') then
                return status.memaccess.id;
            elsif ((status.writeback.instr.base.rd = rsx) 
                    and status.writeback.instr.destination = REGISTERS and status.writeback.valid = '1') then
                return status.writeback.id;
            end if;
        end if;

        -- A value of -1 means no hazard.
        -- Note: this does not identify when the hazarded value becomes available. That is a different functionality.
        return -1;
    end function;

    signal stalled    : stage_status_t;
    signal cpu_ready  : std_logic := '0';
begin
    
    -- An idea is to precompute the branch and jump PCs here (with the exception of JALR, not sure what to do here.)
    -- This same logic can be used for LUI and AUIPC.

    o_cpu_ready <= cpu_ready;

    StateMachine: process(i_clk)
        variable id      : issue_id_t := 0;
        variable rs1_hzd : issue_id_t := -1;
        variable rs2_hzd : issue_id_t := -1;

        variable decoded : decoded_instr_t;
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                stalled.valid  <= '0';
                cpu_ready      <= '0';
                o_issued <= stage_status_t'(
                    id           => -1,
                    pc           => (others => '0'),
                    instr        => decoded_instr_t'(
                        base           => decode(x"00000000"),
                        unit           => ALU,
                        operation      => NULL_OP,
                        source1        => REGISTERS,
                        source2        => REGISTERS,
                        immediate      => (others => '0'),
                        mem_operation  => NULL_OP,
                        mem_access     => BYTE_ACCESS,
                        jump_branch    => NOT_JUMP,
                        condition      => NO_COND,
                        new_pc         => (others => '0'),
                        csr_operation  => NULL_OP,
                        csr_access     => CSRRW,
                        destination    => REGISTERS
                    ),
                    valid        => '0',
                    stall_reason => NOT_STALLED,
                    rs1_hzd      => -1, -- These values will be overwritten by the below function calls.
                    rs2_hzd      => -1
                );
            else
                if (i_pcwen = '1') then
                    stalled.valid  <= '0';
                    cpu_ready      <= '0';
                    o_issued.valid <= '0';
                elsif (i_status.execute.stall_reason /= NOT_STALLED or 
                        i_status.memaccess.stall_reason /= NOT_STALLED or 
                            i_status.writeback.stall_reason /= NOT_STALLED) then
                    -- If anything in the status is stalled, we need to not accept any further instructions.
                    cpu_ready <= '0';
                    
                    -- However, if we said previously we were accepting instructions, and we now have a new
                    -- instruction, we cannot just drop this instruction. Store this stalled instruction in
                    -- a register, and we will provide it when the stall clears.
                    if (i_valid = '1' and cpu_ready = '1') then
                        -- Decode the new instruction, adding in the additional enums.
                        decoded := contextual_decode(i_instr, i_pc);

                        assert stalled.valid = '0' report "Overwriting previously valid stalled instruction." severity failure;

                        stalled <= (
                            id           => id,
                            pc           => i_pc,
                            instr        => decoded,
                            valid        => '1',
                            stall_reason => NOT_STALLED,
                            rs1_hzd      => -1, -- No point in finding the hazards right now since they may update before
                            rs2_hzd      => -1  -- this instruction gets issued.
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
                        
                        -- Pass the stalled instruction to the datapath
                        o_issued <= stalled;

                        -- Identify any current hazards in the datapath
                        rs1_hzd := find_hazards(stalled.instr.base.opcode, stalled.instr.source1, stalled.instr.base.rs1, i_status);
                        rs2_hzd := find_hazards(stalled.instr.base.opcode, stalled.instr.source2, stalled.instr.base.rs2, i_status);

                        -- Link the hazards to the issued instruction.
                        o_issued.rs1_hzd <= rs1_hzd;
                        o_issued.rs2_hzd <= rs2_hzd;

                        -- Temporary: if we have any hazards, we're going to stall until those hazards finish.
                        -- This is to avoid needing complex data hazard handling logic, also known as an excuse
                        -- in order to meet deadlines.
                        if (rs1_hzd = -1 and rs2_hzd = -1) then
                            o_issued.valid <= '1';
                            stalled.valid  <= '0';
                            cpu_ready      <= '1';
                        else
                            -- Invalidate the ID temporarily since we cannot issue due to hazards.
                            o_issued.id    <= -1;
                            o_issued.valid <= '0';
                            stalled.valid  <= '1';
                            cpu_ready      <= '0';
                        end if;
                    elsif (i_valid = '1' and cpu_ready = '1') then
                        -- Decode the new instruction, adding in the additional enums.
                        decoded := contextual_decode(i_instr, i_pc);

                        -- Go ahead and fill out the issued output, and set it to not valid.
                        -- Since it's not valid, we dont give it its assigned ID yet, since if we
                        -- put it in the issued state and we have to stall for hazards,
                        -- we'll accidentally stall ourselves permanently.
                        o_issued <= stage_status_t'(
                            id           => -1,
                            pc           => i_pc,
                            instr        => decoded,
                            valid        => '0',
                            stall_reason => NOT_STALLED,
                            rs1_hzd      => -1, -- These values will be overwritten by the below function calls.
                            rs2_hzd      => -1
                        );

                        -- Also do the same for the stalled register, and set it to not valid.
                        stalled <= stage_status_t'(
                            id           => id,
                            pc           => i_pc,
                            instr        => decoded,
                            valid        => '0',
                            stall_reason => NOT_STALLED,
                            rs1_hzd      => -1, -- These values will be overwritten by the below function calls.
                            rs2_hzd      => -1
                        );

                        -- Identify the hazards of the instruction.
                        rs1_hzd := find_hazards(decoded.base.opcode, decoded.source1, decoded.base.rs1, i_status);
                        rs2_hzd := find_hazards(decoded.base.opcode, decoded.source2, decoded.base.rs2, i_status);

                        -- Link the hazards to the issued instruction.
                        o_issued.rs1_hzd <= rs1_hzd;
                        o_issued.rs2_hzd <= rs2_hzd;

                        -- Temporary: if we have any hazards, we're going to stall until those hazards finish.
                        -- This is to avoid needing complex data hazard handling logic, also known as an excuse
                        -- in order to meet deadlines.
                        if (rs1_hzd = -1 and rs2_hzd = -1) then
                            -- If there are no hazards, we allow it to have its ID now.
                            o_issued.id    <= id;
                            o_issued.valid <= '1';
                            stalled.valid  <= '0';
                            cpu_ready      <= '1';
                        else
                            o_issued.valid <= '0';
                            stalled.valid  <= '1';
                            cpu_ready      <= '0';
                        end if;
    
                        -- Since we have now issued/stalled this instruction, we need to move on to the next id.
                        if (id < cMaxId) then
                            id := id + 1;
                        else
                            id := 0;
                        end if;
                    else
                        -- We have neither a stalled instruction, nor need to stall
                        -- request a new instruction from the prefetcher
                        cpu_ready <= '1';

                        -- We also need to not issue several of the same instruction,
                        -- so drop the o_issued.valid signal here.
                        o_issued <= stage_status_t'(
                            id           => -1,
                            pc           => (others => '0'),
                            instr        => decoded_instr_t'(
                                base           => decode(x"00000000"),
                                unit           => ALU,
                                operation      => NULL_OP,
                                source1        => REGISTERS,
                                source2        => REGISTERS,
                                immediate      => (others => '0'),
                                mem_operation  => NULL_OP,
                                mem_access     => BYTE_ACCESS,
                                jump_branch    => NOT_JUMP,
                                condition      => NO_COND,
                                new_pc         => (others => '0'),
                                csr_operation  => NULL_OP,
                                csr_access     => CSRRW,
                                destination    => REGISTERS
                            ),
                            valid        => '0',
                            stall_reason => NOT_STALLED,
                            rs1_hzd      => -1, -- These values will be overwritten by the below function calls.
                            rs2_hzd      => -1
                        );
                    end if;
                end if;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;