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
begin

    process(R, C) is
        constant T : natural := CLOCK_F / BAUDRATE; -- liczba taktów zegara przypadaj¹ca na jeden bit danej (jeden bod)
        variable currT : natural := 0;
        variable curr_state : state := WAITING;
        variable data_read : natural := 0; -- how many Rx data bits already read
        variable stop_read : natural := 0;
    begin
        -- narpierw trzeba zrobiæ offset T/2 ¿eby po œrodku szczytywaæ a dopiero potem normalnie wystartowaæ z okresami co T
        case curr_state is
            when WAITING =>
                if RX = '1' then
                    curr_state := START;
                end if;
            when START =>
                currT := currT + 1;

                if currT >= T/2 then
                    curr_state := READ;
                    currT := 0;
                end if;
            when READ =>
                currT := currT + 1;

                if currT >= T then
                    DATA(data_read) <= RX;
                    data_read := data_read + 1;
                    currT := 0;
                    if data_read >= DATA_L then
                        case PARITY_L is
                            when 0 => curr_state := STOP; -- do not check parity bit
                            when 1 => curr_state := PARITY;
                        end case;                            
                    end if;     
                end if;           
            when PARITY => -- !!!niedokoñczone
                currT := currT + 1;
                if currT >= T then
                    currT := 0;
                end if;  
            when STOP =>
        end case;
                 
    end process;
end Behavioral;
