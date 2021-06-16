library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
entity COMPUTE_UNIT_TB is
  generic (
    constant F_ZEGARA : natural := 20_000_000; -- czestotliwosc zegata w [Hz]
    constant L_BODOW : natural := 5_000_000; -- predkosc nadawania w [bodach]
    constant DATA_L : natural := 8; -- (5-8) data length, how many bits
    constant B_PARZYSTOSCI : natural := 1; -- liczba bitow parzystosci (0-1)
    constant B_STOPOW : natural := 2 -- liczba bitow stopu (1-2)
  );
end COMPUTE_UNIT_TB;

architecture behavioural of COMPUTE_UNIT_TB is
  signal R : std_logic := '0'; -- symulowany sygnal resetujacacy
  signal C : std_logic := '1'; -- symulowany zegar taktujacy inicjowany na '1'

  constant O_ZEGARA : time := 1 sec/F_ZEGARA; -- okres zegara systemowego
  constant O_BITU : time := 1 sec/L_BODOW; -- okres czasu trwania jednego bodu

  constant bits_time : time := (1 + DATA_L + B_PARZYSTOSCI + B_STOPOW) * O_BITU; -- jak d�ugo dana powinna by� wystawiona do TX (+1 to bit startu)
  constant ROZKAZ_1 : string := "111+22+3="; -- sekwencja wysylanych znakow ASCII
  constant ROZKAZ_2 : string := "-55+40=";
  constant ROZKAZ_3 : string := "-1-2-3=";
  constant ROZKAZ_4 : string := "0=";

  signal DATA : std_logic_vector (DATA_L - 1 downto 0);
  signal READY : std_logic := '0'; -- czytaj rozkaz

  signal RESULT : std_logic_vector (DATA_L - 1 downto 0);
  signal SEND : std_logic := '0'; -- wyslij wynik
begin
  process is -- proces bezwarunkowy
  begin -- czesc wykonawcza procesu
    R <= '1';
    wait for 100 ns; -- ustawienie sygnalu 'res' na '1' i odczekanie 100 ns
    R <= '0';
    wait; -- ustawienie sygnalu 'res' na '0' i zatrzymanie
  end process; -- zakonczenie procesu
  process is -- proces bezwarunkowy
  begin -- czesc wykonawcza procesu
    C <= not(C);
    wait for O_ZEGARA/2; -- zanegowanie sygnalu 'clk' i odczekanie pol okresu zegara
  end process; -- zakonczenie procesu

  process is
  begin
    wait for 150 ns;
    for i in 1 to ROZKAZ_1'length loop
      READY <= '1';
      DATA <= CONV_STD_LOGIC_VECTOR(character'pos(ROZKAZ_1(i)), DATA_L);
      wait for O_ZEGARA;
      READY <= '0';
      DATA <= "00000000";
      wait for O_BITU - O_ZEGARA;
    end loop;
    wait for 3 * bits_time;
    for i in 1 to ROZKAZ_2'length loop
      READY <= '1';
      DATA <= CONV_STD_LOGIC_VECTOR(character'pos(ROZKAZ_2(i)), DATA_L);
      wait for O_ZEGARA;
      READY <= '0';
      DATA <= "00000000";
      wait for O_BITU - O_ZEGARA;
    end loop;
    wait for 3 * bits_time;
    for i in 1 to ROZKAZ_3'length loop
      READY <= '1';
      DATA <= CONV_STD_LOGIC_VECTOR(character'pos(ROZKAZ_3(i)), DATA_L);
      wait for O_ZEGARA;
      READY <= '0';
      DATA <= "00000000";
      wait for O_BITU - O_ZEGARA;
    end loop;
    wait for 2 * bits_time;
    for i in 1 to ROZKAZ_4'length loop
      READY <= '1';
      DATA <= CONV_STD_LOGIC_VECTOR(character'pos(ROZKAZ_4(i)), DATA_L);
      wait for O_ZEGARA;
      READY <= '0';
      DATA <= "00000000";
      wait for O_BITU - O_ZEGARA;
    end loop;
    wait;
  end process;

  cpu : entity work.COMPUTE_UNIT(behavioral)
    generic map(
      CLOCK_F => F_ZEGARA,
      BAUDRATE => L_BODOW,
      DATA_L => DATA_L,
      PARITY_L => B_PARZYSTOSCI,
      STOP_L => B_STOPOW
    )
    port map(
      CLOCK => C,
      RESET => R,
      DATA => DATA,
      READY => READY,
      RESULT => RESULT,
      SEND => SEND
    );

end behavioural;