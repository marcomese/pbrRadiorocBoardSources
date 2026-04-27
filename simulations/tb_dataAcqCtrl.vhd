library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.devicesPkg.all;

entity tb_dataAcqCtrl is
end tb_dataAcqCtrl;

architecture Behavioral of tb_dataAcqCtrl is

constant clkPeriod200M : time                         := 5 ns;
constant clkPeriod100M : time                         := 10 ns;
constant clkFreq       : real                         := 200.0e6;
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

signal rst               : std_logic := '0';
signal clk_200M          : std_logic := '1';
signal clk_100M          : std_logic := '1';
signal start             : std_logic := '0';
signal resetAcq          : std_logic    := '0';
signal sdo_hg          : std_logic := '0';
signal sdo_lg          : std_logic := '0';
signal NORT1          : std_logic := '1';
signal NORT2           : std_logic := '1';
signal NORTQ             : std_logic := '1';
signal nb_acq            : std_logic_vector(7 downto 0)  := (others => '0');
signal t           : std_logic_vector(63 downto 0) := (others => '1');
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
signal rxValid           : std_logic                    := '0';
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
signal id             : std_logic_vector(3 downto 0) := (others => '0');

begin

stimProc: process
begin
    rst <= '1';
    wait for clkPeriod200M*5;
    rst <= '0';
    id  <= "0110";
    wait for clkPeriod200M*5;

    wait for 350 ns;

    testDataIn <= x"76";
    wait for clkPeriod200M*delay;
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"55";
    wait for clkPeriod200M*delay;
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"03";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"02";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;

    wait for 5 us;

    testDataIn <= x"76";
    wait for clkPeriod200M*delay;
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"A5";
    wait for clkPeriod200M*delay;
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"05";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;

    wait for 100 us;

    testRxRead <= '1';

    testDataIn <= x"76";
    wait for clkPeriod200M*delay;
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"55";
    wait for clkPeriod200M*delay;
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"01";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"01";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;

    wait for 10 us;

    NORT1 <= '0';
    wait for clkPeriod200M;
    NORT1 <= '1';

    wait for 100 us;

    testDataIn <= x"76";
    wait for clkPeriod200M*delay;
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"b5";
    wait for clkPeriod200M*delay;
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"01";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"05";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;

    wait for 600 us;

    testDataIn <= x"76";
    wait for clkPeriod200M*delay;
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"b5";
    wait for clkPeriod200M*delay;
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"01";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    testDataIn <= x"00";
    testTxWrite <= '1';
    wait for clkPeriod200M;
    testTxWrite <= '0';
    wait for clkPeriod200M*delay;

    wait;
end process;

dataAcqCtrlInst: entity work.dataAcqCtrl
port map(
    clk100M     => clk_200M,
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

adcInst: entity work.adc
port map(
    rst               => resetAcq,
    clk_100M          => clk_100M,
    clk_200M          => clk_200M,
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
    rdValid           => rdValid
);

clk_100M <= not clk_100M after clkPeriod100M/2;
clk_200M <= not clk_200M after clkPeriod200M/2;

devDataInVec(acqSystem) <= dataFromAcq;
devReadyVec(acqSystem)  <= devReadyAcq;
devBusyVec(acqSystem)   <= acqBusy;
devBrstRst(acqSystem)   <= devBrstRstAcq;

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
    clk          => clk_200M,
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
    clk          => clk_200M,
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
    clk          => clk_200M,
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
