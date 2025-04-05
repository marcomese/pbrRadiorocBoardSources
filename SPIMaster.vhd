----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: SPIMaster
-- Create Date: 05.12.2024 12:33:35
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity SPIMaster is
generic(
    clkFreq      : real; -- the ratio clkFreq/sclkFreq must be at least 4
    sclkFreq     : real  -- (clkFreq/sclkFreq >= 4)
);
port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    data_out     : out std_logic_vector(7 downto 0);
    data_in      : in  std_logic_vector(7 downto 0);
    rx_read      : in  std_logic;
    rx_present   : out std_logic;
    rx_half_full : out std_logic;
    rx_full      : out std_logic;
    tx_write     : in  std_logic;
    tx_present   : out std_logic;
    tx_half_full : out std_logic;
    tx_full      : out std_logic;
    rx_reset     : in  std_logic;
    tx_reset     : in  std_logic;
    read_rq      : in  std_logic;
    cs           : out std_logic;
    sclk         : out std_logic;
    miso         : in  std_logic;
    mosi         : out std_logic
);
end SPIMaster;

architecture Behavioral of SPIMaster is

component rxFifo
port(
    clk       : in  std_logic;
    srst      : in  std_logic;
    din       : in  std_logic_vector(7 downto 0);
    wr_en     : in  std_logic;
    rd_en     : in  std_logic;
    dout      : out std_logic_vector(7 downto 0);
    full      : out std_logic;
    empty     : out std_logic;
    valid     : out std_logic;
    prog_full : out std_logic
);
end component;

component txFifo
port(
    clk       : in  std_logic;
    srst      : in  std_logic;
    din       : in  std_logic_vector(7 downto 0);
    wr_en     : in  std_logic;
    rd_en     : in  std_logic;
    dout      : out std_logic_vector(7 downto 0);
    full      : out std_logic;
    empty     : out std_logic;
    valid     : out std_logic;
    prog_full : out std_logic
);
end component;

constant sclkPeriod : real    := floor(clkFreq/sclkFreq);
constant sclkLen    : integer := integer(sclkPeriod);
constant sclkHalf   : integer := integer(ceil(sclkPeriod/2.0));
constant lBSliceL   : integer := integer(floor(sclkPeriod/2.0)+ceil(sclkPeriod/4.0)-1.0);
constant lBSliceR   : integer := integer(ceil(sclkPeriod/4.0));
constant sBSliceL   : integer := integer(ceil(sclkPeriod/2.0)+floor(sclkPeriod/4.0)-1.0);
constant sBSliceR   : integer := integer(floor(sclkPeriod/4.0));

signal sclkSig,
       loadBit,
       sendBit,
       csSig,
       txPres,
       loadTxFifo,
       loadRxFifo : std_logic;
signal bitCount   : unsigned(3 downto 0);
signal sclkShift  : std_logic_vector(sclkLen-1 downto 0);
signal buffIn,
       buffOut,
       txFifoDout : std_logic_vector(7 downto 0);

begin

cs         <= csSig;

sclk       <= sclkSig;

loadTxFifo <= bitCount(bitCount'left);

loadRxFifo <= bitCount(bitCount'left) and read_rq;

mosi       <= buffOut(7);

tx_present <= txPres;

sclkSig    <= sclkShift(0);

sendBit    <= (not or_reduce(sclkShift(sclkShift'left downto lBSliceL+1))) and 
              and_reduce(sclkShift(lBSliceL downto lBSliceR)) and
              (not or_reduce(sclkShift(lBSliceR-1 downto 0)));

loadBit    <= (and_reduce(sclkShift(sclkShift'left downto sBSliceL+1))) and 
              not or_reduce(sclkShift(sBSliceL downto sBSliceR)) and
              (and_reduce(sclkShift(sBSliceR-1 downto 0)));

shiftRegInInst: process(clk, rst, csSig, loadBit)
begin
    if rising_edge(clk) then
        if rst = '1' then
            buffIn <= (others => '0');
        elsif csSig = '0' and loadBit = '1' then
            buffIn <= buffIn(6 downto 0) & miso;
        end if;
    end if;
end process;

shiftRegOutInst: process(clk, rst, sendBit)
begin
    if rising_edge(clk) then
        if rst = '1' then
            buffOut <= (others => '0');
        elsif bitCount = 7 then
            buffOut <= txFifoDOut;
        elsif sendBit = '1' then
            buffOut <= buffOut(6 downto 0) & '0';
        end if;
    end if;
end process;

csGen: process(clk, rst, txPres)
begin
    if rising_edge(clk) then
        if rst = '1' then
            csSig <= '1';
        elsif txPres = '1' or read_rq = '1' then
            csSig <= '0';
        else
            csSig <= '1';
        end if;
    end if;
end process;

sclkGen: process(clk, rst, csSig)
begin
    if rising_edge(clk) then
        if rst = '1' or csSig = '1' then
            sclkShift <= (sclkShift'left downto sclkHalf => '1',
                          others => '0');
        elsif csSig = '0' then
            sclkShift <= sclkShift(0) & sclkShift(sclkShift'left downto 1);
         end if;
    end if;
end process;

bitCounterInst: process(clk, rst, loadBit, csSig)
begin
    if rising_edge(clk) then
        if rst = '1' or bitCount(bitCount'left) = '1' or csSig = '1' then
            bitCount <= to_unsigned(7, 4);
        elsif loadBit = '1' then
            bitCount <= bitCount - 1;
        end if;
    end if;
end process;

rxFifoInst: rxFifo
  PORT MAP (
    clk       => clk,
    srst      => rx_reset,
    din       => buffIn,
    wr_en     => loadRxFifo,
    rd_en     => rx_read,
    dout      => data_out,
    full      => rx_full,
    empty     => open,
    valid     => rx_present,
    prog_full => rx_half_full
  );

txFifoInst: txFifo
port map(
    clk       => clk,
    srst      => tx_reset,
    din       => data_in,
    wr_en     => tx_write,
    rd_en     => loadTxFifo,
    dout      => txFifoDout,
    full      => tx_full,
    empty     => open,
    valid     => txPres,
    prog_full => tx_half_full
);

end Behavioral;
