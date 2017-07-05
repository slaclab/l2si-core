
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package FexAlgPkg is

  type StringArray is array(natural range<>) of string;
  type StringMatrix is array(natural range<>) of StringArray;
  
  constant FEX_ALGORITHMS : StringMatrix(3 downto 0) := (
    0 => ("RAW","RAW"),
    1 => ("RAW","RAW"),
    2 => ("RAW","RAW"),
    3 => ("RAW","RAW") );
  
end FexAlgPkg;
