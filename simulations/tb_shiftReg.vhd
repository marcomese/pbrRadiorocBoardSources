library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_shiftReg is
end tb_shiftReg;

architecture Behavioral of tb_shiftReg is

component shiftReg is
generic(
    direction  : string;
    dataInLen  : integer;
    dataOutLen : integer
);
port(
    clk     : in  std_logic;
    rst     : in  std_logic;
    load    : in  std_logic;
    shift   : in  std_logic;
    dataIn  : in  std_logic_vector(dataInLen-1 downto 0);
    dataOut : out std_logic_vector(dataOutLen-1 downto 0)
);
end component;

constant clkPeriod  : time    := 10 ns;
constant direction  : string  := "right";
constant dataInLen  : integer := 32;
constant dataOutLen : integer := 2;

signal clk     : std_logic := '1';
signal rst     : std_logic := '0';
signal load    : std_logic := '0';
signal shift   : std_logic := '0';
signal dataIn  : std_logic_vector(dataInLen-1 downto 0)  := (others => '0');
signal dataOut : std_logic_vector(dataOutLen-1 downto 0);

begin

stimProc: process
begin
    rst <= '1';
    wait for clkPeriod*5;
    rst <= '0';
    wait for clkPeriod*5;

    dataIn <= x"ABCDEF12";
    load   <= '1';
    wait for clkPeriod;
    load   <= '0';

    wait for clkPeriod*5;

    shift <= '1';
    wait for clkPeriod;
    shift <= '0';
    
    wait for clkPeriod*5;
    
    shift <= '1';
    wait for clkPeriod;
    shift <= '0';
    
    wait for clkPeriod*5;

    shift <= '1';
    wait for clkPeriod;
    shift <= '0';
    
    wait for clkPeriod*5;

    shift <= '1';
    wait for clkPeriod;
    shift <= '0';
    
    wait for clkPeriod*5;
    
    shift <= '1';
    wait for clkPeriod;
    shift <= '0';
    
    wait for clkPeriod*5;

    shift <= '1';
    wait for clkPeriod;
    shift <= '0';
    
    wait for clkPeriod*5;

    shift <= '1';
    wait for clkPeriod;
    shift <= '0';
    
    wait for clkPeriod*5;
    
    shift <= '1';
    wait for clkPeriod;
    shift <= '0';
    
    wait for clkPeriod*5;

    shift <= '1';
    wait for clkPeriod;
    shift <= '0';
    
    wait for clkPeriod*5;

    wait;
end process;

clk <= not clk after clkPeriod/2;

uut: shiftReg
generic map(
    direction  => direction,
    dataInLen  => dataInLen,
    dataOutLen => dataOutLen
)
port map(
    clk     => clk,
    rst     => rst,
    load    => load,
    shift   => shift,
    dataIn  => dataIn,
    dataOut => dataOut
);

end Behavioral;
