library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity SERIAL_TX is
    generic (
        constant CLOCK_F : natural := 20_000_000;
        constant BAUDRATE : natural := 5_000_000;
        constant DATA_L : natural := 8; -- (5-8) data length, how many bits
        constant PARITY_L : natural := 1; -- 0 or 1, parity bits length, informs whether we should write the parity bit after data transmission
        constant STOP_L : natural := 2; -- 1 or 2, stop bits length, how many ending bits after data transmission
        constant NEG_TX : boolean := FALSE; -- if output TxD signal is negated
        constant NEG_DATA_PAR : boolean := FALSE -- if output DATA and PARITY bits are negated
    );
    port (
        RESET : in std_logic;
        CLOCK : in std_logic;
        DATA : in std_logic_vector (DATA_L - 1 downto 0);
        SEND : in std_logic;

        TX : out std_logic;
        SENDING : out std_logic
    );
end SERIAL_TX;

architecture Behavioural of SERIAL_TX is
    constant T : natural := CLOCK_F / BAUDRATE; -- liczba takt�w zegara w  czasie kt�rych jeden bit danej jest dost�pny
    type tx_state is (idle, send_data, parity_bit, stop_bit, ending);

begin
    process (CLOCK, RESET)
        variable bit_1_even_count : std_logic := '0'; -- czy parzysta liczba bit�w
        variable DATA_BUF : std_logic_vector (DATA_L - 1 downto 0);
        variable TX_BUF : std_logic;
        variable state : tx_state; -- obecny stan
        variable ticker : natural; -- licznik takt�w zegara
        variable data_counter : natural := 0; -- ile bit�w danej ju� wys�ano
        variable stop_count : natural := 0; -- ile bit�w stopu ju� przeczytano
        function neg(TX : std_logic) return std_logic is -- oblicza warto�c bitu po na�o�eniu wszystkich negacji
        begin
            if (NEG_TX xor NEG_DATA_PAR) = TRUE then
                return not TX;
            end if;
            return TX;
        end function;
    begin
        if (RESET = '1') then
            bit_1_even_count := '0';
            TX_BUF := '0';
            if (NEG_TX) then
                TX_BUF := '1';
            end if;
            state := idle;
            ticker := 0;
            data_counter := 0;
            stop_count := 0;
            SENDING <= '0';
        elsif rising_edge(CLOCK) then
            case state is
                when idle =>
                    TX_BUF := '0';
                    if (NEG_TX) then
                        TX_BUF := '1';
                    end if;
                    if (SEND = '1') then
                        SENDING <= '1'; -- zaczynamy transmisj�
                        TX_BUF := '1'; -- wy�lij bit startu
                        DATA_BUF := DATA;
                        if (NEG_TX) then
                            TX_BUF := '0';
                        end if;
                        state := send_data; -- zmie� stan
                    end if;
                when send_data =>
                    ticker := ticker + 1;
                    if ticker >= T then -- odczekaj a� b�dziesz m�g� wys�a� kolejny bit
                        ticker := 0;

                        if DATA_BUF(data_counter) = '1' then
                            bit_1_even_count := not bit_1_even_count;
                        end if;

                        TX_BUF := neg(DATA_BUF(data_counter));

                        data_counter := data_counter + 1;
                        if (data_counter >= DATA_L) then -- je�li wys�ali�my ju� ca�� dan� (8 bit�w)
                            data_counter := 0;
                            if (PARITY_L = 1) then -- czy wysy�amy bit parzysto�ci
                                state := parity_bit;
                            else
                                state := stop_bit;
                            end if;
                        end if;
                    end if;
                when parity_bit =>
                    ticker := ticker + 1;
                    if ticker >= T then
                        ticker := 0;

                        TX_BUF := neg(bit_1_even_count);

                        state := stop_bit;
                    end if;
                when stop_bit =>
                    ticker := ticker + 1;
                    if ticker >= T then
                        ticker := 0;

                        stop_count := stop_count + 1;
                        if (stop_count >= STOP_L) then
                            state := ending;
                            stop_count := 0;
                        end if;
                        TX_BUF := '0';
                        if (NEG_TX) then
                            TX_BUF := '1';
                        end if;
                    end if;
                when ending => -- daj ostatniemu bitu stopu si� wy�wietli� przez cztery takty
                    ticker := ticker + 1;
                    if ticker >= T then
                        ticker := 0;

                        state := idle;
                        DATA_BUF := (others => '0');
                        SENDING <= '0'; -- koniec transmisji
                        bit_1_even_count := '0';
                    end if;
            end case;

            TX <= TX_BUF;
        end if;
    end process;
end architecture Behavioural;