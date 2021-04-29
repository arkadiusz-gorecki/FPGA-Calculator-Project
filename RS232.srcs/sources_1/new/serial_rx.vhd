library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SERIAL_RX is
    generic (
        CLOCK_F : natural := 20_000_000;
        BAUDRATE : natural := 9600;
        DATA_L : natural := 8 ; -- (5-8) data length, how many bits
        PARITY_L : natural := 1; -- 0 or 1, parity bits length, informs whether we should read the parity bit after data transmission
        STOP_L : natural := 2; -- 1 or 2, stop bits length, how many ending bits after data transmission
        NEG_RX : boolean := FALSE; -- if input RxD signal is negated
        NEG_DATA_PAR : boolean := FALSE -- if input DATA and PARITY bits are negated
    );
    port (
        R : in std_logic;
        C : in std_logic;
        RX : in std_logic;
        DATA : out std_logic_vector (DATA_L - 1 downto 0);
        READY : out std_logic;
        ERR :out std_logic
    );
end SERIAL_RX;

architecture Behavioral of SERIAL_RX is
    signal waiting : std_logic := '1';
    signal start : std_logic := '0';
    signal read : std_logic := '0';
    signal parity : std_logic := '0';
    signal stop : std_logic := '0';
begin
    process(R, C) is
        constant T : natural := CLOCK_F / BAUDRATE; -- clock ticks per one bit availability frame
        variable currT : natural := 0; -- how many clock ticks have passed already
        variable data_read : natural := 0; -- how many Rx data bits are already read
        variable stop_read : natural := 0; -- how many stop bits are already read
        variable bit_1_count : natural := 0; -- how many '1' bits are already read (needed for parity check)
        variable RX_BUF : std_logic; -- stores RX but negated if NEG_RX set to TRUE

    begin
        if R = '1' then
            READY <= '0';
            DATA <= (others => '0');
            ERR <= '0';
            waiting <= '1';
            currT := 0;
            data_read := 0;
            stop_read := 0;
            bit_1_count := 0;
        elsif rising_edge(C) then
            RX_BUF := RX;
            if(NEG_RX = TRUE) then RX_BUF := not(RX); end if;
            
            if waiting = '1' then
                if RX_BUF = '1' then
                    -- reseting variables for the next data
                    data_read := 0;
                    stop_read := 0;
                    bit_1_count := 0;
                    waiting <= '0';
                    start <= '1';
                    READY <= '0'; -- we start to read another data so it is not ready now
                    DATA <= (others => '0');
                    ERR <= '0';
                end if;
            end if;
            if start = '1' then
                currT := currT + 1;
                -- T/2 offset so we can read bits in the middle of their frame of availability
                if currT >= T/2 then
                    currT := 0;
                    start <= '0';
                    read <= '1';
                end if;
            end if;
            if read = '1' then
                currT := currT + 1;
                if currT >= T then
                    currT := 0;
                    case NEG_DATA_PAR is
                        when FALSE =>
                            DATA(data_read) <= RX_BUF; -- write one input bit to output vector
                            if RX_BUF = '1' then bit_1_count := bit_1_count + 1; end if; -- count how many '1' bits there are (needed for parity check)  
                        when TRUE => -- same as previous but RX is negated
                            DATA(data_read) <= not(RX_BUF);
                            if RX_BUF = '0' then bit_1_count := bit_1_count + 1; end if;
                    end case;
                    
                    data_read := data_read + 1;
                    if data_read >= DATA_L then
                        read <= '0';
                        if PARITY_L /= 0 then
                            parity <= '1';
                        else
                            stop <= '1';
                        end if;                        
                    end if;     
                end if;   
            end if;
            if parity = '1' then
                currT := currT + 1;
                
                if currT >= T then
                    currT := 0;
                    case NEG_DATA_PAR is
                        when FALSE =>
                            if (RX_BUF = '0' and bit_1_count mod 2 = 1) or
                               (RX_BUF = '1' and bit_1_count mod 2 = 0) then
                               ERR <= '1';
                            end if;
                        when TRUE =>
                            if (RX_BUF = '1' and bit_1_count mod 2 = 1) or
                               (RX_BUF = '0' and bit_1_count mod 2 = 0) then
                               ERR <= '1';
                            end if;
                    end case;
                    parity <= '0';
                    stop <= '1';
                end if;  
            end if;
            if stop = '1' then
                currT := currT + 1;
                
                if currT >= T then
                    currT := 0;
                    if RX_BUF = '1' then ERR <= '1'; end if;
                    stop_read := stop_read + 1; -- how many stop bits already read
                    if stop_read >= STOP_L then
                        stop <= '0';
                        waiting <= '1';
                        READY <= '1'; -- the data is ready to be read
                    end if;     
                end if;           
            end if;
        end if;
        
    end process;
end Behavioral;
