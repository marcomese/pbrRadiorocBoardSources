----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: pulseSync
-- Create Date: 04.10.2025 21:41:00
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

entity pulseSync is
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
end pulseSync;

architecture Behavioral of pulseSync is

signal sigToggle,
       sigTFF1,
       sigTFF2   : std_logic_vector(width-1 downto 0);

begin

toggleGen: for i in 0 to width-1 generate
begin
    toggleProc: process(clkOrig, rstOrig, sigOrig(i))
    begin
        if rising_edge(clkOrig) then
            if rstOrig = '1' then
                sigToggle(i) <= '0';
            elsif sigOrig(i) = '1' then
                sigToggle(i) <= not sigToggle(i);
            end if;
        end if;
    end process;
end generate;

syncProc: process(clkDest, rstDest)
begin
    if rising_edge(clkDest) then
        if rstDest = '1' then
            sigTFF1 <= (others => '0');
            sigTFF2 <= (others => '0');
        else
            sigTFF1 <= sigToggle;
            sigTFF2 <= sigTFF1;
        end if;
    end if;
end process;

outProc: process(clkDest, rstDest, sigTFF2, sigTFF2)
begin
    if rising_edge(clkDest) then
        if rstDest = '1' then
            sigDest <= (others => '0');
        else
            sigDest <= sigTFF1 xor sigTFF2;
        end if;
    end if;
end process;

end Behavioral;
