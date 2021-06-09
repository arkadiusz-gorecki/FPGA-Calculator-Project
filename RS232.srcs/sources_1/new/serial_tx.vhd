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
        STOP_L       : natural := 1; -- 1 or 2, stop bits length, how many ending bits after data transmission
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
    constant T : natural := CLOCK_F / BAUDRATE; -- clock ticks per one bit availability frame
    type   tx_state is (idle, reset_state,start_bit, send_data, parity_bit, stop_bit);
    signal current_state, next_state : tx_state := idle;
    signal data_counter              : std_logic_vector(2 downto 0) := (others => '0');
    signal ticker                    : std_logic_vector(3 downto 0) := (others => '0');
begin
    process(CLOCK, RESET)
--        variable stop_bits_count : natural := 0; -- do zliczania ile już bitów stopu odczytaliśmy
    begin
        if (RESET = '1') then
            ticker <= (others => '0');
            current_state <= reset_state;
            data_counter <= (others => '0');
        elsif rising_edge(CLOCK) then
            if (ticker >= T or (current_state = idle and next_state = idle)) then
                ticker        <= (others => '0');
                current_state <= next_state;
                if (current_state = send_data) then
                    data_counter <= data_counter + 1;
                else
                    data_counter <= (others => '0');
                end if;
            else
                current_state <= next_state;
                ticker <= ticker + 1;
            end if;
        end if;
    end process;

    process (current_state, SEND, data_counter)
        variable bit_1_count : std_logic := '0'; -- parity check
        variable TX_BUF : std_logic;
        variable stop_l : natural := 0;
    begin
        case current_state is
            when reset_state =>
                SENDING <= '0';
                TX <= '1';

                next_state <= idle;
            when idle =>
                SENDING <= '0';
                TX <= '1';

                if (SEND = '1') then
                    next_state <= start_bit;
                else
                    next_state <= idle;
                end if;
            when start_bit =>
                SENDING <= '1';
                TX <= '0';

                next_state <= send_data;
            when send_data =>
                SENDING <= '1';
                if(NEG_TX = TRUE) then
                    TX <= not DATA(conv_integer(data_counter));
                else
                    TX <= DATA(conv_integer(data_counter));
                end if;


                if DATA(conv_integer(data_counter)) = '1' then
                    bit_1_count := not bit_1_count;
                end if;

                if (data_counter = DATA_L - 1) then
                    if (PARITY_L = 1) then
                        next_state <= parity_bit;
                    else -- To jest nieosiągalny kod
                        next_state <= stop_bit;
                    end if;
                else
                    next_state <= send_data;
                end if;
            when parity_bit =>
                if (bit_1_count = '1') then
                    TX_BUF := '1';
                else
                    TX_BUF := '0';
                end if;

                if (NEG_DATA_PAR = TRUE) then
                    TX_BUF := not TX_BUF;
                end if;

                TX <= TX_BUF;
                next_state <= stop_bit;
            when stop_bit =>
                SENDING <= '1';
                TX <= '1';
                stop_l := stop_l + 1;

                if (stop_l = STOP_L) then
                    next_state <= idle;
                    stop_l := 0;
                else
                    next_state <= stop_bit;
                end if;
            when others =>
                SENDING <= '0';
                TX <= '1';

                next_state <= reset_state;
        end case;
    end process;
end architecture Behavioural;
