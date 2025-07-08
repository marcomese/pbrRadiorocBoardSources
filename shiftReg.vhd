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
use IEEE.STD_LOGIC_MISC.ALL;
use work.utilsPkg.all;

entity shiftReg is
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
    empty     : out std_logic;
    last      : out std_logic;
    dataOut   : out std_logic_vector(regLen-1 downto 0)
);
end shiftReg;

architecture Behavioral of shiftReg is

constant shiftNum : integer := integer(regLen/shiftLen);

signal   shiftCnt : unsigned(bitsNum(shiftNum)-1 downto 0);

signal   buffInt  : std_logic_vector(regLen-1 downto 0);

begin

empty <= '1' when shiftCnt = ones(shiftCnt'length) else '0';

last <= '1' when shiftCnt = zeroes(shiftCnt'length) else '0';

leftShiftGen: if direction = "left" generate
begin
    dataOut <= buffInt(buffInt'left downto buffInt'left-regLen+1);

    buffIntInst: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                buffInt <= (others => '0');
            elsif load = '1' then
                buffInt <= parDataIn;
            elsif shift = '1' then
                buffInt(buffInt'left downto shiftLen) <= buffInt(buffInt'left-shiftLen downto 0);
                buffInt(shiftLen-1 downto 0)          <= serDataIn;
            end if;
        end if;
    end process;
end generate;

rightShiftGen: if direction = "right" generate
begin
    dataOut <= buffInt(regLen-1 downto 0);

    buffIntInst: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                buffInt <= (others => '0');
            elsif load = '1' then
                buffInt <= parDataIn;
            elsif shift = '1' then
                buffInt(buffInt'left downto buffInt'left-shiftLen+1) <= serDataIn;
                buffInt(buffInt'left-shiftLen downto 0)              <= buffInt(buffInt'left downto shiftLen);
            end if;
        end if;
    end process;
end generate;

shiftCntInst: process(clk, rst)
begin
    if rising_edge(clk) then
        if rst = '1' or load = '1' then
            shiftCnt <= to_unsigned(shiftNum-1, shiftCnt'length);
        elsif shift = '1' then
            shiftCnt <= shiftCnt - 1;
        end if;
    end if;
end process;

end Behavioral;
