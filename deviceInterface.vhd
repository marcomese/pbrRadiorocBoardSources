----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: deviceInterface
-- Create Date: 12.12.2024 16:09:50
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.devicesPkg.all;
use work.utilsPkg.all;

library xpm;
use xpm.vcomponents.all;

entity deviceInterface is
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
end deviceInterface;

architecture Behavioral of deviceInterface is

type state_t is (idle,
                 getDev,
                 getAddr,
                 getData,
                 checkBrstPar,
                 sendBrst,
                 readDev,
                 sendDevData,
                 done,
                 errFifo,
                 errTOut,
                 errBrstPar);

constant tOut          : integer := integer(clkFreq*timeout);
constant bytesNum      : integer := maxBrstLen;

signal   state         : state_t;
signal   tOutRst,
         tOutSig,
         rwSig,
         rxRdSig,
         brstSig,
         validSig,
         devRwSig,
         devBrstSig,
         brstCollect,
         lastBrst,
         wEnFifo,
         txWSig,
         rstFifo,
         wordWrt,
         wordWrtOld,
         wordWrtRise,
         wAckFifo,
         dValidFifo,
         emptyFifo,
         endCnt        : std_logic;
signal   devIdSig      : devices_t;
signal   tOutCnt       : unsigned(bitsNum(tOut) downto 0);
signal   byteCnt       : unsigned(bitsNum(bytesNum) downto 0);
signal   brstByteNum   : unsigned(bitsNum(bytesNum)-1 downto 0);
signal   brstBuff      : byteArray_t(maxBrstLen-1 downto 0);
signal   devDataOutSig : devData_t;
signal   dataToFifo    : std_logic_vector(7 downto 0);

attribute mark_debug : string;
attribute mark_debug of state : signal is "true";

begin

rxRead      <= rxRdSig and not endCnt;
txWrite     <= txWSig;
devRw       <= devRwSig;
devBurst    <= devBrstSig;
devId       <= devIdSig;
devDataOut  <= devDataOutSig;
endCnt      <= byteCnt(byteCnt'left);
tOutSig     <= tOutCnt(tOutCnt'left);
wordWrt     <= not or_reduce(std_logic_vector(byteCnt(1 downto 0))); -- '1' when byteCnt is multiple of 4
wordWrtRise <= wordWrt and not wordWrtOld;
lastBrst    <= not or_reduce(std_logic_vector(byteCnt(byteCnt'left downto 2)));
dataToFifo  <= devDataIn(devIdSig)(0);

devRwDecProc: process(clk, rst, dataIn(7 downto 4))
begin
    case dataIn(7 downto 4) is
        when readCmd =>
            rwSig    <= '1';
            brstSig  <= '0';
            validSig <= '1';
        when writeCmd =>
            rwSig    <= '0';
            brstSig  <= '0';
            validSig <= '1';
        when burstRdCmd =>
            rwSig    <= '1';
            brstSig  <= '1';
            validSig <= '1';
        when burstWrCmd =>
            rwSig    <= '0';
            brstSig  <= '1';
            validSig <= '1';
        when others =>
            rwSig    <= '1';
            brstSig  <= '0';
            validSig <= '0';
    end case;
end process;

devFSM: process(clk, rst, rxPresent)
    variable i : integer := 0;
begin
    if rising_edge(clk) then
        if rst = '1' then
            tOutRst        <= '0';
            byteCnt        <= to_unsigned(devAddrBytes-1, byteCnt'length);
            rxRdSig        <= '0';
            txWSig         <= '0';
            rxEna          <= '1';
            flushRxFifo    <= '0';
            flushTxFifo    <= '0';
            devIdSig       <= none;
            devRwSig       <= '0';
            devBrstSig     <= '0';
            devAddr        <= (others => (others => '0'));
            devDataOutSig  <= (others => (others => '0'));
            devExec        <= '0';
            busy           <= '0';
            brstByteNum    <= (others => '0');
            brstBuff       <= (others => (others => '0'));
            brstCollect    <= '0';
            wEnFifo        <= '0';
            txWSig         <= '0';
            rstFifo        <= '1';
            wordWrtOld     <= '0';
            error          <= (others => '0');

            state          <= idle;
        else
            wordWrtOld <= wordWrt;

            case state is
                when idle =>
                    tOutRst <= '1';
                    busy    <= '0';
                    devExec <= '0';
                    rxRdSig <= rxPresent;

                    state   <= idle;

                    if rxPresent = '1' and validSig = '1' then
                        devRwSig   <= rwSig;
                        devBrstSig <= brstSig;
                        devIdSig   <= slvToDev(dataIn(3 downto 0));
                        busy       <= '1';
                        error      <= (others => '0');

                        state      <= getDev;
                    end if;

                when getDev =>
                    tOutRst <= '0';
                    rstFifo <= '0';

                    state   <= getDev;

                    if devIdSig = none then
                        tOutRst <= '1';
                        rxRdSig <= '0';
                        busy    <= '0';

                        state   <= idle;
                    elsif rxPresent = '1' then
                        tOutRst    <= '1';
                        rxRdSig    <= '1';

                        state      <= getAddr;
                    elsif tOutSig = '1'  then
                        tOutRst <= '1';
                        rxRdSig <= '0';

                        state   <= errFifo;
                    end if;

                when getAddr =>
                    i := to_integer(byteCnt);

                    tOutRst <= '0';

                    state   <= getAddr;

                    if endCnt = '1' and devRwSig = devWrite then
                        tOutRst <= '1';
                        byteCnt <= to_unsigned(devDataBytes-1, byteCnt'length);

                        state   <= getData;
                    elsif endCnt = '1' and devRwSig = devRead then
                        tOutRst <= '1';
                        byteCnt <= to_unsigned(devDataBytes-1, byteCnt'length);
                        devExec <= '1';

                        state <= getData;

                        if devBrstSig = '0' then
                            byteCnt <= (others => '0');

                            state   <= readDev;
                        end if;
                    elsif rxPresent = '1' then
                        tOutRst    <= '1';
                        byteCnt    <= byteCnt - 1;
                        devAddr(i) <= dataIn;
                    elsif tOutSig = '1' then
                        tOutRst <= '1';
                        rxRdSig <= '0';

                        state   <= errFifo;
                    end if;

                when getData =>
                    i := to_integer(byteCnt);

                    tOutRst <= '0';

                    state   <= getData;

                    if endCnt = '1' and devBrstSig = '0' then
                        tOutRst <= '1';
                        rxRdSig <= '0';

                        state   <= done;
                    elsif endCnt = '1' and devBrstSig = '1' and brstCollect = '0' then
                        tOutRst <= '1';
                        rxRdSig <= '0';

                        state   <= checkBrstPar;
                    elsif endCnt = '1' and devBrstSig = '1' and brstCollect = '1' then
                        tOutRst     <= '1';
                        rxRdSig     <= '0';
                        devExec     <= '1';
                        brstCollect <= '0';
                        byteCnt     <= resize(brstByteNum, byteCnt'length);

                        state       <= sendBrst;
                    elsif rxPresent = '1' and brstCollect = '0' then
                        tOutRst          <= '1';
                        rxRdSig          <= '1';
                        byteCnt          <= byteCnt - 1;
                        devDataOutSig(i) <= dataIn;
                    elsif rxPresent = '1' and brstCollect = '1' then
                        tOutRst     <= '1';
                        rxRdSig     <= '1';
                        byteCnt     <= byteCnt - 1;
                        brstBuff(i) <= dataIn;
                    elsif tOutSig = '1' then
                        tOutRst <= '1';
                        rxRdSig <= '0';

                        state   <= errTOut;
                    end if;

                when checkBrstPar =>
                    rxRdSig      <= '1';
                    brstByteNum  <= resize(devDataToUnsigned(devDataOutSig)-1, brstByteNum'length);
                    byteCnt      <= resize(devDataToUnsigned(devDataOutSig)-1, byteCnt'length);
                    brstCollect  <= '1';

                    if devRwSig = devWrite then
                        state <= getData;
                    else
                        state <= readDev;
                    end if;

                    if unsigned(devDataToSlv(devDataOutSig)) = 0 then
                        state <= errBrstPar;
                    elsif unsigned(devDataToSlv(devDataOutSig)) > maxBrstLen then
                        brstByteNum <= to_unsigned(maxBrstLen-1, brstByteNum'length);
                        byteCnt     <= to_unsigned(maxBrstLen-1, byteCnt'length);
                    end if;

                when sendBrst =>
                    i := to_integer(byteCnt);

                    devExec <= '0';

                    state   <= sendBrst;

                    if devReady(devIdSig) = '1' and lastBrst = '0' then
                        devExec <= '1';
                        byteCnt <= byteCnt - devDataBytes;

                        byteArrCpy(devDataOutSig, brstBuff, i);
                    elsif devReady(devIdSig) = '1' and lastBrst = '1' and devBrstSig = '1' then
                        devBrstSig    <= '0';
                        devDataOutSig <= (0      => std_logic_vector(resize(brstByteNum(1 downto 0), 8)),
                                          others => (others => '0'));
                    elsif lastBrst = '1' and devBrstSig = '0' then
                        devDataOutSig <= (others => (others => '0'));

                        byteArrCpy(devDataOutSig, brstBuff, i);

                        state <= done;
                    end if;

                when readDev =>
                    tOutRst  <= '0';
                    devExec  <= '0';
                    rxEna    <= '0';
                    wEnFifo  <= '0';

                    state    <= readDev;

                    if devReady(devIdSig) = '1' then
                        tOutRst <= '1';
                        wEnFifo <= '1';
                    elsif wAckFifo = '1' then
                        byteCnt <= byteCnt - 1;
                    elsif byteCnt = 0 and devBrstSig = '1' then
                        devBrstSig <= '0';
                    elsif wordWrtRise = '1' or (endCnt = '1' and dValidFifo = '1') then
                        tOutRst <= '1';
                        txWSig  <= '1';

                        state   <= sendDevData;
                    elsif tOutSig = '1' then
                        tOutRst <= '1';
                        rxEna   <= '1';

                        state   <= errTOut;
                    end if;

                when sendDevData =>
                    tOutRst <= '0';
                    txWSig  <= txWrAck and not emptyFifo;

                    state   <= sendDevData;

                    if emptyFifo = '1' and endCnt = '0' then
                        state <= readDev;
                    elsif emptyFifo = '1' and endCnt = '1' then
                        state <= done;
                    end if;

                when done =>
                    devExec <= '0';
                    byteCnt <= to_unsigned(devAddrBytes-1, byteCnt'length);
                    txWSig  <= '0';
                    error   <= (others => '0');

                    state   <= done;

                    if devBrstSig = '0' then
                        devExec <= not devRwSig;
                        rxEna   <= '1';
                        busy    <= '0';

                        state   <= idle;
                    elsif devBrstSig = '1' and devReady(devIdSig) = '1' then
                        rxEna   <= '1';
                        busy    <= '0';

                        state   <= idle;
                    end if;

                when errTOut =>
                    tOutRst       <= '1';
                    byteCnt       <= to_unsigned(devAddrBytes-1, byteCnt'length);
                    rxRdSig       <= '0';
                    txWSig        <= '0';
                    rxEna         <= '1';
                    flushRxFifo   <= '0';
                    flushTxFifo   <= '0';
                    devIdSig      <= none;
                    devAddr       <= (others => (others => '0'));
                    devDataOutSig <= (others => (others => '0'));
                    devBrstSig    <= '0';
                    busy          <= '0';
                    error         <= "001";

                    state         <= idle;

                when errFifo =>
                    tOutRst       <= '1';
                    byteCnt       <= to_unsigned(devAddrBytes-1, byteCnt'length);
                    rxRdSig       <= '0';
                    txWSig        <= '0';
                    rxEna         <= '1';
                    flushRxFifo   <= '0';
                    flushTxFifo   <= '0';
                    devIdSig      <= none;
                    devAddr       <= (others => (others => '0'));
                    devDataOutSig <= (others => (others => '0'));
                    devBrstSig    <= '0';
                    busy          <= '0';
                    error         <= "010";

                    state         <= idle;

                when errBrstPar =>
                    tOutRst       <= '1';
                    byteCnt       <= to_unsigned(devAddrBytes-1, byteCnt'length);
                    rxRdSig       <= '0';
                    txWSig        <= '0';
                    rxEna         <= '1';
                    flushRxFifo   <= '0';
                    flushTxFifo   <= '0';
                    devIdSig      <= none;
                    devAddr       <= (others => (others => '0'));
                    devDataOutSig <= (others => (others => '0'));
                    devBrstSig    <= '0';
                    busy          <= '0';
                    error         <= "011";

                    state         <= idle;

                when others =>
                    tOutRst       <= '1';
                    byteCnt       <= to_unsigned(devAddrBytes-1, byteCnt'length);
                    rxRdSig       <= '0';
                    txWSig        <= '0';
                    rxEna         <= '1';
                    flushRxFifo   <= '0';
                    flushTxFifo   <= '0';
                    devIdSig      <= none;
                    devAddr       <= (others => (others => '0'));
                    devDataOutSig <= (others => (others => '0'));
                    devBrstSig    <= '0';
                    busy          <= '0';
                    error         <= "111";

                    state         <= idle;
            end case;
        end if;
    end if;
end process;

tOutCntInst: process(clk, rst, tOutRst, tOutSig)
begin
    if rising_edge(clk) then
        if rst = '1' or tOutRst = '1' or tOutSig = '1' then
            tOutCnt <= to_unsigned(tOut-1, tOutCnt'length);
        else
            tOutCnt <= tOutCnt-1;
        end if;
    end if;
end process;

xpm_fifo_sync_inst : xpm_fifo_sync
generic map(
    FIFO_MEMORY_TYPE  => "block",
    FIFO_READ_LATENCY => 0,
    FIFO_WRITE_DEPTH  => maxBrstLen,
    READ_DATA_WIDTH   => 8,
    READ_MODE         => "fwft",
    USE_ADV_FEATURES  => "1010",
    WRITE_DATA_WIDTH  => 8
)
port map(
    dout          => dataOut,
    empty         => emptyFifo,
    full          => open,
    din           => dataToFifo,
    wr_en         => wEnFifo,
    wr_clk        => clk,
    rd_en         => txWSig,
    rst           => rstFifo,
    data_valid    => dValidFifo,
    wr_ack        => wAckFifo,
    sleep         => '0',
    almost_empty  => open,
    almost_full   => open,
    dbiterr       => open,
    overflow      => open,
    prog_empty    => open,
    prog_full     => open,
    rd_data_count => open,
    rd_rst_busy   => open,
    sbiterr       => open,
    underflow     => open,
    wr_data_count => open,
    wr_rst_busy   => open,
    injectdbiterr => '0',
    injectsbiterr => '0'

);

end Behavioral;