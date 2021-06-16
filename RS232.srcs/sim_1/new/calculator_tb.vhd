library ieee;
use     ieee.std_logic_1164.all;
use     ieee.std_logic_unsigned.all;
use     ieee.std_logic_arith.all;
use     ieee.std_logic_misc.all;

entity CALCULATOR_TB is
  generic (
    F_ZEGARA		:natural := 20_000_000;			-- czestotliwosc zegata w [Hz]
    L_BODOW	    	:natural := 5_000_000;			-- predkosc nadawania w [bodach]
    B_SLOWA	 	    :natural := 8;				-- liczba bitow slowa danych (5-8)
    B_PARZYSTOSCI	:natural := 1;				-- liczba bitow parzystosci (0-1)
    B_STOPOW		:natural := 2;				-- liczba bitow stopu (1-2)
    N_SERIAL		:boolean := false;			-- negacja logiczna sygnalu szeregowego
    N_SLOWO		    :boolean := false		-- negacja logiczna slowa danych
  );
end CALCULATOR_TB;

architecture behavioural of CALCULATOR_TB is

  signal   RX_DATA_TO_CPU		:std_logic_vector(B_SLOWA-1 downto 0);
--  signal   RX_READY_TO_CPU		:std_logic;
  signal   CPU_RESULT_TO_TX		:std_logic_vector(B_SLOWA-1 downto 0);
--  signal   CPU_SEND_TO_TX		:std_logic;
  signal   R		:std_logic := '0';			-- symulowany sygnal resetujacacy
  signal   C		:std_logic := '1';			-- symulowany zegar taktujacy inicjowany na '1'
  signal   RX		:std_logic;				-- symulowane wejscie 'RX'
  signal   TX		:std_logic;				-- symulowane wyjscie 'TX'
  
  constant O_ZEGARA	:time := 1 sec/F_ZEGARA;		-- okres zegara systemowego
  constant O_BITU	:time := 1 sec/L_BODOW;			-- okres czasu trwania jednego bodu

  constant ROZKAZ	:string := "6*7*8=";			-- = -321 sekwencja wysylanych znakow ASCII
  signal   WYNIK	:string(ROZKAZ'length downto 1); -- sekwencja odebranych znakow ASCII

  function neg(V :std_logic; N :boolean) return std_logic is	-- deklaracja funkcji wewnetrznej 'neg'
  begin								-- czesc wykonawcza funkcji wewnetrznej
    if (N=false) then return (V); end if;			-- zwrot wartosc 'V' gdy 'N'=FALSE
    return (not(V));						-- zwrot zanegowanej wartosci 'V'
  end function;							-- zakonczenie funkcji wewnetrznej
 
begin

 process is							-- proces bezwarunkowy
  begin								-- czesc wykonawcza procesu
    R <= '1'; wait for 100 ns;					-- ustawienie sygnalu 'res' na '1' i odczekanie 100 ns
    R <= '0'; wait;						-- ustawienie sygnalu 'res' na '0' i zatrzymanie
  end process;							-- zakonczenie procesu

  process is							-- proces bezwarunkowy
  begin								-- czesc wykonawcza procesu
    C <= not(C); wait for O_ZEGARA/2;				-- zanegowanie sygnalu 'clk' i odczekanie pol okresu zegara
  end process;							-- zakonczenie procesu
  
  process is							-- proces bezwarunkowy
    variable D :std_logic_vector(B_SLOWA-1 downto 0);		-- deklaracja zmiennej 'D' slowa nadawanego
  begin								-- czesc wykonawcza procesu
    RX <= neg('0',N_SERIAL);					-- incjalizacja sygnalu 'RX' na wartosci spoczynkowa
    wait for 200 ns;						-- odczekanie 200 ns
    for i in 1 to rozkaz'length loop				-- petla po kolenych wysylanych znakach
      wait for 10*O_BITU;					-- odczekanie zadanego czasu przerwy 
      D := CONV_STD_LOGIC_VECTOR(character'pos(rozkaz(i)),D'length); -- pobranie i konwersja 'i-tego' znaku ASCII
      RX <= neg('1',N_SERIAL);					-- ustawienie 'RX' na wartosc bitu START
      wait for O_BITU;						-- odczekanie jednego bodu
      for i in 0 to B_SLOWA-1 loop				-- petla po kolejnych bitach slowa danych 'D'
        RX <= neg(neg(D(i),N_SLOWO),N_SERIAL);			-- ustawienie 'RX' na wartosc bitu 'D(i)'
        wait for O_BITU;					-- odczekanie jednego bodu
      end loop;							-- zakonczenie petli
      if (B_PARZYSTOSCI = 1) then				-- badanie aktywowania bitu parzystosci
        RX <= neg(neg(XOR_REDUCE(D),N_SLOWO),N_SERIAL);		-- ustawienie 'RX' na wartosc bitu parzystosci	
        wait for O_BITU;					-- odczekanie jednego bodu
      end if;							-- zakonczenie instukcji warunkowej
      for i in 0 to B_STOPOW-1 loop				-- petla po liczbie bitow STOP
        RX <= neg('0',N_SERIAL);					-- ustawienie 'RX' na wartosc bitu STOP
        wait for O_BITU;					-- odczekanie jednego bodu
      end loop;							-- zakonczenie petli
    end loop;							-- zakonczenie petli
    wait;							-- zatrzymanie procesu do konca symulacji
  end process;							-- zakonczenie procesu
  
  serial_sum_inst: entity work.CALCULATOR
    generic map (
      CLOCK_F              => F_ZEGARA,				-- czestotliwosc zegata w [Hz]
      BAUDRATE             => L_BODOW,				-- predkosc odbierania w [bodach]
      DATA_L               => B_SLOWA,				-- liczba bitow slowa danych (5-8)
      PARITY_L             => B_PARZYSTOSCI,			-- liczba bitow parzystosci (0-1)
      STOP_L               => B_STOPOW,				-- liczba bitow stopu (1-2)
      NEG_X                => N_SERIAL,				-- negacja logiczna sygnalu szeregowego
      NEG_DATA_PAR         => N_SLOWO		-- liczba cyfr dziesietnych
    )                      
    port map (           
      
        RX_DATA_TO_CPU => RX_DATA_TO_CPU,
--        RX_READY_TO_CPU  => RX_READY_TO_CPU,
        CPU_RESULT_TO_TX   =>CPU_RESULT_TO_TX,
--        CPU_SEND_TO_TX    => CPU_SEND_TO_TX,  
      RESET                    => R,				-- sygnal resetowania
      CLOCK                    => C,				-- zegar taktujacy
      RX                   => RX,				-- odbierany sygnal szeregowy
      TX                   => TX				-- wysylany sygnal szeregowy
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
      wait until neg(TX,N_SERIAL)='1';				-- oczekiwanie na poczatek bitu START
      wait for O_BITU/2;					-- odczekanie polowy trwania jednego bodu 
      if (neg(TX,N_SERIAL) /= '1') then				-- zbadanie niepoprawnosci stanu bit START
        blad := TRUE;						-- dla nieporawnego stanu ustawienie flagi BLAD
      end if;							-- zakonczenie instukcji warunkowej
      wait for O_BITU;						-- odczekanie okresu jednego bodu
      for i in 0 to B_SLOWA-1 loop				-- petla po kolejnych bitach odbieranej danej
        D(D'left-1 downto 0) := D(D'left downto 1);		-- przesuniecie bufora 'D' w prawo o jedna pozycje
        D(D'left) := neg(TX,N_SERIAL);				-- przypisanie odebranego bitu na najstarsza pozycje
        wait for O_BITU;					-- odczekanie okresu jednego bodu
      end loop;							-- zakonczenie petli
      if (B_PARZYSTOSCI = 1) then				-- badanie aktywowania bitu parzystosci
        if ((neg(TX,N_SERIAL) = XOR_REDUCE(D)) = N_SLOWO) then	-- zbadanie niezgodnosci stanu bitu parzystaosci
          blad := TRUE;						-- dla nieporawnego stanu ustawienie flagi BLAD
        end if;							-- zakonczenie instukcji warunkowej
        wait for O_BITU;					-- odczekanie okresu jednego bodu
      end if;							-- zakonczenie instukcji warunkowej
      for i in 0 to B_STOPOW-1 loop				-- petla po liczbie bitow STOP
        if (neg(TX,N_SERIAL) /= '0') then			-- zbadanie niepoprawnosci stanu bit STOP
          blad := TRUE;						-- dla nieporawnego stanu ustawienie flagi BLAD
        end if;							-- zakonczenie instukcji warunkowej
      end loop;							-- zakonczenie petli
      if (N_SLOWO=TRUE) then					-- zbadanie ustawienia flagi negacji danej
        D := not(D);						-- negacja odebranej danej dla usawionej flagi
      end if;							-- zakonczenie instukcji warunkowej
      WYNIK(WYNIK'left downto 2) <= WYNIK(WYNIK'left-1 downto 1); -- przesuniecie o jedna pozycje w lewo bufora znakow
      WYNIK(1) <= character'val(CONV_INTEGER(D));		-- przypisanie odebranej wartosci jako znaku ASCII
      if (blad=TRUE) then					-- zbadanie ustawienia flagi bledu
        WYNIK(1) <= '#';					-- przypisanie odebranego znaku na '#' jako bledu
      end if;							-- zakonczenie instukcji warunkowej
    end loop;							-- zakonczenie petli
  end process;							-- zakonczenie procesu

end behavioural;
