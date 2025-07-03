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

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;

library tb_ndsmd_riscv;
    use tb_ndsmd_riscv.ZiCsr_Utility.all;

entity Tb_ZiCsr is
    generic (runner_cfg : string);
end entity Tb_ZiCsr;

architecture tb of Tb_ZiCsr is
    constant cPeriod : time := 10 ns;

    signal clk : std_logic := '0';

    signal stimuli   : stimuli_t;
    signal responses : responses_t;
begin

    stimuli.clk <= clk;

    CreateClock(clk=>clk, period=>cPeriod);
    
    TestRunner : process
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
                stimuli.resetn                <= '1';
                stimuli.decoded.base          <= decode(generate_read_instruction(x"301", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRS;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Check MISA register for default value
                check(responses.res = x"40001100");
                -- Reset the driving signals
                stimuli.decoded.base          <= decode(x"00000000");
                stimuli.decoded.csr_operation <= NULL_OP;
                stimuli.decoded.source1       <= REGISTERS;

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Write an arbitrary value to the mscratch register
                stimuli.decoded.base          <= decode(generate_write_instruction(x"340", REGISTERS, CSRRS));
                stimuli.decoded.csr_operation <= CSRROP;
                stimuli.decoded.csr_access    <= CSRRW;
                stimuli.decoded.source1       <= REGISTERS;
                stimuli.opA                   <= x"12345678";

                wait until rising_edge(clk);
                wait for 100 ps;

                -- Verify that the read that occurred is a zero value
                check(responses.res = x"00000000");
                -- Read mscratch register
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

            elsif run("t_interrupt_specific") then
                -- write mip and mie to allow interrupts
                -- trigger each type of interrupt
                -- use an mret to complete the interrupt

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

    eChecker : entity tb_ndsmd_riscv.ZiCsr_Checker
    port map (
        i_stimuli   => stimuli,
        i_responses => responses
    );
    
end architecture tb;