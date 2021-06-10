library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.utils.all;

entity COMPUTE_UNIT is
    generic (
        DATA_L : natural := 8; -- (5-8) data length, how many bits
        DISPLAY_SIZE : natural := 10
    );
    port (
        -- input
        RESET : in std_logic;
        DATA : in std_logic_vector (DATA_L - 1 downto 0);
        READY : in std_logic;
        
        -- output
        RESULT : out number(DISPLAY_SIZE - 1 downto 0); -- array of ascii codes
        SEND : out std_logic
    );
end COMPUTE_UNIT;

architecture Behavioral of COMPUTE_UNIT is
    signal current_sum : number(DISPLAY_SIZE - 1 downto 0); -- array of ascii charaters [0-9]
    signal current_number : number(DISPLAY_SIZE - 1 downto 0);
    signal current_number_negative : boolean := FALSE;
    signal current_sign : natural;
    type   state is (start, first_num_minus, first_num, operand, other_num_minus, other_num);
    signal current_state : state := start;
begin
    process(READY, RESET) is
        variable input : std_logic_vector (DATA_L - 1 downto 0);
    begin
        if (RESET = '1') then
            current_state <= start;
        elsif (rising_edge(READY)) then
            input := DATA;
            case current_state is
                when start =>
                    -- reset state
                    current_sum <= (others => (others => '0'));
                    current_number <= (others => (others => '0'));
                    current_number_negative <= FALSE;
                    
                    -- handle input
                    if (input = 45) then -- minus sign
                        current_number_negative <= TRUE;
                        current_state <= first_num_minus;
                    elsif (input > 47 and input < 58) then -- it's a digit
                        -- TODO: move digits to the left and add new digit
                        current_sum(current_sum'left-1 downto 0) <= current_sum(current_sum'left downto 1);
                        current_sum(0) <= input;
                        current_state <= first_num;
                    else
                        current_state <= start; -- TODO: how to handle this
                    end if;
                when first_num_minus =>
                    if (input > 47 and input < 58) then -- it's a digit
                        current_sum(current_sum'left-1 downto 0) <= current_sum(current_sum'left downto 1);
                        current_sum(0) <= input;
                        current_state <= first_num;
                    else
                        current_state <= start;
                    end if;
                when first_num =>
                    if (input > 47 and input < 58) then -- it's a digit
                        current_sum(current_sum'left-1 downto 0) <= current_sum(current_sum'left downto 1);
                        current_sum(0) <= input;
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
                        
                        RESULT <= current_sum;
                        SEND <= '1';
                        current_state <= start;
                    else
                        current_state <= start;
                    end if;
                when operand =>
                    if (input = 45) then -- minus sign
                        current_number_negative <= TRUE;
                        current_state <= other_num_minus;
                    elsif (input > 47 and input < 58) then -- it's a digit
                        current_number(current_number'left-1 downto 0) <= current_number(current_number'left downto 1);
                        current_number(0) <= input;
                        current_state <= other_num;
                    else
                        current_state <= start;
                    end if;
                when other_num_minus =>
                    if (input > 47 and input < 58) then -- it's a digit
                        current_number(current_number'left-1 downto 0) <= current_number(current_number'left downto 1);
                        current_number(0) <= input;
                        current_state <= other_num;
                    else
                        current_state <= start;
                    end if;
                 when other_num =>
                    if (input > 47 and input < 58) then -- it's a digit
                        current_number(current_number'left-1 downto 0) <= current_number(current_number'left downto 1);
                        current_number(0) <= input;
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
                        current_number <= (others => (others => '0'));
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
                        
                        RESULT <= current_sum;
                        SEND <= '1';
                        current_state <= start;
                    else
                        current_state <= start;
                    end if;
            end case;
        end if; 
    end process;


end Behavioral;

