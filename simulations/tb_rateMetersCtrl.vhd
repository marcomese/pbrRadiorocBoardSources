library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.devicesPkg.all;

entity tb_rateMetersCtrl is
end tb_rateMetersCtrl;

library UNISIM;
use UNISIM.vcomponents.all;

library UNIMACRO;
use UNIMACRO.vcomponents.all;

architecture Behavioral of tb_rateMetersCtrl is

constant clkPeriod100M : time                         := 10 ns;
constant clkFreq       : real                         := 100.0e6;
constant sclkFreq      : real                         := 20.0e6;
constant timeout       : real                         := 1.0;
constant idHeader      : std_logic_vector(3 downto 0) := x"7";
constant broadcastId   : std_logic_vector(3 downto 0) := x"F";
constant readCmd       : std_logic_vector(3 downto 0) := x"A";
constant writeCmd      : std_logic_vector(3 downto 0) := x"5";
constant burstWrCmd    : std_logic_vector(3 downto 0) := x"3";
constant burstRdCmd    : std_logic_vector(3 downto 0) := x"B";
constant maxBrstLen    : natural                      := 2048;
constant delay         : natural                      := 1;--50000;
constant trgNum        : natural                      := 128;

signal rst               : std_logic := '0';
signal clk_100M          : std_logic := '1';
signal t           : std_logic_vector(127 downto 0) := (others => '0');
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
signal rxValid           : std_logic                    := '0';
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
signal id             : std_logic_vector(3 downto 0) := (others => '0');
signal testMeter, testMeterL      : std_logic_vector(31 downto 0) := (others => '0');
signal testT   : std_logic := '0';
signal testRst : std_logic := '1';
begin

stimProc: process
begin
    rst <= '1';
    testRst <= '1';
    wait for clkPeriod100M*5;
    rst <= '0';
    testRst <= '0';
    id  <= "0110";

    wait until rising_edge(clk_100M);
    testT <= '1';
    
    wait until rising_edge(clk_100M);
    testT <= '0';

    wait until rising_edge(clk_100M);
    testT <= '1';
    
    wait until rising_edge(clk_100M);
    testT <= '0';

    wait until rising_edge(clk_100M);
    testT <= '1';
    
    wait until rising_edge(clk_100M);
    testT <= '0';

    testRst <= '1';
    wait for clkPeriod100M;
    testRst <= '0';

    wait until rising_edge(clk_100M);
    testT <= '1';
    
    wait until rising_edge(clk_100M);
    testT <= '0';

    wait until rising_edge(clk_100M);
    testT <= '1';
    
    wait until rising_edge(clk_100M);
    testT <= '0';


--    wait for 1 us;

--    testDataIn <= x"76";
--    wait for clkPeriod100M*delay;
--    testTxWrite <= '1';
--    wait for clkPeriod100M;
--    testTxWrite <= '0';
--    wait for clkPeriod100M*delay;
--    testDataIn <= x"a6";
--    wait for clkPeriod100M*delay;
--    testTxWrite <= '1';
--    wait for clkPeriod100M;
--    testTxWrite <= '0';
--    wait for clkPeriod100M*delay;
--    testDataIn <= x"00";
--    testTxWrite <= '1';
--    wait for clkPeriod100M;
--    testTxWrite <= '0';
--    wait for clkPeriod100M*delay;
--    testDataIn <= x"76";
--    testTxWrite <= '1';
--    wait for clkPeriod100M;
--    testTxWrite <= '0';
    
--        wait for 350 us;
    
--    wait for clkPeriod100M*delay;
--    testDataIn <= x"76";
--    wait for clkPeriod100M*delay;
--    testTxWrite <= '1';
--    wait for clkPeriod100M;
--    testTxWrite <= '0';
--    wait for clkPeriod100M*delay;
--    testDataIn <= x"a6";
--    wait for clkPeriod100M*delay;
--    testTxWrite <= '1';
--    wait for clkPeriod100M;
--    testTxWrite <= '0';
--    wait for clkPeriod100M*delay;
--    testDataIn <= x"00";
--    testTxWrite <= '1';
--    wait for clkPeriod100M;
--    testTxWrite <= '0';
--    wait for clkPeriod100M*delay;
--    testDataIn <= x"71";
--    testTxWrite <= '1';
--    wait for clkPeriod100M;
--    testTxWrite <= '0';

--    wait for 350 ns;

    testDataIn <= x"76";
    wait for clkPeriod100M*delay;
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
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

    testDataIn <= x"76";
    wait for clkPeriod100M*delay;
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
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
    testDataIn <= x"01";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';

    wait for 500 ns;
    
    wait until rising_edge(clk_100M);
    t(trgNum-1) <= '1';
    t(0)        <= '1';
    
    wait until rising_edge(clk_100M);
    t(trgNum-1) <= '0';
    t(0)        <= '0';

    wait until rising_edge(clk_100M);
    wait until rising_edge(clk_100M);
    t(trgNum-1) <= '1';
    t(0)        <= '1';
    
    wait until rising_edge(clk_100M);
    t(trgNum-1) <= '0';
    t(0)        <= '0';

    wait until rising_edge(clk_100M);
    wait until rising_edge(clk_100M);
    t(trgNum-1) <= '1';
    t(0)        <= '1';
    
    wait until rising_edge(clk_100M);
    t(trgNum-1) <= '0';
    t(0)        <= '0';
 
    wait for clkPeriod100M;

    testDataIn <= x"76";
    wait for clkPeriod100M*delay;
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
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

    wait for 1 us;

    testDataIn <= x"76";
    wait for clkPeriod100M*delay;
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
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
    testDataIn <= x"70";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';

    wait for 500 ns;

    testDataIn <= x"76";
    wait for clkPeriod100M*delay;
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;
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
    testDataIn <= x"71";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';

    wait for 500 ns;

    wait;
end process;

testCntInst: COUNTER_TC_MACRO
generic map(
    COUNT_BY      => X"000000000001",
    DEVICE        => "7SERIES",
    DIRECTION     => "UP",
    RESET_UPON_TC => "FALSE",
    TC_VALUE      => X"000000000000",
    WIDTH_DATA    => 32
)
port map(
    CLK => clk_100M,
    RST => testRst,
    Q   => testMeter,
    CE  => testT
);

uut: entity work.rateMetersCtrl
generic map(
    trgNum     => trgNum
)
port map(
    clk        => clk_100M,
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

devDataInVec(rateMeters) <= dataFromRM;
devReadyVec(rateMeters)  <= devReadyRM;
devBusyVec(rateMeters)   <= rmBusy;
devBrstRst(rateMeters)   <= devBrstRstRM;

devInterfInst: entity work.deviceInterface
generic map(
    clkFreq      => clkFreq,
    timeout      => timeout,
    idHeader     => idHeader,
    broadcastId  => broadcastId,
    readCmd      => readCmd,
    writeCmd     => writeCmd,
    burstWrCmd   => burstWrCmd,
    burstRdCmd   => burstRdCmd,
    maxBrstLen   => maxBrstLen
)
port map(
    clk          => clk_100M,
    rst          => rst,
    id           => id,
    dataIn       => dataFromMaster,
    dataOut      => dataToMaster,
    rxRead       => rxRead,
    rxPresent    => rxPresent,
    rxValid      => rxValid,
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
generic map(
    maxBrstLen   => maxBrstLen
)
port map(
    clk          => clk_100M,
    rst          => rst,
    data_out     => dataFromMaster,
    data_in      => dataToMaster,
    rx_read      => rxRead,
    rx_ena       => rxEna,
    rx_present   => rxPresent,
    rx_valid     => rxValid,
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

spiInst: entity work.SPIMaster
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
