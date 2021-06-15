library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.utils.all;

entity COMPUTE_UNIT is
  generic (
    constant CLOCK_F : natural := 20_000_000;
    constant BAUDRATE : natural := 5_000_000; -- liczba bitow stopu (1-2)
    constant DATA_L : natural := 8; -- (5-8) data length, how many bits
    constant PARITY_L : natural := 1; -- liczba bitow parzystosci (0-1)
    constant STOP_L : natural := 2; -- liczba bitow stopu (1-2)
    constant DISPLAY_SIZE : natural := 10 -- display size, max digit count of calculations

  );
  port (
    CLOCK : in std_logic;
    RESET : in std_logic;
    DATA : in std_logic_vector (DATA_L - 1 downto 0);
    READY : in std_logic;

    RESULT : out std_logic_vector (DATA_L - 1 downto 0);
    SEND : out std_logic
  );
end COMPUTE_UNIT;

architecture Behavioral of COMPUTE_UNIT is
  type cpu_state is (start, first_num, operand, other_num, send_result);
  constant T : natural := CLOCK_F / BAUDRATE; -- liczba taktów zegara w  czasie których jeden bit danej jest dostêpny
  constant ticks : natural := (1 + DATA_L + PARITY_L + STOP_L + 1) * T; -- jak d³ugo dana powinna byæ wystawiona do tx (+1 to bit startu)
--  constant ticks : natural := (1 + PARITY_L + STOP_L) * T; -- jak d³ugo dana powinna byæ wystawiona do tx (+1 to bit startu)
  --    constant bit_time :time := 1 sec/BAUDRATE;
  constant result_length : natural := 1; -- liczba taktów zegara w  czasie których jeden bit danej jest dostêpny
  --    constant bits_time :time := bits * bit_time;			-- okres czasu trwania jednego bodu
begin
  process (CLOCK, RESET) is
    variable input : std_logic_vector (DATA_L - 1 downto 0);
    variable digit_sum : std_logic_vector (DATA_L - 1 downto 0);
    variable carry : std_logic_vector (DATA_L - 1 downto 0) := (others => '0');
    constant zero_digit_vector : std_logic_vector (DATA_L - 1 downto 0) := "00110000";

    variable current_sum : integer;
    variable current_number : integer;
    variable is_current_number_negative : boolean := FALSE;
    variable current_operation : std_logic_vector (DATA_L - 1 downto 0);
    variable state : cpu_state := start;
    variable znak : character;
    variable cyfra : integer;
    variable ticks_count : natural; -- liczba wys³anych ju¿ bitów obecnej danej
    variable result_count : natural; -- liczba wys³anych ju¿ bitów obecnej danej
    variable is_first_bit : boolean := true;
    variable is_sum_zero : boolean := false;
    constant err_vector : std_logic_vector (DATA_L - 1 downto 0) := "XXXXXXXX";
    procedure err_and_reset is
    begin
      RESULT <= err_vector;
      SEND <= '1';
      state := start;
      current_sum := 0;
      current_number := 0;
      is_current_number_negative := FALSE;
    end procedure;
    function add_digit(number : natural; digit : std_logic_vector) return natural is -- przesuniêcie znakow liczby w prawo i dodanie cyfry
    begin
      return number * 10 + (CONV_INTEGER(digit) - character'pos('0'));
    end function;
    function kod_znaku(c : character) return std_logic_vector is -- konwersja kodu znaku do rozmiaru slowa
    begin -- cialo funkcji
      return("00000000" + character'pos(c)); -- wyznaczenia i zwrocenie wartosci slowa
    end function;
  begin
    if (RESET = '1') then
      state := start;
    elsif (rising_edge(CLOCK)) then
      if (READY = '1') then
        input := DATA;
        case state is
          when start =>
            -- reset for new data
            current_sum := 0;
            current_number := 0;
            is_current_number_negative := FALSE;

            -- handle only minus sign for first number
            if (input = 45) then -- minus sign
              is_current_number_negative := TRUE;
              state := first_num;
            elsif (47 < input and input < 58) then -- it's a digit
              current_number := add_digit(current_number, input);
              state := first_num;
            else
              err_and_reset;
            end if;
          when first_num =>
            if (input > 47 and input < 58) then -- it's a digit
              current_number := add_digit(current_number, input);
            elsif (input = 43 or input = 45 or input = 61) then -- sign + - =
              if (is_current_number_negative = TRUE) then
                current_number := current_number * (-1);
              end if;

              current_sum := current_sum + current_number;
              current_number := 0;
              current_operation := input;
              state := operand;
              if (input = 61) then
                if(current_sum = 0) then
                    is_sum_zero := true;
                end if;
                state := send_result;
              end if;
            end if;
          when operand =>
            if (input > 47 and input < 58) then -- it's a digit
              current_number := add_digit(current_number, input);
              state := other_num;
            else
              err_and_reset;
            end if;
          when other_num =>
            if (input > 47 and input < 58) then -- it's a digit
              current_number := add_digit(current_number, input);
            elsif (input = 43 or input = 45 or input = 61) then
              if current_operation = 43 then
                current_sum := current_sum + current_number;
              elsif current_operation = 45 then
                current_sum := current_sum - current_number;
              end if;
              current_number := 0;
              current_operation := input;
              state := operand;
              if (input = 61) then
                if(current_sum = 0) then
                    is_sum_zero := true;
                end if;
                state := send_result;
                --SEND <= '1';
              end if;
            else
              err_and_reset;
            end if;
          when send_result =>
        end case;
      else
        if (state = send_result) then
                  
          if (current_sum /= 0) then -- dopóki nie zredukowa³o siê do zera
            ticks_count := ticks_count + 1;
            
            if(is_first_bit) then
                is_first_bit := false;
                if current_sum < 0 then -- liczba ujemna wiêc wypisz minus
                    RESULT <= "00000000" + character'pos('-');
                    current_sum := abs(current_sum);
                else -- pierwsza cyfra
                    cyfra := current_sum mod 10;
                    current_sum := current_sum / 10;
                    RESULT <= "00000000" + character'pos('0') + cyfra;
                end if;
                SEND <= '1';
            elsif ticks_count >= ticks then
              cyfra := current_sum mod 10;
              current_sum := current_sum / 10;
              RESULT <= "00000000" + character'pos('0') + cyfra;
              SEND <= '1';
              ticks_count := 0;
              result_count := result_count + 1;
            else
              SEND <= '0';
              RESULT <= "UUUUUUUU";
            end if;
          elsif is_sum_zero then
            is_sum_zero := false;
            RESULT <= "00000000" + character'pos('0');
            SEND <= '1';
          else
            is_first_bit := true; -- zresetowanie
            result_count := 0;
            SEND <= '0';
            RESULT <= "UUUUUUUU";
            state := start;
          end if;
        end if;
      end if;
    end if;
  end process;
end Behavioral;