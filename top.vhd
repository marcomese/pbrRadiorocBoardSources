library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

library xil_defaultlib;

use work.utilsPkg.all;
use work.devicesPkg.all;

entity radioroc_fw is
	port
	(
		CLK_100M_p    : in std_logic;
		CLK_100M_n    : in std_logic;
		npwr_reset    : in std_logic;

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

		T_p           : in std_logic_vector(63 downto 0);
		T_n           : in std_logic_vector(63 downto 0);

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

        dbgOut        : out std_logic_vector(7 downto 0);

		extTrg        : out std_logic -- in std_logic
	);
end entity;

architecture arch of radioroc_fw is

    component PLL_Radioroc_1
    port
     (-- Clock in ports
      -- Clock out ports
      clk_out1          : out    std_logic;
      clk_out2          : out    std_logic;
      clk_out3          : out    std_logic;
      clk_out4          : out    std_logic;
      clk_out5          : out    std_logic;
      clk_out6          : out    std_logic;
      clk_out7          : out    std_logic;
      -- Status and control signals
      reset             : in     std_logic;
      locked            : out    std_logic;
      clk_in1_p         : in     std_logic;
      clk_in1_n         : in     std_logic
     );
    end component;

    -- LVDS
	signal ADC_SCKHG, ADC_SCKLG, ADC_HG, ADC_LG : std_logic;
	signal T                                              : std_logic_vector(63 downto 0);
	-- Clock and reset
	signal reset, locked_1, locked_2, locked_3                               : std_logic;
	signal clk_2M, clk_10M, clk_20M, clk_25M, clk_50M, clk_100M, clk_200M, clk_250M : std_logic;
	signal clk_500M : std_logic;
	signal clk_100k                                                          : std_logic;
	signal cpt_clk                                                           : natural range 0 to 4;
	-- I2C
--	signal end_i2c, n_reset_i2c, rd55, wr_i2c, en_clki2c, sda_i, sda_o, sda_oen : std_logic;
    signal end_i2c, n_reset_i2c, rd55, wr_i2c, en_clki2c : std_logic;
	signal rstb_read_sft, reset_n_sft : std_logic;
	signal i2c_in, i2c_set, q, start, end_rd, spy_i2c     : std_logic_vector(7 downto 0);
	-- Scurves
	signal en_test_Scurve, rstb_Scurve, clk_Scurve, reset_scurve, raz_chn_scurve, clk_scurves: std_logic;
	signal clk_S, nb_scurve                       : std_logic_vector(1 downto 0);
	signal sel_chn_scurve              : std_logic_vector(7 downto 0);
	signal P_cnt, T_cnt                : std_logic_vector(15 downto 0);
	-- Staircases
	signal rst_staircase, enable_stair : std_logic;
	signal cpt_testair                 : integer range 0 to 268435455;
	-- TDC
	signal en_tdc, coincidence_on, rst_tdc, rst_tdc_sft, fifo_wr, master, overrun : std_logic;
	signal coincidence_delay, coincidence_width : std_logic_vector(7 downto 0);
	signal fifo_in : std_logic_vector(31 downto 0);
	signal en_l_tdc : std_logic_vector(63 downto 0);
	-- Others
	signal OR64_s           : std_logic := '0';
	signal Scurve_trigger   : std_logic;
	signal testair          : std_logic_vector(31 downto 0);
	signal spy_hi  : std_logic_vector(7 downto 0);
	signal sel_trigger : std_logic_vector(7 downto 0);
	signal sel_io : std_logic_vector(23 downto 0);
	--ADC Acquisition
	signal reset_acq, start_acq, rd_acq, adc_sck, end_acq, empty_acq, rstn_read_acq, reset_n_acq, trig_out : std_logic;
	signal nb_acq, dout_acq : std_logic_vector(7 downto 0);
	signal rd_data_count_acq : std_logic_vector(15 downto 0);
	signal sel_adc : std_logic_vector(63 downto 0);
	-- Temperature
	signal temp_cfg, temp_ctrl : std_logic_vector(7 downto 0);
	signal temperature : std_logic_vector(15 downto 0);

	signal cpt : natural range 0 to 255;
	signal spy_tdc : std_logic_vector(7 downto 0);

	signal test_daq : std_logic;
	signal on_edge : std_logic;

-- CONSTANTS for deviceInterface, sipmHvTmpCtrl and PulseGentCtrl

constant clkFreq        : real      := 100.0e6;
constant sclkFreq       : real      := 25.0e6;
constant timeout        : real      := 1.0;
constant sleepOnPwrOn   : boolean   := True;
constant pwrOnTime      : real      := 20.0e-6;
constant settlingTime   : real      := 5.0e-6;
constant readPeriod     : real      := 1.0;
----debug
constant testCount      : integer   := 50;

constant tmpAddr        : std_logic_vector(6 downto 0) := "1001000";
constant sipmHvAddr     : std_logic_vector(6 downto 0) := "1110011";
constant chipID         : std_logic_vector(3 downto 0) := "0000";

constant readCmd    : std_logic_vector(3 downto 0) := x"A";
constant writeCmd   : std_logic_vector(3 downto 0) := x"5";
constant burstWrCmd : std_logic_vector(3 downto 0) := x"3";
constant burstRdCmd : std_logic_vector(3 downto 0) := x"B";
constant maxBrstLen : integer                      := 125;

constant rstRadI2CLen : integer := 5;

signal   dataToDev,
         dataFromPGen,
         dataFromHvTmp,
         dataFromRadioroc  : devData_t;
signal   devDataInVec      : devDataVec_t;
signal   devReadyVec       : devReady_t;
signal   devBusyVec        : devBusy_t;

signal   devId          : devices_t;
signal   devReadyPGen,
         devReadyHvTmp,
         devReadyRadioroc,
         devRw,
         devBurst,
         devExec,
         pgenBusy,
         hvTmpBusy,
         devBusyPGen,
         devBusyHvTmp,
         devBusyRadioroc,
         devIntBusy     : std_logic;
signal   devAddr        : devAddr_t;

-- SIGNALS FOR spiSlave --
signal   error          : std_logic_vector(2 downto 0);
signal   dataIn         : std_logic_vector(7 downto 0);
signal   dataOut        : std_logic_vector(7 downto 0);
signal   rxRead         : std_logic;
signal   rxPresent      : std_logic;
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
signal   resetn         : std_logic;
signal   testTxWrite,
         testRxRead,
         testRxPresent  : std_logic;
signal   dataToMaster,
         dataFromMaster : std_logic_vector(7 downto 0);

signal extTrgFF, extTrgSig : std_logic;

signal readRq,
       cs,
       sclk,
       mosi,
       miso    : std_logic;

signal testCnt : unsigned(bitsNum(testCount) downto 0);

signal rstI2CCnt : unsigned(bitsNum(rstRadI2CLen) downto 0);

attribute mark_debug : string;
attribute mark_debug of readRq,
                        cs,
                        sclk,
                        mosi,
                        miso,
                        sc_rstb_i2c,
                        sc_rstb_sc,
                        dataFromMaster,
                        dataToMaster,
                        rxPresent      : signal is "true";

begin

	reset <= not(npwr_reset);

	nCMOS <= '1';

extTrg <= extTrgSig;

testOutInst: process(reset, clk_10M)
begin
    if rising_edge(clk_10M) then
        if reset = '1' then
            extTrgSig  <= '0';
            testCnt    <= to_unsigned(testCount, testCnt'length);
        elsif testCnt(testCnt'left) = '1' then
            extTrgSig  <= not extTrgSig;
            testCnt    <= to_unsigned(testCount, testCnt'length);
        else
            testCnt <= testCnt - 1;
        end if;
    end if;
end process;

--    extTrgSync: process(reset, clk_200M)
--    begin
--        if rising_edge(clk_200M) then
--            if reset = '1' then
--                extTrgFF  <= '0';
--                extTrgSig <= '0';
--            else
--                extTrgFF  <= extTrg;
--                extTrgSig <= extTrgFF;
--            end if;
--        end if;
--    end process;

	IOs : entity xil_defaultlib.IO
    Port map(
        ADC_SCKHG => ADC_SCKHG,
        ADC_SCKLG => ADC_SCKLG,
        ADC_HG    => ADC_HG,
        ADC_LG    => ADC_LG,
        T_p       => T_p,
        T_n       => T_n,
        ADC_SCKHG_p => ADC_SCKHG_p,
        ADC_SCKHG_n => ADC_SCKHG_n,
        ADC_SCKLG_p => ADC_SCKLG_p,
        ADC_SCKLG_n => ADC_SCKLG_n,
        ADC_HG_p    => ADC_HG_p,
        ADC_HG_n    => ADC_HG_n,
        ADC_LG_p => ADC_LG_p,
        ADC_LG_n => ADC_LG_n,
        T       => T,
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

	pll1 : PLL_RADIOROC_1
	port map
	(
		clk_in1_p  => CLK_100M_P,
		clk_in1_n  => CLK_100M_N,
		reset    => reset,
		clk_out1 => clk_10M,
		clk_out2 => clk_20M,
		clk_out3 => clk_25M,
		clk_out4 => clk_100M,
		clk_out5 => clk_200M,
		clk_out6 => clk_250M,
		clk_out7 => clk_500M,
		locked   => locked_1
	);
 
	process (reset, clk_20M)
	begin
		if reset = '1' then
			cpt_clk <= 0;
			clk_2M  <= '0';
		elsif rising_edge(clk_20M) then
			if cpt_clk = 4 then
				clk_2M  <= not clk_2M;
				cpt_clk <= 0;
			else
				cpt_clk <= cpt_clk + 1;
			end if;
		end if;
	end process;

	Div : entity xil_defaultlib.Diviseur
	port map(
	clock_in   => clk_10M,
	clk_Scurve => clk_S,
	clk_100k   => clk_100k,
	clock_out  => clk_Scurve
	);

	OR64_inst : entity xil_defaultlib.OR64
	port map (
	data   => T,
	result => OR64_s
	);

    iom : entity xil_defaultlib.io_mux
	port map
	(
		t             => t,
		clk_scurves   => clk_scurves,
		NORT1         => sc_NORT1,
		NORT2         => sc_NORT2,
		NORTQ         => sc_NORTQ,
		trig_out      => trig_out,
		sc_outd_probe => sc_outd_probe,
		sel_trigger   => sel_trigger(5 downto 0),
		sel           => sel_io(17 downto 0),
		test_daq      => test_daq
    );

	process (rst_staircase, Scurve_trigger)
	begin
		if rst_staircase = '1' then
			cpt_testair <= 0;
		elsif rising_edge(Scurve_trigger) then
			if enable_stair = '1' then
				if cpt_testair = 268435455 then
					cpt_testair <= 0;
				else
					cpt_testair <= cpt_testair + 1;
				end if;
			end if;
		end if;
	end process;

	testair <= std_logic_vector(to_unsigned(cpt_testair, 32));

	chn_mx : entity xil_defaultlib.Scurve_chn_mux
	port map(
	T           => T,
	OR64        => OR64_s,
	sel         => sel_chn_Scurve,
	CH_Scurve_o => Scurve_trigger
	);

	Scurve_inst : entity xil_defaultlib.scurves
	port map(
	rst       => reset_scurve,
	clk       => clk_10M,
	fq_clk    => clk_S,
	nb        => nb_scurve,
	enable    => en_test_scurve,
	trigger   => Scurve_trigger,
	on_edge   => on_edge,
	cpt_pulse => P_cnt,
	cpt_trig  => T_cnt,
	ready     => open,
	raz_chn   => raz_chn_scurve,
	clk_scurves => clk_scurves
	);

	reset_scurve <= not(rstb_Scurve and npwr_reset);
	n_reset_i2c <= en_clki2c and npwr_reset;

i2cRadModule: entity work.i2cMaster
generic map(
    input_clk => 100000000,
    bus_clk   => 500000
)
port map(
    clk       => clk_100M,
    reset_n   => npwr_reset,
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

	sc_clk_sm <= clk_10M when (en_clki2c = '1') else '0';

    dbgOut <= dout_acq;

	adc : entity xil_defaultlib.adc
	Port map (
		rst 	 => reset_acq,
		clk_100M => clk_100M,
		clk_200M => clk_200M,
		clk_500M => clk_500M,
		clk_25M  => clk_25M,
		start    => start_acq,
		sdo_hg	 => ADC_HG,
		sdo_lg	 => ADC_LG,
		NORT1	 => sc_NORT1,
		NORT2 	 => sc_NORT2,
		NORTQ    => sc_NORTQ,
		nb_acq   => nb_acq,
		t		 => t,
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
		extTrg => extTrgSig,
		test => test_daq
	);

	sc_reset_n   <= reset_n_sft and reset_n_acq;

	sc_rstn_read <= rstb_read_sft and rstn_read_acq;

    sc_rstb_i2c  <= rstI2CCnt(rstI2CCnt'left);

    sc_rstb_sc  <= rstI2CCnt(rstI2CCnt'left);

    radiorocI2CRst: process(clk_100M, reset, rstI2CCnt)
    begin
        if rising_edge(clk_100M) then
            if reset = '1' then
                rstI2CCnt <= to_unsigned(rstRadI2CLen-1, rstI2CCnt'length);
            elsif rstI2CCnt(rstI2CCnt'left) = '0' then
                rstI2CCnt <= rstI2CCnt - 1;
            end if;
        end if;
    end process;

	ADC_SCKHG <= adc_sck;
	ADC_SCKLG <= adc_sck;

i2cModule: entity work.i2cMaster
generic map(
    input_clk => 100000000,
    bus_clk   => 400000
)
port map(
    clk       => clk_100M,
    reset_n   => npwr_reset,
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

   rst_tdc <= reset or rst_tdc_sft;

spiSlaveInst: entity work.SPISlave
port map(
    clk          => clk_100M,
    rst          => reset,
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
    rx_reset     => reset,
    tx_reset     => reset,
    cs           => cs,
    sclk         => sclk,
    miso         => miso,
    mosi         => mosi
);

pGenInst: entity work.pulseGenCtrl
generic map(
    clkFreq      => clkFreq,
    sleepOnPwrOn => sleepOnPwrOn,
    pwrOnTime    => pwrOnTime,
    settlingTime => settlingTime
)
port map(
    clk          => clk_100M,
    rst          => reset,
    devId        => devId,
    devReady     => devReadyPGen,
    devRw        => devRw,
    devAddr      => devAddr,
    devDataIn    => dataToDev,
    devDataOut   => dataFromPGen,
    devExec      => devExec,
    busy         => devBusyPGen,
    pulse        => pulse,
    dacSDI       => dacSDI,
    dacSCLK      => dacSCLK,
    dacCS        => dacCS
);

radInterfInst: entity work.radiorocInterface
generic map(
    chipID     => chipID
)
port map(
    clk        => clk_100M,
    rst        => reset,
    devExec    => devExec,
    devId      => devId,
    devRw      => devRw,
    devBurst   => devBurst,
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

hvTmpCtrlInst: entity work.sipmHvTmpCtrl
generic map(
    clkFreq    => clkFreq,
    readPeriod => readPeriod,
    tmpAddr    => tmpAddr,
    sipmHvAddr => sipmHvAddr
)
port map(
    clk        => clk_100M,
    rst        => reset,
    devExec    => devExec,
    devId      => devId,
    devRw      => devRw,
    devAddr    => devAddr,
    devDataIn  => dataToDev,
    devDataOut => dataFromHvTmp,
    devReady   => devReadyHvTmp,
    busy       => devBusyHvTmp,
    i2cEna     => i2cEna,
    i2cAddr    => i2cAddr,
    i2cRw      => i2cRw,
    i2cDataWr  => i2cDataWr,
    i2cBusy    => i2cBusy,
    i2cDataRd  => i2cDataRd
);

devDataInVec(pulseGen) <= dataFromPGen;
devDataInVec(tmp275)   <= dataFromHvTmp;
devDataInVec(a7585d)   <= dataFromHvTmp;
devDataInVec(radioroc) <= dataFromRadioroc;

devReadyVec(pulseGen)  <= devReadyPGen;
devReadyVec(tmp275)    <= devReadyHvTmp;
devReadyVec(a7585d)    <= devReadyHvTmp;
devReadyVec(radioroc)  <= devReadyRadioroc;

devBusyVec(pulseGen)   <= devBusyPGen;
devBusyVec(tmp275)     <= devBusyHvTmp;
devBusyVec(a7585d)     <= devBusyHvTmp;
devBusyVec(radioroc)   <= devBusyRadioroc;

devInterfInst: entity work.deviceInterface
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
    clk        => clk_100M,
    rst        => reset,
    dataIn     => dataFromMaster,
    dataOut    => dataToMaster,
    rxRead     => rxRead,
    rxEna      => rxEna,
    rxPresent  => rxPresent,
    txWrite    => txWrite,
    txWrAck    => txWrAck,
    devId      => devId,
    devReady   => devReadyVec,
    devBusy    => devBusyVec,
    devRw      => devRw,
    devBurst   => devBurst,
    devAddr    => devAddr,
    devDataIn  => devDataInVec,
    devDataOut => dataToDev,
    devExec    => devExec,
    busy       => devIntBusy,
    error      => error
);

end arch;