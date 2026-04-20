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
    maxBrstLen   : natural
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
    wr_ack    : out std_logic;
    empty     : out std_logic;
    valid     : out std_logic;
    prog_full : out std_logic
);
end component;

signal sclkFF,
       sclkRise,
       sclkFall,
       csFF,
       csRise,
       csFall,
       txPres,
       loadBuff,
       loadTxFifo,
       loadRxFifo,
       rxEna,
       rxEmpty,
       lastBit    : std_logic;
signal bitCount   : unsigned(3 downto 0);
signal buffIn,
       buffOut,
       txFifoDout : std_logic_vector(7 downto 0);

begin

lastBit    <= bitCount(bitCount'left);

loadBuff   <= and_reduce(std_logic_vector(bitCount(2 downto 0)));

loadRxFifo <= lastBit and rxEna;

loadTxFifo <= lastBit;

rx_present <= not rxEmpty;

misoRegProc: process(clk)
begin
    if rising_edge(clk) then
        if rst = '1' then
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
        if rst = '1' then
            tx_present <= '0';
        else
            tx_present <= txPres;
        end if;
    end if;
end process;

sclkCsFFProc: process(clk)
begin
    if rising_edge(clk) then
        if rst = '1' then
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

rxEnaProc: process(clk, rst, csRise, rx_ena)
begin
    if rising_edge(clk) then
        if rst = '1' or csRise = '1' then
            rxEna <= '1';
        elsif rx_ena = '0' then
            rxEna <= '0';
        end if;
    end if;
end process;

shiftRegInInst: process(clk, rst, sclkFall, cs)
begin
    if rising_edge(clk) then
        if rst = '1' then
            buffIn <= (others => '0');
        elsif cs = '0' and sclkFall = '1' then
            buffIn <= buffIn(6 downto 0) & mosi;
        end if;
    end if;
end process;

shiftRegOutInst: process(clk, rst, sclkRise, txPres, bitCount)
begin
    if rising_edge(clk) then
        if rst = '1' then
            buffOut <= (others => '0');
        elsif loadBuff = '1' and txPres = '1' then
            buffOut <= txFifoDout;
        elsif cs = '0' and sclkRise = '1' then
            buffOut <= buffOut(6 downto 0) & '0';
        end if;
    end if;
end process;

bitCounterInst: process(clk, rst, sclkRise, cs)
begin
    if rising_edge(clk) then
        if rst = '1' or lastBit = '1' or cs = '1' then
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
    rd_en         => rx_read,
    data_valid    => rx_valid,
    empty         => rxEmpty,
    full          => rx_full,
    prog_full     => rx_half_full,
    sleep         => '0',
    injectdbiterr => '0',
    injectsbiterr => '0'
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
    wr_ack    => tx_wr_ack,
    empty     => open,
    valid     => txPres,
    prog_full => tx_half_full
);

end Behavioral;