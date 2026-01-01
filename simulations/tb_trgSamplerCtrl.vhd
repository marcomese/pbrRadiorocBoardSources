library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.devicesPkg.all;

entity tb_trgSampler is
end tb_trgSampler;

architecture Behavioral of tb_trgSampler is

component trgSampler is
generic(
    trgNum     : natural
);
port(
    clk        : in  std_logic;
    clkTmr     : in  std_logic;
    rst        : in  std_logic;
    evtTrigger : in  std_logic;
    trgIn      : in  std_logic_vector(trgNum-1 downto 0);
    devExec    : in  std_logic;
    devId      : in  devices_t;
    devRw      : in  std_logic;
    devBrst    : in  std_logic;
    devBrstWrt : in  std_logic;
    devBrstSnd : in  std_logic;
    devBrstRst : out std_logic;
    devAddr    : in  devAddr_t;
    devDataIn  : in  devData_t;
    devDataOut : out devData_t;
    devReady   : out std_logic;
    busy       : out std_logic
);
end component;

component deviceInterface is
generic(
    clkFreq     : real;
    timeout     : real;
    readCmd     : std_logic_vector(3 downto 0);
    writeCmd    : std_logic_vector(3 downto 0);
    burstWrCmd  : std_logic_vector(3 downto 0);
    burstRdCmd  : std_logic_vector(3 downto 0);
    maxBrstLen  : natural -- maximum number of bytes to read/write in burst mode
);
port(
    clk         : in  std_logic;
    rst         : in  std_logic;
    dataIn      : in  std_logic_vector(7 downto 0);
    dataOut     : out std_logic_vector(7 downto 0);
    rxRead      : out std_logic;
    rxPresent   : in  std_logic;
    txWrite     : out std_logic;
    txWrAck     : in  std_logic;
    rxEna       : out std_logic;
    flushRxFifo : out std_logic;
    flushTxFifo : out std_logic;
    devId       : out devices_t;
    devReady    : in  devStdLogic_t;
    devBusy     : in  devStdLogic_t;
    devRw       : out std_logic;
    devBrst     : out std_logic;
    devBrstWrt  : out std_logic;
    devBrstSnd  : out std_logic;
    devBrstRst  : in  devStdLogic_t;
    devAddr     : out devAddr_t;
    devDataIn   : in  devDataVec_t;
    devDataOut  : out devData_t;
    devExec     : out std_logic;
    busy        : out std_logic;
    error       : out std_logic_vector(2 downto 0)
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

constant clkPeriod100M : time                         := 10 ns;
constant clkFreq       : real                         := 100.0e6;
constant sclkFreq      : real                         := 20.0e6;
constant timeout       : real                         := 1.0;
constant readCmd       : std_logic_vector(3 downto 0) := x"A";
constant writeCmd      : std_logic_vector(3 downto 0) := x"5";
constant burstWrCmd    : std_logic_vector(3 downto 0) := x"3";
constant burstRdCmd    : std_logic_vector(3 downto 0) := x"B";
constant maxBrstLen    : natural                      := 14000;
constant delay         : natural                      := 1;--50000;
constant trgNum        : natural                      := 64;

signal rst               : std_logic := '0';
signal clk_100M          : std_logic := '1';
signal t           : std_logic_vector(63 downto 0) := (others => '1');
signal devId             : devices_t    := none;
signal devReadyRm        : std_logic    := '0';
signal devRw             : std_logic    := '0';
signal devBrst           : std_logic    := '0';
signal devBrstWrt        : std_logic    := '0';
signal devBrstSnd        : std_logic    := '0';
signal devBrstRst        : devStdLogic_t := (others => '0');
signal devAddr           : devAddr_t    := (others => (others => '0'));
signal devExec           : std_logic    := '0';
signal dataToDev,
       dataFromRM        : devData_t     := (others => (others => '0'));
signal devDataInVec      : devDataVec_t  := (others => (others => (others => '0')));
signal devReadyVec       : devStdLogic_t := (others => '0');
signal devBusyVec        : devStdLogic_t := (others => '0');
signal rmBusy            : std_logic     := '0';
signal error             : std_logic_vector(2 downto 0) := "000";
signal rxRead            : std_logic                    := '0';
signal rxPresent         : std_logic                    := '0';
signal txWrite           : std_logic                    := '0';
signal txWrAck           : std_logic                    := '0';
signal flushRxFifo       : std_logic                    := '0';
signal rxEna             : std_logic                    := '1';
signal readRq,
       cs,
       sclk,
       miso,
       mosi,
       testTxWrite,
       testRxRead,
       testRxPresent,
       devIntBusy,
       devBrstRstRM,
       rdValid        : std_logic                     := '0';
signal dataToMaster,
       testDataIn,
       testDataOut,
       testData,
       dataFromMaster : std_logic_vector(7 downto 0)  := (others => '0');
signal rdDataCnt      : std_logic_vector(15 downto 0) := (others => '0');

begin

stimProc: process
begin
    rst <= '1';
    wait for clkPeriod100M*5;
    rst <= '0';
    wait for clkPeriod100M*5;

    wait for 350 ns;

    testDataIn <= x"56";
    wait for clkPeriod100M*delay;
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
    testDataIn <= x"01";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    testDataIn <= x"01";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    testDataIn <= x"86";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    testDataIn <= x"a0"; -- reset every 1e8*10ns = 1s
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;

    wait for 50 us;

    testDataIn <= x"a6";
    wait for clkPeriod100M*delay;
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
    testDataIn <= x"02";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';

    wait for 500 ns;
    
    t(0) <= '0';
    wait for clkPeriod100M;
    t(0) <= '1';

    wait for clkPeriod100M;

    t(0) <= '0';
    wait for clkPeriod100M;
    t(0) <= '1';

    wait for clkPeriod100M;

    t(0) <= '0';
    wait for clkPeriod100M;
    t(0) <= '1';

    wait for clkPeriod100M;

    testDataIn <= x"a6";
    wait for clkPeriod100M*delay;
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
    testDataIn <= x"02";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';

    wait;
end process;

uut: trgSamplerCtrl
generic map(
    trgNum     => trgNum
)
port map(
    clk        => clk_100M,
    clkTmr     => clk_100M,
    rst        => rst,
    trgIn      => t,
    devExec    => devExec,
    devId      => devId,
    devRw      => devRw,
    devBrst    => devBrst,
    devBrstWrt => devBrstWrt,
    devBrstSnd => devBrstSnd,
    devBrstRst => devBrstRstRM,
    devAddr    => devAddr,
    devDataIn  => dataToDev,
    devDataOut => dataFromRM,
    devReady   => devReadyRM,
    busy       => rmBusy
);

clk_100M <= not clk_100M after clkPeriod100M/2;

devDataInVec(acqSystem) <= dataFromRM;
devReadyVec(acqSystem)  <= devReadyRM;
devBusyVec(acqSystem)   <= rmBusy;
devBrstRst(acqSystem)   <= devBrstRstRM;

devInterfInst: deviceInterface
generic map(
    clkFreq      => clkFreq,
    timeout      => timeout,
    readCmd      => readCmd,
    writeCmd     => writeCmd,
    burstWrCmd   => burstWrCmd,
    burstRdCmd   => burstRdCmd,
    maxBrstLen   => maxBrstLen
)
port map(
    clk          => clk_100M,
    rst          => rst,
    dataIn       => dataFromMaster,
    dataOut      => dataToMaster,
    rxRead       => rxRead,
    rxPresent    => rxPresent,
    txWrite      => txWrite,
    rxEna        => rxEna,
    txWrAck      => txWrAck,
    flushRxFifo  => flushRxFifo,
    devId        => devId,
    devReady     => devReadyVec,
    devBusy      => devBusyVec,
    devRw        => devRw,
    devBrst      => devBrst,
    devBrstWrt   => devBrstWrt,
    devBrstSnd   => devBrstSnd,
    devBrstRst   => devBrstRst,
    devAddr      => devAddr,
    devDataIn    => devDataInVec,
    devDataOut   => dataToDev,
    devExec      => devExec,
    busy         => devIntBusy,
    error        => error
);

spiSlaveInst: entity work.SPISlave
port map(
    clk          => clk_100M,
    rst          => rst,
    data_out     => dataFromMaster,
    data_in      => dataToMaster,
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
    rx_reset     => flushRxFifo,
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
    clk          => clk_100M,
    rst          => rst,
    data_out     => testDataOut,
    data_in      => testDataIn,
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
