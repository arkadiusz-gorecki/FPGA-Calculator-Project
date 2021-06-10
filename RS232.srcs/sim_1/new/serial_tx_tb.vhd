library ieee;
use     ieee.std_logic_1164.all;
use     ieee.std_logic_unsigned.all;
use     ieee.std_logic_misc.all;
entity SERIAL_TX_TB is
  generic (
    constant F_ZEGARA      :natural := 20_000_000;		-- czestotliwosc zegara systemowego w [Hz]
    constant L_BODOW       :natural := 5_000_000;		-- predkosc nadawania w [bodach]
    constant B_SLOWA       :natural := 8;			-- liczba bitow slowa danych (5-8)
    constant B_PARZYSTOSCI :natural := 1;			-- liczba bitow parzystosci (0-1)
    constant B_STOPOW      :natural := 2;			-- liczba bitow stopu (1-2)
    constant N_TX          :boolean := FALSE;			-- negacja logiczna sygnalu szeregowego
    constant N_SLOWO       :boolean := FALSE			-- negacja logiczna slowa danych
  );
end SERIAL_TX_TB;
architecture behavioural of SERIAL_TX_TB is
  constant O_ZEGARA	:time := 1 sec/F_ZEGARA;		-- okres zegara systemowego
  constant O_BITU	:time := 1 sec/L_BODOW;			-- okres czasu trwania jednego bodu
  signal   R		:std_logic := '0';			-- symulowany sygnal resetujacacy
  signal   C		:std_logic := '1';			-- symulowany zegar taktujacy inicjowany na '1'
  signal   SLOWO	:std_logic_vector(B_SLOWA-1 downto 0) := (others=>'0'); -- symulowany wejscie 'SLOWO'
  signal   NADAJ	:std_logic := '0';			-- symulowany wejscie 'NADAJ'
  signal   WYSYLANIE	:std_logic;				-- symulowany wejscie 'WYSYLANIE'
  signal   TX		:std_logic;				-- obserwowane wyjscie 'TX'
  signal   ODEBRANO	:std_logic_vector(SLOWO'range);		-- dana oderana przez emulator odbiornika
  
begin
 process is							-- proces bezwarunkowy
  begin						-- czesc wykonawcza procesu	
    R <= '1'; wait for 100 ns;					-- ustawienie sygnalu 'R' na '1' i odczekanie 100 ns	
    R <= '0'; wait;						-- ustawienie sygnalu 'R' na '0' i zatrzymanie
  end process;							-- zakonczenie procesu
  process is							-- proces bezwarunkowy
  begin								-- czesc wykonawcza procesu
    C <= not(C); wait for O_ZEGARA/2;				-- zanegowanie sygnalu 'clk' i odczekanie pol okresu zegara
  end process;							-- zakonczenie procesu
  
  process is							-- proces bezwarunkowy
  begin								-- czesc wykonawcza procesu
    wait for 200 ns;						-- dczekanie 200 ns
    NADAJ  <= '1';						-- ustawienie sygnalu 'NADAJ' na '1'
    wait for O_ZEGARA;						-- dczekanie jeden okres zegara 'C'
    NADAJ  <= '0';						-- ustawienie sygnalu 'NADAJ' na '1';
    wait for O_ZEGARA;						-- dczekanie jeden okres zegara 'C'
    if WYSYLANIE='0' then
        SLOWO <= SLOWO + 7;						-- zwiekszenia wartosci 'SLOWO' o 7
    else
        wait until WYSYLANIE='0';	
        SLOWO <= SLOWO + 7;					-- czekanie az sygnal 'WYSYLANIE' przyjmie stan '0'
    end if;    
   end process;					-- zakonczenie procesu
  
  serial_tx_inst: entity work.SERIAL_TX(behavioural)
    generic map (
      CLOCK_F             => F_ZEGARA,				-- czestotliwosc zegata w [Hz]
      BAUDRATE              => L_BODOW,				-- predkosc odbierania w [bodach]
      DATA_L              => B_SLOWA,				-- liczba bitow slowa danych (5-8)
      PARITY_L        => B_PARZYSTOSCI,			-- liczba bitow parzystosci (0-1)
      STOP_L             => B_STOPOW,				-- liczba bitow stopu (1-2)
      NEG_TX                 => N_TX,				-- negacja logiczna sygnalu szeregowego
      NEG_DATA_PAR              => N_SLOWO				-- negacja logiczna slowa danych
    )
    port map (
      RESET                    => R,				-- sygnal resetowania
      CLOCK                    => C,				-- zegar taktujacy
      TX                   => TX,				-- wysylany sygnal szeregowy
      DATA                => SLOWO,				-- wysylane slowo danych
      SEND                => NADAJ,				-- flaga zadania nadania
      SENDING           => WYSYLANIE				-- flaga zajetosci nadajnika
   );
  process is							-- proces bezwarunkowy
    function neg(V :std_logic; N :boolean) return std_logic is	-- deklaracja funkcji wewnetrznej 'neg'
    begin							-- czesc wykonawcza funkcji wewnetrznej
      if (N=FALSE) then return (V); end if;			-- zwrot wartosc 'V' gdy 'N'=FALSE
      return (not(V));						-- zwrot zanegowanej wartosci 'V'
    end function;						-- zakonczenie funkcji wewnetrznej
    variable D    :std_logic_vector(B_SLOWA-1 downto 0);	-- deklaracja zmiennej bufora bitow
    variable blad : boolean;					-- deklaracja zmiennej flagi bledu odbioru
  begin								-- czesc wykonawcza procesu
    D := (others => '0');					-- zerowanie bufora odbioru
    loop							-- nieskonczona petla odbioru danych
      blad := FALSE;						-- skasowanie  flagi bledu
      wait until neg(TX,N_TX)='1';				-- oczekiwanie na poczatek bitu START
      wait for O_BITU/2;					-- odczekanie polowy trwania jednego bodu 
      if (neg(TX,N_TX) /= '1') then				-- zbadanie niepoprawnosci stanu bit START
        blad := TRUE;						-- dla nieporawnego stanu ustawienie flagi BLAD
      end if;							-- zakonczenie instukcji warunkowej
      wait for O_BITU;						-- odczekanie okresu jednego bodu
      for i in 0 to B_SLOWA-1 loop				-- petla po kolejnych bitach odbieranej danej
        D(D'left-1 downto 0) := D(D'left downto 1);		-- przesuniecie bufora 'D' w prawo o jedna pozycje
        D(D'left) := neg(TX,N_TX);				-- przypisanie odebranego bitu na najstarsza pozycje
        wait for O_BITU;					-- odczekanie okresu jednego bodu
      end loop;							-- zakonczenie petli
      if (B_PARZYSTOSCI = 1) then				-- badanie aktywowania bitu parzystosci
        if ((neg(TX,N_TX) = XOR_REDUCE(D)) = N_SLOWO) then	-- zbadanie niezgodnosci stanu bitu parzystaosci
          blad := TRUE;						-- dla nieporawnego stanu ustawienie flagi BLAD
        end if;							-- zakonczenie instukcji warunkowej
        wait for O_BITU;					-- odczekanie okresu jednego bodu
      end if;							-- zakonczenie instukcji warunkowej
      for i in 0 to B_STOPOW-1 loop				-- petla po liczbie bitow STOP
        if (neg(TX,N_TX) /= '0') then				-- zbadanie niepoprawnosci stanu bit STOP
          blad := TRUE;						-- dla nieporawnego stanu ustawienie flagi BLAD
        end if;							-- zakonczenie instukcji warunkowej
      end loop;							-- zakonczenie petli
      if (N_SLOWO=TRUE) then					-- zbadanie ustawienia flagi negacji danej
        D := not(D);						-- negacja odebranej danej dla usawionej flagi
      end if;							-- zakonczenie instukcji warunkowej
      ODEBRANO <= D;						-- przypisanie do wektora 'ODEBRANO' odebranej danej
      if (blad=TRUE) then					-- zbadanie ustawienia flagi bledu
        ODEBRANO <= (others => 'X');				-- ustawienie wektora 'ODEBRANO' na stan bledu
      end if;							-- zakonczenie instukcji warunkowej
    end loop;							-- zakonczenie petli
  end process;							-- zakonczenie procesu
end behavioural;