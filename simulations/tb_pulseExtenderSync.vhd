library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_pulseExtenderSync is
end tb_pulseExtenderSync;

architecture Behavioral of tb_pulseExtenderSync is

component pulseExtenderSync is
generic(
    width       : integer := 1;
    syncStages  : integer;
    clkOrigFreq : real;
    clkDestFreq : real
);
port(
    clkOrig : in  std_logic;
    rstOrig : in  std_logic;
    clkDest : in  std_logic;
    rstDest : in  std_logic;
    sigOrig : in  std_logic_vector(width-1 downto 0);
    sigDest : out std_logic_vector(width-1 downto 0)
);
end component;

constant clkPeriodOrig : time      := 10 ns;
constant clkPeriodDest : time      := 40 ns;
constant syncStages    : integer   := 2;
constant width         : integer   := 3;
constant clkOrigFreq   : real      := 100.0e6;
constant clkDestFreq   : real      := 25.0e6;

signal   clkOrig       : std_logic := '1';
signal   rstOrig       : std_logic := '0';
signal   clkDest       : std_logic := '1';
signal   rstDest       : std_logic := '0';
signal   sigOrig       : std_logic_vector(2 downto 0) := (others => '0');
signal   sigDest       : std_logic_vector(2 downto 0) := (others => '0');

begin

stimProc: process
begin
    rstOrig <= '1';
    rstDest <= '1';
    wait for clkPeriodDest*5;
    rstOrig <= '0';
    rstDest <= '0';

    wait for clkPeriodOrig*10;

    sigOrig <= "001";
    wait for clkPeriodOrig;
    sigOrig <= "000";

    wait for clkPeriodOrig*10;

    sigOrig <= "010";
    wait for clkPeriodOrig;
    sigOrig <= "000";

    wait for clkPeriodOrig*10;

    sigOrig <= "101";
    wait for clkPeriodOrig;
    sigOrig <= "000";

    wait for clkPeriodOrig*10 - 15.0 ns;

    sigOrig <= "001";
    wait for clkPeriodOrig;
    sigOrig <= "000";

    wait for clkPeriodOrig*10 + 15.0 ns;

    sigOrig <= "001";
    wait for clkPeriodOrig;
    sigOrig <= "000";

    wait for clkPeriodOrig*10 + 15.0 ns;

    sigOrig <= "001";
    wait for clkPeriodOrig;
    sigOrig <= "000";

    wait for clkPeriodOrig*10 + 15.0 ns;

    sigOrig <= "001";
    wait for clkPeriodOrig;
    sigOrig <= "000";

    wait for clkPeriodOrig*10 + 15.0 ns;

    sigOrig <= "001";
    wait for clkPeriodOrig*50;
    sigOrig <= "000";

    wait;
end process;

clkOrig <= not clkOrig after clkPeriodOrig/2;

clkDest <= not clkDest after clkPeriodDest/2;

uut: pulseExtenderSync
generic map(
    width       => width,
    syncStages  => syncStages,
    clkOrigFreq => clkOrigFreq,
    clkDestFreq => clkDestFreq
)
port map(
    clkOrig => clkOrig,
    rstOrig => rstOrig,
    clkDest => clkDest,
    rstDest => rstDest,
    sigOrig => sigOrig,
    sigDest => sigDest
);

end Behavioral;
