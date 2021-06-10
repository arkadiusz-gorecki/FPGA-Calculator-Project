library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity SERIAL_TX is
    generic (
        CLOCK_F      : natural := 20_000_000;
        BAUDRATE     : natural := 9600;
        DATA_L       : natural := 8 ; -- (5-8) data length, how many bits
        PARITY_L     : natural := 1; -- 0 or 1, parity bits length, informs whether we should write the parity bit after data transmission
        STOP_L       : natural := 2; -- 1 or 2, stop bits length, how many ending bits after data transmission
        NEG_TX       : boolean := FALSE; -- if output TxD signal is negated
        NEG_DATA_PAR : boolean := FALSE -- if output DATA and PARITY bits are negated
    );
    port (
        RESET     : in std_logic;
        CLOCK     : in std_logic;
        DATA      : in std_logic_vector (DATA_L - 1 downto 0);
        SEND      : in std_logic;

        TX        : out std_logic;
        SENDING   : out std_logic 
    );
end SERIAL_TX;

architecture Behavioural of SERIAL_TX is
    constant T : natural := CLOCK_F / BAUDRATE; -- liczba taktów zegara w  czasie których jeden bit danej jest dostêpny
    type   tx_state is (idle, send_data, parity_bit, stop_bit, ending);

begin
    process(CLOCK, RESET)
        variable bit_1_even_count : std_logic := '0'; -- parity check
        variable TX_BUF : std_logic;
        variable state : tx_state; -- obecny stan
        variable ticker : natural; -- licznik taktów zegara
        variable data_counter : natural := 0; -- ile bitów danej ju¿ wys³ano
        variable stop_count : natural := 0; -- ile bitów stopu ju¿ przeczytano
    begin
        if (RESET = '1') then
            bit_1_even_count := '0';
            TX_BUF := '0';
            state := idle;
            ticker := 0;
            data_counter := 0;
            stop_count := 0;
        elsif rising_edge(CLOCK) then
            case state is
                when idle =>
                    TX_BUF := '0';
                    if (SEND = '1') then
                        SENDING <= '1'; -- zaczynamy transmisjê
                        TX_BUF := '1'; -- wyœlij bit startu
                        state := send_data; -- zmieñ stan
                    end if;
                when send_data =>
                    ticker := ticker + 1;
                    if ticker >= T then -- odczekaj a¿ bêdziesz móg³ wys³aæ kolejny bit
                        ticker := 0;
                        
                        if DATA(data_counter) = '1' then
                            bit_1_even_count := not bit_1_even_count;
                        end if;
                        
                        if(NEG_TX) then
                            TX_BUF :=  not DATA(data_counter);
                        else
                            TX_BUF := DATA(data_counter);
                        end if;
                        
                        data_counter := data_counter + 1;
                        if (data_counter >= DATA_L) then -- jeœli wys³aliœmy ju¿ ca³¹ dan¹ (8 bitów)
                            data_counter := 0;
                            if (PARITY_L = 1) then -- czy wysy³amy bit parzystoœci
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
                        
                        if(NEG_DATA_PAR) then
                            TX_BUF :=  not bit_1_even_count;
                        else
                            TX_BUF := bit_1_even_count;
                        end if;
                        
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
                    end if;
                when ending => -- daj ostatniemu bitu stopu siê wyœwietliæ przez cztery takty
                    ticker := ticker + 1;
                    if ticker >= T then
                        ticker := 0;
                        
                        state := idle;
                        SENDING <= '0'; -- koniec transmisji
                        bit_1_even_count := '0';
                    end if;
            end case;
            
            TX <= TX_BUF;
        end if;
    end process;
end architecture Behavioural;
