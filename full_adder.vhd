entity full_adder is
  port (
    i_bit1  : in bit;
    i_bit2  : in bit;
    i_carry : in bit;
    --
    o_sum   : out bit;
    o_carry : out bit
  );
end full_adder;


architecture rtl of full_adder is
    signal sig12 : bit;
    signal and12cin : bit;
    signal and12 : bit;
    
begin
    sig12 <= i_bit1 xor i_bit2;
    o_sum <= sig12 xor i_carry;
    
    and12cin <= sig12 and i_carry;
    and12 <= i_bit1 and i_bit2;
    o_carry <= and12cin or and12;
end rtl;