library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;

package ZiCsr_Utility is
    
    type stimuli_t is record
        clk         : std_logic;
        resetn      : std_logic;
        decoded     : decoded_instr_t;
        opA         : std_logic_vector(31 downto 0);
        instret     : std_logic;
        irpt_gen    : std_logic_vector(15 downto 0);
        irpt_ext    : std_logic;
        irpt_sw     : std_logic;
        irpt_timer  : std_logic;
        irpt_bkmkpc : unsigned(31 downto 0);
    end record stimuli_t;

    type responses_t is record
        res         : std_logic_vector(31 downto 0);
        irpt_pc     : unsigned(31 downto 0);
        irpt_valid  : std_logic;
        irpt_mepc   : unsigned(31 downto 0);
    end record responses_t;

    function generate_read_instruction(
            addr   : std_logic_vector(11 downto 0);
            source : source_t;
            sc     : csr_access_t
    ) return std_logic_vector;

    function generate_write_instruction(
            addr   : std_logic_vector(11 downto 0);
            source : source_t;
            sc     : csr_access_t
    ) return std_logic_vector;
    
end package ZiCsr_Utility;

package body ZiCsr_Utility is
    
    function generate_read_instruction(
            addr   : std_logic_vector(11 downto 0);
            source : source_t;
            sc     : csr_access_t
    ) return std_logic_vector is
        variable instr : std_logic_vector(31 downto 0) := (others => '0');
    begin
        instr(31 downto 20) := addr(11 downto 0);
        case sc is
            when CSRRS =>
                if (source = REGISTERS) then
                    instr(14 downto 12) := "010";
                elsif (source = IMMEDIATE) then
                    instr(14 downto 12) := "110";
                else
                    assert false report "CSR source can only be source or immediate" severity error;
                end if;

            when CSRRC =>
                if (source = REGISTERS) then
                    instr(14 downto 12) := "011";
                elsif (source = IMMEDIATE) then
                    instr(14 downto 12) := "111";
                else
                    assert false report "CSR source can only be source or immediate" severity error;
                end if;
        
            when others =>
                assert false report "CSR source can only be source or immediate" severity error;
        
        end case;
        
        instr(11 downto 7) := "00101";
        instr(6 downto 0)  := cEcallOpcode;
        return instr;
    end function;

    function generate_write_instruction(
            addr   : std_logic_vector(11 downto 0);
            source : source_t;
            sc     : csr_access_t
    ) return std_logic_vector is
        variable instr : std_logic_vector(31 downto 0) := (others => '0');
    begin
        instr(31 downto 20) := addr(11 downto 0);
        instr(19 downto 15) := "00101";
        case sc is
            when CSRRS =>
                if (source = REGISTERS) then
                    instr(14 downto 12) := "010";
                elsif (source = IMMEDIATE) then
                    instr(14 downto 12) := "110";
                else
                    assert false report "CSR source can only be source or immediate" severity error;
                end if;

            when CSRRC =>
                if (source = REGISTERS) then
                    instr(14 downto 12) := "011";
                elsif (source = IMMEDIATE) then
                    instr(14 downto 12) := "111";
                else
                    assert false report "CSR source can only be source or immediate" severity error;
                end if;
        
            when CSRRW =>
                if (source = REGISTERS) then
                    instr(14 downto 12) := "011";
                elsif (source = IMMEDIATE) then
                    instr(14 downto 12) := "111";
                else
                    assert false report "CSR source can only be source or immediate" severity error;
                end if;

            when NULL_OP => 
                assert false report "Cannot be null op" severity error;
        
        end case;
        
        instr(11 downto 7) := "00101";
        instr(6 downto 0)  := cEcallOpcode;
        return instr;
    end function;
    
end package body ZiCsr_Utility;