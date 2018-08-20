
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package FexAlgPkg is

  type StringArray is array(natural range<>) of string;
  type StringMatrix is array(natural range<>) of StringArray;
  
  constant FEX_ALGORITHMS : StringMatrix(3 downto 0) := (
    0 => ("RAW","THR"),
    1 => ("RAW","THR"),
    2 => ("RAW","THR"),
    3 => ("RAW","THR") );
  
end FexAlgPkg;
