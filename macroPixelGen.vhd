----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: macroPixelGen
-- Create Date: 04.03.2026 14:42:40
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
use work.utilsPkg.all;
use work.pixelMappingPkg.all;

entity macroPixelGen is
generic(
    maxMacroRows : integer;
    maxMacroCols : integer
);
port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    mPixelRows   : in  std_logic_vector(bitsNum(maxMacroRows)-1 downto 0);
    mPixelCols   : in  std_logic_vector(bitsNum(maxMacroCols)-1 downto 0);
    pixelIn      : in  pixels_t(0 to nRows-1, 0 to nCols-1);
    trgMask      : in  pixels_t(0 to maxMacroRows-1, 0 to maxMacroCols-1);
    vetoMask     : in  pixels_t(0 to maxMacroRows-1, 0 to maxMacroCols-1)
);
end macroPixelGen;

architecture Behavioral of macroPixelGen is

signal macroPixels : pixels_t(0 to maxMacroRows-1, 0 to maxMacroCols-1);

signal macroR      : integer range 0 to maxMacroRows-1;

signal macroC      : integer range 0 to maxMacroCols-1;

signal lastC       : integer range 0 to maxMacroCols-1;

begin

centralTrgSigGen: process(clk)
begin
    if rising_edge(clk) then
        if rst = '1' then
            macroR      <= 0;
            macroC      <= 0;
            lastC       <= 0;
            macroPixels <= initPixels(maxMacroRows, maxMacroCols, '0');
        else
            macroR <= to_integer(unsigned(mPixelRows));
            macroC <= to_integer(unsigned(mPixelCols));
            lastC  <= nCols - macroC;

            rowLoop: for r in 0 to macroR loop
                colLoop: for c in 0 to lastC loop
                    macroPixels(r,c) <= pixelIn(r,c) and trgMask(r,c);
                end loop;
            end loop;
        end if;
    end if;
end process;

end Behavioral;
