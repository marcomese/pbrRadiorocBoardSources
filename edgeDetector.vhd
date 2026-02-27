library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity edgeDetector is
generic(
    inputFF   : boolean;
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

inputFFGen: if inputFF = True generate
    inFFProc: process(clk)
    begin
        if rising_edge(clk) then
            ff1 <= signalIn;
        end if;
    end process;
end generate;

noInputFFGen: if inputFF = False generate
    ff1 <= signalIn;
end generate;

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
            ff2 <= signalIn;
        elsif rising_edge(clk) then
            ff2 <= ff1;
        end if;
    end process;
end generate;

fallEdgeGen: if clockEdge = "falling" generate
    edgeProc: process(clk,rst)
    begin
        if rst = '1' then
            ff2 <= signalIn;
        elsif falling_edge(clk) then
            ff2 <= ff1;
        end if;
    end process;
end generate;

end Behavioral;