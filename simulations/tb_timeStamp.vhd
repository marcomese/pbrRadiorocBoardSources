library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_timeStamp is
end tb_timeStamp;

architecture Behavioral of tb_timeStamp is

constant clkPeriod  : time := 5 ns;
constant clkFreq    : real := 5.0e-9;
constant coarseBase : real := 150.0e-6;

signal clk     : std_logic := '0';
signal rst     : std_logic := '1';
signal freeze  : std_logic := '0';
signal tFine   : std_logic_vector(31 downto 0);
signal tCoarse : std_logic_vector(31 downto 0);
signal tStamp  : std_logic_vector(63 downto 0);

begin

rst <= '0' after clkPeriod*5;

clk <= not clk after clkPeriod/2;

freeze <= '1' after clkPeriod*69600,
          '0' after clkPeriod*69601,
          '1' after clkPeriod*208800,
          '0' after clkPeriod*208801;

timeStampInst: entity work.timeStamp
generic map(
    clkFreq    => clkFreq,
    coarseBase => coarseBase
)
port map(
    clk     => clk,
    rst     => rst,
    freeze  => freeze,
    tFine   => tFine,
    tCoarse => tCoarse,
    tStamp  => tStamp
);

end Behavioral;