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

entity MExtension is
    port (
        i_clk : in std_logic;
        i_resetn : in std_logic;

        i_decoded : in decoded_instr_t;
        i_valid   : in std_logic;
        i_opA     : in std_logic_vector(31 downto 0);
        i_opB     : in std_logic_vector(31 downto 0);

        o_res : out std_logic_vector(31 downto 0);
        o_valid : out std_logic
    );
end entity MExtension;

architecture rtl of MExtension is
    signal valid_enum : std_logic := '0';
    signal upper_enum : std_logic := '0';
    signal unsigned_enum : std_logic_vector(1 downto 0) := "00";
    signal signed_enum : std_logic := '0';

    signal mul_valid : std_logic := '0';
    signal div_valid : std_logic := '0';
    signal mul_res   : std_logic_vector(31 downto 0) := (others => '0');
    signal div_res   : std_logic_vector(31 downto 0) := (others => '0');
    signal rem_res   : std_logic_vector(31 downto 0) := (others => '0');
begin
    
    eMultiplier : entity ndsmd_riscv.MultiplierUnit
    port map (
        i_clk    => i_clk,
        i_resetn => i_resetn,

        i_valid    => valid_enum,
        i_upper    => upper_enum,
        i_unsigned => unsigned_enum,
        i_opA      => i_opA,
        i_opB      => i_opB,

        o_res => mul_res,
        o_valid => mul_valid
    );

    upper_enum    <= bool2bit(i_decoded.operation = MULTIPLY_UPPER 
        or i_decoded.operation = MULTIPLY_UPPER_SU 
        or i_decoded.operation = MULTIPLY_UPPER_UNS);
    unsigned_enum <= bool2bit(i_decoded.operation = MULTIPLY_UPPER_UNS) 
        & bool2bit(i_decoded.operation = MULTIPLY_UPPER_UNS 
            or i_decoded.operation = MULTIPLY_UPPER_SU);

    valid_enum  <= bool2bit(i_decoded.unit = MEXT) and i_valid;
    signed_enum <= bool2bit(i_decoded.operation = DIVIDE or i_decoded.operation = REMAINDER);

    eDivider : entity ndsmd_riscv.DivisionUnit
    port map (
        i_clk    => i_clk,
        i_en     => valid_enum,
        i_signed => signed_enum,
        i_num    => i_opA,
        i_denom  => i_opB,
        o_div    => div_res,
        o_rem    => rem_res,
        o_error  => open, -- Error is not used, division is supposed to check its inputs
        o_valid  => div_valid
    );

    ResultMux: process(i_decoded, mul_res, div_res, rem_res)
    begin
        if (i_decoded.operation = DIVIDE or i_decoded.operation = DIVIDE_UNS) then
            o_res <= div_res;
        elsif (i_decoded.operation = REMAINDER or i_decoded.operation = REMAINDER_UNS) then
            o_res <= rem_res;
        else
            o_res <= mul_res;
        end if;
    end process ResultMux;

    o_valid <= div_valid or mul_valid;
    
end architecture rtl;