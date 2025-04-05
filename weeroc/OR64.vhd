library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity OR64 is
  Port ( 
  data : in std_logic_vector(63 downto 0);
  result : out std_logic
  );
end OR64;

architecture Behavioral of OR64 is

begin

result <= 
    data(0) or
    data(1) or
	data(2) or
    data(3) or
	data(4) or
    data(5) or
	data(6) or
    data(7) or
	data(8) or
    data(9) or
	data(10) or
    data(11) or
	data(12) or
    data(13) or
	data(14) or
    data(15) or
	data(16) or
    data(17) or
	data(18) or
    data(19) or
	data(20) or
    data(21) or
	data(22) or
    data(23) or
	data(24) or
    data(25) or
	data(26) or
    data(27) or
	data(28) or
    data(29) or
	data(30) or
    data(31) or
	data(32) or
    data(33) or
	data(34) or
    data(35) or
	data(36) or
    data(37) or
	data(38) or
    data(39) or
	data(40) or
    data(41) or
	data(42) or
    data(43) or
	data(44) or
    data(45) or
	data(46) or
    data(47) or
	data(48) or
    data(49) or
	data(50) or
    data(51) or
	data(52) or
    data(53) or
	data(54) or
    data(55) or
	data(56) or
    data(57) or
	data(58) or
    data(59) or
	data(60) or
    data(61) or
	data(62) or
    data(63);
    
end Behavioral;
