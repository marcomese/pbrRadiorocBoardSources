----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: trgSync
-- Create Date: 01.01.2026 13:07:07
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity trgSync is
generic(
    trgNum : natural
);
port(
    clk  : in  std_logic;
    rst  : in  std_logic;
    tIn  : in  std_logic_vector(trgNum-1 downto 0);
    tOut : out std_logic_vector(trgNum-1 downto 0)
);
end trgSync;

architecture Behavioral of trgSync is

begin

trgEdgeGen: for i in 0 to trgNum-1 generate
begin
    trgEdgeInst: entity work.edgeDetector
    generic map(
        clockEdge => "rising",
        edge      => "falling"
    )
    port map(
        clk       => clk,
        rst       => rst,
        signalIn  => tIn(i),
        signalOut => tOut(i)
    );
end generate;

end Behavioral;
