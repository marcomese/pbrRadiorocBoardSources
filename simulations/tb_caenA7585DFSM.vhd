library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_caenA7585DFSM is
end tb_caenA7585DFSM;

architecture Behavioral of tb_caenA7585DFSM is

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

component caenA7585DFSM is
generic(
    caenAddr  : std_logic_vector(6 downto 0)
);
port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    exec      : in  std_logic;
    rw        : in  std_logic;
    addr      : in  std_logic_vector(7 downto 0);
    dataIn    : in  std_logic_vector(31 downto 0);
    dataOut   : out std_logic_vector(31 downto 0);
    busy      : out std_logic;
    dataReady : out std_logic;
    i2cEna    : out std_logic;
    i2cAddr   : out std_logic_vector(6 downto 0);
    i2cRw     : out std_logic;
    i2cDataWr : out std_logic_vector(7 downto 0);
    i2cBusy   : in  std_logic;
    i2cDataRd : in  std_logic_vector(7 downto 0)
);
end component;

constant clkPeriod : time := 10 ns;
constant caenAddr  : std_logic_vector(6 downto 0) := "1110011";

signal clk         : std_logic := '1';
signal rst         : std_logic := '0';
signal exec        : std_logic := '0';
signal rw          : std_logic := '0';
signal addr        : std_logic_vector(7 downto 0)  := (others => '0');
signal dataIn      : std_logic_vector(31 downto 0) := (others => '0');
signal dataOut     : std_logic_vector(31 downto 0) := (others => '0');
signal busy        : std_logic := '0';
signal dataReady   : std_logic := '0';
signal i2cEna      : std_logic := '0';
signal i2cAddr     : std_logic_vector(6 downto 0) := (others => '0');
signal i2cRw       : std_logic := '0';
signal i2cDataWr   : std_logic_vector(7 downto 0) := (others => '0');
signal i2cBusy     : std_logic := '0';
signal i2cDataRd   : std_logic_vector(7 downto 0) := (others => '0');
signal sda, scl    : std_logic := '0';
signal resetn      : std_logic := '0';

signal testData    : std_logic_vector(7 downto 0) := (others => '0');

begin

resetn <= not rst;

stimProc: process
begin
    rst <= '1';
    wait for clkPeriod*5;
    rst <= '0';
    wait until i2cBusy = '0';

    wait for clkPeriod;

    rw     <= '0';
    addr   <= x"05";
    dataIn <= x"ABCD_1E1F";

    exec <= '1';
    wait for clkPeriod;
    exec <= '0';

    wait until busy = '0';

    wait for clkPeriod;

    rw     <= '0';
    addr   <= x"01";
    dataIn <= x"AAAA_BBBB";

    exec <= '1';
    wait for clkPeriod;
    exec <= '0';

    wait until busy = '0';

    wait for clkPeriod*100;

    rw     <= '1';
    addr   <= x"0B";

    wait for clkPeriod;
    exec <= '1';
    wait for clkPeriod;
    exec <= '0';

    wait until i2cBusy = '0';

    wait until i2cBusy = '0';

    wait until i2cBusy = '0';

    testData <= x"CD";

    wait until i2cBusy = '0';
    
    testData <= x"BB";

    wait until i2cBusy = '0';
    
    testData <= x"FE";

    wait until i2cBusy = '0';
    
    testData <= x"B1";

    wait until i2cBusy = '0';
    
    testData <= x"FF";

    wait;
end process;

clkProc: process
begin
    clk <= '1';
    wait for clkPeriod/2;
    clk <= '0';
    wait for clkPeriod/2;
end process;

uut: caenA7585DFSM
generic map(
    caenAddr  => caenAddr
)
port map(
    clk       => clk,
    rst       => rst,
    exec      => exec,
    rw        => rw,
    addr      => addr,
    dataIn    => dataIn,
    dataOut   => dataOut,
    busy      => busy,
    dataReady => dataReady,
    i2cEna    => i2cEna,
    i2cAddr   => i2cAddr,
    i2cRw     => i2cRw,
    i2cDataWr => i2cDataWr,
    i2cBusy   => i2cBusy,
    i2cDataRd => testData--i2cDataRd
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
    data_rd   => open,--i2cDataRd,
    ack_error => open,
    sda       => sda,
    scl       => scl
);

end Behavioral;