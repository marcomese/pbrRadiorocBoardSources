library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.devicesPkg.all;

entity tb_radiorocInterface is
end tb_radiorocInterface;

architecture Behavioral of tb_radiorocInterface is

component radiorocInterface is
generic(
    chipID     : std_logic_vector(3 downto 0)
);
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    devExec    : in  std_logic;
    devId      : in  devices_t;
    devRw      : in  std_logic;
    devBurst   : in  std_logic;
    devAddr    : in  devAddr_t;
    devDataIn  : in  devData_t;
    devDataOut : out devData_t;
    devReady   : out std_logic;
    busy       : out std_logic;
    i2cEnClk   : out std_logic;
    i2cEna     : out std_logic;
    i2cAddr    : out std_logic_vector(6 downto 0);
    i2cRw      : out std_logic;
    i2cDataWr  : out std_logic_vector(7 downto 0);
    i2cBusy    : in  std_logic;
    i2cDataRd  : in  std_logic_vector(7 downto 0)
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
    devReady    : in  devReady_t;
    devBusy     : in  devBusy_t;
    devRw       : out std_logic;
    devBurst    : out std_logic;
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

constant clkPeriod      : time                         := 10 ns;
constant clkFreq        : real                         := 100.0e6;
constant sclkFreq       : real                         := 20.0e6;
constant timeout        : real                         := 1.0;
constant chipID         : std_logic_vector(3 downto 0) := "0000";
constant readCmd        : std_logic_vector(3 downto 0) := x"A";
constant writeCmd       : std_logic_vector(3 downto 0) := x"5";
constant burstWrCmd     : std_logic_vector(3 downto 0) := x"3";
constant burstRdCmd     : std_logic_vector(3 downto 0) := x"B";
constant maxBrstLen     : natural                      := 40;--677;
constant delay          : natural                      := 1;--50000;

signal   clk            : std_logic                    := '1';
signal   rst            : std_logic                    := '0';
signal   devId          : devices_t                    := none;
signal   devReadyRad    : std_logic                    := '0';
signal   devRw          : std_logic                    := '0';
signal   devBurst       : std_logic                    := '0';
signal   devAddr        : devAddr_t                    := (others => (others => '0'));
signal   devExec        : std_logic                    := '0';
signal   radBusy,
         devIntBusy     : std_logic                    := '0';
signal   dataToDev,
         dataFromRad    : devData_t                    := (others => (others => '0'));
signal   devDataInVec   : devDataVec_t                 := (others => (others => (others => '0')));
signal   devReadyVec    : devReady_t                   := (others => '0');
signal   devBusyVec     : devBusy_t                    := (others => '0');
signal   error          : std_logic_vector(2 downto 0) := "000";
signal   rxRead         : std_logic                    := '0';
signal   rxPresent      : std_logic                    := '0';
signal   txWrite        : std_logic                    := '0';
signal   txWrAck        : std_logic                    := '0';
signal   flushRxFifo    : std_logic                    := '0';
signal   i2cEnClk       : std_logic                    := '0';
signal   i2cEna         : std_logic                    := '0';
signal   i2cAddr        : std_logic_vector(6 downto 0) := (others => '0');
signal   i2cRw          : std_logic                    := '0';
signal   i2cDataWr      : std_logic_vector(7 downto 0) := (others => '0');
signal   i2cBusy        : std_logic                    := '0';
signal   i2cDataRd      : std_logic_vector(7 downto 0) := (others => '0');
signal   sda, scl       : std_logic                    := '0';
signal   resetn         : std_logic                    := '0';
signal   rxEna          : std_logic                    := '1';
signal   readRq,
         cs,
         sclk,
         miso,
         mosi,
         testTxWrite,
         testRxRead,
         testRxPresent  : std_logic                    := '0';
signal   dataToMaster,
         testDataIn,
         testDataOut,
         testData,
         dataFromMaster : std_logic_vector(7 downto 0) := (others => '0');

begin

resetn <= not rst;

stimProc: process
begin
    rst <= '1';
    wait for clkPeriod*5;
    rst <= '0';
    wait for clkPeriod*5;

--    wait for clkPeriod*5;

--    testRxRead <= '1';

--    testDataIn <= x"A3";
--    wait for clkPeriod;
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testDataIn <= x"BA";
--    wait for clkPeriod;
--    testDataIn <= x"12";
--    wait for clkPeriod;
--    testDataIn <= x"0A";
--    wait for clkPeriod;
--    testDataIn <= x"00";
--    wait for clkPeriod;
--    testDataIn <= x"00";
--    wait for clkPeriod;
--    testDataIn <= x"00";
--    wait for clkPeriod;
--    testTxWrite <= '0';

--    wait until i2cBusy = '0';

--    wait until i2cBusy = '0';

--    wait until i2cBusy = '0';

--    wait until i2cBusy = '0';
    
--    testData <= x"BB";

--    wait for 10 us;

--    testRxRead <= '1';

--    testDataIn <= x"A3";
--    wait for clkPeriod;
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testDataIn <= x"01";
--    wait for clkPeriod;
--    testDataIn <= x"02";
--    wait for clkPeriod;
--    testDataIn <= x"0A";
--    wait for clkPeriod;
--    testDataIn <= x"00";
--    wait for clkPeriod;
--    testDataIn <= x"00";
--    wait for clkPeriod;
--    testDataIn <= x"0C";
--    wait for clkPeriod;
--    testTxWrite <= '0';

--    wait until i2cBusy = '0';

--    wait until i2cBusy = '0';

--    wait until i2cBusy = '0';

--    testData <= x"CC";

--    wait for 10 us;

--    testDataIn <= x"A3";
--    wait for clkPeriod;
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testDataIn <= x"01";
--    wait for clkPeriod;
--    testDataIn <= x"02";
--    wait for clkPeriod;
--    testDataIn <= x"0F";
--    wait for clkPeriod;
--    testDataIn <= x"00";
--    wait for clkPeriod;
--    testDataIn <= x"00";
--    wait for clkPeriod;
--    testDataIn <= x"00";
--    wait for clkPeriod;
--    testTxWrite <= '0';

--    wait until i2cBusy = '0';

--    wait for 150 us;

--    testRxRead <= '1';

--    testDataIn <= x"53";
--    wait for clkPeriod;
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testDataIn <= x"00";
--    wait for clkPeriod;
--    testDataIn <= x"01";
--    wait for clkPeriod;
--    testDataIn <= x"AB";
--    wait for clkPeriod;
--    testDataIn <= x"CD";
--    wait for clkPeriod;
--    testDataIn <= x"EF";
--    wait for clkPeriod;
--    testDataIn <= x"77";
--    wait for clkPeriod;
--    testTxWrite <= '0';

--    wait for 350 us;

--    testRxRead <= '1';

--    testDataIn <= x"33";
--    wait for clkPeriod*delay;
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"11";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"22";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"00";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"00";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"00";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"07"; -- send 0xNN bytes in burst mode
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;

--    testDataIn <= x"84";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"c4";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"48"; --0x33 0x00 0x00 0x00 0x00 0x00 0x06 0x84 0xc4 0x48 0x15 0x03 0x04
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"15";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;

--    testDataIn <= x"03";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"04";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"88";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"99";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;

--    testDataIn <= x"cA";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"4E";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"C3";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"64";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;

--    testDataIn <= x"F3";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"7E";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"cB";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"CD";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;

--    testDataIn <= x"40";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"20";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"10";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"80";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;

--    testDataIn <= x"08";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"04";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"02";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"01";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;

--    testDataIn <= x"c8";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"c4";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"c2";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"c1";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;

--    testDataIn <= x"D8";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"D4";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"D2";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"D1";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;

--    testDataIn <= x"E8";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"E4";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"E2";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;
--    testDataIn <= x"E1";
--    testTxWrite <= '1';
--    wait for clkPeriod;
--    testTxWrite <= '0';
--    wait for clkPeriod*delay;

--   testTxWrite <= '0';

--    wait until radBusy = '0';

    wait for 150 us;

    testRxRead <= '1';

    testDataIn <= x"B3";
    wait for clkPeriod;
    testTxWrite <= '1';
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"00";
    wait for clkPeriod;
    testDataIn <= x"03";
    wait for clkPeriod;
    testTxWrite <= '0';

    --wait until i2cBusy = '0';

    wait until i2cBusy = '0';

    wait until i2cBusy = '0';

    wait until i2cBusy = '0';

    testData <= x"AA";
    
    wait until i2cBusy = '0';

    testData <= x"BB";

    wait until i2cBusy = '0';

    testData <= x"CC";

    wait until i2cBusy = '0';

    testData <= x"DD";

    wait until i2cBusy = '0';

    testData <= x"EE";

    wait until i2cBusy = '0';

    testData <= x"AB";
    
    wait until i2cBusy = '0';

    testData <= x"CD";

    wait until i2cBusy = '0';

    testData <= x"EF";

    wait until i2cBusy = '0';

    testData <= x"12";

    wait for 10 us;

    wait;
end process;

clk <= not clk after clkPeriod/2;

uut: radiorocInterface
generic map(
    chipID     => chipID
)
port map(
    clk        => clk,
    rst        => rst,
    devExec    => devExec,
    devId      => devId,
    devRw      => devRw,
    devBurst   => devBurst,
    devAddr    => devAddr,
    devDataIn  => dataToDev,
    devDataOut => dataFromRad,
    devReady   => devReadyRad,
    busy       => radBusy,
    i2cEnClk   => i2cEnClk,
    i2cEna     => i2cEna,
    i2cAddr    => i2cAddr,
    i2cRw      => i2cRw,
    i2cDataWr  => i2cDataWr,
    i2cBusy    => i2cBusy,
    i2cDataRd  => testData--i2cDataRd
);

devDataInVec(radioroc) <= dataFromRad;
devReadyVec(radioroc)  <= devReadyRad;
devBusyVec(radioroc)   <= radBusy;

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
    clk          => clk,
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
    devBurst     => devBurst,
    devAddr      => devAddr,
    devDataIn    => devDataInVec,
    devDataOut   => dataToDev,
    devExec      => devExec,
    busy         => devIntBusy,
    error        => error
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

i2cModule: i2cMaster
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