library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity COMPUTE_UNIT is
  generic (
    constant CLOCK_F : natural := 20_000_000;
    constant BAUDRATE : natural := 5_000_000;
    constant DATA_L : natural := 8; -- liczba bitow jednej danej
    constant PARITY_L : natural := 1; -- liczba bitow parzystosci (0-1)
    constant STOP_L : natural := 2 -- liczba bitow stopu (1-2)
  );
  port (
    CLOCK : in std_logic;
    RESET : in std_logic;
    DATA : in std_logic_vector (DATA_L - 1 downto 0); -- dana wejsciowa (cyfra, operacja)
    READY : in std_logic; -- informacja od RX zeby odebrac jedna dana

    RESULT : out std_logic_vector (DATA_L - 1 downto 0); -- dana wyjsciowa, wynik obliczenia
    SEND : out std_logic -- informacja dla TX zeby odebrac wynik
  );
end COMPUTE_UNIT;

architecture Behavioral of COMPUTE_UNIT is
  type cpu_state is (start, first_num, operand, other_num, send_result);
  constant T : natural := CLOCK_F / BAUDRATE; -- liczba taktww zegara w czasie ktwrych jeden bit danej jest dostepny
  constant ticks : natural := (1 + DATA_L + PARITY_L + STOP_L + 1) * T; -- jak dlugo dana powinna byc wystawiona do TX (+1 bit startu, +1 przerwa)
begin
  process (CLOCK, RESET) is
    variable input : std_logic_vector (DATA_L - 1 downto 0); -- bufor na dana wejsciowa (cyfra, operacja)

    variable current_sum : integer;
    variable is_sum_zero : boolean := false; -- czy suma jest rowna 0
    variable current_number : integer;
    variable is_first_number_negative : boolean := false;
    variable current_operation : std_logic_vector (DATA_L - 1 downto 0);
    variable state : cpu_state := start;
    variable cyfra : integer;
    variable ticks_count : natural; -- liczba wyslanych juz bitow jednej cyfry wyniku do TX
    variable result_count : natural; -- liczba wyslanych juz cyfr wyniku do TX
    variable is_first_bit : boolean := true; 
    variable digits_count : integer := 1;
    variable sum_copy : integer;
    constant ERR_VECTOR : std_logic_vector (DATA_L - 1 downto 0) := (others => 'X');
    constant ZEROS_VECTOR : std_logic_vector (DATA_L - 1 downto 0) := (others => '0');
    procedure err_and_reset is -- daj blad na sygnal i zresetuj komponent
    begin
      RESULT <= ERR_VECTOR;
      SEND <= '1';
      state := start;
      current_sum := 0;
      current_number := 0;
      is_first_number_negative := false;
        ticks_count := 0;
        is_sum_zero := false;
      digits_count := 1;
    end procedure;
    function add_digit(number : natural; digit : std_logic_vector) return natural is -- przesuniecie znakow liczby w prawo i dodanie cyfry
    begin
      return number * 10 + (CONV_INTEGER(digit) - character'pos('0'));
    end function;
    function char_to_binary(c : character) return std_logic_vector is -- konwersja znaku do binarnej reprezentacji kodu ASCII
    begin
      return(ZEROS_VECTOR + character'pos(c));
    end function;
    function count_digits(number: integer) return integer is -- ile jest cyfr w liczbie
        variable digits_count : integer := 1;
        variable num_copy: integer;
    begin
        num_copy := number / 10;
        while (num_copy > 0) loop
            digits_count := digits_count * 10;
            num_copy := num_copy / 10;
        end loop;
        return digits_count;
    end function;
  begin
    if (RESET = '1') then
      state := start;
        current_sum := 0;
        current_number := 0;
        is_first_number_negative := false;
        ticks_count := 0;
        is_sum_zero := false;
        digits_count := 1;
    elsif (rising_edge(CLOCK)) then
      if (READY = '1') then
        input := DATA;
        case state is
          when start =>
            -- reset dla nowej danej
            current_sum := 0;
            current_number := 0;
            is_first_number_negative := false;

            if (input = 45) then -- znak minus
              is_first_number_negative := true;
              state := first_num;
            elsif (47 < input and input < 58) then -- jesli cyfra
              current_number := add_digit(current_number, input);
              state := first_num;
            else
              err_and_reset;
            end if;
          when first_num =>
            if (input > 47 and input < 58) then -- jezeli cyfra
              current_number := add_digit(current_number, input);
            elsif (input = 43 or input = 45 or input = 61 or input = 42) then -- znaki + - = *
              if (is_first_number_negative = true) then
                current_number := current_number * (-1);
              end if;

              current_sum := current_sum + current_number;
              current_number := 0;
              current_operation := input; -- zapamietaj operacje na przyszlosc
              state := operand;
              if (input = 61) then
                if(current_sum = 0) then
                    is_sum_zero := true;
                end if;
                state := send_result;
              end if;
            end if;
          when operand =>
            if (input > 47 and input < 58) then -- jezeli cyfra
              current_number := add_digit(current_number, input);
              state := other_num;
            else
              err_and_reset;
            end if;
          when other_num =>
            if (input > 47 and input < 58) then -- jezeli cyfra
              current_number := add_digit(current_number, input);
            elsif (input = 43 or input = 45 or input = 61 or input = 42) then -- znaki + - = *
              if current_operation = 43 then -- dodawanie do sumy
                current_sum := current_sum + current_number;
              elsif current_operation = 45 then -- odejmowanie od sumy
                current_sum := current_sum - current_number;
              elsif current_operation = 42 then -- mnozenie
                current_sum := current_sum * current_number;
              end if;
              current_number := 0;
              current_operation := input; -- zapamietaj operacje na przyszlosc
              state := operand;
              if (input = 61) then -- znak =
                if(current_sum = 0) then
                    is_sum_zero := true;
                end if;
                state := send_result;
              end if;
            else
              err_and_reset;
            end if;
          when send_result =>
        end case;
      else
        if (state = send_result) then
                  
          if (digits_count /= 0) then -- dopoki nie zredukowalo sie do zera
            ticks_count := ticks_count + 1;
            
            if(is_first_bit) then -- pierwsza cyfra (lub znak minus) wyniku
                is_first_bit := false;
                if current_sum < 0 then -- liczba ujemna wiec wypisz minus
                    RESULT <= ZEROS_VECTOR + character'pos('-');
                    current_sum := abs(current_sum);
                    digits_count := count_digits(current_sum);
                else -- pierwsza cyfra
                    digits_count := count_digits(current_sum);
                    cyfra := current_sum / digits_count; -- nastepna cyfra wyniku
                    current_sum := current_sum - (cyfra * digits_count);
                    digits_count := digits_count / 10;
              RESULT <= ZEROS_VECTOR + character'pos('0') + cyfra;
                end if;
                SEND <= '1';
            elsif ticks_count >= ticks then -- odliczaj takty zegara
              cyfra := current_sum / digits_count; -- nastepna cyfra wyniku
              current_sum := current_sum - (cyfra * digits_count);
              digits_count := digits_count / 10;
              RESULT <= ZEROS_VECTOR + character'pos('0') + cyfra;
              SEND <= '1';
              ticks_count := 0;
              result_count := result_count + 1;
            else
              SEND <= '0';
              RESULT <= "UUUUUUUU";
            end if;
          elsif is_sum_zero then
            is_sum_zero := false;
            RESULT <= ZEROS_VECTOR + character'pos('0');
            SEND <= '1';
          else
            is_first_bit := true;
            result_count := 0;
            SEND <= '0';
            RESULT <= "UUUUUUUU";
            state := start;
            digits_count := 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end Behavioral;