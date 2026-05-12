----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: timeStamp
-- Create Date: 12.05.2026 16:15:11
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
use IEEE.MATH_REAL.ALL;
use work.utilsPkg.all;

entity timeStamp is
generic(
    clkFreq    : real;
    coarseBase : real
);
port(
    clk     : in  std_logic;
    rst     : in  std_logic;
    freeze  : in  std_logic;
    tFine   : out std_logic_vector(31 downto 0);
    tCoarse : out std_logic_vector(31 downto 0);
    tStamp  : out std_logic_vector(63 downto 0)
);
end timeStamp;

architecture Behavioral of timeStamp is

constant cntMax     : integer := integer(coarseBase/clkFreq);

signal   locRst,
         coarseEn   : std_logic;

signal   tFineSig   : unsigned(bitsNum(cntMax)-1 downto 0);

signal   tCoarseSig : unsigned(31 downto 0);

begin

tFine    <= std_logic_vector(resize(tFineSig,tFine'length));

tCoarse  <= std_logic_vector(tCoarseSig);

locRstProc: process(clk)
begin
    if rising_edge(clk) then
        locRst <= rst;
    end if;
end process;

tStampProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            tStamp <= (others => '0');
        elsif freeze = '1' then
            tStamp <= std_logic_vector(tCoarseSig) &
                      std_logic_vector(resize(tFineSig,tFine'length));
        end if;
    end if;
end process;

fineCntProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            coarseEn <= '0';
            tFineSig <= (others => '0');
        elsif tFineSig = cntMax-1 then
            coarseEn <= '1';
            tFineSig <= (others => '0');
        else
            coarseEn <= '0';
            tFineSig <= tFineSig + 1;
        end if;
    end if;
end process;

coarseCntProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            tCoarseSig <= (others => '0');
        elsif coarseEn = '1' then
            tCoarseSig <= tCoarseSig + 1;
        end if;
    end if;
end process;

end Behavioral;