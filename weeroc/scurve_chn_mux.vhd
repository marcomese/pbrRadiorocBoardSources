library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_unsigned.all;

entity Scurve_chn_mux is
	port
	(
		T         : in  std_logic_vector(63 downto 0);
		OR64      : in  std_logic;
		sel       : in  std_logic_vector(7 downto 0);
		CH_Scurve_o : out std_logic
	);
end Scurve_chn_mux;

architecture rtl of Scurve_chn_mux is

signal CH_Scurve : std_logic;

begin

    CH_Scurve_o <= not CH_Scurve;
    
	demux_CH_Scurve : process (sel(7 downto 0))
	begin
		case sel(7 downto 0) is
			when "00000000" => CH_Scurve <= T(0);
			when "00000001" => CH_Scurve <= T(1);
			when "00000010" => CH_Scurve <= T(2);
			when "00000011" => CH_Scurve <= T(3);
			when "00000100" => CH_Scurve <= T(4);
			when "00000101" => CH_Scurve <= T(5);
			when "00000110" => CH_Scurve <= T(6);
			when "00000111" => CH_Scurve <= T(7);
			when "00001000" => CH_Scurve <= T(8);
			when "00001001" => CH_Scurve <= T(9);
			when "00001010" => CH_Scurve <= T(10);
			when "00001011" => CH_Scurve <= T(11);
			when "00001100" => CH_Scurve <= T(12);
			when "00001101" => CH_Scurve <= T(13);
			when "00001110" => CH_Scurve <= T(14);
			when "00001111" => CH_Scurve <= T(15);
			when "00010000" => CH_Scurve <= T(16);
			when "00010001" => CH_Scurve <= T(17);
			when "00010010" => CH_Scurve <= T(18);
			when "00010011" => CH_Scurve <= T(19);
			when "00010100" => CH_Scurve <= T(20);
			when "00010101" => CH_Scurve <= T(21);
			when "00010110" => CH_Scurve <= T(22);
			when "00010111" => CH_Scurve <= T(23);
			when "00011000" => CH_Scurve <= T(24);
			when "00011001" => CH_Scurve <= T(25);
			when "00011010" => CH_Scurve <= T(26);
			when "00011011" => CH_Scurve <= T(27);
			when "00011100" => CH_Scurve <= T(28);
			when "00011101" => CH_Scurve <= T(29);
			when "00011110" => CH_Scurve <= T(30);
			when "00011111" => CH_Scurve <= T(31);
			when "00100000" => CH_Scurve <= T(32);
			when "00100001" => CH_Scurve <= T(33);
			when "00100010" => CH_Scurve <= T(34);
			when "00100011" => CH_Scurve <= T(35);
			when "00100100" => CH_Scurve <= T(36);
			when "00100101" => CH_Scurve <= T(37);
			when "00100110" => CH_Scurve <= T(38);
			when "00100111" => CH_Scurve <= T(39);
			when "00101000" => CH_Scurve <= T(40);
			when "00101001" => CH_Scurve <= T(41);
			when "00101010" => CH_Scurve <= T(42);
			when "00101011" => CH_Scurve <= T(43);
			when "00101100" => CH_Scurve <= T(44);
			when "00101101" => CH_Scurve <= T(45);
			when "00101110" => CH_Scurve <= T(46);
			when "00101111" => CH_Scurve <= T(47);
			when "00110000" => CH_Scurve <= T(48);
			when "00110001" => CH_Scurve <= T(49);
			when "00110010" => CH_Scurve <= T(50);
			when "00110011" => CH_Scurve <= T(51);
			when "00110100" => CH_Scurve <= T(52);
			when "00110101" => CH_Scurve <= T(53);
			when "00110110" => CH_Scurve <= T(54);
			when "00110111" => CH_Scurve <= T(55);
			when "00111000" => CH_Scurve <= T(56);
			when "00111001" => CH_Scurve <= T(57);
			when "00111010" => CH_Scurve <= T(58);
			when "00111011" => CH_Scurve <= T(59);
			when "00111100" => CH_Scurve <= T(60);
			when "00111101" => CH_Scurve <= T(61);
			when "00111110" => CH_Scurve <= T(62);
			when "00111111" => CH_Scurve <= T(63);
			when "01000000" => CH_Scurve <= OR64;

			when others => CH_Scurve <= OR64;
		end case;
	end process;

end rtl;
