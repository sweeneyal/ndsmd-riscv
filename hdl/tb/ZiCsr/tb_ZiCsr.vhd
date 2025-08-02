-----------------------------------------------------------------------------------------------------------------------
-- entity: tb_InstrPrefetcher
--
-- library: tb_ndsmd_riscv
-- 
-- generics:
--      runner_cfg : configuration string for Vunit
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

library universal;
    use universal.CommonFunctions.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.ZicsrUtility.all;

library tb_ndsmd_riscv;
    use tb_ndsmd_riscv.ZiCsr_Utility.all;

entity Tb_ZiCsr is
    generic (runner_cfg : string);
end entity Tb_ZiCsr;

architecture tb of Tb_ZiCsr is
    constant cPeriod : time := 10 ns;
    constant cMretInstr : std_logic_vector(31 downto 0) := "00110000001000000000000001110011";

    signal clk : std_logic := '0';

    signal stimuli   : stimuli_t;
    signal responses : responses_t;
begin

    stimuli.clk <= clk;

    CreateClock(clk=>clk, period=>cPeriod);
    
    TestRunner : process
        variable v : std_logic_vector(31 downto 0) := (others => '0');
    begin
        test_runner_setup(runner, runner_cfg);
  
        while test_suite loop
            -- types of tests needed:
            --  verification of specific behaviors of registers
            --    e.g., event counters, timer, instret, etc.
            --  verification of interrupt performance
            --    e.g., for a given set of interrupts, which one takes priority, 
            --     whats the target address, behavior that occurs on mret
            if run("t_register_verification") then
                stimuli.resetn      <= '0';
                stimuli.decoded     <= decoded_instr_t'(
                                        base          => decode(x"00000000"),
                                        unit          => ALU,
                                        operation     => NULL_OP,
                                        source1       => REGISTERS,
                                        source2       => REGISTERS,
                                        immediate     => (others => '0'),
                                        mem_operation => NULL_OP,
                                        mem_access    => BYTE_ACCESS,
                                        jump_branch   => NOT_JUMP,
                                        condition     => NO_COND,
                                        new_pc        => (others => '0'),
                                        csr_operation => NULL_OP,
                                        csr_access    => CSRRW,
                                        destination   => REGISTERS
                                    );
                stimuli.opA         <= (others => '0');
                stimuli.instret     <= '0';
                stimuli.irpt_gen    <= (others => '0');
                stimuli.irpt_ext    <= '0';
                stimuli.irpt_sw     <= '0';
                stimuli.irpt_timer  <= '0';
                stimuli.irpt_bkmkpc <= (others => '0');
                check(false);
            elsif run("t_csr_operations") then
                -- Initial default values and reset signal
                info("Setting initial default values and reset signal.");
                stimuli.resetn      <= '0';
                stimuli.decoded     <= decoded_instr_t'(
                                        base          => decode(x"00000000"),
                                        unit          => ALU,
                                        operation     => NULL_OP,
                                        source1       => REGISTERS,
                                        source2       => REGISTERS,
                                        immediate     => (others => '0'),
                                        mem_operation => NULL_OP,
                                        mem_access    => BYTE_ACCESS,
                                        jump_branch   => NOT_JUMP,
                                        condition     => NO_COND,
                                        new_pc        => (others => '0'),
                                        csr_operation => NULL_OP,
                                        csr_access    => CSRRW,
                                        destination   => REGISTERS
                                    );
                stimuli.opA         <= (others => '0');
                stimuli.instret     <= '0';
                stimuli.irpt_gen    <= (others => '0');
                stimuli.irpt_ext    <= '0';
                stimuli.irpt_sw     <= '0';
                stimuli.irpt_timer  <= '0';
                stimuli.irpt_bkmkpc <= (others => '0');

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Deassert reset, and read the MISA register
                info("Deasserting reset and reading the MISA register.");
                stimuli.resetn                <= '1';
                stimuli.decoded.base          <= decode(generate_read_instruction(x"301", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRS;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Check MISA register for default value
                info("Checking MISA register for expected default value.");
                check(responses.res = x"40001100");
                -- Reset the driving signals
                stimuli.decoded.base          <= decode(x"00000000");
                stimuli.decoded.csr_operation <= NULL_OP;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Write an arbitrary value to the mscratch register
                info("Writing an arbitrary value to the mscratch register.");
                stimuli.decoded.base          <= decode(generate_write_instruction(x"340", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRW;
                stimuli.decoded.source1       <= REGISTERS;
                stimuli.opA                   <= x"12345678";

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that the read that occurred is a zero value
                info("Verifying that register read returned a zero value.");
                check(responses.res = x"00000000");
                -- Read mscratch register
                info("Reading mscratch register to confirm that value was written as expected.");
                stimuli.decoded.base          <= decode(generate_read_instruction(x"340", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRC;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify the output of the scratch register has changed to the arbitrary value
                check(responses.res = x"12345678");
                stimuli.decoded.base          <= decode(x"00000000");
                stimuli.decoded.csr_operation <= NULL_OP;
                stimuli.decoded.source1       <= REGISTERS;
                info("Register read matched register write. Test passed.");

            elsif run("t_interrupt_specific") then
                -- write mip and mie to allow interrupts
                -- trigger each type of interrupt
                -- use an mret to complete the interrupt

                -- enable an interrupt
                -- trigger an interrupt
                -- check that target address is correct
                -- perform an mret
                -- do this for all interrupt types

                info("Setting initial default values and reset signal.");
                stimuli.resetn      <= '0';
                stimuli.decoded     <= decoded_instr_t'(
                                        base          => decode(x"00000000"),
                                        unit          => ALU,
                                        operation     => NULL_OP,
                                        source1       => REGISTERS,
                                        source2       => REGISTERS,
                                        immediate     => (others => '0'),
                                        mem_operation => NULL_OP,
                                        mem_access    => BYTE_ACCESS,
                                        jump_branch   => NOT_JUMP,
                                        condition     => NO_COND,
                                        new_pc        => (others => '0'),
                                        csr_operation => NULL_OP,
                                        csr_access    => CSRRW,
                                        destination   => REGISTERS
                                    );
                stimuli.opA         <= (others => '0');
                stimuli.instret     <= '0';
                stimuli.irpt_gen    <= (others => '0');
                stimuli.irpt_ext    <= '0';
                stimuli.irpt_sw     <= '0';
                stimuli.irpt_timer  <= '0';
                stimuli.irpt_bkmkpc <= (others => '0');

                wait until rising_edge(clk);
                wait for 100 ps;

                info("Deasserting reset and writing MIE status bit to allow interrupts at the architecture level.");
                stimuli.resetn                <= '1';
                stimuli.decoded.base          <= decode(generate_write_instruction(x"300", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRW;
                stimuli.decoded.source1       <= REGISTERS;

                -- using v as a temp register to set the value of mstatus
                v(cMIE)     := '1';
                stimuli.opA <= v;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that the read that occurred is a zero value
                info("Verifying that register read returned a zero value.");
                check(responses.res = x"00000000");
                -- Read mscratch register
                info("Reading mstatus register to confirm that value was written as expected.");
                stimuli.decoded.base          <= decode(generate_read_instruction(x"300", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRC;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that what was read matched what was written
                check(responses.res = v);

                info("Writing mie bit for Machine External Interrupt Enable (MEIE)");
                stimuli.decoded.base          <= decode(generate_write_instruction(x"304", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRW;
                stimuli.decoded.source1       <= REGISTERS;

                -- using v as a temp register to set the value of mstatus
                v           := (others => '0');
                v(cMEI)     := '1';
                stimuli.opA <= v;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that the read that occurred is a zero value
                info("Verifying that register read returned a zero value.");
                check(responses.res = x"00000000");
                -- Read mie register
                info("Reading mie register to confirm that value was written as expected.");
                stimuli.decoded.base          <= decode(generate_read_instruction(x"304", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRC;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that what was read matched what was written
                check(responses.res = v);

                info("Clearing control signals and triggering a machine external interrupt.");
                stimuli.decoded.base          <= decode(x"00000000");
                stimuli.decoded.csr_operation <= NULL_OP;
                stimuli.decoded.source1       <= REGISTERS;
                stimuli.irpt_ext    <= '1';
                stimuli.irpt_bkmkpc <= x"44444444";

                wait until rising_edge(clk);
                wait for 100 ps;

                info("Checking that interrupt valid is set, and that the interrupt target pc and bookmark pc match the expected values.");
                check(responses.irpt_valid = '1');
                v := x"FFFF0000";
                v := std_logic_vector(unsigned(v) + cMEI * 4);
                check(responses.irpt_pc = unsigned(v));
                check(responses.irpt_mepc = unsigned(stimuli.irpt_bkmkpc));
                stimuli.irpt_ext <= '0';

                wait until rising_edge(clk);
                wait for 100 ps;

                info("Checking that interrupt valid is cleared, so multiple triggers don't occur.");
                check(responses.irpt_valid = '0');
                check(responses.irpt_mepc = unsigned(stimuli.irpt_bkmkpc));

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Read the mcause register to confirm value
                info("Reading mcause register to confirm that cause was written as expected.");
                stimuli.decoded.base          <= decode(generate_read_instruction(x"342", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRC;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that what was read matched what was written
                check(responses.res = '1' & to_slv(cMEI, 31));

                -- Read the mstatus register to confirm mie and mpie are cleared and set, respectively.
                info("Reading mstatus register to confirm that MIE and MPIE are cleared and set, respectively.");
                stimuli.decoded.base          <= decode(generate_read_instruction(x"300", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRC;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that what was read matched what was written
                v := (others => '0');
                v(cMPIE) := '1';
                check(responses.res = v);

                info("Clearing control signals for single cycle reprieve.");
                stimuli.decoded.base          <= decode(x"00000000");
                stimuli.decoded.csr_operation <= NULL_OP;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Clear MIP
                info("Clearing mip bit for Machine External Interrupt Enable (MEIE)");
                stimuli.decoded.base          <= decode(generate_write_instruction(x"344", REGISTERS, CSRRC));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRC;
                stimuli.decoded.source1       <= REGISTERS;

                -- using v as a temp register to set the value of MIP
                v           := (others => '1');
                stimuli.opA <= v;

                wait until rising_edge(clk);
                wait for 100 ps;

                v           := (others => '0');
                v(cMEI)     := '1';
                check(responses.res = v);

                info("Performing MRET operation.");
                stimuli.decoded.base          <= decode(cMretInstr);
                stimuli.decoded.csr_operation <= MRET;
                stimuli.decoded.csr_access    <= NULL_OP;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                info("Reading mstatus register to confirm that MIE and MPIE are set.");
                stimuli.decoded.base          <= decode(generate_read_instruction(x"300", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRS;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                v           := (others => '0');
                v(cMIE)     := '1';
                v(cMPIE)    := '1';
                check(responses.res = v);

                info("Writing mie bit for Machine Software Interrupt Enable (MSIE)");
                stimuli.decoded.base          <= decode(generate_write_instruction(x"304", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRS;
                stimuli.decoded.source1       <= REGISTERS;

                -- using v as a temp register to set the value of mstatus
                v           := (others => '0');
                v(cMSI)     := '1';
                stimuli.opA <= v;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that the read that occurred is cMEI (since we just sent cMSI).
                info("Verifying that register read returned the expected value.");
                v           := (others => '0');
                v(cMEI)     := '1';
                check(responses.res = v);
                -- Read mie register
                info("Reading mie register to confirm that value was written as expected.");
                stimuli.decoded.base          <= decode(generate_read_instruction(x"304", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRC;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that what was read matched what was written
                v(cMSI)     := '1';
                check(responses.res = v);

                info("Clearing control signals and triggering a machine external interrupt.");
                stimuli.decoded.base          <= decode(x"00000000");
                stimuli.decoded.csr_operation <= NULL_OP;
                stimuli.decoded.source1       <= REGISTERS;
                stimuli.irpt_sw     <= '1';
                stimuli.irpt_bkmkpc <= x"88888888";

                wait until rising_edge(clk);
                wait for 100 ps;

                info("Checking that interrupt valid is set, and that the interrupt target pc and bookmark pc match the expected values.");
                check(responses.irpt_valid = '1');
                v := x"FFFF0000";
                v := std_logic_vector(unsigned(v) + cMSI * 4);
                check(responses.irpt_pc = unsigned(v));
                check(responses.irpt_mepc = unsigned(stimuli.irpt_bkmkpc));
                stimuli.irpt_sw <= '0';

                wait until rising_edge(clk);
                wait for 100 ps;

                info("Checking that interrupt valid is cleared, so multiple triggers don't occur.");
                check(responses.irpt_valid = '0');
                check(responses.irpt_mepc = unsigned(stimuli.irpt_bkmkpc));

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Read the mcause register to confirm value
                info("Reading mcause register to confirm that cause was written as expected.");
                stimuli.decoded.base          <= decode(generate_read_instruction(x"342", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRC;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that what was read matched what was written
                check(responses.res = '1' & to_slv(cMSI, 31));

                -- Read the mstatus register to confirm mie and mpie are cleared and set, respectively.
                info("Reading mstatus register to confirm that MIE and MPIE are cleared and set, respectively.");
                stimuli.decoded.base          <= decode(generate_read_instruction(x"300", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRC;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that what was read matched what was written
                v := (others => '0');
                v(cMPIE) := '1';
                check(responses.res = v);

                info("Clearing control signals for single cycle reprieve.");
                stimuli.decoded.base          <= decode(x"00000000");
                stimuli.decoded.csr_operation <= NULL_OP;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Clear MIP
                info("Clearing mip bit for Machine External Interrupt Enable (MSIE)");
                stimuli.decoded.base          <= decode(generate_write_instruction(x"344", REGISTERS, CSRRC));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRC;
                stimuli.decoded.source1       <= REGISTERS;

                -- using v as a temp register to set the value of MIP
                v           := (others => '1');
                stimuli.opA <= v;

                wait until rising_edge(clk);
                wait for 100 ps;

                v           := (others => '0');
                v(cMSI)     := '1';
                check(responses.res = v);

                info("Performing MRET operation.");
                stimuli.decoded.base          <= decode(cMretInstr);
                stimuli.decoded.csr_operation <= MRET;
                stimuli.decoded.csr_access    <= NULL_OP;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                info("Reading mstatus register to confirm that MIE and MPIE are set.");
                stimuli.decoded.base          <= decode(generate_read_instruction(x"300", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRS;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                v           := (others => '0');
                v(cMIE)     := '1';
                v(cMPIE)    := '1';
                check(responses.res = v);

            end if;
        end loop;
    
        test_runner_cleanup(runner);
    end process;
    
    eDut : entity ndsmd_riscv.ZiCsr
    generic map (
        cTrapBaseAddress => x"FFFF0000"
    ) port map (
        i_clk    => stimuli.clk,
        i_resetn => stimuli.resetn,

        -- CSRR operations interface
        i_decoded => stimuli.decoded,
        i_opA     => stimuli.opA,
        o_res     => responses.res,
        
        -- Event counter signaling
        i_instret => stimuli.instret,
        
        -- Interrupt Signals
        -- General purpose lower-priority interrupts
        i_irpt_gen   => stimuli.irpt_gen,
        -- External interrupt signal
        i_irpt_ext   => stimuli.irpt_ext,
        -- Software interrupt signal
        i_irpt_sw    => stimuli.irpt_sw,
        -- Timer interrupt signal
        i_irpt_timer => stimuli.irpt_timer,
        
        -- Interupt Control Interface
        -- Last Completed PC serving as bookmark
        i_irpt_bkmkpc => stimuli.irpt_bkmkpc,
        -- PC of interrupt handler selected by active interrupt
        o_irpt_pc     => responses.irpt_pc,
        -- Indicator signal that indicates o_irpt_pc is valid
        o_irpt_valid  => responses.irpt_valid,
        -- PC of return instruction that occurs at MRET
        o_irpt_mepc   => responses.irpt_mepc
    );
    
end architecture tb;