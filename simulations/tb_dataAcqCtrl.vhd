library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.devicesPkg.all;

entity tb_dataAcqCtrl is
end tb_dataAcqCtrl;

architecture Behavioral of tb_dataAcqCtrl is

component dataAcqCtrl is
port(
    clk100M    : in  std_logic;
    rst        : in  std_logic;
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
    busy       : out std_logic;
    resetAcq   : out std_logic;
    startAcq   : out std_logic;
    endAcq     : in  std_logic;
    rdValid    : in  std_logic;
    rdAcq      : out std_logic;
    rdDataCnt  : in  std_logic_vector(15 downto 0);
    emptyAcq   : in  std_logic;
    nbAcq      : out std_logic_vector(7 downto 0);
    selAdc     : out std_logic_vector(63 downto 0);
    doutAcq    : in  std_logic_vector(7 downto 0)
);
end component;

component adc is
 Port (
  rst   : in std_logic;
  clk_100M : in std_logic;
  clkN_100M : in std_logic;
  clk_200M : in std_logic;
  clkN_200M : in std_logic;
  clk_500M : in std_logic;
  start    : in std_logic;
  sdo_hg  : IN STD_LOGIC;
  sdo_lg  : IN STD_LOGIC;
  NORT1  : in std_logic;
  NORT2   : in std_logic;
  NORTQ    : in std_logic;
  nb_acq   : in std_logic_vector(7 downto 0);
  t   : in std_logic_vector(63 downto 0);
  sel_adc : in std_logic_vector(63 downto 0);
  rd_en   : in std_logic;
  dout   : out std_logic_vector(7 downto 0);
  reset_n    : out std_logic;
  rstb_rd  : out std_logic;
  ck_read  : out std_logic;
  n_cnv   : out std_logic;
  adc_sck  : out std_logic;
  empty_acq : out std_logic;
  end_multi_acq : out std_logic;
  rd_data_count_acq : out std_logic_vector(15 downto 0);
  hold_ext : out std_logic;
  trig_ext : out std_logic;
  trig_out : out std_logic;
  evtTrigger : out std_logic;
  pulse : in std_logic;
  pulsing : in std_logic;
  extTrg : in std_logic;
  endAcq : out std_logic;
  rdValid : out std_logic;
  test : out std_logic
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

COMPONENT i2cMaster IS
  GENERIC(
    input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
    bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
  PORT(
    clk       : IN     STD_LOGIC;                    --system clock
    reset_n   : IN     STD_LOGIC;                    --active low reset
    ena       : IN     STD_LOGIC;                    --latch in command
    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
    data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
    sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
    scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
END COMPONENT;

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
constant clkPeriod200M : time                         := 5 ns;
constant clkPeriod25M  : time                         := 40 ns;
constant clkFreq       : real                         := 100.0e6;
constant sclkFreq      : real                         := 20.0e6;
constant timeout       : real                         := 1.0;
constant readCmd       : std_logic_vector(3 downto 0) := x"A";
constant writeCmd      : std_logic_vector(3 downto 0) := x"5";
constant burstWrCmd    : std_logic_vector(3 downto 0) := x"3";
constant burstRdCmd    : std_logic_vector(3 downto 0) := x"B";
constant maxBrstLen    : natural                      := 14000;
constant delay         : natural                      := 1;--50000;

signal rst               : std_logic := '0';
signal clk_100M          : std_logic := '1';
signal clkN_100M          : std_logic := '0';
signal clk_200M          : std_logic := '1';
signal clkN_200M          : std_logic := '0';
signal clk_500M          : std_logic := '0';
signal clk_25M           : std_logic := '1';
signal start             : std_logic := '0';
signal resetAcq          : std_logic    := '0';
signal sdo_hg          : std_logic := '0';
signal sdo_lg          : std_logic := '0';
signal NORT1          : std_logic := '0';
signal NORT2           : std_logic := '0';
signal NORTQ             : std_logic := '0';
signal nb_acq            : std_logic_vector(7 downto 0)  := (others => '0');
signal t           : std_logic_vector(63 downto 0) := (others => '0');
signal sel_adc           : std_logic_vector(63 downto 0) := (others => '0');
signal rd_en           : std_logic := '0';
signal dout           : std_logic_vector(7 downto 0)  := (others => '0');
signal reset_n           : std_logic := '0';
signal rstb_rd           : std_logic := '0';
signal ck_read           : std_logic := '0';
signal n_cnv           : std_logic := '0';
signal adc_sck           : std_logic := '0';
signal empty_acq         : std_logic := '0';
signal end_multi_acq     : std_logic := '0';
signal rd_data_count_acq : std_logic_vector(15 downto 0) := (others => '0');
signal hold_ext          : std_logic := '0';
signal trig_ext          : std_logic := '0';
signal trig_out          : std_logic := '0';
signal extTrg            : std_logic := '0';
signal endAcq            : std_logic := '0';
signal test              : std_logic := '0';
signal devId             : devices_t    := none;
signal devReadyAcq       : std_logic    := '0';
signal devRw             : std_logic    := '0';
signal devBrst           : std_logic    := '0';
signal devBrstWrt        : std_logic    := '0';
signal devBrstSnd        : std_logic    := '0';
signal devBrstRst        : devStdLogic_t := (others => '0');
signal devAddr           : devAddr_t    := (others => (others => '0'));
signal devExec           : std_logic    := '0';
signal dataToDev,
       dataFromAcq       : devData_t     := (others => (others => '0'));
signal devDataInVec      : devDataVec_t  := (others => (others => (others => '0')));
signal devReadyVec       : devStdLogic_t := (others => '0');
signal devBusyVec        : devStdLogic_t := (others => '0');
signal acqBusy           : std_logic     := '0';
signal error             : std_logic_vector(2 downto 0) := "000";
signal rxRead            : std_logic                    := '0';
signal rxPresent         : std_logic                    := '0';
signal txWrite           : std_logic                    := '0';
signal txWrAck           : std_logic                    := '0';
signal flushRxFifo       : std_logic                    := '0';
signal pulsing       : std_logic                    := '0';
signal pulse       : std_logic                    := '0';
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
       devBrstRstAcq,
       rdValid,
       evtTrigger        : std_logic                     := '0';
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

    testDataIn <= x"55";
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
    testDataIn <= x"04";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    testDataIn <= x"04";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;

    wait for 100 us;

    testRxRead <= '1';

    testDataIn <= x"55";
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
    testDataIn <= x"00";
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
    wait for clkPeriod100M*delay;

    wait for 10 us;

    extTrg <= '1';
    wait for clkPeriod100M;
    extTrg <= '0';

    wait for 100 us;

    testDataIn <= x"b5";
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
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    testDataIn <= x"00";
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
    testDataIn <= x"05";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;

    wait for 600 us;

    testDataIn <= x"b5";
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
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    testDataIn <= x"00";
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
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod100M;
    testTxWrite <= '0';
    wait for clkPeriod100M*delay;

    wait;
end process;

dataAcqCtrlInst : dataAcqCtrl
port map(
    clk100M     => clk_100M,
    rst         => rst,
    devExec     => devExec,
    devId       => devId,
    devRw       => devRw,
    devBrst     => devBrst,
    devBrstWrt  => devBrstWrt,
    devBrstSnd  => devBrstSnd,
    devBrstRst  => devBrstRstAcq,
    devAddr     => devAddr,
    devDataIn   => dataToDev,
    devDataOut  => dataFromAcq,
    devReady    => devReadyAcq,
    busy        => acqBusy,
    resetAcq    => resetAcq,
    startAcq    => start,
    endAcq      => endAcq,
    rdValid     => rdValid,
    rdAcq       => rd_en,
    rdDataCnt   => rdDataCnt,
    emptyAcq    => empty_acq,
    nbAcq       => nb_acq,
    selAdc      => sel_adc,
    doutAcq     => dout
);

adcInst: adc
port map(
    rst               => resetAcq,
    clk_100M          => clk_100M,
    clkN_100M          => clkN_100M,
    clk_200M          => clk_200M,
    clkN_200M          => clkN_200M,
    clk_500M          => clk_500M,
    start             => start,
    sdo_hg            => sdo_hg,
    sdo_lg            => sdo_lg,
    NORT1             => NORT1,
    NORT2             => NORT2,
    NORTQ             => NORTQ,
    nb_acq            => nb_acq,
    t                 => t,
    sel_adc           => sel_adc,
    rd_en             => rd_en,
    dout              => dout,
    reset_n           => reset_n,
    rstb_rd           => rstb_rd,
    ck_read           => ck_read,
    n_cnv             => n_cnv,
    adc_sck           => adc_sck,
    empty_acq         => empty_acq,
    end_multi_acq     => end_multi_acq,
    rd_data_count_acq => rd_data_count_acq,
    hold_ext          => hold_ext,
    trig_ext          => trig_ext,
    trig_out          => trig_out,
    evtTrigger        => evtTrigger,
    extTrg            => extTrg,
    pulsing           => pulsing,
    pulse             => pulse,
    endAcq            => endAcq,
    rdValid           => rdValid,
    test              => test
);

clk_100M <= not clk_100M after clkPeriod100M/2;
clkN_100M <= not clkN_100M after clkPeriod100M/2;
clk_200M <= not clk_200M after clkPeriod200M/2;
clkN_200M <= not clkN_200M after clkPeriod200M/2;

devDataInVec(acqSystem) <= dataFromAcq;
devReadyVec(acqSystem)  <= devReadyAcq;
devBusyVec(acqSystem)   <= acqBusy;
devBrstRst(acqSystem)   <= devBrstRstAcq;

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
