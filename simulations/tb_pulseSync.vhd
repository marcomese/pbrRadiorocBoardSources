library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_pulseSync is
end tb_pulseSync;

architecture Behavioral of tb_pulseSync is

constant clkPeriod25M  : time    := 40 ns;
constant clkPeriod100M : time    := 10 ns;
constant width         : natural := 4;

signal clkOrig         : std_logic := '1';
signal rstOrig         : std_logic := '1';
signal clkDest         : std_logic := '1';
signal rstDest         : std_logic := '1';
signal sigOrig         : std_logic_vector(width-1 downto 0) := (others => '0');
signal sigDest         : std_logic_vector(width-1 downto 0) := (others => '0');

begin

stimProc: process
begin
    wait for clkPeriod100M*5;
    rstOrig <= '0';
    rstDest <= '0';

    wait for clkPeriod100M*5;

    sigOrig(0) <= '1';
    
    wait for clkPeriod100M;
    
    sigOrig(0) <= '0';

    wait;
end process;

clkOrig <= not clkOrig after clkPeriod100M/2;

clkDest <= not clkDest after clkPeriod25M/2;

uut: entity work.pulseSync
generic map(
    width       => width
)
port map(
    clkOrig     => clkOrig,
    rstOrig     => rstOrig,
    clkDest     => clkDest,
    rstDest     => rstDest,
    sigOrig     => sigOrig,
    sigDest     => sigDest
);

end Behavioral;