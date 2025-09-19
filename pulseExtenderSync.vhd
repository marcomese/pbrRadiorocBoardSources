----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: pulseExtenderSync
-- Create Date: 19.09.2025 11:08:17
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

entity pulseExtenderSync is
generic(
    width       : integer := 1;
    syncStages  : integer;
    clkOrigFreq : real;
    clkDestFreq : real
);
port(
    clkOrig     : in  std_logic;
    rstOrig     : in  std_logic;
    clkDest     : in  std_logic;
    rstDest     : in  std_logic;
    sigOrig     : in  std_logic_vector(width-1 downto 0);
    sigDest     : out std_logic_vector(width-1 downto 0)
);
end pulseExtenderSync;

architecture Behavioral of pulseExtenderSync is

begin

pulseExtFsmGen: for n in 0 to width-1 generate
begin
    pExtFsmInstGen: entity work.pulseExtFSM
    generic map(
        syncStages  => syncStages,
        clkOrigFreq => clkOrigFreq,
        clkDestFreq => clkDestFreq
    )
    port map(
        clkOrig     => clkOrig,
        clkDest     => clkDest,
        rstOrig     => rstOrig,
        rstDest     => rstDest,
        sigOrig     => sigOrig(n),
        sigDest     => sigDest(n)
    );
end generate;

end Behavioral;
