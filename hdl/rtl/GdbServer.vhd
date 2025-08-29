library ieee;
    use ieee.numeric_std.all;
    use ieee.std_logic_1164.all;

entity GdbServer is
    port (
        i_clk    : in std_logic;
        i_resetn : in std_logic;
        
        i_rx : in std_logic;
        o_tx : out std_logic
    );
end entity GdbServer;

architecture rtl of GdbServer is
    ---------------------------------------------------------------------------------------------
    -- Should implement at least the following RSP packet
    ---------------------------------------------------------------------------------------------
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
begin
    
    -- receive packet
    -- return acknowledgement (+ if accepted, or - if checksum is wrong and needs resending)
    -- parse packet
    -- execute packet command
    -- return response
    
end architecture rtl;