library IEEE;
use IEEE.STD_LOGIC_1164.all;

library work;

entity CALCULATOR is
  generic (
    CLOCK_F : natural := 20_000_000;
    BAUDRATE : natural := 5_000_000;
    DATA_L : natural := 8; -- (5-8) data length, how many bits
    PARITY_L : natural := 1; -- 0 or 1, how many parity bits
    STOP_L : natural := 2; -- 1 or 2, how many stop bits
    NEG_X : boolean := false; -- if signal is negated
    NEG_DATA_PAR : boolean := false -- if output DATA and PARITY bits are negated
  );
  port (
    RESET : in std_logic;
    CLOCK : in std_logic;
    RX : in std_logic;

    TX : out std_logic
  );
end CALCULATOR;

architecture Behavioral of CALCULATOR is
  -- from rx to compute_unit
  signal rx_data : std_logic_vector(DATA_L - 1 downto 0);
  signal rx_ready : std_logic;

  -- from compute_unit to tx
  signal tx_data : std_logic_vector(DATA_L - 1 downto 0);
  signal tx_send : std_logic;

begin
  some_rx : entity work.SERIAL_RX
    generic map(
      CLOCK_F => CLOCK_F,
      BAUDRATE => BAUDRATE,
      DATA_L => DATA_L,
      PARITY_L => PARITY_L,
      STOP_L => STOP_L,
      NEG_RX => NEG_X,
      NEG_DATA_PAR => NEG_DATA_PAR
    )
    port map(
      -- in
      RESET => RESET,
      CLOCK => CLOCK,
      RX => RX,
      -- out
      DATA => rx_data,
      READY => rx_ready
    );
  some_tx : entity work.SERIAL_TX
    generic map(
      CLOCK_F => CLOCK_F,
      BAUDRATE => BAUDRATE,
      DATA_L => DATA_L,
      PARITY_L => PARITY_L,
      STOP_L => STOP_L,
      NEG_TX => NEG_X,
      NEG_DATA_PAR => NEG_DATA_PAR
    )
    port map(
      -- in
      RESET => RESET,
      CLOCK => CLOCK,
      DATA => tx_data,
      SEND => tx_send,
      -- out
      TX => TX
    );
  some_compute_unit : entity work.COMPUTE_UNIT
    generic map(
      CLOCK_F => CLOCK_F,
      BAUDRATE => BAUDRATE,
      DATA_L => DATA_L,
      PARITY_L => PARITY_L,
      STOP_L => STOP_L
    )
    port map(
      -- in
      CLOCK => CLOCK,
      RESET => RESET,
      DATA => rx_data,
      READY => rx_ready,
      -- out
      RESULT => tx_data,
      SEND => tx_send
    );
end Behavioral;