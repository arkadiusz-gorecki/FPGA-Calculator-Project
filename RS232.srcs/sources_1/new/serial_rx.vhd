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
        BAUDRATE : natural := 5_000_000;
        DATA_L : natural; -- (5-8) data length, how many bits
        PARITY_L : natural; -- 0 or 1, parity bits length, informs whether we should read the parity bit after data transmission
        STOP_L : natural; -- 1 or 2, stop bits length, how many ending bits after data transmission
        N_RX : boolean;
        N_SLOWO : boolean
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
    type state is (WAITING, START, READ, PARITY, STOP);
    function reset_vector return std_logic_vector is
        variable vector: std_logic_vector (DATA_L - 1 downto 0);
    begin
        return vector;
    end;
begin
    process(R, C) is
        constant T : natural := CLOCK_F / BAUDRATE; -- clock ticks per one bit availability frame
        variable currT : natural := 0; -- how many clock ticks have passed already
        variable curr_state : state := WAITING;
        variable data_read : natural := 0; -- how many Rx data bits are already read
        variable stop_read : natural := 0; -- how many stop bits are already read
        variable bit_1_count : natural := 0; -- how many '1' bits are already read (needed for parity check)
    begin
        if C'event and C = '1' then
            case curr_state is
                when WAITING =>
                    if RX = '1' then
                        curr_state := START;
                        READY <= '0'; -- we start to read another data so it is not ready now
                        DATA <= reset_vector; -- set to "UUUUUUUU"
                        ERR <= '0';
                    end if;
                when START =>
                    currT := currT + 1;
                    -- T/2 offset so we can read bits in the middle of their frame of availability
                    if currT >= T/2 then
                        currT := 0;
                        curr_state := READ;
                    end if;
                when READ =>
                    currT := currT + 1;
    
                    if currT >= T then
                        currT := 0;
                        DATA(data_read) <= RX; -- write one input bit to output vector
                        if RX = '1' then bit_1_count := bit_1_count + 1; end if; -- count how many '1' bits there are (needed for parity check)
                        data_read := data_read + 1;
                        if data_read >= DATA_L then
                            case PARITY_L is
                                when 0 => curr_state := STOP; -- skip PARITY state
                                when 1 => curr_state := PARITY;
                                when others => curr_state := PARITY; -- ignore higher than 1
                            end case;                            
                        end if;     
                    end if;           
                when PARITY =>
                    currT := currT + 1;
                    
                    if currT >= T then
                        currT := 0;
                        if (RX = '0' and bit_1_count mod 2 = 1) or
                           (RX = '1' and bit_1_count mod 2 = 0) then
                           ERR <= '1';
                        end if;
                        curr_state := STOP;
                    end if;  
                when STOP =>
                    currT := currT + 1;
                    
                    if currT >= T then
                        currT := 0;
                        if RX = '1' then ERR <= '1'; end if;
                        stop_read := stop_read + 1; -- how many stop bits already read
                        if stop_read >= STOP_L then
                            curr_state := WAITING;
                            READY <= '1'; -- the data is ready to be read
                            
                            -- reseting variables for the next data
                            data_read := 0;
                            stop_read := 0;
                            bit_1_count := 0;
                        end if;     
                    end if;           
            end case;
        end if;
        
    end process;
end Behavioral;
