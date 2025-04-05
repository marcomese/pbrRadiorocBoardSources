library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_SPIMaster is
end tb_SPIMaster;

architecture Behavioral of tb_SPIMaster is

component SPIMaster is
generic(
    clkFreq      : real;
    sclkFreq     : real
);
port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    data_out     : out std_logic_vector(7 downto 0);
    data_in      : in  std_logic_vector(7 downto 0);
    rx_read      : in  std_logic;
    rx_present   : out std_logic;
    rx_half_full : out std_logic;
    rx_full      : out std_logic;
    tx_write     : in  std_logic;
    tx_present   : out std_logic;
    tx_half_full : out std_logic;
    tx_full      : out std_logic;
    rx_reset     : in  std_logic;
    tx_reset     : in  std_logic;
    cs           : out std_logic;
    sclk         : out std_logic;
    miso         : in  std_logic;
    mosi         : out std_logic
);
end component;

constant clkPeriod    : time := 10 ns;
constant sclkPeriod   : time := 80 ns;
constant clkFreq      : real := 100.0e6;
constant sclkFreq     : real := 12.5e6;

signal   clk          : std_logic := '1';
signal   rst          : std_logic := '1';
signal   data_out     : std_logic_vector(7 downto 0) := (others => '0');
signal   data_in      : std_logic_vector(7 downto 0) := (others => '0');
signal   rx_read      : std_logic := '0';
signal   rx_present   : std_logic := '0';
signal   rx_half_full : std_logic := '0';
signal   rx_full      : std_logic := '0';
signal   tx_write     : std_logic := '0';
signal   tx_present   : std_logic := '0';
signal   tx_half_full : std_logic := '0';
signal   tx_full      : std_logic := '0';
signal   rx_reset     : std_logic := '0';
signal   tx_reset     : std_logic := '0';
signal   cs           : std_logic := '1';
signal   sclk         : std_logic := '1';
signal   miso         : std_logic := '0';
signal   mosi         : std_logic := '0';

begin

stimProc: process
begin
    rst <= '1';
    wait for clkPeriod*5;
    rst <= '0';
    wait for clkPeriod;

    data_in  <= x"AB";
    tx_write <= '1';
    wait for clkPeriod;
    tx_write <= '0';
    wait for clkPeriod;
    data_in  <= x"CD";
    tx_write <= '1';
    wait for clkPeriod;
    tx_write <= '0';
    data_in  <= x"EF";
    tx_write <= '1';
    wait for clkPeriod;
    tx_write <= '0';

    wait until sclk = '0';
    
    miso <= '1';
    
    wait for sclkPeriod*2;
    
    miso <= '0';
    
    wait for sclkPeriod*4;
    
    miso <= '1';
    
    wait for sclkPeriod*2;
    
    miso <= '1';

    wait for sclkPeriod;
    
    miso <= '0';
    
    wait for sclkPeriod*2;
    
    miso <= '0';
    
    wait for sclkPeriod*4;
    
    miso <= '1';
    
    wait for sclkPeriod*2;
    
    miso <= '1';

    wait for sclkPeriod;
    
    miso <= '0';

    wait for sclkPeriod*10;
    
    rx_read <= '1';
    wait for clkPeriod;
    rx_read <= '0';
    wait for sclkPeriod*5;
    rx_read <= '1';
    wait for clkPeriod;
    rx_read <= '0';
    wait for sclkPeriod*5;
    rx_read <= '1';
    wait for clkPeriod;
    rx_read <= '0';
    wait for sclkPeriod*5;
    rx_read <= '1';
    wait for clkPeriod;
    rx_read <= '0';
    wait for sclkPeriod*5;
    rx_read <= '1';
    wait for clkPeriod;
    rx_read <= '0';
    wait for sclkPeriod*5;
    rx_read <= '1';
    wait for clkPeriod;
    rx_read <= '0';
    wait for sclkPeriod*5;
    rx_read <= '1';
    wait for clkPeriod;
    rx_read <= '0';

    wait;
end process;

clk <= not clk after clkPeriod/2;

uut: SPIMaster
generic map(
    clkFreq      => clkFreq,
    sclkFreq     => sclkFreq
)
port map(
    clk          => clk,
    rst          => rst,
    data_out     => data_out,
    data_in      => data_in,
    rx_read      => rx_read,
    rx_present   => rx_present,
    rx_half_full => rx_half_full,
    rx_full      => rx_full,
    tx_write     => tx_write,
    tx_present   => tx_present,
    tx_half_full => tx_half_full,
    tx_full      => tx_full,
    rx_reset     => rst,
    tx_reset     => rst,
    cs           => cs,
    sclk         => sclk,
    miso         => miso,
    mosi         => mosi
);

end Behavioral;
