library ieee;
use ieee.std_logic_1164.all;
use work.ucrc_pkg.all;

entity tb_crc is
end tb_crc;

architecture behav of tb_crc is

constant clkPeriod    : time := 5 ns;
constant POLYNOMIAL   : std_logic_vector(31 downto 0) := x"04C11DB7";
constant INIT_VALUE   : std_logic_vector(31 downto 0) := x"FFFFFFFF";
constant DATA_WIDTH   : integer          := 32;
signal   clk, rst     : std_logic := '1';
signal   clken        : std_logic := '0';
signal   match_p      : std_logic;
signal   par_in       : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal   crc_p        : std_logic_vector(POLYNOMIAL'length - 1 downto 0);
signal   crcXor       : std_logic_vector(POLYNOMIAL'length - 1 downto 0);

begin

crcXor <= crc_p xor x"FFFFFFFF";

MAIN : process
begin
    rst <= '1';
    wait for clkPeriod*5;
    rst <= '0';
    wait for clkPeriod*5;

    par_in <= x"abcdef12";
    wait for clkPeriod;
    clken <= '1';
    wait for clkPeriod;
    clken <= '0';
    
    wait for clkPeriod*5;

    wait;
end process;

ucrcInst: ucrc_par
generic map(
    POLYNOMIAL => POLYNOMIAL,
    INIT_VALUE => INIT_VALUE,
    DATA_WIDTH => DATA_WIDTH,
    SYNC_RESET => 1
)
port map(
    clk_i   => clk,
    rst_i   => rst,
    clken_i => clken,
    data_i  => par_in,
    match_o => match_p,
    crc_o   => crc_p
);

clk <= not clk after clkPeriod/2;

end behav;

