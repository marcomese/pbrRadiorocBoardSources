----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: SPISlave
-- Create Date: 03.12.2024 18:19:16
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

library xpm;
use xpm.vcomponents.all;

entity SPISlave is
generic(
    maxBrstLen   : integer
);
port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    data_out     : out std_logic_vector(7 downto 0);
    data_in      : in  std_logic_vector(7 downto 0);
    rx_read      : in  std_logic;
    rx_ena       : in  std_logic;
    rx_present   : out std_logic;
    rx_valid     : out std_logic;
    rx_half_full : out std_logic;
    rx_full      : out std_logic;
    tx_write     : in  std_logic;
    tx_present   : out std_logic;
    tx_half_full : out std_logic;
    tx_full      : out std_logic;
    tx_wr_ack    : out std_logic;
    rx_reset     : in  std_logic;
    tx_reset     : in  std_logic;
    cs           : in  std_logic;
    sclk         : in  std_logic;
    miso         : out std_logic;
    mosi         : in  std_logic
);
end SPISlave;

architecture Behavioral of SPISlave is

signal sclkFF,
       sclkRise,
       sclkFall,
       csFF,
       csRise,
       txPres,
       loadBuff,
       loadTxFifo,
       loadRxFifo,
       rxRead,
       txWrite,
       rxEna,
       rxEmpty,
       txEmpty,
       lastBit,
       rxRdRstBusy,
       rxWrRstBusy,
       txRdRstBusy,
       txWrRstBusy,
       locRst      : std_logic;
signal bitCount    : unsigned(3 downto 0);
signal buffIn,
       buffOut,
       txFifoDout  : std_logic_vector(7 downto 0);

begin

rxRead <= rx_read and not rxRdRstBusy;

txWrite <= tx_write and not txWrRstBusy;

lastBit    <= bitCount(bitCount'left);

loadBuff   <= and_reduce(std_logic_vector(bitCount(2 downto 0)));

loadRxFifo <= lastBit and rxEna and not rxWrRstBusy;

loadTxFifo <= lastBit and not txRdRstBusy;

rx_present <= not rxEmpty;

txPres <= not txEmpty;

locRstProc: process(clk)
begin
    if rising_edge(clk) then
        locRst <= rst;
    end if;
end process;

misoRegProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            miso <= '0';
        else
            if cs = '0' then
                miso <= buffOut(7);
            else
                miso <= '0';
            end if;
        end if;
    end if;
end process;

txPresInst: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            tx_present <= '0';
        else
            tx_present <= txPres;
        end if;
    end if;
end process;

sclkCsFFProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            sclkFF <= '0';
            csFF   <= '1';
        else
            sclkFF <= sclk;
            csFF   <= cs;
        end if;
    end if;
end process;

sclkRise <= sclk and not sclkFF;

sclkFall <= not sclk and sclkFF;

csRise   <= cs and not csFF;

rxEnaProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' or csRise = '1' then
            rxEna <= '1';
        elsif rx_ena = '0' then
            rxEna <= '0';
        end if;
    end if;
end process;

shiftRegInInst: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            buffIn <= (others => '0');
        elsif cs = '0' and sclkFall = '1' then
            buffIn <= buffIn(6 downto 0) & mosi;
        end if;
    end if;
end process;

shiftRegOutInst: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            buffOut <= (others => '0');
        elsif loadBuff = '1' and txPres = '1' then
            buffOut <= txFifoDout;
        elsif cs = '0' and sclkRise = '1' then
            buffOut <= buffOut(6 downto 0) & '0';
        end if;
    end if;
end process;

bitCounterInst: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' or lastBit = '1' or cs = '1' then
            bitCount <= to_unsigned(7, bitCount'length);
        elsif sclkFall = '1' then
            bitCount <= bitCount - 1;
        end if;
    end if;
end process;

rxFifoInst: xpm_fifo_sync
generic map(
    FIFO_WRITE_DEPTH => maxBrstLen,
    READ_DATA_WIDTH  => 8,
    WRITE_DATA_WIDTH => 8,
    PROG_FULL_THRESH => 7,
    READ_MODE        => "std",
    USE_ADV_FEATURES => "1002",
    FIFO_MEMORY_TYPE => "block"
)
port map(
    wr_clk        => clk,
    rst           => rx_reset,
    din           => buffIn,
    wr_en         => loadRxFifo,
    dout          => data_out,
    rd_en         => rxRead,
    data_valid    => rx_valid,
    empty         => rxEmpty,
    full          => rx_full,
    prog_full     => rx_half_full,
    rd_rst_busy   => rxRdRstBusy,
    wr_rst_busy   => rxWrRstBusy,
    sleep         => '0',
    injectdbiterr => '0',
    injectsbiterr => '0'
);

txFifoInst: xpm_fifo_sync
generic map(
    FIFO_WRITE_DEPTH => maxBrstLen,
    READ_DATA_WIDTH  => 8,
    WRITE_DATA_WIDTH => 8,
    PROG_FULL_THRESH => 7,
    READ_MODE        => "fwft",
    USE_ADV_FEATURES => "0012",
    FIFO_MEMORY_TYPE => "block"
)
port map(
    wr_clk        => clk,
    rst           => tx_reset,
    din           => data_in,
    wr_en         => txWrite,
    dout          => txFifoDout,
    rd_en         => loadTxFifo,
    wr_ack        => tx_wr_ack,
    empty         => txEmpty,
    full          => tx_full,
    prog_full     => tx_half_full,
    rd_rst_busy   => txRdRstBusy,
    wr_rst_busy   => txWrRstBusy,
    sleep         => '0',
    injectdbiterr => '0',
    injectsbiterr => '0'
);

end Behavioral;