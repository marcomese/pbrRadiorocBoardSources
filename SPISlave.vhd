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
use IEEE.NUMERIC_STD.ALL;

entity SPISlave is
port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    data_out     : out std_logic_vector(7 downto 0);
    data_in      : in  std_logic_vector(7 downto 0);
    rx_read      : in  std_logic;
    rx_ena       : in  std_logic;
    rx_present   : out std_logic;
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

signal sclkRise,
       sclkFall,
       csRise,
       txPres,
       loadBit,
       loadTxFifo,
       loadRxFifo,
       rxEna      : std_logic;
signal bitCount   : integer range 0 to 8;
signal buffIn,
       buffOut,
       txFifoDout : std_logic_vector(7 downto 0);

attribute MARK_DEBUG : string;
attribute MARK_DEBUG of buffIn  : signal is "true";
attribute MARK_DEBUG of buffOut : signal is "true";

begin

tx_present <= txPres;

miso       <= buffOut(7);

loadBit    <= '1' when bitCount = 8 else '0';

loadRxFifo <= loadBit and rxEna;

loadTxFifo <= loadBit;

sclkRiseInst: entity work.edgeDetector
generic map(
    clockEdge => "falling",
    edge      => "rising"
)
port map(
    clk       => clk,
    rst       => rst,
    signalIn  => sclk,
    signalOut => sclkRise
);

sclkFallInst: entity work.edgeDetector
generic map(
    clockEdge => "falling",
    edge      => "falling"
)
port map(
    clk       => clk,
    rst       => rst,
    signalIn  => sclk,
    signalOut => sclkFall
);

csRiseInst: entity work.edgeDetector
generic map(
    clockEdge => "falling",
    edge      => "rising"
)
port map(
    clk       => clk,
    rst       => rst,
    signalIn  => cs,
    signalOut => csRise
);

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

shiftRegInInst: process(clk, rst, sclkRise, cs)
begin
    if rising_edge(clk) then
        if rst = '1' then
            buffIn <= (others => '0');
        elsif cs = '0' and sclkRise = '1' then
            buffIn <= buffIn(6 downto 0) & mosi;
        end if;
    end if;
end process;

shiftRegOutInst: process(clk, rst, sclkFall, txPres, bitCount)
begin
    if rising_edge(clk) then
        if rst = '1' then
            buffOut <= (others => '0');
        elsif bitCount = 0 and txPres = '1' then
            buffOut <= txFifoDout;
        elsif cs = '0' and sclkFall = '1' then
            buffOut <= buffOut(6 downto 0) & '0';
        end if;
    end if;
end process;

bitCounterInst: process(clk, rst, sclkRise, cs)
begin
    if rising_edge(clk) then
        if rst = '1' or bitCount = 8 or cs = '1' then
            bitCount <= 0;
        elsif sclkRise = '1' then
            bitCount <= bitCount + 1;
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
    wr_ack    => tx_wr_ack,
    empty     => open,
    valid     => txPres,
    prog_full => tx_half_full
);

end Behavioral;