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
		test_daq       : in std_logic
	);
end entity io_mux;

architecture rtl of io_mux is

	signal t_l     : std_logic_vector(64 downto 0);
	signal trigger : std_logic;

begin

	t_l     <= '0' & t;
	trigger <= t_l(to_integer(unsigned(sel_trigger)));

end architecture;
