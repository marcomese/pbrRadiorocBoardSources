library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_shiftReg is
end tb_shiftReg;

architecture Behavioral of tb_shiftReg is

component shiftReg is
generic(
    direction : string;
    regLen    : integer;
    shiftLen  : integer
);
port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    load      : in  std_logic;
    shift     : in  std_logic;
    serDataIn : in  std_logic_vector(shiftLen-1 downto 0);
    parDataIn : in  std_logic_vector(regLen-1 downto 0);
    full      : out std_logic;
    last      : out std_logic;
    dataOut   : out std_logic_vector(regLen-1 downto 0)
);
end component;

constant clkPeriod  : time    := 10 ns;
constant direction  : string  := "left";
constant regLen     : integer := 32;
constant shiftLen   : integer := 8;

signal clk       : std_logic := '1';
signal rst       : std_logic := '0';
signal load      : std_logic := '0';
signal shift     : std_logic := '0';
signal serDataIn : std_logic_vector(shiftLen-1 downto 0) := (others => '0');
signal parDataIn : std_logic_vector(regLen-1 downto 0)   := (others => '0');
signal dataOut   : std_logic_vector(regLen-1 downto 0);
signal full      : std_logic;
signal last      : std_logic;

begin

stimProc: process
begin
    rst <= '1';
    wait for clkPeriod*5;
    rst <= '0';
    wait for clkPeriod*5;

    serDataIn <= x"55";
--    parDataIn <= x"ABCDEF12";
--    load   <= '1';
--    wait for clkPeriod;
--    load   <= '0';

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

    parDataIn <= x"FFEEDDCC";
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

    wait;
end process;

clk <= not clk after clkPeriod/2;

uut: shiftReg
generic map(
    direction => direction,
    regLen    => regLen,
    shiftLen  => shiftLen
)
port map(
    clk        => clk,
    rst        => rst,
    load       => load,
    shift      => shift,
    serDataIn  => serDataIn,
    parDataIn  => parDataIn,
    full       => full,
    last       => last,
    dataOut    => dataOut
);

end Behavioral;
