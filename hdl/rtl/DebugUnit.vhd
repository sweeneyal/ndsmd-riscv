library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    use ndsmd_riscv.DebugUtility.all;
    use ndsmd_riscv.InstructionUtility.all;

entity DebugUnit is
    generic (
        -- the width of of the address bus
        cMemoryUnit_AddressWidth_b  : natural := 32;
        -- the size of the cache line (aka cache block size)
        cMemoryUnit_CachelineSize_B : natural := 16
    );
    port (
        i_clk : in std_logic;
        i_resetn : in std_logic;

        i_decoded : in decoded_instr_t;
        i_valid   : in std_logic;

        i_debug_control : in debug_unit_control_t;
        i_debug_valid : in std_logic;
        o_debug_status  : out debug_unit_status_t;

        -------------------------------------------------------
        -- AXI4 LITE Debug Ports
        -------------------------------------------------------
        -- AXI-like interface to allow for easier implementation
        -- address bus for requesting an address
        o_axi_debug_awaddr : out std_logic_vector(cMemoryUnit_AddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        o_axi_debug_awprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_axi_debug_awvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_axi_debug_awready : in std_logic;

        -- write data bus
        o_axi_debug_wdata  : out std_logic_vector(8 * cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- write data strobe
        o_axi_debug_wstrb : out std_logic_vector(cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- write valid
        o_axi_debug_wvalid : out std_logic;
        -- write ready
        i_axi_debug_wready : in std_logic;

        -- response indicating error occurred, if any
        i_axi_debug_bresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that write response data is valid
        i_axi_debug_bvalid : in std_logic;
        -- ready to receive write response data
        o_axi_debug_bready : out std_logic;

        -- address bus for requesting an address
        o_axi_debug_araddr : out std_logic_vector(cMemoryUnit_AddressWidth_b - 1 downto 0);
        -- protection level of the transaction
        o_axi_debug_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_axi_debug_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_axi_debug_arready : in std_logic;

        -- returned instruction data bus
        i_axi_debug_rdata  : in std_logic_vector(8 * cMemoryUnit_CachelineSize_B - 1 downto 0);
        -- response indicating error occurred, if any
        i_axi_debug_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        i_axi_debug_rvalid : in std_logic;
        -- ready to receive instruction data
        o_axi_debug_rready : out std_logic
    );
end entity DebugUnit;

architecture rtl of DebugUnit is

begin
    
    
    
end architecture rtl;