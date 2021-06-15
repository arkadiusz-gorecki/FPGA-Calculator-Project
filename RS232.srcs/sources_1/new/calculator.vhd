library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library work;
use work.utils.all;

entity CALCULATOR is
    generic (
        CLOCK_F      : natural := 20_000_000;
        BAUDRATE     : natural := 5_000_000;
        DATA_L       : natural := 8 ; -- (5-8) data length, how many bits
        PARITY_L     : natural := 1; -- 0 or 1, parity bits length, informs whether we should write the parity bit after data transmission
        STOP_L       : natural := 2; -- 1 or 2, stop bits length, how many ending bits after data transmission
        NEG_X       : boolean := FALSE;
        NEG_DATA_PAR : boolean := FALSE; -- if output DATA and PARITY bits are negated
        
        DISPLAY_SIZE : natural := 10
    );
    port (
        RESET : in std_logic;
        CLOCK : in std_logic;
        RX    : in std_logic;
        
        TX    : out std_logic;
        
        RX_DATA_TO_CPU    : out std_logic_vector(DATA_L-1 downto 0);
        RX_READY_TO_CPU    : out std_logic;
        CPU_RESULT_TO_TX    : out std_logic_vector(DATA_L-1 downto 0);
        CPU_SEND_TO_TX    : out std_logic
    );
end CALCULATOR;

architecture Behavioral of CALCULATOR is
    -- rx out
    signal rx_data : std_logic_vector(DATA_L-1 downto 0);
    signal rx_ready : std_logic;
    signal rx_error : std_logic;
    
    -- tx in
    signal tx_data : std_logic_vector(DATA_L-1 downto 0);
    signal tx_send : std_logic;
    
    -- tx out
    signal tx_sending : std_logic;
    
    -- cpu in
    signal compute_reset : std_logic;
    
    -- cpu out
    signal compute_result : std_logic_vector(DATA_L-1 downto 0);
    signal compute_ready : std_logic;
    
    -- calculator specific
    constant WAITTIME : natural := DATA_L + PARITY_L + STOP_L;
    
    type state is (idle, sending, waiting);
    signal current_state : state := idle;
    signal current_digit : natural range DISPLAY_SIZE - 1 downto 0 := 0;
    signal wait_time : natural := 0;
    
begin
    RX_DATA_TO_CPU <= rx_data;
        RX_READY_TO_CPU  <= rx_ready;
        CPU_RESULT_TO_TX   <= tx_data;
        CPU_SEND_TO_TX    <= tx_send;
    some_rx : entity work.SERIAL_RX
      generic map (
        CLOCK_F => CLOCK_F,
        BAUDRATE => BAUDRATE,
        DATA_L => DATA_L, -- (5-8) data length, how many bits
        PARITY_L => PARITY_L, -- 0 or 1, parity bits length, informs whether we should read the parity bit after data transmission
        STOP_L => STOP_L, -- 1 or 2, stop bits length, how many ending bits after data transmission
        NEG_RX => NEG_X, -- if input RxD signal is negated
        NEG_DATA_PAR => NEG_DATA_PAR
      )
      port map (
        RESET => RESET,
        CLOCK => CLOCK,
        RX => RX,
        
        DATA => rx_data,
        READY => rx_ready,
        ERR => rx_error
      );
    some_tx : entity work.SERIAL_TX
      generic map (
        CLOCK_F => CLOCK_F,
        BAUDRATE => BAUDRATE,
        DATA_L => DATA_L, -- (5-8) data length, how many bits
        PARITY_L => PARITY_L, -- 0 or 1, parity bits length, informs whether we should read the parity bit after data transmission
        STOP_L => STOP_L, -- 1 or 2, stop bits length, how many ending bits after data transmission
        NEG_TX => NEG_X, -- if input RxD signal is negated
        NEG_DATA_PAR => NEG_DATA_PAR
      )
      port map (
        RESET => RESET,
        CLOCK => CLOCK,
        DATA => tx_data,
        SEND => tx_send,
        
        TX => TX,
        SENDING => tx_sending
      );
    some_compute_unit: entity work.COMPUTE_UNIT
      generic map (
        CLOCK_F => CLOCK_F,
        BAUDRATE => BAUDRATE,
        DATA_L => DATA_L,
        PARITY_L => PARITY_L,
        STOP_L => STOP_L,
        DISPLAY_SIZE => DISPLAY_SIZE
      )
      port map (
        -- in
        CLOCK => CLOCK,
        RESET => compute_reset,
        DATA => rx_data,
        READY => rx_ready,
        
        -- out
--        RESULT => compute_result,
--        SEND => compute_ready
        RESULT => tx_data,
        SEND => tx_send
      );
      
--    process (RESET, CLOCK) is
--    begin
--        if (RESET = '1') then
--           -- clean tx
--           tx_data	<= (others => '0');
--           tx_send <= '0';
--           -- clean calc state
--           compute_reset <= '1';
--        elsif (rising_edge(CLOCK)) then
            
--            tx_send <= '0';
--            compute_reset <= '0'; -- TODO: ok here?
        
--            if (rx_ready = '1') then
--                -- passing arguments to cpu is automatic by mapping rx ports to cpu ports directly
--            end if;
            
--            if (compute_ready = '1') then
--                -- 
--                current_state <= sending;
--            end if;
            
--            -- state machine for sending output through TX
--            case current_state is
--                when idle =>
--                    -- do nothig
--                when sending =>
--                    -- get current digit and send it via TX
--                    if (current_digit < DISPLAY_SIZE) then
--                        tx_data <= compute_result(DISPLAY_SIZE - 1 - current_digit);
--                        tx_send <= '1';
--                        current_digit <= current_digit + 1;
--                        current_state <= waiting;
--                    else
--                        tx_send <= '0';
--                        current_digit <= 0;
--                        current_state <= idle;
--                    end if;
--                when waiting =>
--                    -- wait for TX to process current byte
--                    if (wait_time = WAITTIME) then
--                        wait_time <= 0;
--                        current_state <= sending;
--                    else
--                        wait_time <= wait_time + 1;
--                    end if;
--            end case;
--        end if;
--    end process;
       
    
end Behavioral;