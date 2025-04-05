library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_unsigned.all;
use ieee.numeric_std.all;

entity io_mux is
	port
	(
		t             : in  std_logic_vector (63 downto 0);
		clk_scurves   : in  std_logic;
		NORT1         : in  std_logic;
		NORT2         : in  std_logic;
		NORTQ         : in  std_logic;
		trig_out      : in  std_logic;
		sc_outd_probe : in  std_logic;
		sel_trigger   : in  std_logic_vector(5 downto 0);
		sel           : in  std_logic_vector(17 downto 0);
		test_daq       : in std_logic;
		IO_FPGA       : out std_logic_vector(5 downto 0)
	);
end entity io_mux;

architecture rtl of io_mux is

	signal t_l     : std_logic_vector(64 downto 0);
	signal trigger : std_logic;

begin

	t_l     <= '0' & t;
	trigger <= t_l(to_integer(unsigned(sel_trigger)));

	TRIG : for I in 0 to 5 generate
		with sel(3 * I + 2 downto 3 * I) select IO_FPGA(I) <=
			trigger       	when "000",
			NORT1    		when "001",
			NORT2		 	when "010",
			NORTQ           when "011",
			clk_scurves     when "100",
			trig_out      	when "101",
			sc_outd_probe 	when "110",
			'0'             when others;
	end generate;

end architecture;
