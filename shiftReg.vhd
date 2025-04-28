----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: shiftReg
-- Create Date: 24.04.2025 14:00:57
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

entity shiftReg is
generic(
    direction  : string;
    dataInLen  : integer;
    dataOutLen : integer
);
port(
    clk     : in  std_logic;
    rst     : in  std_logic;
    load    : in  std_logic;
    shift   : in  std_logic;
    dataIn  : in  std_logic_vector(dataInLen-1 downto 0);
    dataOut : out std_logic_vector(dataOutLen-1 downto 0)
);
end shiftReg;

architecture Behavioral of shiftReg is

signal buffInt : std_logic_vector(dataInLen-1 downto 0);

begin

leftShiftGen: if direction = "left" generate
begin
    dataOut <= buffInt(buffInt'left downto buffInt'left-dataOutLen+1);

    buffIntInst: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                buffInt <= (others => '0');
            elsif load = '1' then
                buffInt <= dataIn;
            elsif shift = '1' then
                buffInt(buffInt'left downto dataOutLen) <= buffInt(buffInt'left-dataOutLen downto 0);
                buffInt(dataOutLen-1 downto 0)          <= (others => '0');
            end if;
        end if;
    end process;
end generate;

rightShiftGen: if direction = "right" generate
begin
    dataOut <= buffInt(dataOutLen-1 downto 0);

    buffIntInst: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                buffInt <= (others => '0');
            elsif load = '1' then
                buffInt <= dataIn;
            elsif shift = '1' then
                buffInt(buffInt'left downto buffInt'left-dataOutLen+1) <= (others => '0');
                buffInt(buffInt'left-dataOutLen downto 0)              <= buffInt(buffInt'left downto dataOutLen);
            end if;
        end if;
    end process;
end generate;

end Behavioral;
