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

entity IntegerAlu is
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_decoded : in decoded_instr_t;
        i_opA     : in std_logic_vector(31 downto 0);
        i_opB     : in std_logic_vector(31 downto 0);

        o_res : out std_logic_vector(31 downto 0);
        o_eq  : out std_logic
    );
end entity IntegerAlu;

architecture rtl of IntegerAlu is
    signal add_res     : std_logic_vector(31 downto 0) := (others => '0');
    signal slt_res     : std_logic_vector(31 downto 0) := (others => '0');
    signal bitwise_res : std_logic_vector(31 downto 0) := (others => '0');
    signal shift_res   : std_logic_vector(31 downto 0) := (others => '0');

    signal right_enum : std_logic := '0';
    signal arith_enum : std_logic := '0';
begin
    
    Adder: process(i_decoded, i_opA, i_opB)
    begin
        if (i_decoded.operation = SUBTRACT) then
            add_res <= std_logic_vector(
                signed(i_opA) - signed(i_opB)
            );
        else 
            -- ADD, as well as anything else, since this result will
            -- be ignored.
            add_res <= std_logic_vector(
                signed(i_opA) + signed(i_opB)
            );
        end if;
    end process Adder;

    Slt_Sltu: process(i_decoded, i_opA, i_opB)
    begin
        o_eq <= bool2bit(i_opA = i_opB);
        if (i_decoded.operation = SLT) then
            slt_res <= (31 downto 1 => '0') & bool2bit(signed(i_opA) > signed(i_opB));
        else
            -- SLTU, as well as anything else, as again, if not selected will be ignored.
            slt_res <= (31 downto 1 => '0') & bool2bit(unsigned(i_opA) > unsigned(i_opB));
        end if;
    end process Slt_Sltu;
    
    Bitwise: process(i_decoded, i_opA, i_opB)
    begin
        if (i_decoded.operation = BITWISE_XOR) then
            bitwise_res <= i_opA xor i_opB;
        elsif (i_decoded.operation = BITWISE_OR) then
            bitwise_res <= i_opA or i_opB;
        else
            -- BITWISE_AND, as well as anything else.
            bitwise_res <= i_opA and i_opB;
        end if;
    end process Bitwise;

    right_enum <= bool2bit(i_decoded.operation = SHIFT_RA 
        or i_decoded.operation = SHIFT_RL);

    arith_enum <= bool2bit(i_decoded.operation = SHIFT_RA);

    eShift : entity ndsmd_riscv.BarrelShift
    port map (
        i_right  => right_enum,
        i_arith  => arith_enum,
        i_opA    => i_opA,
        i_shamt  => i_opB(4 downto 0),
        o_res    => shift_res
    );
    
end architecture rtl;