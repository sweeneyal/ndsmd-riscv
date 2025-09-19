library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ndsmd_riscv;
    use ndsmd_riscv.CommonUtility.all;

package CacheUtility is
    
    type metadata_t is record
        upper_address : std_logic_vector;
        dirty         : std_logic;
        valid         : std_logic;
    end record metadata_t;

    function slv_to_metadata(s : std_logic_vector) return metadata_t;
    function metadata_to_slv(m : metadata_t) return std_logic_vector;
    
end package CacheUtility;

package body CacheUtility is
    
    function slv_to_metadata(s : std_logic_vector) return metadata_t is
        variable m : metadata_t(upper_address(s'length - 3 downto 0));
    begin
        m.upper_address := s(s'length - 3 downto 0);
        m.dirty         := s(s'length - 2);
        m.valid         := s(s'length - 1);
        return m;
    end function;

    function metadata_to_slv(m : metadata_t) return std_logic_vector is
    begin
        return m.valid & m.dirty & m.upper_address;
    end function;
    
end package body CacheUtility;