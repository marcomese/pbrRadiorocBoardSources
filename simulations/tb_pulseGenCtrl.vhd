library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.devicesPkg.all;

entity tb_pulseGenCtrl is
end tb_pulseGenCtrl;

architecture Behavioral of tb_pulseGenCtrl is

component pulseGenCtrl
generic(
    clkFreq      : real;
    sleepOnPwrOn : boolean;
    pwrOnTime    : real;
    settlingTime : real
);
port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    devId        : in  devices_t;
    devReady     : out std_logic;
    devRw        : in  std_logic;
    devAddr      : in  devAddr_t;
    devDataIn    : in  devData_t;
    devDataOut   : out devData_t;
    devExec      : in  std_logic;
    busy         : out std_logic;
    pulse        : out std_logic;
    pulsing      : out std_logic;
    dacSDI       : out std_logic;
    dacSCLK      : out std_logic;
    dacCS        : out std_logic
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

constant clkPeriod    : time      := 10 ns;
constant dacClkPeriod : time      := 100 ns;
constant clkFreq      : real      := 100.0e6;
constant sclkFreq     : real      := 20.0e6;
constant timeout      : real      := 1.0e-6;
constant sleepOnPwrOn : boolean   := True;
constant pwrOnTime    : real      := 20.0e-6;
constant settlingTime : real      := 5.0e-6;

constant chipID         : std_logic_vector(3 downto 0) := "0000";
constant readCmd        : std_logic_vector(3 downto 0) := x"A";
constant writeCmd       : std_logic_vector(3 downto 0) := x"5";
constant burstWrCmd     : std_logic_vector(3 downto 0) := x"3";
constant burstRdCmd     : std_logic_vector(3 downto 0) := x"B";
constant tmpAddr        : std_logic_vector(6 downto 0) := "1001000";
constant readPeriod     : real      := 1.0;

signal   clk          : std_logic := '1';
signal   rst          : std_logic := '0';
signal   devId        : devices_t := none;
signal   devReady     : std_logic := '0';
signal   devRw        : std_logic := '0';
signal   devBrst      : std_logic := '0';
signal   devBrstWrt   : std_logic := '0';
signal   devBrstSnd   : std_logic := '0';
signal   devBrstRst   : devStdLogic_t := (others => '0');
signal   devAddr      : devAddr_t := (others => (others => '0'));
signal   devExec      : std_logic := '0';
signal   txWrAck      : std_logic := '0';
signal   pgenBusy,
         devIntBusy   : std_logic := '0';
signal   pulse        : std_logic := '0';
signal   dacClk       : std_logic := '1';
signal   dacSDI       : std_logic := '0';
signal   dacSCLK      : std_logic := '0';
signal   dacCS        : std_logic := '0';
signal   dataToDev,
         dataFromRadioroc,
         dataFromTmp,
         dataFromDev  : devData_t := (others => (others => '0'));
signal   devDataInVec : devDataVec_t                 := (others => (others => (others => '0')));
signal   devReadyVec  : devStdLogic_t                := (others => '0');
signal   devBusyVec   : devStdLogic_t                := (others => '0');
signal   error        : std_logic_vector(2 downto 0) := "000";
signal   dataIn       : std_logic_vector(7 downto 0) := (others => '0');
signal   dataOut      : std_logic_vector(7 downto 0) := (others => '0');
signal   rxRead       : std_logic                    := '0';
signal   rxPresent    : std_logic                    := '0';
signal   txWrite      : std_logic                    := '0';
signal   rxEna,en_clki2c        : std_logic                    := '1';
signal   i2cAddrRad     : std_logic_vector(6 downto 0) := (others => '0');
signal   readRq,
         cs,
         sclk,
         miso,
         mosi,
         i2cEnaRad,       
         i2cRwRad,
         i2cBusyRad,
         devReadyRadioroc,
         devBusyRadioroc,
         testTxWrite,
         testRxRead,
         sc_sda,
         sc_scl, 
         rst_n,
         devReadyTmp,
         devBusyTmp, 
         pulsing,
         testRxPresent  : std_logic := '0';
signal   dataToMaster,
         testDataIn,
         testDataOut,
         dataFromMaster,
         i2cDataWrRad,    
         i2cDataRdRad       : std_logic_vector(7 downto 0) := (others => '0');

begin

rst_n <= not rst;

stimProc: process
begin
    rst <= '1';
    wait for clkPeriod*5;
    rst <= '0';
    wait for clkPeriod*5;

    testRxRead <= '1';

    testDataIn <= x"53";
    wait for clkPeriod;
    testTxWrite <= '1';
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"06";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"64";
    wait for clkPeriod;

    testDataIn <= x"53";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"05";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"14";
    wait for clkPeriod;

    testDataIn <= x"53";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"04";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"BB";
    wait for clkPeriod;
    testDataIn <= x"AA";
    wait for clkPeriod;

    testDataIn <= x"53";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"01";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"01";
    wait for clkPeriod;
    testTxWrite <= '0';

    wait for 24 us;

    testDataIn <= x"a3";
    wait for clkPeriod;
    testTxWrite <= '1';
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"05";
    wait for clkPeriod;
    testTxWrite <= '0';

    wait for 5 us;

    testDataIn <= x"53";
    wait for clkPeriod;
    testTxWrite <= '1';
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"03";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"01";
    wait for clkPeriod;
    testTxWrite <= '0';
    
    wait for 30 us;

    testDataIn <= x"53";
    wait for clkPeriod;
    testTxWrite <= '1';
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"01";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"01";
    wait for clkPeriod;
    testTxWrite <= '0';

--    wait for 20 us;

--    testDataIn <= x"a1";
--    wait for clkPeriod;
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testDataIn <= x"00";
--    wait for clkPeriod;
--    testDataIn <= x"01";
--    wait for clkPeriod;
--    testDataIn <= x"0A";
--    wait for clkPeriod;
--    testDataIn <= x"0B";
--    wait for clkPeriod;
--    testDataIn <= x"0C";
--    wait for clkPeriod;
--    testDataIn <= x"0D";
--    wait for clkPeriod;
--    testTxWrite <= '0';

    wait for 50 us;

    testDataIn <= x"53";
    wait for clkPeriod;
    testTxWrite <= '1';
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"01";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testTxWrite <= '0';

    wait for 30 us;

    testDataIn <= x"53";
    wait for clkPeriod;
    testTxWrite <= '1';
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"02";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"01";
    wait for clkPeriod;
    testTxWrite <= '0';

    wait for 40 us;

    testDataIn <= x"53";
    wait for clkPeriod;
    testTxWrite <= '1';
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"02";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;

    testDataIn <= x"53";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"04";
    wait for clkPeriod;
    testDataIn <= x"0A";
    wait for clkPeriod;
    testDataIn <= x"0B";
    wait for clkPeriod;
    testDataIn <= x"0C";
    wait for clkPeriod;
    testDataIn <= x"0D";
    wait for clkPeriod;
    testTxWrite <= '0';

    wait;
end process;

clk <= not clk after clkPeriod/2;

dacClk <= not dacClk after dacClkPeriod/2;

uut: pulseGenCtrl
generic map(
    clkFreq      => clkFreq,
    sleepOnPwrOn => sleepOnPwrOn,
    pwrOnTime    => pwrOnTime,
    settlingTime => settlingTime
)
port map(
    clk          => clk,
    rst          => rst,
    devId        => devId,
    devReady     => devReady,
    devRw        => devRw,
    devAddr      => devAddr,
    devDataIn    => dataToDev,
    devDataOut   => dataFromDev,
    devExec      => devExec,
    busy         => pgenBusy,
    pulse        => pulse,
    pulsing      => pulsing,
    dacSDI       => dacSDI,
    dacSCLK      => dacSCLK,
    dacCS        => dacCS
);

radInterfInst: entity work.radiorocInterface
generic map(
    chipID     => chipID
)
port map(
    clk        => clk,
    rst        => rst,
    devExec    => devExec,
    devId      => devId,
    devRw      => devRw,
    devBrst    => devBrst,
    devAddr    => devAddr,
    devDataIn  => dataToDev,
    devDataOut => dataFromRadioroc,
    devReady   => devReadyRadioroc,
    busy       => devBusyRadioroc,
    i2cEnClk   => en_clki2c,
    i2cEna     => i2cEnaRad,
    i2cAddr    => i2cAddrRad,
    i2cRw      => i2cRwRad,
    i2cDataWr  => i2cDataWrRad,
    i2cBusy    => i2cBusyRad,
    i2cDataRd  => i2cDataRdRad
);

tmpCtrlInst: entity work.tmpCtrl
generic map(
    clkFreq    => clkFreq,
    readPeriod => readPeriod,
    tmpAddr    => tmpAddr
)
port map(
    clk        => clk,
    rst        => rst,
    devExec    => devExec,
    devId      => devId,
    devRw      => devRw,
    devAddr    => devAddr,
    devDataIn  => dataToDev,
    devDataOut => dataFromTmp,
    devReady   => devReadyTmp,
    busy       => devBusyTmp,
    i2cEna     => i2cEnaRad,
    i2cAddr    => i2cAddrRad,
    i2cRw      => i2cRwRad,
    i2cDataWr  => i2cDataWrRad,
    i2cBusy    => i2cBusyRad,
    i2cDataRd  => i2cDataRdRad
);

i2cRadModule: entity work.i2cMaster
generic map(
    input_clk => 100000000,
    bus_clk   => 500000
)
port map(
    clk       => clk,
    reset_n   => rst_n,
    ena       => i2cEnaRad,
    addr      => i2cAddrRad,
    rw        => i2cRwRad,
    data_wr   => i2cDataWrRad,
    busy      => i2cBusyRad,
    data_rd   => i2cDataRdRad,
    ack_error => open,
    sda       => sc_sda,
    scl       => sc_scl
);

devDataInVec(pulseGen) <= dataFromDev;
devReadyVec(pulseGen)  <= devReady;
devBusyVec(pulseGen)   <= pgenBusy;

devDataInVec(tmp275) <= dataFromTmp;
devReadyVec(tmp275)  <= devReadyTmp;
devBusyVec(tmp275)   <= devBusyTmp;

devDataInVec(radioroc) <= dataFromRadioroc;
devReadyVec(radioroc)  <= devReadyRadioroc;
devBusyVec(radioroc)   <= devBusyRadioroc;

devInterfInst: deviceInterface
generic map(
    clkFreq    => clkFreq,
    timeout    => timeout,
    readCmd    => readCmd,
    writeCmd   => writeCmd,
    burstWrCmd => burstWrCmd,
    burstRdCmd => burstRdCmd,
    maxBrstLen => 100
)
port map(
    clk        => clk,
    rst        => rst,
    dataIn     => dataFromMaster,
    dataOut    => dataToMaster,
    rxRead     => rxRead,
    rxPresent  => rxPresent,
    txWrite    => txWrite,
    txWrAck    => txWrAck,
    rxEna      => rxEna,
    devId      => devId,
    devReady   => devReadyVec,
    devBusy    => devBusyVec,
    devRw      => devRw,
    devBrst    => devBrst,
    devBrstWrt => devBrstWrt,
    devBrstSnd => devBrstSnd,
    devBrstRst => devBrstRst,
    devAddr    => devAddr,
    devDataIn  => devDataInVec,
    devDataOut => dataToDev,
    devExec    => devExec,
    busy       => devIntBusy,
    error      => error
);

spiSlaveInst: entity work.SPISlave
port map(
    clk          => clk,
    rst          => rst,
    data_out     => dataFromMaster,
    data_in      => dataToMaster,
    rx_read      => rxRead,
    rx_ena       => rxEna,
    rx_present   => rxPresent,
    rx_half_full => open,
    rx_full      => open,
    tx_write     => txWrite,
    tx_present   => open,
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