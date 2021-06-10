library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package utils is
    subtype digit is std_logic_vector(7 downto 0);
    type number is array(natural range <>) of digit;
end package;