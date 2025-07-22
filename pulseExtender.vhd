----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: pulseExtender
-- Create Date: 17.07.2025 15:51:55
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
use work.utilsPkg.bitsNum;

entity pulseExtender is
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
end pulseExtender;

architecture Behavioral of pulseExtender is

signal pulseRecv,
       pulseRecvOld,
       pulseEdge,
       pulseFF,
       pulseOut     : std_logic_vector(width-1 downto 0);

begin

sigDest <= pulseOut;

pRecvGen: for i in 0 to width-1 generate
begin
    pulseRecvProc: process(clkOrig, rstOrig, sigOrig(i))
    begin
        if rising_edge(clkOrig) then
            if rstOrig = '1' then
                pulseRecv(i) <= '0';
            elsif sigOrig(i) = '1' then
                pulseRecv(i) <= not pulseRecv(i);
            end if;
        end if;
    end process;
end generate;

edgeDet: process(clkDest, rstDest, pulseRecv)
begin
    if rising_edge(clkDest) then
        if rstDest = '1' then
            pulseRecvOld <= (others => '0');
            pulseEdge    <= (others => '0');
        else
            pulseRecvOld <= pulseRecv;
            pulseEdge    <= pulseRecv xor pulseRecvOld;
        end if;
    end if;
end process;

syncProc: process(clkDest, rstDest, pulseEdge)
begin
    if rising_edge(clkDest) then
        if rstDest = '1' then
            pulseFF  <= (others => '0');
            pulseOut <= (others => '0');
        else
            pulseFF  <= pulseEdge;
            pulseOut <= pulseFF;
        end if;
    end if;
end process;

end Behavioral;
