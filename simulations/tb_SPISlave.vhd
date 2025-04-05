library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.commandsPkg.all;

entity tb_SPISlave is
end tb_SPISlave;

architecture Behavioral of tb_SPISlave is

component SPIMaster is
generic(
    clkFreq      : real;
    sclkFreq     : real
);
port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    data_rx      : out std_logic_vector(7 downto 0);
    data_tx      : in  std_logic_vector(7 downto 0);
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
    cs           : out std_logic;
    sclk         : out std_logic;
    miso         : in  std_logic;
    mosi         : out std_logic
);
end component;

component SPISlave is
port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    data_rx      : out std_logic_vector(7 downto 0);
    data_tx      : in  std_logic_vector(7 downto 0);
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
    cs           : in  std_logic;
    sclk         : in  std_logic;
    miso         : out std_logic;
    mosi         : in  std_logic
);
end component;

component serialCmdParser is
generic(
    paramBytes : integer
);
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    rxPresent  : in  std_logic;
    dataRx     : in  std_logic_vector(7 downto 0);
    rxRead     : out std_logic;
    cmdValid   : out std_logic;
    cmdSel     : out std_logic_vector(commands'range);
    cmdParam   : out std_logic_vector(paramBytes*8-1 downto 0);
    cmdErr     : out std_logic_vector(1 downto 0)
);
end component;

constant clkPeriod     : time := 10 ns;
constant sclkPeriod    : time := 20 ns;
constant clkFreq       : real := 100.0e6;
constant sclkFreq      : real := 50.0e6;
constant paramBytes    : integer := 4;

signal   clk           : std_logic := '1';
signal   rst           : std_logic;
signal   data_rxM      : std_logic_vector(7 downto 0);
signal   data_txM      : std_logic_vector(7 downto 0) := (others => '0');
signal   data_rx       : std_logic_vector(7 downto 0);
signal   data_tx       : std_logic_vector(7 downto 0) := (others => '0');
signal   rx_read       : std_logic := '0';
signal   rx_present    : std_logic;
signal   rx_half_full  : std_logic;
signal   rx_full       : std_logic;
signal   tx_write      : std_logic := '0';
signal   tx_present    : std_logic;
signal   tx_half_full  : std_logic;
signal   tx_full       : std_logic;
signal   rx_readM      : std_logic := '0';
signal   rx_presentM   : std_logic;
signal   rx_half_fullM : std_logic;
signal   rx_fullM      : std_logic;
signal   tx_writeM     : std_logic := '0';
signal   tx_presentM   : std_logic;
signal   tx_half_fullM : std_logic;
signal   tx_fullM      : std_logic;
signal   cs            : std_logic := '0';
signal   sclk          : std_logic := '0';
signal   miso          : std_logic;
signal   mosi          : std_logic := '0';
signal   cmdValid      : std_logic;
signal   cmdSel        : std_logic_vector(commands'range);
signal   cmdParam      : std_logic_vector(paramBytes*8-1 downto 0);
signal   cmdErr        : std_logic_vector(1 downto 0);
signal   i2cEna        : std_logic;
signal   i2cAddr       : std_logic_vector(6 downto 0);
signal   i2cRw         : std_logic;
signal   i2cDataWr     : std_logic_vector(7 downto 0);
signal   i2cBusy       : std_logic;
signal   i2cDataRd     : std_logic_vector(7 downto 0);
signal   sda           : std_logic :='0';
signal   scl           : std_logic :='0';
signal   resetn        : std_logic;
signal   temp          : std_logic_vector(11 downto 0);
signal   vbias         : std_logic_vector(31 downto 0);
signal   current       : std_logic_vector(31 downto 0);
signal   dataReady     : std_logic;


begin

clk  <= not clk after clkPeriod/2;

rst  <= '1', '0' after clkPeriod*5;

resetn <= not rst;

stimProc: process
begin
    rst <= '1';
    wait for clkPeriod*5;
    rst <= '0';
    wait for clkPeriod;

    data_txM  <= serSetSipmHVCMD;
    tx_writeM <= '1';
    wait for clkPeriod;
    data_txM  <= x"CD";
    wait for clkPeriod;
    data_txM  <= x"23";
    wait for clkPeriod;
    data_txM  <= x"11";
    wait for clkPeriod;
    data_txM  <= x"EF";
    wait for clkPeriod;

    tx_writeM <= '0';

    wait;
end process;

masterSpi: SPIMaster
generic map(
    clkFreq      => clkFreq,
    sclkFreq     => sclkFreq
)
port map(
    clk          => clk,
    rst          => rst,
    data_rx      => data_rxM,
    data_tx      => data_txM,
    rx_read      => rx_readM,
    rx_present   => rx_presentM,
    rx_half_full => rx_half_fullM,
    rx_full      => rx_fullM,
    tx_write     => tx_writeM,
    tx_present   => tx_presentM,
    tx_half_full => tx_half_fullM,
    tx_full      => tx_fullM,
    rx_reset     => rst,
    tx_reset     => rst,
    cs           => cs,
    sclk         => sclk,
    miso         => miso,
    mosi         => mosi
);

slaveSpi: SPISlave
port map(
    clk          => clk,
    rst          => rst,
    data_rx      => data_rx,
    data_tx      => data_tx,
    rx_read      => rx_read,
    rx_present   => rx_present,
    rx_half_full => rx_half_full,
    rx_full      => rx_full,
    tx_write     => tx_write,
    tx_present   => tx_present,
    tx_half_full => tx_half_full,
    tx_full      => tx_full,
    rx_reset     => rst,
    tx_reset     => rst,
    cs           => cs,
    sclk         => sclk,
    miso         => miso,
    mosi         => mosi
);

--serialCmdInst: entity work.serialCmdParser
--generic map(
--    paramBytes => paramBytes
--)
--port map(
--    clk        => clk,
--    rst        => rst,
--    rxPresent  => rx_present,
--    dataRx     => data_rx,
--    rxRead     => rx_read,
--    cmdValid   => cmdValid,
--    cmdSel     => cmdSel,
--    cmdParam   => cmdParam,
--    cmdErr     => cmdErr
--);

--sipmHvTmpCtrlInst: entity work.sipmHvTmpCtrl
--generic map(
--    clkFreq      => clkFreq,
--    paramBytes   => paramBytes,
--    depth        => 4,
--    aEmptyThresh => 1,
--    aFullThresh  => 3,
--    readPeriod   => 1.0,
--    tmpAddr      => "1001000",
--    sipmHvAddr   => "1110011"
--)
--port map(
--    clk          => clk,
--    rst          => rst,
--    cmdValid     => cmdValid,
--    cmdSel       => cmdSel,
--    cmdParam     => cmdParam,
--    temperature  => temp,
--    vbias        => vbias,
--    current      => current,
--    dataReady    => dataReady,
--    i2cEna       => i2cEna,
--    i2cAddr      => i2cAddr,
--    i2cRw        => i2cRw,
--    i2cDataWr    => i2cDataWr,
--    i2cBusy      => i2cBusy,
--    i2cDataRd    => i2cDataRd
--);

i2cModule: entity work.i2cMaster
generic map(
    input_clk => 100000000,
    bus_clk   => 400000
)
port map(
    clk       => clk,
    reset_n   => resetn,
    ena       => i2cEna,
    addr      => i2cAddr,
    rw        => i2cRw,
    data_wr   => i2cDataWr,
    busy      => i2cBusy,
    data_rd   => i2cDataRd,
    ack_error => open,
    sda       => sda,
    scl       => scl
);

end Behavioral;