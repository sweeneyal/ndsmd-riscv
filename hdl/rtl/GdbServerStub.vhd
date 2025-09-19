library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;
    use ndsmd_riscv.DebugUtility.all;

entity GdbServerStub is
    generic (
        cCheckCommandSupported : boolean := false
    );
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;
        
        i_rx_byte  : in byte_t;
        i_rx_valid : in std_logic;

        o_tx_byte  : out byte_t;
        o_tx_valid : out std_logic;

        o_debug_control : out debug_unit_control_t;
        o_debug_valid   : out std_logic;
        i_debug_status  : in debug_unit_status_t
    );
end entity GdbServerStub;

architecture rtl of GdbServerStub is
    ---------------------------------------------------------------------------------------------
    -- Should implement at least the following RSP packet
    ---------------------------------------------------------------------------------------------
    --
    -- The GDB spec requires at minimum, the following:
    --
    -- g, G. Read and write general registers.
    --
    -- m, M. Read and write memory.
    --
    -- c. Continue execution.
    --
    -- s. Single step of execution.
    --
    -- Embecosm recommends the following:
    --
    -- ?. Report why the target halted.
    --
    -- c, C, s and S. Continue or step the target (possibly with a particular signal). A minimal
    --      implementation may not support stepping or continuing with a signal.
    --
    -- D. Detach from the client.
    --
    -- g and G. Read or write general registers.
    --
    -- qC and H. Report the current thread or set the thread for subsequent operations. The
    --      significance of this will depend on whether the target supports threads.
    --
    -- k. Kill the target. The semantics of this are not clearly defined. Most targets should
    --      probably ignore it.
    --
    -- m and M. Read or write main memory.
    --
    -- p and P. Read or write a specific register.
    --
    -- qOffsets. Report the offsets to use when relocating downloaded code.
    --
    -- qSupported. Report the features supported by the RSP server. As a minimum, just the
    --      packet size can be reported. 
    --
    -- qSymbol:: (i.e. the qSymbol packet with no arguments). Request any symbol table data.
    --      A minimal implementation should request no data.
    --
    -- vCont?. Report what vCont actions are supported. A minimal implementation should
    --      return an empty packet to indicate no actions are supported.
    --
    -- X. Load binary data.
    --
    -- z and Z. Clear or set breakpoints or watchpoints.
    --
    -- !. Advise the target that extended remote debugging is being used.
    --
    -- R. Restart the program being run.
    --
    -- vAttach. Attach to a new process with a specified process ID. This packet need not be 
    --      implemented if the target has no concept of a process ID, but should return an error code.
    --
    -- vRun. Specify a new program and arguments to run. A minimal implementation may
    --      restrict this to the case where only the current program may be run again.
    ---------------------------------------------------------------------------------------------

    function ascii_to_halfbyte(a : byte_t) return std_logic_vector is
        variable ac : character;
    begin
        ac := to_char(a);
        case ac is
            when '0' =>
                return x"0";
            when '1' =>
                return x"1";
            when '2' =>
                return x"2";
            when '3' =>
                return x"3";
            when '4' =>
                return x"4";
            when '5' =>
                return x"5";
            when '6' =>
                return x"6";
            when '7' =>
                return x"7";
            when '8' =>
                return x"8";
            when '9' =>
                return x"9";
            when 'a' | 'A' =>
                return x"a";
            when 'b' | 'B' =>
                return x"b";
            when 'c' | 'C' =>
                return x"c";
            when 'd' | 'D' =>
                return x"d";
            when 'e' | 'E' =>
                return x"e";
            when others =>
                assert false report "Non-convertable ASCII character provided." severity error;
        end case;
    end function;

    constant cEmptyPacket : string := "$#00";

    type state_t is (
        IDLE, RECEIVE_PACKET, RECEIVE_CHECKSUM, 
        EVALUATE_CHECKSUM, PARSE_PACKET, SEND_EMPTY_PACKET, 
        PARSE_ADDRESS, READ_GENERAL_REGS, WRITE_GENERAL_REGS,
        PARSE_WRITE_DATA, CONTINUE_EXECUTION, STEP_EXECUTION);
    signal state : state_t := IDLE;

    type flag_t is (REG_WRITE, MEM_READ, MEM_WRITE, NULL_OP);
    signal flag : flag_t := NULL_OP;

    signal checksum : unsigned(7 downto 0) := (others => '0');
    signal rx_checksum : unsigned(7 downto 0) := (others => '0');
    signal fifo_pop : std_logic := '0';
    signal fifo_dvalid : std_logic := '0';
    signal fifo_data : std_logic_vector(7 downto 0) := (others => '0');
    signal fifo_empty : std_logic := '0';
begin
    
    -- receive packet
    -- return acknowledgement (+ if accepted, or - if checksum is wrong and needs resending)
    -- parse packet
    -- execute packet command
    -- return response

    StateMachine: process(i_clk)
        variable eidx : positive range 1 to 4 := 1;
        variable cidx : natural range 0 to 2 := 0;
    begin
        if rising_edge(i_clk) then
            if (i_resetn = '0') then
                
            else
                case state is
                    when IDLE =>
                        if (i_rx_valid = '1' and to_char(i_rx_byte) = '$') then
                            state <= RECEIVE_PACKET;
                        end if;

                    when RECEIVE_PACKET =>
                        if (i_rx_valid = '1') then
                            if (to_char(i_rx_byte) = '#') then
                                state <= RECEIVE_CHECKSUM;
                                cidx  := 0;
                            else
                                checksum <= checksum + unsigned(i_rx_byte);
                            end if;
                        end if;

                    when RECEIVE_CHECKSUM =>
                        if (i_rx_valid = '1') then
                            rx_checksum(4 * cidx + 3 downto 4 * cidx) <= unsigned(ascii_to_halfbyte(i_rx_byte));
                            cidx := cidx + 1;
                            if (cidx = 2) then
                                state <= EVALUATE_CHECKSUM;
                            end if;
                        end if;

                    when EVALUATE_CHECKSUM =>
                        o_tx_valid <= '1';
                        fifo_pop <= '0';
                        if (rx_checksum = checksum) then
                            o_tx_byte  <= to_byte('+');
                            state    <= PARSE_PACKET;
                            fifo_pop <= '1';
                        else
                            o_tx_byte <= to_byte('-');
                            state   <= IDLE;
                        end if;

                    when PARSE_PACKET =>
                        fifo_pop <= '0';
                        if (fifo_dvalid = '1') then
                            case to_char(fifo_data) is
                                when 'c' =>
                                    state <= CONTINUE_EXECUTION;
                                    -- flag  <= CONTINUE_EXECUTION;

                                when 's' =>
                                    state <= STEP_EXECUTION;
                                    -- flag  <= STEP_EXECUTION;
                                    
                                when 'g' =>
                                    state <= READ_GENERAL_REGS;

                                when 'G' =>
                                    state <= PARSE_WRITE_DATA;
                                    flag  <= REG_WRITE;

                                when 'm' =>
                                    state <= PARSE_ADDRESS;
                                    flag  <= MEM_READ;

                                when 'M' =>
                                    state <= PARSE_ADDRESS;
                                    flag  <= MEM_WRITE;
                            
                                when others =>
                                    assert cCheckCommandSupported report "Unsupported command." severity error;
                                    state <= SEND_EMPTY_PACKET;
                                    eidx  := 1;
                                    
                            end case;
                        end if;
                        
                    when SEND_EMPTY_PACKET =>
                        o_tx_byte  <= to_byte(cEmptyPacket(eidx));
                        o_tx_valid <= '1';
                        if (eidx < cEmptyPacket'length) then
                            eidx := eidx + 1;
                        else
                            state <= IDLE;
                        end if;

                    when PARSE_ADDRESS =>
                        case flag is
                            when MEM_READ =>
                                if (fifo_empty = '1') then
                                    
                                end if;
                        
                            when MEM_WRITE =>
                                
                            when others =>
                                assert false report "Unsupported flag in PARSE_ADDRESS." severity error;
                        
                        end case;
                        -- I'm betting that certain commands where the addr is omitted (c, s)
                        -- can look like 'c', 'c ', or 'c [addr]', and so we need to be able to
                        -- handle that. 

                        -- Additionally, we need to identify whether the address is even needed.
                        -- Further, make sure the address is appropriately fitted into the address
                        -- space being used, i.e. 32 bit addresses.
                        
                    when CONTINUE_EXECUTION =>
                        
                    when STEP_EXECUTION =>
                        
                    
                    when others =>
                        
                
                end case;
            end if;
        end if;
    end process StateMachine;
    
end architecture rtl;