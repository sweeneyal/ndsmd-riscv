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

entity Datapath is
    generic (
        cMemoryUnit_AddressWidth_b  : natural := 32;
        cMemoryUnit_CachelineSize_B : natural := 16;

        cMExtension_GenerateDivisionUnit : boolean := true;

        cZiCsr_TrapBaseAddress : unsigned
    );
    port (
        i_clk : in std_logic;
        i_resetn : in std_logic;

        o_status : out datapath_status_t;
        i_issued : in stage_status_t;

        o_pc    : out unsigned(31 downto 0);
        o_pcwen : out std_logic;

        o_dbg_pc    : out std_logic_vector(31 downto 0);
        o_dbg_rd    : out std_logic_vector(4 downto 0);
        o_dbg_rdwen : out std_logic;
        o_dbg_res   : out std_logic_vector(31 downto 0);

        -- AXI-like interface to allow for easier implementation
        -- address bus for requesting an address
        o_data_awaddr : out std_logic_vector(cMemoryUnit_AddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        o_data_awprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_data_awvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_data_awready : in std_logic;

        -- write data bus
        o_data_wdata  : out std_logic_vector(8 * cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- write data strobe
        o_data_wstrb : out std_logic_vector(cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- write valid
        o_data_wvalid : out std_logic;
        -- write ready
        i_data_wready : in std_logic;

        -- response indicating error occurred, if any
        i_data_bresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that write response data is valid
        i_data_bvalid : in std_logic;
        -- ready to receive write response data
        o_data_bready : out std_logic;

        -- address bus for requesting an address
        o_data_araddr : out std_logic_vector(cMemoryUnit_AddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        o_data_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_data_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_data_arready : in std_logic;

        -- returned instruction data bus
        i_data_rdata  : in std_logic_vector(8 * cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- response indicating error occurred, if any
        i_data_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        i_data_rvalid : in std_logic;
        -- ready to receive instruction data
        o_data_rready : out std_logic
    );
end entity Datapath;

architecture rtl of Datapath is
    signal reg_opA        : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_opB        : std_logic_vector(31 downto 0) := (others => '0');

    signal opA        : std_logic_vector(31 downto 0) := (others => '0');
    signal opB        : std_logic_vector(31 downto 0) := (others => '0');

    signal alu_out    : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_res    : std_logic_vector(31 downto 0) := (others => '0');
    signal eq_res     : std_logic := '0';
    signal slt_res    : std_logic := '0';
    signal mext_res   : std_logic_vector(31 downto 0) := (others => '0');
    signal mext_valid : std_logic := '0';

    signal pcwen : std_logic := '0';

    signal mem_res : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_valid : std_logic := '0';

    signal csr_opA : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_res : std_logic_vector(31 downto 0) := (others => '0');

    signal irpt_pc    : unsigned(31 downto 0) := (others => '0');
    signal irpt_valid : std_logic := '0';
    signal irpt_mepc  : unsigned(31 downto 0) := (others => '0');

    constant cDecodeIndex : natural := 0;

    type execute_stage_t is record
        status   : stage_status_t;
        reg_opA  : std_logic_vector(31 downto 0);
        reg_opB  : std_logic_vector(31 downto 0);
        alu_res  : std_logic_vector(31 downto 0);
        mext_res : std_logic_vector(31 downto 0);
    end record execute_stage_t;
    signal exec : execute_stage_t;

    constant cExecuteIndex : natural := 1;

    type memaccess_stage_t is record
        status   : stage_status_t;
        exec_res : std_logic_vector(31 downto 0);
        mem_res  : std_logic_vector(31 downto 0);
    end record memaccess_stage_t;
    signal memaccess : memaccess_stage_t;

    constant cMemAccessIndex : natural := 2;

    type writeback_stage_t is record
        status  : stage_status_t;
        res     : std_logic_vector(31 downto 0);
        rdwen   : std_logic;
        bkmkpc  : unsigned(31 downto 0);
    end record writeback_stage_t;
    signal writeback : writeback_stage_t;

    constant cWritebackIndex : natural := 3;

    signal global_stall_bus : std_logic_vector(cWritebackIndex downto cDecodeIndex) := (others => '0');
begin

    o_dbg_pc    <= std_logic_vector(writeback.status.pc);
    o_dbg_rd    <= writeback.status.instr.base.rd;
    o_dbg_rdwen <= writeback.rdwen;
    o_dbg_res   <= writeback.res;

    o_status <= datapath_status_t'(
        decode    => i_issued,
        execute   => exec.status,
        memaccess => memaccess.status,
        writeback => writeback.status
    );

    global_stall_bus(cDecodeIndex) <= global_stall_bus(cExecuteIndex) or not i_issued.valid;
    
    eRegisters : entity ndsmd_riscv.RegisterFile
    port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        i_rs1 => i_issued.instr.base.rs1,
        o_opA => reg_opA,

        i_rs2 => i_issued.instr.base.rs2,
        o_opB => reg_opB,

        i_rd    => writeback.status.instr.base.rd,
        i_res   => writeback.res,
        i_valid => writeback.rdwen
    );

    OperandSelection: process(i_issued, reg_opA, reg_opB)
    begin
        case i_issued.instr.source1 is
            when REGISTERS =>
                opA <= reg_opA;
            when PROGRAM_COUNTER =>
                opA <= std_logic_vector(i_issued.pc);
            when ZERO =>
                opA <= (others => '0');
            when others =>
                assert false 
                    report "Operand A should never be anything other than registers, program counter, or zero." 
                    severity failure;
                opA <= (others => '0');
        end case;

        case i_issued.instr.source2 is
            when REGISTERS =>
                opB <= reg_opB;
            when IMMEDIATE =>
                opB <= std_logic_vector(i_issued.instr.immediate);
            when others =>
                assert false 
                    report "Operand A should never be anything other than registers, program counter, or zero." 
                    severity failure;
                opB <= (others => '0');
        end case;
    end process OperandSelection;

    eAlu : entity ndsmd_riscv.IntegerAlu
    port map (
        i_decoded => i_issued.instr,
        i_opA     => opA,
        i_opB     => opB,

        o_res => alu_out,
        o_eq  => eq_res
    );

    slt_res <= alu_out(0);

    eMext : entity ndsmd_riscv.MExtension
    generic map(
        cEnableDivisionUnit => cMExtension_GenerateDivisionUnit
    ) port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        i_decoded => i_issued.instr,
        i_valid   => i_issued.valid,
        i_opA     => opA,
        i_opB     => opB,

        o_res   => mext_res,
        o_valid => mext_valid
    );

    o_pcwen <= (pcwen and i_issued.valid) or irpt_valid;

    JumpBranchHandling: process(i_issued, alu_out, slt_res, eq_res, irpt_pc, irpt_valid)
    begin
        alu_res <= alu_out;
        -- TODO: Preemptively handle mrets here, since mepc is already
        -- available on irpt_mepc, we should be able to simply handle them here.
        case i_issued.instr.jump_branch is
            when BRANCH =>
                o_pc    <= i_issued.instr.new_pc;
                case i_issued.instr.condition is
                    when LESS_THAN =>
                        pcwen <= bool2bit(slt_res = '1' and eq_res = '0');
                    when EQUAL =>
                        pcwen <= bool2bit(slt_res = '0' and eq_res = '1');
                    when NOT_EQUAL =>
                        pcwen <= bool2bit(eq_res = '0');
                    when GREATER_THAN_EQ =>
                        pcwen <= bool2bit(slt_res = '0' or eq_res = '1');
                    when NO_COND =>
                        assert false 
                            report "Datapath::JumpBranchHandling: BRANCH operation encountered with NO_COND condition set." 
                            severity note;
                        pcwen <= '0';
                end case;
                
            when JAL =>
                o_pc    <= i_issued.instr.new_pc;
                pcwen <= '1';

            when JALR =>
                -- Because indirect jumps are a pain, we precompute the post-jump PC in the
                -- control engine, and use the ALU to compute the target address.
                -- Every other option in this setup has the target address precomputed instead.
                alu_res <= std_logic_vector(i_issued.instr.new_pc);
                o_pc    <= unsigned(alu_out);
                pcwen <= '1';
        
            when others =>
                o_pc    <= i_issued.instr.new_pc;
                pcwen <= '0';
                
        end case;

        -- Override whatever is going on o_pc to handle here with the interrupt logic.
        if (irpt_valid = '1') then
            o_pc <= irpt_pc;
        end if;
    end process JumpBranchHandling;

    global_stall_bus(cExecuteIndex) <= global_stall_bus(cMemAccessIndex) or bool2bit(exec.status.stall_reason /= NOT_STALLED);

    ExecuteStage: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                exec.reg_opA  <= (others => '0');
                exec.reg_opB  <= (others => '0');
                exec.alu_res  <= (others => '0');
                exec.mext_res <= (others => '0');
                exec.status <= stage_status_t'(
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
                    rs1_hzd      => -1,
                    rs2_hzd      => -1
                );
            else
                -- If everything after this stage is not stalled, we're not stalled.
                -- The global stall bus indicates the status of the current stage to the end, and
                -- then the following stage.

                -- If the execute stage and all stages after it are not stalled, and the 
                -- decode stage is also not stalled, we can accept a new instruction.
                if (global_stall_bus(cExecuteIndex downto cDecodeIndex) = "00") then
                    exec.status <= i_issued;
    
                    -- If it's the ALU, the instruction is done already, so grab the ALU
                    -- result and move on.
                    if (i_issued.instr.unit = ALU) then
                        exec.alu_res <= alu_res;
                    elsif (i_issued.instr.unit = MEXT) then
                        -- However, if it's the MEXT, we need to stall until the MEXT is done.
                        exec.status.stall_reason <= EXECUTION_STALL;
                    end if;

                    exec.reg_opA <= reg_opA;
                    exec.reg_opB <= reg_opB;

                elsif (global_stall_bus(cExecuteIndex) = '1') then
                    -- If we're stalled, we're either stalled because later stages are stalled or
                    -- because we're executing a multi-cycle instruction. The decode stage's status
                    -- of stalled/not stalled does not matter, as it cannot be accepted anyway without
                    -- dropping the current instruction.

                    -- If we're the one thats stalled, check if the stall has been resolved.
                    if (exec.status.stall_reason = EXECUTION_STALL) then
                        -- We would only be here if there's an MEXT instruction running. Wait until the
                        -- MEXT instruction finishes.
                        if (mext_valid = '1') then
                            exec.mext_res <= mext_res;
                            exec.status.stall_reason <= NOT_STALLED;
                        end if;
                    end if;

                elsif (global_stall_bus(cExecuteIndex downto cDecodeIndex) = "01") then
                    -- Alternatively, the decode stage could be stalled, i.e. it did not issue a new
                    -- instruction. Therefore just populate the exec status with an invalid instruction.

                    exec.status <= stage_status_t'(
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
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    );
                end if;
            end if;
        end if;
    end process ExecuteStage;

    eMemoryUnit : entity ndsmd_riscv.MemoryUnit
    generic map (
        cAddressWidth_b => cMemoryUnit_AddressWidth_b,
        cCachelineSize_B => cMemoryUnit_CachelineSize_B
    ) port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        i_decoded => exec.status.instr,
        i_valid   => exec.status.valid,
        i_addr    => exec.alu_res,
        i_data    => exec.reg_opB,
        o_res     => mem_res,
        o_valid   => mem_valid,

        o_data_awaddr  => o_data_awaddr,
        o_data_awprot  => o_data_awprot,
        o_data_awvalid => o_data_awvalid,
        i_data_awready => i_data_awready,

        o_data_wdata  => o_data_wdata,
        o_data_wstrb  => o_data_wstrb,
        o_data_wvalid => o_data_wvalid,
        i_data_wready => i_data_wready,

        i_data_bresp  => i_data_bresp,
        i_data_bvalid => i_data_bvalid,
        o_data_bready => o_data_bready,

        o_data_araddr  => o_data_araddr,
        o_data_arprot  => o_data_arprot,
        o_data_arvalid => o_data_arvalid,
        i_data_arready => i_data_arready,

        i_data_rdata  => i_data_rdata,
        i_data_rresp  => i_data_rresp,
        i_data_rvalid => i_data_rvalid,
        o_data_rready => o_data_rready
    );

    CsrOpASelect: process(exec.status.instr, exec.reg_opA)
    begin
        if (exec.status.instr.source1 = IMMEDIATE) then
            csr_opA <= std_logic_vector(resize(unsigned(exec.status.instr.base.rs1), 32));
        else
            csr_opA <= reg_opA;
        end if;
    end process CsrOpASelect;

    eZiCsr : entity ndsmd_riscv.ZiCsr
    generic map (
        cTrapBaseAddress => cZiCsr_TrapBaseAddress
    ) port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        i_decoded => exec.status.instr,
        i_opA     => csr_opA,
        o_res     => csr_res,
        
        i_instret => writeback.status.valid,
        
        -- generic interrupts will be allowed to support other interrupt needs that arent the below
        i_irpt_gen   => (others => '0'),
        -- ext will be a high priority external interrupt
        i_irpt_ext   => '0',
        -- software interrupts are ecalls or exceptions. This signal here will be used for exceptions,
        -- since ecalls will be handled internal to this entity.
        i_irpt_sw    => '0', 
        -- timer interrupts are self explanatory.
        i_irpt_timer => '0',
        
        i_irpt_bkmkpc => writeback.bkmkpc,
        o_irpt_pc     => irpt_pc,
        o_irpt_valid  => irpt_valid,
        o_irpt_mepc   => irpt_mepc
    );

    global_stall_bus(cMemAccessIndex) <= global_stall_bus(cWritebackIndex) or bool2bit(memaccess.status.stall_reason /= NOT_STALLED);

    MemAccessStage: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                memaccess.status <= stage_status_t'(
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
                    rs1_hzd      => -1,
                    rs2_hzd      => -1
                );
            else
                -- If everything after this stage is not stalled, we're not stalled.
                -- The global stall bus indicates the status of the current stage to the end, and
                -- then the following stage.

                -- If the execute stage and all stages after it are not stalled, and the 
                -- decode stage is also not stalled, we can accept a new instruction.
                if (global_stall_bus(cMemAccessIndex downto cExecuteIndex) = "00") then
                    memaccess.status <= exec.status;
                    if (exec.status.instr.unit = MEXT) then
                        memaccess.exec_res <= exec.mext_res;
                    elsif (exec.status.instr.destination = REGISTERS) then
                        memaccess.exec_res <= exec.alu_res;
                    end if;

                    if (exec.status.instr.mem_operation /= NULL_OP) then
                        if (mem_valid = '1') then
                            -- If we got a cache hit (which initially with this design we won't)
                            -- then we can move on with our lives, merrily chugging away.
                            memaccess.mem_res <= mem_res;
                        else
                            -- Otherwise, we're stalled until the memory unit returns some data.
                            memaccess.status.stall_reason <= MEMORY_STALL;
                        end if;
                    end if;

                elsif (global_stall_bus(cMemAccessIndex) = '1') then
                    -- If we're stalled, we're either stalled because later stages are stalled or
                    -- because we're executing a multi-cycle instruction. The execute stage's status
                    -- of stalled/not stalled does not matter, as it cannot be accepted anyway without
                    -- dropping the current instruction.

                    -- If we're the one thats stalled, check if the stall has been resolved.
                    if (memaccess.status.stall_reason = MEMORY_STALL) then
                        if (mem_valid = '1') then
                            memaccess.mem_res <= mem_res;
                            memaccess.status.stall_reason <= NOT_STALLED;
                        end if;
                    end if;

                elsif (global_stall_bus(cMemAccessIndex downto cExecuteIndex) = "01") then
                    -- Alternatively, the decode stage could be stalled, i.e. it did not issue a new
                    -- instruction. Therefore just populate the exec status with an invalid instruction.

                    memaccess.status <= stage_status_t'(
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
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    );
                end if;
            end if;
        end if;
    end process MemAccessStage;

    global_stall_bus(cWritebackIndex) <= '0';

    WritebackStage: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                writeback.status <= stage_status_t'(
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
                    rs1_hzd      => -1,
                    rs2_hzd      => -1
                );

                writeback.bkmkpc <= (others => '0');
                writeback.res    <= (others => '0');
                writeback.rdwen  <= '0';
            else
                -- If everything after this stage is not stalled, we're not stalled.
                -- The global stall bus indicates the status of the current stage to the end, and
                -- then the following stage.

                if (writeback.status.valid = '1') then
                    writeback.bkmkpc <= writeback.status.pc;
                end if;

                -- If the execute stage and all stages after it are not stalled, and the 
                -- decode stage is also not stalled, we can accept a new instruction.
                if (global_stall_bus(cMemAccessIndex) = '0') then
                    writeback.status  <= memaccess.status;
                    if (memaccess.status.instr.mem_operation /= LOAD) then
                        writeback.res <= memaccess.exec_res;
                    else
                        writeback.res <= memaccess.mem_res;
                    end if;
                    writeback.rdwen <= bool2bit(memaccess.status.valid = '1' and memaccess.status.instr.destination = REGISTERS);

                else
                    -- Alternatively, the decode stage could be stalled, i.e. it did not issue a new
                    -- instruction. Therefore just populate the exec status with an invalid instruction.
                    writeback.status <= stage_status_t'(
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
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    );

                    writeback.res   <= (others => '0');
                    writeback.rdwen <= '0';
                end if;
            end if;
        end if;
    end process WritebackStage;

    -- For the eventual tomasulo, leverage a FIFO that allows me to 
    -- keep track of the issued instructions. For example, we can issue
    -- ids 0 thru 63, but when 0 needs to be reissued, we need to make sure
    -- we get thru the previously issued ids before we complete 0.
    
    
end architecture rtl;