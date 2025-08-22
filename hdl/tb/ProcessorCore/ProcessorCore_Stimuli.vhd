-----------------------------------------------------------------------------------------------------------------------
-- entity: ProcessorCore_Stimuli
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
    use std.textio.all;
    use ieee.std_logic_textio.all;

library osvvm;
    use osvvm.TbUtilPkg.all;
    use osvvm.RandomPkg.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;

library simtools;

library tb_ndsmd_riscv;
    use tb_ndsmd_riscv.ProcessorCore_Utility.all;
    use tb_ndsmd_riscv.RiscvUtility.all;

entity ProcessorCore_Stimuli is
    generic (nested_runner_cfg : string);
    port (
        o_stimuli : out stimuli_t;
        -- we have to see the responses to know when to respond to requests
        i_responses : in responses_t
    );
end entity ProcessorCore_Stimuli;

architecture rtl of ProcessorCore_Stimuli is
    constant cPeriod : time := 10 ns;

    signal clk : std_logic := '0';
    signal stimuli : stimuli_t;

    -- procedure stimulate_memory_interface is
    -- begin
    --     for ii in 0 to 10000 loop
    --         wait on i_responses;
    --         if (i_responses.instr_ren = '1') then
    --             -- For ease of testing, remap the requested PC as the data.
    --             stimuli.instr_rdata  <= transport i_responses.instr_addr after cPeriod;
    --             -- Set rvalid high after a clock cycle, then clear it the next clock cycle.
    --             stimuli.instr_rvalid <= transport '1' after cPeriod, '0' after 2 * cPeriod;
    --         end if;
    --     end loop;
    -- end procedure;

    package InstructionListPackage is new simtools.GenericListPkg
        generic map (element_t => std_logic_vector(31 downto 0));
    shared variable instructions : InstructionListPackage.list;

    package AddressListPackage is new simtools.GenericListPkg
        generic map (element_t => std_logic_vector(31 downto 0));
    shared variable addresses : AddressListPackage.list;

    file file_instr : text;
begin
    
    o_stimuli <= stimuli;
    stimuli.clk <= clk;

    CreateClock(clk=>clk, period=>cPeriod);

    -- The Stimuli entity in this testbench is designed to emulate instruction memory,
    -- because it generates valid instructions based on random numbers and the CPU 
    -- interprets these instructions as they are given, with the assumption of correct
    -- instruction ordering.

    TestRunner : process
        variable rand : RandomPType;
        variable idx  : natural := 0;
        variable rand_wait : natural := 0;

        variable iline : line;
        variable instr : std_logic_vector(31 downto 0);
        variable addr  : std_logic_vector(31 downto 0);
    begin
        test_runner_setup(runner, nested_runner_cfg);
  
        while test_suite loop
            if run("t_max_throughput") then
                info("Running maxthroughput test");
                stimuli.resetn <= '0';
                stimuli.instr_arready <= '0';
                stimuli.instr_rresp   <= "00";
                stimuli.instr_rdata   <= (others => '0');
                stimuli.instr_rvalid  <= '0';

                wait until rising_edge(clk);
                wait for 100 ps;
                stimuli.resetn <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;

                stimuli.instr_arready <= '1';

                for ii in 0 to 10 loop
                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;

                for ii in 0 to 10000 loop
                    -- Waiting until this is 1 when it is already 1 is 
                    -- a surefire way to trigger the WDT. Probably a VHDL feature?
                    if (i_responses.instr_rready = '1') then
                        stimuli.instr_rdata  <= generate_instruction(
                            -1, 
                            rand.RandInt(0, 100000),
                            rand.RandInt(0, 100000)
                        );
                        stimuli.instr_rvalid <= '1';
                        stimuli.instr_rresp  <= "00";
                    end if;
                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;
            elsif run("t_matmult") then
                info("Running matmult test");

                file_open(file_instr, "./hdl/tb/ProcessorCore/matmult.hex", read_mode);

                while not endfile(file_instr) loop
                    readline(file_instr, iline);
                    hread(iline, instr);
                    instructions.append(instr);
                end loop;

                instructions.append(x"00000013");
                instructions.append(x"00000013");
                instructions.append(x"00000013");
                instructions.append(x"00000013");
                instructions.append(x"00000013");
                instructions.append(x"00000013");

                file_close(file_instr);

                stimuli.resetn <= '0';
                stimuli.instr_arready <= '0';
                stimuli.instr_rresp   <= "00";
                stimuli.instr_rdata   <= (others => '0');
                stimuli.instr_rvalid  <= '0';

                wait until rising_edge(clk);
                wait for 100 ps;
                stimuli.resetn <= '1';

                wait until rising_edge(clk);
                wait for 100 ps;

                for ii in 0 to 50000 loop
                    if (i_responses.instr_arvalid = '1') then
                        addresses.append(i_responses.instr_araddr);
                        stimuli.instr_arready <= '1';
                    end if;

                    if (i_responses.instr_rready = '1' and addresses.length > 0) then
                        addr := addresses.get(0);
                        addresses.delete(0);
                        report "Reading address " & to_hstring(addr);

                        stimuli.instr_rdata  <= instructions.get(to_natural(addr(31 downto 2)));
                        stimuli.instr_rvalid <= '1';
                        stimuli.instr_rresp  <= "00";
                    else
                        stimuli.instr_rvalid <= '0';
                    end if;

                    wait until rising_edge(clk);
                    wait for 100 ps;
                end loop;
            end if;
        end loop;
    
        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 2 ms);
    
end architecture rtl;