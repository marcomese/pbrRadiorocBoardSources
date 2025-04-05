library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_unsigned.all;

entity Diviseur is
	port
	(
		clock_in   : in  std_logic; --10M clock
		clk_Scurve : in  std_logic_vector(1 downto 0);
		clk_100k   : out std_logic := '0';
		clock_out  : out std_logic := '0' --Clk_Scurve
	);
end entity diviseur;

architecture rtl of diviseur is

	signal cpt, cpt100         : std_logic_vector(12 downto 0) := "0000000000000";
	signal fin_cpt, fin_cpt100 : std_logic_vector(12 downto 0) := "0000000000000";
	signal clk_in, clk_in100   : std_logic                     := '0';

begin

	with clk_Scurve select
		fin_cpt <= "1001110001000" when "00", -- 1kHz
		"0000111110100" when "01",            -- 10kHz
		"0000001100100" when "10",            -- 50kHz
		"0000000110010" when "11";            -- 100kHz
		
	fin_cpt100 <= "0000000110010";
	
	process (clock_in)
	begin
		if rising_edge(clock_in) then
			if (cpt /= fin_cpt) then
				cpt <= cpt + 1;

			else
				cpt    <= "0000000000000";
				clk_in <= not(clk_in);
			end if;
		end if;
	end process;

	process (clock_in)
	begin
		if rising_edge(clock_in) then
			if (cpt100 /= fin_cpt100) then
				cpt100 <= cpt100 + 1;
			else
				cpt100    <= "0000000000000";
				clk_in100 <= not(clk_in100);
			end if;
		end if;
	end process;

	clock_out <= clk_in;
	clk_100k  <= clk_in100;
	
end architecture;
