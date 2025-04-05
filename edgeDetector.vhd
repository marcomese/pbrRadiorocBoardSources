library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity edgeDetector is
generic(
    clockEdge : string;
    edge      : string
);
port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    signalIn  : in  std_logic;
    signalOut : out std_logic
);
end edgeDetector;

architecture Behavioral of edgeDetector is

signal ff1,
       ff2 : std_logic;

begin

risingEdgeGen: if edge = "rising" generate
    signalOut <= ff1 and not ff2;
end generate;

fallingEdgeGen: if edge = "falling" generate
    signalOut <= not ff1 and ff2;
end generate;

riseEdgeGen: if clockEdge = "rising" generate
    edgeProc: process(clk,rst)
    begin
        if rst = '1' then
            ff1 <= '0';
            ff2 <= '0';
        elsif rising_edge(clk) then
            ff1 <= signalIn;
            ff2 <= ff1;
        end if;
    end process;
end generate;

fallEdgeGen: if clockEdge = "falling" generate
    edgeProc: process(clk,rst)
    begin
        if rst = '1' then
            ff1 <= '0';
            ff2 <= '0';
        elsif falling_edge(clk) then
            ff1 <= signalIn;
            ff2 <= ff1;
        end if;
    end process;
end generate;


end Behavioral;