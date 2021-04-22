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
        F_ZEGARA : natural; -- czêstotliwoœc próbkowania
        L_BODOW : natural; -- liczba bodów/baud rate?
        B_SLOWA : natural; -- d³ugoœc s³owa?
        B_PARZYSTOSCI : natural;
        B_STOPOW : natural;
        N_RX : boolean;
        N_SLOWO : boolean
    );
    port (
        R : in std_logic;
        C : in std_logic;
        RX : in std_logic;
        SLOWO : out std_logic_vector (B_SLOWA - 1 downto 0);
        GOTOWE : out std_logic;
        BLAD :out std_logic
    );
end SERIAL_RX;

architecture Behavioral of SERIAL_RX is

begin


end Behavioral;
