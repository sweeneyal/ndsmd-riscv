-----------------------------------------------------------------------------------------------------------------------
-- entity: InstrPrefetcher_Stimuli
--
-- library: tb_ndsmd_riscv
-- 
-- signals:
--      o_stimuli   : 
--
-- description:
--      
-----------------------------------------------------------------------------------------------------------------------
library vunit_lib;
    context vunit_lib.vunit_context;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library osvvm;
    use osvvm.TbUtilPkg.all;
    use osvvm.RandomPkg.all;

    
library simtools;
    
library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.DatapathUtility.all;

library tb_ndsmd_riscv;
    use tb_ndsmd_riscv.ControlEngine_Utility.all;
    use tb_ndsmd_riscv.RiscvUtility.all;

entity ControlEngine_Stimuli is
    generic (nested_runner_cfg : string);
    port (
        o_stimuli : out stimuli_t;
        -- we have to see the responses to know when to respond to requests
        i_responses : in responses_t
    );
end entity ControlEngine_Stimuli;

architecture rtl of ControlEngine_Stimuli is
    constant cPeriod : time := 10 ns;

    signal clk : std_logic := '0';
    signal stimuli : stimuli_t;
begin
    
    o_stimuli <= stimuli;
    stimuli.clk <= clk;

    CreateClock(clk=>clk, period=>cPeriod);

    -- Create constrained random stimuli generator that:
    -- 1. generates instructions in response to requests
    -- 2. generates random delays of several clock cycles to requests (range 0 to 100+?)
    -- 3. generates random stalls of several clock cycles

    -- One idea is to use the name of the test run to generate stimuli.
    -- e.g. if it contains maxthroughput, then turn off random delays and random stalls
    -- e.g. if it contains randdelay in the test name, then vary the delay value over a range
    -- e.g. if it contains bathtubdelay, then bias the random delays to bathtub distribution (high no. of 0s and 100s)
    -- e.g. if it contains randstall, then vary the stall delay
    -- e.g. if it contains bathtubstall, then bias the random stalls to bathtub distribution (high no. of 0s and 100s)

    TestRunner : process
        variable rand : RandomPType;
        variable idx  : natural := 0;
        variable rand_wait : natural := 0;
        variable pc_update : boolean := false;
    begin
        test_runner_setup(runner, nested_runner_cfg);
  
        while test_suite loop
            if run("t_nominal") then
                info("Running maxthroughput test");
                stimuli.resetn <= '0';
                stimuli.pc     <= (others => '0');
                stimuli.valid  <= '0';
                stimuli.instr  <= decode(x"00000000");
                stimuli.status <= datapath_status_t'(
                    decode   => stage_status_t'(
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
                            fp_format      => NULL_FORMAT,
                            fp_qualifiers  => NULL_QUALIFIER,
                            csr_operation  => NULL_OP,
                            csr_access     => CSRRW,
                            destination    => REGISTERS
                        ),
                        valid        => '0',
                        stall_reason => NOT_STALLED,
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    ),
                    execute   => stage_status_t'(
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
                            fp_format      => NULL_FORMAT,
                            fp_qualifiers  => NULL_QUALIFIER,
                            csr_operation  => NULL_OP,
                            csr_access     => CSRRW,
                            destination    => REGISTERS
                        ),
                        valid        => '0',
                        stall_reason => NOT_STALLED,
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    ),
                    memaccess => stage_status_t'(
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
                            fp_format      => NULL_FORMAT,
                            fp_qualifiers  => NULL_QUALIFIER,
                            csr_operation  => NULL_OP,
                            csr_access     => CSRRW,
                            destination    => REGISTERS
                        ),
                        valid        => '0',
                        stall_reason => NOT_STALLED,
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    ),
                    writeback => stage_status_t'(
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
                            fp_format      => NULL_FORMAT,
                            fp_qualifiers  => NULL_QUALIFIER,
                            csr_operation  => NULL_OP,
                            csr_access     => CSRRW,
                            destination    => REGISTERS
                        ),
                        valid        => '0',
                        stall_reason => NOT_STALLED,
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    )
                );

                wait until rising_edge(clk);
                wait for 100 ps;
                stimuli.resetn <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;
                check(i_responses.cpu_ready = '1');

                for ii in 0 to 1000 loop
                    if (i_responses.cpu_ready = '1') then
                        stimuli.instr <= decode(
                            generate_instruction(
                                -1, 
                                rand.RandInt(0, 100000),
                                rand.RandInt(0, 100000)
                            )
                        );
                        stimuli.valid <= '1';
                        pc_update := true;
                    else
                        pc_update := false;
                    end if;

                    stimuli.status.writeback <= stimuli.status.memaccess;
                    stimuli.status.memaccess <= stimuli.status.execute;
                    if (i_responses.issued.valid = '1') then
                        stimuli.status.execute <= i_responses.issued;
                    else
                        stimuli.status.execute <= stage_status_t'(
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
                                fp_format      => NULL_FORMAT,
                                fp_qualifiers  => NULL_QUALIFIER,
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

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    if (pc_update) then
                        stimuli.pc <= stimuli.pc + 4;
                    end if;
                end loop;
                
            elsif run("t_offnominal") then
                info("Running bathtub delay with bathtub stall");
                stimuli.resetn <= '0';
                stimuli.pc     <= (others => '0');
                stimuli.valid  <= '0';
                stimuli.instr  <= decode(x"00000000");
                stimuli.status <= datapath_status_t'(
                    decode   => stage_status_t'(
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
                            fp_format      => NULL_FORMAT,
                            fp_qualifiers  => NULL_QUALIFIER,
                            csr_operation  => NULL_OP,
                            csr_access     => CSRRW,
                            destination    => REGISTERS
                        ),
                        valid        => '0',
                        stall_reason => NOT_STALLED,
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    ),
                    execute   => stage_status_t'(
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
                            fp_format      => NULL_FORMAT,
                            fp_qualifiers  => NULL_QUALIFIER,
                            csr_operation  => NULL_OP,
                            csr_access     => CSRRW,
                            destination    => REGISTERS
                        ),
                        valid        => '0',
                        stall_reason => NOT_STALLED,
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    ),
                    memaccess => stage_status_t'(
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
                            fp_format      => NULL_FORMAT,
                            fp_qualifiers  => NULL_QUALIFIER,
                            csr_operation  => NULL_OP,
                            csr_access     => CSRRW,    
                            destination    => REGISTERS
                        ),
                        valid        => '0',
                        stall_reason => NOT_STALLED,
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    ),
                    writeback => stage_status_t'(
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
                            fp_format      => NULL_FORMAT,
                            fp_qualifiers  => NULL_QUALIFIER,
                            csr_operation  => NULL_OP,
                            csr_access     => CSRRW,
                            destination    => REGISTERS
                        ),
                        valid        => '0',
                        stall_reason => NOT_STALLED,
                        rs1_hzd      => -1,
                        rs2_hzd      => -1
                    )
                );

                wait until rising_edge(clk);
                wait for 100 ps;
                stimuli.resetn <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;
                check(i_responses.cpu_ready = '1');

                for ii in 0 to 1000 loop
                    if (i_responses.cpu_ready = '1') then
                        stimuli.instr <= decode(
                            generate_instruction(
                                -1, 
                                rand.RandInt(0, 100000),
                                rand.RandInt(0, 100000)
                            )
                        );
                        stimuli.valid <= '1';
                        pc_update := true;
                    else
                        pc_update := false;
                    end if;

                    if (rand.RandInt(1,6) = 1) then
                        -- We're going to randomly stall the memaccess stage.
                        stimuli.status.writeback <= stage_status_t'(
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
                                fp_format      => NULL_FORMAT,
                                fp_qualifiers  => NULL_QUALIFIER,
                                csr_operation  => NULL_OP,
                                csr_access     => CSRRW,
                                destination    => REGISTERS
                            ),
                            valid        => '0',
                            stall_reason => NOT_STALLED,
                            rs1_hzd      => -1,
                            rs2_hzd      => -1
                        );

                        stimuli.status.memaccess.stall_reason <= MEMORY_STALL;
                    elsif (rand.RandInt(1,6) = 2) then
                        -- We're going to randomly stall the execute stage.
                        stimuli.status.writeback <= stimuli.status.memaccess;
                        stimuli.status.memaccess <= stage_status_t'(
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
                                fp_format      => NULL_FORMAT,
                                fp_qualifiers  => NULL_QUALIFIER,
                                csr_operation  => NULL_OP,
                                csr_access     => CSRRW,
                                destination    => REGISTERS
                            ),
                            valid        => '0',
                            stall_reason => NOT_STALLED,
                            rs1_hzd      => -1,
                            rs2_hzd      => -1
                        );
                        stimuli.status.execute.stall_reason <= EXECUTION_STALL;

                        stimuli.status.writeback.stall_reason <= NOT_STALLED;
                    else
                        stimuli.status.writeback <= stimuli.status.memaccess;
                        stimuli.status.memaccess <= stimuli.status.execute;

                        stimuli.status.writeback.stall_reason <= NOT_STALLED;
                        stimuli.status.memaccess.stall_reason <= NOT_STALLED;
                        stimuli.status.execute.stall_reason <= NOT_STALLED;

                        if (i_responses.issued.valid = '1') then
                            stimuli.status.execute <= i_responses.issued;
                        else
                            stimuli.status.execute <= stage_status_t'(
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
                                    jump_branch => NOT_JUMP,
                                    condition      => NO_COND,
                                    new_pc         => (others => '0'),
                                    fp_format      => NULL_FORMAT,
                                    fp_qualifiers  => NULL_QUALIFIER,
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

                    wait until rising_edge(clk);
                    wait for 100 ps;

                    if (pc_update) then
                        stimuli.pc <= stimuli.pc + 4;
                    end if;
                end loop;
            end if;
        end loop;
    
        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 2 ms);
    
end architecture rtl;