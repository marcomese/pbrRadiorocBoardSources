library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use IEEE.STD_LOGIC_MISC.ALL;

library UNISIM;
use UNISIM.VComponents.all;

library xpm;
use xpm.vcomponents.all;

library xil_defaultlib;

use work.utilsPkg.all;
use work.devicesPkg.all;

entity radioroc_fw is
	port
	(
		sysClk_p    : in std_logic;
		sysClk_n    : in std_logic;
		npwr_reset    : in std_logic;

        id            : in std_logic_vector(2 downto 0);

		sc_scl        : inout std_logic;
		sc_sda        : inout std_logic;
		sc_clk_sm     : out   std_logic;
		sc_val_evt    : out   std_logic;
		sc_errorb     : in    std_logic;
		sc_rstn_read  : out   std_logic;
		sc_ck_read    : out   std_logic;
		sc_reset_n    : out   std_logic;
		sc_rstb_sc    : out   std_logic;
		sc_rstb_probe : out   std_logic;
		sc_rstb_i2c   : out   std_logic;
		sc_outd_probe : in    std_logic;
		sc_holdext    : out   std_logic;
		sc_trigext    : out   std_logic;
		sc_NORT2      : in    std_logic;
		sc_NORT1      : in    std_logic;
		sc_NORTQ      : in    std_logic;

		T_1           : in std_logic_vector(63 downto 0);
		T_2           : in std_logic_vector(63 downto 0);

		ADC_SCKHG_p   : out std_logic;
		ADC_SCKHG_n   : out std_logic;
		ADC_SCKLG_p   : out std_logic;
		ADC_SCKLG_n   : out std_logic;
		ADC_HG_p      : in std_logic;
		ADC_HG_n      : in std_logic;
		ADC_LG_p      : in std_logic;
		ADC_LG_n      : in std_logic;
		nCNV          : out std_logic;
		nCMOS         : out std_logic;

		SCL_275       : inout std_logic;
		SDA_275       : inout std_logic;

        pulse         : out std_logic;
        dacSDI        : out std_logic;
        dacSCLK       : out std_logic;
        dacCS         : out std_logic;

        readRq_p      : out std_logic;
        readRq_n      : out std_logic;
        cs_p          : in  std_logic;
        cs_n          : in  std_logic;
        sclk_p        : in  std_logic;
        sclk_n        : in  std_logic;
        mosi_p        : in  std_logic;
        mosi_n        : in  std_logic;
        miso_p        : out std_logic;
        miso_n        : out std_logic;

		extTrg        : out std_logic
	);
end entity;

architecture arch of radioroc_fw is

    -- LVDS
	signal ADC_SCKHG, ADC_SCKLG, ADC_HG, ADC_LG : std_logic;
	signal T_1Buf, T_2Buf,
	       T_1Sync, T_2Sync,
	       tEdge1, tEdge2 : std_logic_vector(63 downto 0);
	signal tEdge21, TBuf21 : std_logic_vector(127 downto 0);
	-- Clock and reset
	signal reset, resetn, resetSig : std_logic;
	signal clk_10M, clk_20M, clk_200M : std_logic;
	signal sysClkDS : std_logic;
	-- I2C
    signal en_clki2c, enClkI2CSync : std_logic;

	--ADC Acquisition
	signal reset_acq, start_acq, rd_acq, adc_sck, end_acq, empty_acq, rstn_read_acq, reset_n_acq, trig_out : std_logic;
	signal nb_acq, dout_acq : std_logic_vector(7 downto 0);
	signal rd_data_count_acq : std_logic_vector(16 downto 0);
	signal sel_adc : std_logic_vector(63 downto 0);

-- CONSTANTS for deviceInterface, tmpCtrl and PulseGentCtrl

constant clkFreq        : real      := 200.0e6;
constant timeout        : real      := 1.0;
constant sleepOnPwrOn   : boolean   := True;
constant pwrOnTime      : real      := 20.0e-6;
constant settlingTime   : real      := 5.0e-6;
constant coarseBase     : real      := 1.0;

constant tmpAddr        : std_logic_vector(6 downto 0) := "1001000";
constant sipmHvAddr     : std_logic_vector(6 downto 0) := "1110011";
constant chipID         : std_logic_vector(3 downto 0) := "0000";

constant idHeader    : std_logic_vector(3 downto 0) := x"7";
constant broadcastId : std_logic_vector(3 downto 0) := x"F";
constant readCmd     : std_logic_vector(3 downto 0) := x"A";
constant writeCmd    : std_logic_vector(3 downto 0) := x"5";
constant burstRdCmd  : std_logic_vector(3 downto 0) := x"B";
constant burstWrCmd  : std_logic_vector(3 downto 0) := x"3";
constant maxBrstLen  : integer                      := 2048;

constant rstPORLen : integer := 10;

signal   dataToDev,
         dataFromPGen,
         dataFromTmp,
         dataFromRadioroc,
         dataFromAcq,
         dataFromRM,
         dataFromTSmpl     : devData_t;
signal   devDataInVec      : devDataVec_t;
signal   devReadyVec,
         devBusyVec,
         devBrstRst        : devStdLogic_t;

signal   devId          : devices_t;

signal   devReadyPGen,
         devReadyTmp,
         devReadyRadioroc,
         devReadyAcq,
         devReadyRM,
         devReadyTSmpl,
         devRw,
         devBrst,
         devBrstWrt,
         devBrstSnd,
         devExec,
         devBusyPGen,
         devBusyTmp,
         devBusyRadioroc,
         devBusyAcq,
         devBusyRM,
         devBusyTSmpl,
         devBrstRstAcq,
         devBrstRstRM,
         devBrstRstTSmpl,
         devIntBusy,
         pulseSig,
         pulsingSig,
         evtTrigger     : std_logic;
signal   devAddr        : devAddr_t;

-- SIGNALS FOR spiSlave --
signal   error          : std_logic_vector(2 downto 0);
signal   rxRead         : std_logic;
signal   rxPresent      : std_logic;
signal   rxValid        : std_logic;
signal   txWrite        : std_logic;
signal   rxEna          : std_logic;
signal   txWrAck        : std_logic;
signal   i2cEna         : std_logic;
signal   i2cAddr        : std_logic_vector(6 downto 0);
signal   i2cRw          : std_logic;
signal   i2cDataWr      : std_logic_vector(7 downto 0);
signal   i2cBusy        : std_logic;
signal   i2cDataRd      : std_logic_vector(7 downto 0);
signal   i2cEnaRad      : std_logic;
signal   i2cAddrRad     : std_logic_vector(6 downto 0);
signal   i2cRwRad       : std_logic;
signal   i2cDataWrRad   : std_logic_vector(7 downto 0);
signal   i2cBusyRad     : std_logic;
signal   i2cDataRdRad   : std_logic_vector(7 downto 0);
signal   areset         : std_logic;
signal   dataToMaster,
         dataFromMaster : std_logic_vector(7 downto 0);

signal   tFine   : std_logic_vector(31 downto 0);
signal   tCoarse : std_logic_vector(31 downto 0);
signal   tStamp  : std_logic_vector(63 downto 0);

signal extTrgFF, extTrgSig : std_logic;

signal idSync : std_logic_vector(2 downto 0);

signal boardID : std_logic_vector(3 downto 0);

signal readRq,
       cs,
       sclk,
       mosi,
       miso,
       csSync,
       sclkSync,
       mosiSync  : std_logic;

signal endAcq, rdValid : std_logic;

signal clkCnt : unsigned(4 downto 0); -- MSB = overflow

signal clk10MT : std_logic;

begin

areset        <= not npwr_reset;

sc_val_evt    <= '1';

sc_reset_n    <= reset_n_acq;

sc_rstn_read  <= rstn_read_acq;

sc_rstb_i2c   <= en_clki2c and resetn;

sc_rstb_sc    <= resetn;

sc_rstb_probe <= resetn;

pulse         <= pulseSig;

nCMOS         <= '1';

tEdge21       <= tEdge2 & tEdge1;

TBuf21        <= T_2Buf & T_1Buf;

ADC_SCKHG     <= adc_sck;

ADC_SCKLG     <= adc_sck;

boardID       <= '0' & idSync;

resetNSync: xpm_cdc_async_rst
generic map(
  DEST_SYNC_FF    => 4,
  INIT_SYNC_FF    => 0,
  RST_ACTIVE_HIGH => 0
)
port map(
    dest_clk  => clk_200M,
    src_arst  => npwr_reset,
    dest_arst => resetn
);

resetSync: xpm_cdc_async_rst
generic map(
  DEST_SYNC_FF    => 4,
  INIT_SYNC_FF    => 0,
  RST_ACTIVE_HIGH => 1
)
port map(
    dest_clk  => clk_200M,
    src_arst  => areset,
    dest_arst => resetSig
);

resetBUFG: BUFG
port map(
    I => resetSig,
    O => reset
);

T1SyncInst: xpm_cdc_array_single
generic map(
    DEST_SYNC_FF   => 2,
    INIT_SYNC_FF   => 0,
    SIM_ASSERT_CHK => 0,
    SRC_INPUT_REG  => 0,
    WIDTH          => T_1'length
)
port map(
    src_clk  => '0',
    dest_clk => clk_200M,
    src_in   => T_1Buf,
    dest_out => T_1Sync
);

T2SyncInst: xpm_cdc_array_single
generic map(
    DEST_SYNC_FF   => 2,
    INIT_SYNC_FF   => 0,
    SIM_ASSERT_CHK => 0,
    SRC_INPUT_REG  => 0,
    WIDTH          => T_2'length
)
port map(
    src_clk  => '0',
    dest_clk => clk_200M,
    src_in   => T_2Buf,
    dest_out => T_2Sync
);

idSyncInst: xpm_cdc_array_single
generic map(
    DEST_SYNC_FF   => 2,
    INIT_SYNC_FF   => 0,
    SIM_ASSERT_CHK => 0,
    SRC_INPUT_REG  => 0,
    WIDTH          => id'length
)
port map(
    src_clk  => '0',
    dest_clk => clk_200M,
    src_in   => id,
    dest_out => idSync
);

csSyncInst: xpm_cdc_single
generic map(
    DEST_SYNC_FF   => 2,
    INIT_SYNC_FF   => 0,
    SIM_ASSERT_CHK => 0,
    SRC_INPUT_REG  => 0
)
port map(
    src_clk  => '0',
    dest_clk => clk_200M,
    src_in   => cs,
    dest_out => csSync
);

sclkSyncInst: xpm_cdc_single
generic map(
    DEST_SYNC_FF   => 2,
    INIT_SYNC_FF   => 0,
    SIM_ASSERT_CHK => 0,
    SRC_INPUT_REG  => 0
)
port map(
    src_clk  => '0',
    dest_clk => clk_200M,
    src_in   => sclk,
    dest_out => sclkSync
);

mosiSyncInst: xpm_cdc_single
generic map(
    DEST_SYNC_FF   => 2,
    INIT_SYNC_FF   => 0,
    SIM_ASSERT_CHK => 0,
    SRC_INPUT_REG  => 0
)
port map(
    src_clk  => '0',
    dest_clk => clk_200M,
    src_in   => mosi,
    dest_out => mosiSync
);

inTrg1Sync: entity work.trgSync
generic map(
    trgNum => T_1Sync'length
)
port map(
    clk  => clk_200M,
    rst  => reset,
    tIn  => T_1Sync,
    tOut => tEdge1
);

inTrg2Sync: entity work.trgSync
generic map(
    trgNum => T_2Sync'length
)
port map(
    clk  => clk_200M,
    rst  => reset,
    tIn  => T_2Sync,
    tOut => tEdge2
);

extTrgFF  <= '0';
extTrgSig <= '0';

extTrg <= miso;
--extTrgSync: process(clk_200M)
--begin
--    if rising_edge(clk_200M) then
--        if pwrOnRst = '1' then
--            extTrgFF  <= '0';
--            extTrgSig <= '0';
--        else
--            extTrgFF  <= extTrg;
--            extTrgSig <= extTrgFF;
--        end if;
--    end if;
--end process;

IOs : entity xil_defaultlib.IO
port map(
    ADC_SCKHG => ADC_SCKHG,
    ADC_SCKLG => ADC_SCKLG,
    ADC_HG    => ADC_HG,
    ADC_LG    => ADC_LG,
    ADC_SCKHG_p => ADC_SCKHG_p,
    ADC_SCKHG_n => ADC_SCKHG_n,
    ADC_SCKLG_p => ADC_SCKLG_p,
    ADC_SCKLG_n => ADC_SCKLG_n,
    ADC_HG_p    => ADC_HG_p,
    ADC_HG_n    => ADC_HG_n,
    ADC_LG_p => ADC_LG_p,
    ADC_LG_n => ADC_LG_n,
    T1    => T_1,
    T1Buf => T_1Buf,
    T2    => T_2,
    T2Buf => T_2Buf,
    readRq   => readRq,
    readRq_p => readRq_p,
    readRq_n => readRq_n,
    cs       => cs,
    cs_p     => cs_p,
    cs_n     => cs_n,
    sclk     => sclk,
    sclk_p   => sclk_p,
    sclk_n   => sclk_n,
    mosi     => mosi,
    mosi_p   => mosi_p,
    mosi_n   => mosi_n,
    miso     => miso,
    miso_p   => miso_p,
    miso_n   => miso_n
);

sysClkIBUFDS: IBUFDS
generic map(
    DIFF_TERM    => TRUE,
    IBUF_LOW_PWR => FALSE,
    IOSTANDARD   => "LVDS_25"
)
port map(
    I  => sysClk_p,
    IB => sysClk_n,
    O  => sysClkDS
);

sysClkBUFG: BUFG
port map(
    I => sysClkDS,
    O => clk_200M
);

clkDividerProc: process(clk_200M)
begin
    if rising_edge(clk_200M) then
        if reset = '1' or clkCnt(clkCnt'left) = '1' then
            clkCnt <= to_unsigned(8, clkCnt'length);
        else
            clkCnt <= clkCnt - 1;
        end if;
    end if;
end process;

burf20MInst: BUFGCE
generic map(
    SIM_DEVICE => "7SERIES"
)
port map(
    I  => clk_200M,
    CE => clkCnt(clkCnt'left),
    O  => clk_20M
);

clk10MProc: process(clk_20M)
begin
    if rising_edge(clk_20M) then
        if reset = '1' then
            clk10MT <= '0';
        else
            clk10MT <= not clk10MT;
        end if;
    end if;
end process;

buf10MInst: BUFG
port map(
    I => clk10MT,
    O => clk_10M
);

i2cRadModule: entity work.i2cMaster
generic map(
    input_clk => 200000000,
    bus_clk   => 500000
)
port map(
    clk       => clk_200M,
    reset_n   => resetn,
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

enClkI2CSyncInst: xpm_cdc_single
generic map(
    DEST_SYNC_FF   => 2,
    INIT_SYNC_FF   => 0,
    SIM_ASSERT_CHK => 0,
    SRC_INPUT_REG  => 1
)
port map(
    src_clk  => clk_200M,
    dest_clk => clk_10M,
    src_in   => en_clki2c,
    dest_out => enClkI2CSync
);

scClkSmBufInst: BUFGCE
generic map(
    SIM_DEVICE => "7SERIES"
)
port map(
    O => sc_clk_sm,
    CE => enClkI2CSync,
    I => clk_10M
);

adc: entity xil_defaultlib.adc
port map(
    rst 	 => reset_acq,
    clk_200M => clk_200M,
    start    => start_acq,
    sdo_hg	 => ADC_HG,
    sdo_lg	 => ADC_LG,
    NORT1	 => sc_NORT1,
    NORT2 	 => sc_NORT2,
    NORTQ    => sc_NORTQ,
    nb_acq   => nb_acq,
    tStamp   => tStamp,
    t		 => T_1Sync,
    sel_adc => sel_adc,
    rd_en 	 => rd_acq,
    dout 	 => dout_acq,
    reset_n    => reset_n_acq,
    rstb_rd  => rstn_read_acq,
    ck_read  => sc_ck_read,
    n_cnv 	 => nCNV,
    adc_sck  => adc_sck,
    empty_acq => empty_acq,
    end_multi_acq => end_acq,
    rd_data_count_acq => rd_data_count_acq,
    hold_ext => sc_holdext,
    trig_ext => sc_trigext,
    trig_out => trig_out,
    evtTrigger => evtTrigger,
    pulsing => pulsingSig,
    pulse => pulseSig,
    extTrg => extTrgSig,
    endAcq => endAcq,
    rdValid => rdValid
);

trgSamplerInst: entity work.trgSamplerCtrl
generic map(
    trgNum        => TBuf21'length,
    nSAfterTrgDef => 16
)
port map(
    clk        => clk_200M,
    rst        => reset,
    evtTrigger => evtTrigger,
    trgIn      => TBuf21,
    devExec    => devExec,
    devId      => devId,
    devRw      => devRw,
    devBrst    => devBrst,
    devBrstWrt => devBrstWrt,
    devBrstSnd => devBrstSnd,
    devBrstRst => devBrstRstTSmpl,
    devAddr    => devAddr,
    devDataIn  => dataToDev,
    devDataOut => dataFromTSmpl,
    devReady   => devReadyTSmpl,
    busy       => devBusyTSmpl
);

rateMetersInst: entity work.rateMetersCtrl
generic map(
    trgNum     => tEdge21'length
)
port map(
    clk        => clk_200M,
    rst        => reset,
    trgIn      => tEdge21,
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
    busy       => devBusyRM
);

timeStampInst: entity work.timeStamp
generic map(
    clkFreq    => clkFreq,
    coarseBase => coarseBase
)
port map(
    clk     => clk_200M,
    rst     => reset,
    freeze  => evtTrigger,
    tFine   => tFine,
    tCoarse => tCoarse,
    tStamp  => tStamp
);

dataAcqCtrlInst : entity work.dataAcqCtrl
port map(
    clk100M     => clk_200M,
    rst         => reset,
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
    busy        => devBusyAcq,
    resetAcq    => reset_acq,
    startAcq    => start_acq,
    endAcq      => endAcq,
    rdValid     => rdValid,
    rdAcq       => rd_acq,
    rdDataCnt   => rd_data_count_acq,
    emptyAcq    => empty_acq,
    nbAcq       => nb_acq,
    selAdc      => sel_adc,
    doutAcq     => dout_acq
);

i2cTmpModule: entity work.i2cMaster
generic map(
    input_clk => 200000000,
    bus_clk   => 400000
)
port map(
    clk       => clk_200M,
    reset_n   => resetn,
    ena       => i2cEna,
    addr      => i2cAddr,
    rw        => i2cRw,
    data_wr   => i2cDataWr,
    busy      => i2cBusy,
    data_rd   => i2cDataRd,
    ack_error => open,
    sda       => SDA_275,
    scl       => SCL_275
);

spiSlaveInst: entity work.SPISlave
generic map(
    maxBrstLen   => maxBrstLen
)
port map(
    clk          => clk_200M,
    rst          => reset,
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
    rx_reset     => reset,
    tx_reset     => reset,
    cs           => csSync,
    sclk         => sclkSync,
    miso         => miso,
    mosi         => mosiSync
);

pGenInst: entity work.pulseGenCtrl
generic map(
    clkFreq      => clkFreq,
    sleepOnPwrOn => sleepOnPwrOn,
    pwrOnTime    => pwrOnTime,
    settlingTime => settlingTime
)
port map(
    clk          => clk_200M,
    rst          => reset,
    devId        => devId,
    devReady     => devReadyPGen,
    devRw        => devRw,
    devAddr      => devAddr,
    devDataIn    => dataToDev,
    devDataOut   => dataFromPGen,
    devExec      => devExec,
    busy         => devBusyPGen,
    pulsing      => pulsingSig,
    pulse        => pulseSig,
    dacSDI       => dacSDI,
    dacSCLK      => dacSCLK,
    dacCS        => dacCS
);

radInterfInst: entity work.radiorocInterface
generic map(
    chipID     => chipID
)
port map(
    clk        => clk_200M,
    rst        => reset,
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
    tmpAddr    => tmpAddr
)
port map(
    clk        => clk_200M,
    rst        => reset,
    devExec    => devExec,
    devId      => devId,
    devRw      => devRw,
    devAddr    => devAddr,
    devDataIn  => dataToDev,
    devDataOut => dataFromTmp,
    devReady   => devReadyTmp,
    busy       => devBusyTmp,
    i2cEna     => i2cEna,
    i2cAddr    => i2cAddr,
    i2cRw      => i2cRw,
    i2cDataWr  => i2cDataWr,
    i2cBusy    => i2cBusy,
    i2cDataRd  => i2cDataRd
);

devDataInVec(none)      <= (others => (others => '0'));
devDataInVec(pulseGen)  <= dataFromPGen;
devDataInVec(tmp275)    <= dataFromTmp;
devDataInVec(radioroc)  <= dataFromRadioroc;
devDataInVec(dataReg)   <= (others => (others => '0'));
devDataInVec(acqSystem) <= dataFromAcq;
devDataInVec(rateMeters)<= dataFromRM;
devDataInVec(trgSampler)<= dataFromTSmpl;

devReadyVec(none)       <= '0';
devReadyVec(pulseGen)   <= devReadyPGen;
devReadyVec(tmp275)     <= devReadyTmp;
devReadyVec(radioroc)   <= devReadyRadioroc;
devReadyVec(dataReg)    <= '0';
devReadyVec(acqSystem)  <= devReadyAcq;
devReadyVec(rateMeters) <= devReadyRM;
devReadyVec(trgSampler) <= devReadyTSmpl;

devBusyVec(none)        <= '0';
devBusyVec(pulseGen)    <= devBusyPGen;
devBusyVec(tmp275)      <= devBusyTmp;
devBusyVec(radioroc)    <= devBusyRadioroc;
devBusyVec(dataReg)     <= '0'; 
devBusyVec(acqSystem)   <= devBusyAcq;
devBusyVec(rateMeters)  <= devBusyRM;
devBusyVec(trgSampler)  <= devBusyTSmpl;

devBrstRst(none)        <= '0';
devBrstRst(pulseGen)    <= '0';
devBrstRst(tmp275)      <= '0';
devBrstRst(radioroc)    <= '0';
devBrstRst(dataReg)     <= '0';
devBrstRst(acqSystem)   <= devBrstRstAcq;
devBrstRst(rateMeters)  <= devBrstRstRM;
devBrstRst(trgSampler)  <= devBrstRstTSmpl;

devInterfInst: entity work.deviceInterface
generic map(
    clkFreq     => clkFreq,
    timeout     => timeout,
    idHeader    => idHeader,
    broadcastId => broadcastId,
    readCmd     => readCmd,
    writeCmd    => writeCmd,
    burstWrCmd  => burstWrCmd,
    burstRdCmd  => burstRdCmd,
    maxBrstLen  => maxBrstLen
)
port map(
    clk        => clk_200M,
    rst        => reset,
    id         => boardID,
    dataIn     => dataFromMaster,
    dataOut    => dataToMaster,
    rxRead     => rxRead,
    rxEna      => rxEna,
    rxPresent  => rxPresent,
    rxValid    => rxValid,
    txWrite    => txWrite,
    txWrAck    => txWrAck,
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

end arch;