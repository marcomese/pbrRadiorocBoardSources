library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_pulseExtender is
end tb_pulseExtender;

architecture Behavioral of tb_pulseExtender is

component pulseExtender is
generic(
    width   : integer := 1
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

constant clkPeriodOrig : time := 10 ns;
constant clkPeriodDest : time := 40 ns;

signal clkOrig : std_logic := '1';
signal rstOrig : std_logic := '0';
signal clkDest : std_logic := '1';
signal rstDest : std_logic := '0';
signal sigOrig : std_logic_vector(2 downto 0) := (others => '0');
signal sigDest : std_logic_vector(2 downto 0) := (others => '0');

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

    wait;
end process;

clkOrig <= not clkOrig after clkPeriodOrig/2;

clkDest <= not clkDest after clkPeriodDest/2;

uut: pulseExtender
generic map(
    width   => 3
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
