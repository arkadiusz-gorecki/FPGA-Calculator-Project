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
        ERR : in std_logic;
        
        RESULT : out string
    );
end CALCULATOR;

architecture Behavioral of CALCULATOR is
    function ascii_to_binary (char: in character) return std_logic_vector is
    begin
    
    end;
    function binary_to_ascii (vector: in std_logic_vector) return character is
    begin
        -- return to_integer(signed(vector));
    end;
    signal current_sum : natural := 0;
    signal current_number : natural := 0;
    signal current_number_negative : boolean := FALSE;
    signal current_sign : natural;
    type   state is (start, first_num_minus, first_num, operand, other_num_minus, other_num, error);
    signal current_state : state := start;
begin
    process(READY) is
        variable input : integer;
    begin
        input := to_integer(unsigned(DATA));
        case current_state is
            when start =>
                -- reset state
                current_sum <= 0;
                current_number <= 0;
                current_number_negative <= FALSE;
                
                -- handle input
                if (input = 45) then -- minus sign
                    current_number_negative <= TRUE;
                    current_state <= first_num_minus;
                elsif (input > 47 and input < 58) then -- it's a digit
                    current_sum <= current_sum * (input - 48);
                    current_state <= first_num;
                else
                    current_state <= error; -- TODO: how to handle this
                end if;
            when first_num_minus =>
                if (input > 47 and input < 58) then -- it's a digit
                    current_sum <= current_sum * (input - 48);
                    current_state <= first_num;
                else
                    current_state <= error; -- TODO: how to handle this
                end if;
            when first_num =>
                if (input > 47 and input < 58) then -- it's a digit
                    current_sum <= current_sum * (input - 48);
                    current_state <= first_num;
                elsif (input = 42 or input = 43 or input = 45) then -- sign
                    if (current_number_negative = TRUE) then
                        current_sum <= current_sum * (-1);
                    end if;
                    current_sign <= input;
                    current_state <= operand;
                elsif (input = 61) then -- equals sign
                    if (current_number_negative = TRUE) then
                        current_sum <= current_sum * (-1);
                    end if;
                    
                    -- TODO: return result
                    current_state <= start;
                else
                    current_state <= error; -- TODO: how to handle this
                end if;
            when operand =>
                if (input = 45) then -- minus sign
                    current_number_negative <= TRUE;
                    current_state <= other_num_minus;
                elsif (input > 47 and input < 58) then -- it's a digit
                    current_number <= current_number * (input - 48);
                    current_state <= other_num;
                else
                    current_state <= error; -- TODO: how to handle this
                end if;
            when other_num_minus =>
                if (input > 47 and input < 58) then -- it's a digit
                    current_number <= current_number * (input - 48);
                    current_state <= other_num;
                else
                    current_state <= error; -- TODO: how to handle this
                end if;
             when other_num =>
                if (input > 47 and input < 58) then -- it's a digit
                    current_number <= current_number * (input - 48);
                    current_state <= other_num;
                elsif (input = 42 or input = 43 or input = 45) then -- sign
                    if (current_number_negative = TRUE) then
                        current_number <= current_number * (-1);
                    end if;
                    -- perform operation
                    if (current_sign = 42) then -- multiplication sign
                        current_sum <= current_sum * current_number;
                    elsif (current_sign = 43) then -- plus sign
                        current_sum <= current_sum + current_number;
                    elsif (current_sign = 45) then -- minus sign
                        current_sum <= current_sum - current_number;
                    end if;
                    
                    -- reset current number
                    current_number <= 0;
                    current_number_negative <= FALSE;
                    
                    current_sign <= input;
                    current_state <= operand;
                elsif (input = 61) then -- equals sign
                    if (current_number_negative = TRUE) then
                        current_number <= current_number * (-1);
                    end if;
                    
                    -- perform operation
                    if (current_sign = 42) then -- multiplication sign
                        current_sum <= current_sum * current_number;
                    elsif (current_sign = 43) then -- plus sign
                        current_sum <= current_sum + current_number;
                    elsif (current_sign = 45) then -- minus sign
                        current_sum <= current_sum - current_number;
                    end if;
                    
                    -- TODO: return result
                    current_state <= start;
                else
                    current_state <= error; -- TODO: how to handle this
                end if;
        end case;
    end process;


end Behavioral;
