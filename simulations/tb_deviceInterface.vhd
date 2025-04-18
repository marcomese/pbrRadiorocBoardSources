library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.devicesPkg.all;

entity tb_deviceInterface is
end tb_deviceInterface;

architecture Behavioral of tb_deviceInterface is

component deviceInterface is
generic(
    clkFreq    : real;
    timeout    : real;
    readCmd    : std_logic_vector(3 downto 0);
    writeCmd   : std_logic_vector(3 downto 0);
    burstWrCmd : std_logic_vector(3 downto 0);
    burstRdCmd : std_logic_vector(3 downto 0)
);
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    dataIn     : in  std_logic_vector(7 downto 0);
    dataOut    : out std_logic_vector(7 downto 0);
    rxRead     : out std_logic;
    rxPresent  : in  std_logic;
    txWrite    : out std_logic;
    txWrAck    : in  std_logic;
    rxEna      : out std_logic;
    devId      : out devices_t;
    devReady   : in  devReady_t;
    devBusy    : in  devBusy_t;
    devRw      : out std_logic;
    devBurst   : out std_logic;
    devAddr    : out devAddr_t;
    devDataIn  : in  devDataVec_t;
    devDataOut : out devData_t;
    devExec    : out std_logic;
    busy       : out std_logic;
    error      : out std_logic_vector(1 downto 0)
);
end component;

component SPIMaster is
generic(
    clkFreq      : real;
    sclkFreq     : real
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
end component;

component SPISlave is
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
end component;

constant clkPeriod  : time         := 10 ns;
constant clkFreq    : real         := 100.0e6;
constant sclkFreq   : real         := 25.0e6;
constant timeout    : real         := 1.0e-6;

constant readCmd    : std_logic_vector(3 downto 0) := x"A";
constant writeCmd   : std_logic_vector(3 downto 0) := x"5";
constant burstWrCmd : std_logic_vector(3 downto 0) := x"3";
constant burstRdCmd : std_logic_vector(3 downto 0) := x"B";

signal   clk        : std_logic    := '1';
signal   rst        : std_logic;
signal   dataFromDevInt  : std_logic_vector(7 downto 0) := (others => '0');
signal   dataToDevInt    : std_logic_vector(7 downto 0);
signal   rxRead     : std_logic;
signal   rxPresent  : std_logic    := '0';
signal   readRq     : std_logic    := '0';
signal   txWrite    : std_logic;
signal   txWrAck    : std_logic    := '0';
signal   devId      : devices_t;
signal   devDataIn  : devDataVec_t := (others => (others => (others => '0')));
signal   devReady   : devReady_t   := (others => '0');
signal   devBusy    : devBusy_t    := (others => '0');
signal   devRw      : std_logic;
signal   devBurst   : std_logic;
signal   devAddr    : devAddr_t;
signal   devDataOut : devData_t;
signal   devExec    : std_logic;
signal   busy       : std_logic;
signal   error      : std_logic_vector(1 downto 0);
signal   rxEna      : std_logic := '1';
signal   cs,
         sclk,
         miso,
         mosi,
         testTxWrite,
         testRxRead,
         testRxPresent : std_logic := '0';
signal   testDataIn,
         testDataOut   : std_logic_vector(7 downto 0) := (others => '0');

begin

stimProc: process
begin
    rst <= '1';
    wait for clkPeriod*5;
    rst <= '0';
    wait for clkPeriod*5;

    devDataIn <= (
        (x"AB",x"CD",x"EF",x"12"),
        (x"AB",x"CD",x"EF",x"23"),
        (x"AB",x"CD",x"EF",x"34"),
        (x"AB",x"CD",x"EF",x"45"),
        (x"AB",x"31",x"74",x"15"),
        (x"AB",x"CD",x"EF",x"67"),
        (x"AB",x"CD",x"EF",x"78")
    );

--    testRxRead <= '1';

--    testDataIn <= x"A4";
--    wait for clkPeriod;
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testDataIn <= x"A1";
--    wait for clkPeriod;
--    testDataIn <= x"B2";
--    wait for clkPeriod;
--    testTxWrite <= '0';

--    wait for 1.6 us;
    
--    devReady(pulseGen) <= '1';
--    wait for clkPeriod;
--    devReady(pulseGen) <= '0';

    testDataIn <= x"55";
    wait for clkPeriod;
    testTxWrite <= '1';
    wait for clkPeriod;
    testDataIn <= x"AA";
    wait for clkPeriod;
    testDataIn <= x"BB";
    wait for clkPeriod;
    testDataIn <= x"11";
    wait for clkPeriod;
    testDataIn <= x"22";
    wait for clkPeriod;
    testDataIn <= x"33";
    wait for clkPeriod;
    testDataIn <= x"44";
    wait for clkPeriod;
    testDataIn <= x"55";
    wait for clkPeriod;
    testTxWrite <= '0';

    wait;
end process;

clk <= not clk after clkPeriod/2;

uut: deviceInterface
generic map(
    clkFreq    => clkFreq,
    timeout    => timeout,
    readCmd    => readCmd,
    writeCmd   => writeCmd,
    burstWrCmd => burstWrCmd,
    burstRdCmd => burstRdCmd
)
port map(
    clk        => clk,
    rst        => rst,
    dataOut    => dataFromDevInt,
    dataIn     => dataToDevInt,
    rxRead     => rxRead,
    rxPresent  => rxPresent,
    txWrite    => txWrite,
    txWrAck    => txWrAck,
    rxEna      => rxEna,
    devId      => devId,
    devDataOut => devDataOut,
    devReady   => devReady,
    devBusy    => devBusy,
    devBurst   => devBurst,
    devRw      => devRw,
    devAddr    => devAddr,
    devDataIn  => devDataIn,
    devExec    => devExec,
    busy       => busy,
    error      => error
);

spiSlaveInst: entity work.SPISlave
port map(
    clk          => clk,
    rst          => rst,
    data_out     => dataToDevInt,
    data_in      => dataFromDevInt,
    rx_read      => rxRead,
    rx_ena       => rxEna,
    rx_present   => rxPresent,
    rx_half_full => open,
    rx_full      => open,
    tx_write     => txWrite,
    tx_present   => readRq,
    tx_half_full => open,
    tx_full      => open,
    tx_wr_ack    => txWrAck,
    rx_reset     => rst,
    tx_reset     => rst,
    cs           => cs,
    sclk         => sclk,
    miso         => miso,
    mosi         => mosi
);

spiInst: SPIMaster
generic map(
    clkFreq      => clkFreq,
    sclkFreq     => sclkFreq
)
port map(
    clk          => clk,
    rst          => rst,
    data_in      => testDataIn,
    data_out     => testDataOut,
    rx_read      => testRxRead,
    rx_present   => testRxPresent,
    rx_half_full => open,
    rx_full      => open,
    tx_write     => testTxWrite,
    tx_present   => open,
    tx_half_full => open,
    tx_full      => open,
    rx_reset     => rst,
    tx_reset     => rst,
    read_rq      => readRq,
    cs           => cs,
    sclk         => sclk,
    miso         => miso,
    mosi         => mosi
);

end Behavioral;