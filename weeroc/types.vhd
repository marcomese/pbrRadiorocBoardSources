library ieee;
use ieee.std_logic_1164.all;

package types is

type logic_array_4_22 is array(3 downto 0) of std_logic_vector(21 downto 0);
type logic_array_8_12 is array(7 downto 0) of std_logic_vector(11 downto 0);
type logic_array_7_8  is array(6 downto 0) of std_logic_vector(7 downto 0);
type logic_array_4_8  is array(3 downto 0) of std_logic_vector(7 downto 0);

type ct is array(3 downto 0) of std_logic_vector(21 downto 0);
type ft is array(3 downto 0) of std_logic_vector(9 downto 0);
type usedw_t is array(3 downto 0) of std_logic_vector(5 downto 0);
type tdc_t is array(3 downto 0) of std_logic_vector(63 downto 0);
type in_t is array(3 downto 0) of std_logic_vector(31 downto 0);
type logic_array_4_6 is array (3 downto 0) of std_logic_vector(5 downto 0);

constant IDS : positive := 6;
constant DTS : natural := 64;
constant FIFO_DCS : natural := 7;
constant DLL 	: natural := 50;

type nat_array_t is array (natural range <>) of natural;                       
type id_t is array(natural range <>) of std_logic_vector(IDS-1 downto 0);

end types;