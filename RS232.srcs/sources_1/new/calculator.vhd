library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity CALCULATOR is
    generic (
        DATA_L : natural := 8 -- (5-8) data length, how many bits
    );
    port (
        DATA : in std_logic_vector (DATA_L - 1 downto 0);
        READY : in std_logic;
        ERR :in std_logic_1164
    );
end CALCULATOR;

architecture Behavioral of CALCULATOR is
    function ascii_to_binary (char: in character) return std_logic_vector is
    begin
    
    end;
    function binary_to_ascii (char: in character) return std_logic_vector is
    begin
    
    end;
    signal current_sum : natural;
    type   state is (number, add, sub, mul, div);
    signal current_state : state := number;
begin
    process(READY) is
    begin
        case current_state is
        when number =>
            current_sum <= current_sum * 10 + int(DATA);
        when add =>
        
        
        when sub =>
        
        
        when mul =>
        
        when div =>
            
    end process;


end Behavioral;
