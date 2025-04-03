library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.InstructionUtility.all;
    use ndsmd_riscv.DatapathUtility.all;

entity MemoryUnit is
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;

        i_decoded : in  decoded_instr_t;
        i_addr    : in  std_logic_vector(31 downto 0);
        i_data    : in  std_logic_vector(31 downto 0);
        o_res     : out std_logic_vector(31 downto 0);
        o_valid   : out std_logic;

        -- AXI-like interface to allow for easier implementation
        -- address bus for requesting an address
        o_data_awaddr : out std_logic_vector(31 downto 0);
        -- protection level of the transaction
        o_data_awprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_data_awvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_data_awready : in std_logic;

        -- write data bus
        o_data_wdata  : out std_logic_vector(31 downto 0);
        -- write data strobe
        o_data_wstrb : out std_logic_vector(3 downto 0);
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
        o_data_araddr : out std_logic_vector(31 downto 0);
        -- protection level of the transaction
        o_data_arprot : out std_logic_vector(2 downto 0);
        -- read enable signal indicating address bus request is valid
        o_data_arvalid : out std_logic;
        -- indicator that memory interface is ready to receive a request
        i_data_arready : in std_logic;

        -- returned instruction data bus
        i_data_rdata  : in std_logic_vector(31 downto 0);
        -- response indicating error occurred, if any
        i_data_rresp : in std_logic_vector(1 downto 0);
        -- valid signal indicating that instruction data is valid
        i_data_rvalid : in std_logic;
        -- ready to receive instruction data
        o_data_rready : out std_logic
    );
end entity MemoryUnit;

architecture rtl of MemoryUnit is
    type state_t is (IDLE, PERFORM_AXI_WRITE, PERFORM_AXI_READ);
    signal state : state_t := IDLE;
begin
    
    StateMachine: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                
            else
                case state is
                    when IDLE =>
                        if (i_decoded.mem_operation /= NULL_OP) then
                            -- If we're not a NULL_OP, we're doing a memory access of some kind.

                            case (i_decoded.mem_access) is
                                when BYTE_ACCESS | UBYTE_ACCESS =>
                                    -- We don't need to check the alignment of the address
                                    
                                when HALF_WORD_ACCESS | UHALF_WORD_ACCESS | WORD_ACCESS =>
                                    -- We do need to check the alignment of the address. 
                                    -- If misaligned, we will stall and attempt two accesses.
                            
                            end case;

                        end if;

                        if (i_decoded.mem_operation = STORE) then
                            state <= PERFORM_AXI_WRITE;
                        end if;

                        if (i_decoded.mem_operation = STORE) then
                            state <= PERFORM_AXI_READ;
                        end if;
                
                    when others =>
                        
                
                end case;
            end if;
        end if;
    end process StateMachine;

    -- Integrate L1dCache here. This needs to do the following:
    -- 1. Read/Write to a BRAM in a single cycle that contains:
    --      - valid bit
    --      - dirty bit
    --      - tag
    --      - cacheline
    -- For first iteration, use a direct mapped cache. Other architectures
    -- will be evaluated later.

    -- Hot take, but could we also integrate memory mapped peripherals
    -- here? Specifically high performance ones, like timers and stuff that
    -- would otherwise have to be placed on the AXI bus?
    
end architecture rtl;