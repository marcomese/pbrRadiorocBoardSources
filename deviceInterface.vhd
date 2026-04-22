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
    idHeader    : std_logic_vector(3 downto 0);
    broadcastId : std_logic_vector(3 downto 0);
    readCmd     : std_logic_vector(3 downto 0);
    writeCmd    : std_logic_vector(3 downto 0);
    burstWrCmd  : std_logic_vector(3 downto 0);
    burstRdCmd  : std_logic_vector(3 downto 0);
    maxBrstLen  : natural -- maximum number of bytes to read/write in burst mode
);
port(
    clk         : in  std_logic;
    rst         : in  std_logic;
    id          : in  std_logic_vector(3 downto 0);
    dataIn      : in  std_logic_vector(7 downto 0);
    dataOut     : out std_logic_vector(7 downto 0);
    rxRead      : out std_logic;
    rxPresent   : in  std_logic;
    rxValid     : in  std_logic;
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
end deviceInterface;

architecture Behavioral of deviceInterface is

type state_t is (idle,
                 getCmd,
                 getDev,
                 getAddr,
                 getData,
                 checkBrstPar,
                 addPadding,
                 sendBrst,
                 readBrst,
                 readDev,
                 sendDevData,
                 done,
                 waitDevBusy,
                 waitRstFifo,
                 errFifo,
                 errTOut,
                 errBrstPar);

constant tOut          : integer := integer(clkFreq*timeout);
constant bytesNum      : integer := maxBrstLen;
constant brdcstId      : std_logic_vector(7 downto 0) := idHeader & broadcastId;

signal   state         : state_t;
signal   tOutRst,
         tOutSig,
         brstWrRstBusy,
         brstRdRstBusy,
         brstFifoRstBusy,
         dataWrRstBusy,
         dataRdRstBusy,
         dataFifoRstBusy,
         validId,
         rwSig,
         rxRdSig,
         rxRdInhib,
         rstAddr,
         loadAddr,
         loadBrstBuff,
         readBrstBuff,
         rstDataOut,
         loadDataIn,
         loadLastBrst,
         brstBuffValid,
         brstSig,
         validSig,
         devRwSig,
         devBrstSig,
         devBusyChk,
         brstCollect,
         paddCollect,
         lastBrst,
         wEnFifo,
         rEnFifo,
         txWSig,
         rstFifo,
         rstBrstBuff,
         wordWrt,
         wAckFifo,
         emptyFifo,
         endCnt,
         locRst        : std_logic;
signal   devIdSig      : devices_t;
signal   tOutCnt       : unsigned(bitsNum(tOut) downto 0);
signal   byteCnt       : unsigned(bitsNum(bytesNum) downto 0);
signal   brstByteNum   : unsigned(bitsNum(bytesNum)-1 downto 0);
signal   paddCnt       : unsigned(1 downto 0);
signal   devDataOutSig : devData_t;
signal   devAddrSig    : devAddr_t;
signal   dataToFifoSel : std_logic_vector(1 downto 0);
signal   dataToFifo    : std_logic_vector(7 downto 0);
signal   idSig         : std_logic_vector(7 downto 0);
signal   dataBrstOut   : std_logic_vector(31 downto 0);

begin

rxRead          <= rxRdSig;
txWrite         <= txWSig;
devRw           <= devRwSig;
devBrst         <= devBrstSig;
devId           <= devIdSig;
devDataOut      <= devDataOutSig;
devAddr         <= devAddrSig;
endCnt          <= byteCnt(byteCnt'left);
tOutSig         <= tOutCnt(tOutCnt'left);
dataFifoRstBusy <= dataWrRstBusy or dataRdRstBusy;
brstFifoRstBusy <= brstWrRstBusy or brstRdRstBusy;
loadBrstBuff    <= (rxValid and brstCollect) or paddCollect;
lastBrst        <= not or_reduce(std_logic_vector(byteCnt(byteCnt'left downto 2)));
idSig           <= idHeader & id;

locRstProc: process(clk)
begin
    if rising_edge(clk) then
        locRst <= rst;
    end if;
end process;

devAddrCtrl: process(clk)
begin
    if rising_edge(clk) then
        if rstAddr = '1' then
            devAddrSig <= (others => (others => '0'));
        elsif loadAddr = '1' and rxValid = '1' and endCnt = '0' then
            devAddrSig <= devAddrSig(devAddrSig'left-1 downto 0) & dataIn;
        end if;
    end if;
end process;

devDataOutCtrl: process(clk)
begin
    if rising_edge(clk) then
        if rstDataOut = '1' then
            devDataOutSig <= (others => (others => '0'));
        else
            if loadDataIn = '1' and rxValid = '1' and endCnt = '0' then
                devDataOutSig <= devDataOutSig(devDataOutSig'left-1 downto 0) & dataIn;
            elsif loadLastBrst = '1' then
                devDataOutSig <= (0      => std_logic_vector(resize(brstByteNum(1 downto 0), 8)),
                                  others => (others => '0'));
            elsif brstBuffValid = '1' then
                devDataOutSig <= slvToDevData(dataBrstOut, LITTLE_ENDIAN);
            end if;
        end if;
    end if;
end process;

validIdMux: process(dataIn)
begin
    if dataIn = idSig then
        validId <= '1';
    elsif dataIn = brdcstId then
        validId <= '1';
    else
        validId <= '0';
    end if;
end process;

devRwDecMux: process(dataIn(7 downto 4))
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

dataToFifoMux: process(dataToFifoSel, devDataIn, byteCnt, devIdSig)
begin
    case dataToFifoSel is
        when "00" =>
            dataToFifo <= (others => '0');
        when "01" =>
            dataToFifo <= (others => '0');
        when "10" =>
            dataToFifo <= devDataIn(devIdSig)(to_integer(byteCnt(1 downto 0)));
        when "11" =>
            dataToFifo <= devDataIn(devIdSig)(0);
        when others =>
            dataToFifo <= (others => '0');
    end case;
end process;

devFSM: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            tOutRst       <= '0';
            byteCnt       <= to_unsigned(devAddrBytes-1, byteCnt'length);
            paddCnt       <= (others => '0');
            rxRdSig       <= '0';
            rxRdInhib     <= '0';
            txWSig        <= '0';
            rxEna         <= '1';
            flushRxFifo   <= '1';
            flushTxFifo   <= '1';
            devIdSig      <= none;
            devRwSig      <= '0';
            devBrstSig    <= '0';
            devBrstWrt    <= '0';
            devBrstSnd    <= '0';
            devBusyChk    <= '0';
            rstAddr       <= '1';
            loadAddr      <= '0';
            devExec       <= '0';
            busy          <= '0';
            brstByteNum   <= (others => '0');
            brstCollect   <= '0';
            paddCollect   <= '0';
            readBrstBuff  <= '0';
            rstDataOut    <= '1';
            loadDataIn    <= '0';
            loadLastBrst  <= '0';
            wEnFifo       <= '0';
            rEnFifo       <= '0';
            txWSig        <= '0';
            rstFifo       <= '1';
            rstBrstBuff   <= '1';
            dataToFifoSel <= "00";
            error         <= (others => '0');

            state         <= idle;
        else
            case state is
                when idle =>
                    tOutRst     <= '1';
                    busy        <= '0';
                    devExec     <= '0';
                    rstFifo     <= '0';
                    rstBrstBuff <= '0';
                    rstAddr     <= '1';
                    flushRxFifo <= '0';
                    flushTxFifo <= '0';
                    rxRdSig     <= '0';

                    state       <= idle;

                    if rxPresent = '1' and rxRdInhib = '0' then
                        rxRdSig   <= '1';
                        rxRdInhib <= '1';
                    elsif rxValid = '1' and validId = '1' then
                        busy       <= '1';
                        rstAddr    <= '0';
                        rstDataOut <= '0';
                        rxRdInhib  <= '0';

                        state      <= getCmd;
                    end if;

                when getCmd =>
                    tOutRst <= '0';
                    rxRdSig <= '0';

                    state   <= getCmd;

                    if rxPresent = '1' and rxRdInhib = '0' then
                        rxRdInhib <= '1';
                        rxRdSig   <= '1';
                    elsif rxValid = '1' and validSig = '1' then
                        tOutRst       <= '1';
                        rxRdInhib     <= '0';
                        devRwSig      <= rwSig;
                        devBrstSig    <= brstSig;
                        dataToFifoSel <= rwSig & brstSig;
                        devIdSig      <= slvToDev(dataIn(3 downto 0));
                        error         <= (others => '0');

                        state         <= getDev;
                    end if;

                when getDev =>
                    tOutRst <= '0';

                    state   <= getDev;

                    if devIdSig = none then
                        tOutRst <= '1';
                        busy    <= '0';

                        state   <= idle;
                    elsif rxPresent = '1' and devBusy(devIdSig) = '1' then
                        state <= getDev;
                    elsif rxPresent = '1' and devBusy(devIdSig) = '0' then
                        tOutRst  <= '1';
                        loadAddr <= '1';

                        state    <= getAddr;
                    elsif tOutSig = '1'  then
                        tOutRst <= '1';

                        state   <= errFifo;
                    end if;

                when getAddr =>
                    tOutRst   <= '0';
                    rxRdSig   <= '0';

                    state     <= getAddr;

                    if rxValid = '1' then
                        tOutRst  <= '1';
                        byteCnt  <= byteCnt - 1;
                    elsif rxPresent = '1' and rxRdSig = '0' and endCnt = '0' then
                        rxRdSig <= '1';
                    elsif endCnt = '1' and devRwSig = devWrite then
                        tOutRst    <= '1';
                        loadAddr   <= '0';
                        loadDataIn <= '1';
                        byteCnt    <= to_unsigned(devDataBytes-1, byteCnt'length);

                        state    <= getData;
                    elsif endCnt = '1' and devRwSig = devRead then
                        tOutRst    <= '1';
                        loadAddr   <= '0';
                        loadDataIn <= '1';
                        byteCnt    <= to_unsigned(devDataBytes-1, byteCnt'length);
                        devExec    <= not devBrstSig;

                        state      <= getData;

                        if devBrstSig = '0' then
                            state <= readDev;
                        end if;
                    elsif tOutSig = '1' then
                        tOutRst <= '1';

                        state   <= errFifo;
                    end if;

                when getData =>
                    tOutRst   <= '0';
                    loadAddr  <= '0';
                    rxRdSig   <= '0';

                    state     <= getData;

                    if rxValid = '1' and brstCollect = '0' then
                        tOutRst <= '1';
                        byteCnt <= byteCnt - 1;
                    elsif rxValid = '1' and brstCollect = '1' then
                        tOutRst      <= '1';
                        byteCnt      <= byteCnt - 1;
                    elsif rxPresent = '1' and rxRdSig = '0' and endCnt = '0' then
                        rxRdSig <= '1';
                    elsif endCnt = '1' and devBrstSig = '0' then
                        tOutRst    <= '1';
                        loadDataIn <= '0';

                        state      <= done;
                    elsif endCnt = '1' and devBrstSig = '1' and brstCollect = '0' then
                        tOutRst    <= '1';
                        loadDataIn <= '0';

                        state      <= checkBrstPar;
                    elsif endCnt = '1' and devBrstSig = '1' and brstCollect = '1' then
                        tOutRst     <= '1';
                        brstCollect <= '0';
                        paddCollect <= '1';
                        loadDataIn  <= '0';
                        byteCnt     <= resize(brstByteNum, byteCnt'length);

                        state       <= addPadding;
                    elsif tOutSig = '1' then
                        tOutRst    <= '1';
                        loadDataIn <= '0';

                        state      <= errTOut;
                    end if;

                when addPadding =>
                    paddCnt   <= paddCnt - 1;

                    state   <= addPadding;

                    if paddCnt = 0 then
                        paddCollect <= '0';
                        devExec     <= '1';

                        state       <= sendBrst;
                    end if;

                when checkBrstPar =>
                    brstByteNum <= resize(devDataToUnsigned(devDataOutSig)-1, brstByteNum'length);
                    byteCnt     <= resize(devDataToUnsigned(devDataOutSig)-1, byteCnt'length);
                    paddCnt     <= resize(4-devDataToUnsigned(devDataOutSig), paddCnt'length);
                    brstCollect <= '1';

                    if devRwSig = devWrite then
                        state <= getData;
                    else
                        devExec       <= '1';
                        brstCollect   <= '0';

                        state         <= readBrst;
                    end if;

                    if devDataToUnsigned(devDataOutSig) = 0 then
                        state <= errBrstPar;
                    elsif devDataToUnsigned(devDataOutSig) > maxBrstLen then
                        brstByteNum <= to_unsigned(maxBrstLen-1, brstByteNum'length);
                        byteCnt     <= to_unsigned(maxBrstLen-1, byteCnt'length);
                    end if;

                when sendBrst =>
                    devExec       <= '0';
                    readBrstBuff  <= '0';
                    loadLastBrst  <= '0';

                    state         <= sendBrst;

                    if devReady(devIdSig) = '1' and lastBrst = '0' then
                        devExec      <= '1';
                        readBrstBuff <= '1';
                        byteCnt      <= byteCnt - devDataBytes;
                    elsif devReady(devIdSig) = '1' and lastBrst = '1' and devBrstSig = '1' then
                        devBrstSig    <= '0';
                        loadLastBrst  <= '1';
                    elsif lastBrst = '1' and devBrstSig = '0' then
                        readBrstBuff  <= '1';

                        state         <= done;
                    elsif devBrstRst(devIdSig) = '1' then
                        devBrstSig    <= '0';

                        state         <= done;
                    end if;

                when readDev =>
                    tOutRst  <= '0';
                    devExec  <= '0';
                    rxEna    <= '0';
                    wEnFifo  <= devReady(devIdSig) or wAckFifo;
                    byteCnt  <= byteCnt - stdLogicToInt(wAckFifo);

                    state    <= readDev;

                    if byteCnt = 0 then
                        rEnFifo <= '1';
                        byteCnt <= byteCnt - 1;

                        state   <= sendDevData;
                    end if;

                when readBrst =>
                    tOutRst     <= '0';
                    devExec     <= '0';
                    rxEna       <= '0';
                    devBrstWrt  <= '0';
                    devBrstSnd  <= '0';
                    wEnFifo     <= devReady(devIdSig);

                    state       <= readBrst;

                    if wAckFifo = '1' then
                        devBrstWrt  <= '1';
                        byteCnt     <= byteCnt - 1;
                    elsif byteCnt = 0 and devBrstSig = '1' then
                        devBrstSig <= '0';
                    elsif wordWrt = '1' or endCnt = '1' then
                        tOutRst    <= '1';
                        rEnFifo    <= '1';
                        devBrstSnd <= '1';

                        state      <= sendDevData;
                    elsif devBrstRst(devIdSig) = '1' then
                        devBrstSig <= '0';

                        state      <= done;
                    elsif tOutSig = '1' then
                        tOutRst <= '1';
                        rxEna   <= '1';

                        state   <= errTOut;
                    end if;

                when sendDevData =>
                    tOutRst     <= '0';
                    wEnFifo     <= '0';
                    rEnFifo     <= txWrAck and not emptyFifo;
                    txWSig      <= rEnFifo;
                    devBrstSnd  <= not emptyFifo;

                    state   <= sendDevData;

                    if emptyFifo = '1' and endCnt = '0' then
                        state       <= readBrst;
                    elsif emptyFifo = '1' and endCnt = '1' then
                        state <= done;
                    elsif devBrstRst(devIdSig) = '1' then
                        devBrstSig <= '0';

                        state      <= done;
                    end if;

                when done =>
                    devExec      <= '0';
                    byteCnt      <= to_unsigned(devAddrBytes-1, byteCnt'length);
                    txWSig       <= '0';
                    readBrstBuff <= '0';
                    error        <= (others => '0');

                    state        <= done;

                    if devBrstSig = '0' then
                        devExec <= not devRwSig;
                        rxEna   <= '1';
                        busy    <= '0';

                        state   <= waitDevBusy;
                    elsif devBrstSig = '1' and devReady(devIdSig) = '1' then
                        rxEna <= '1';
                        busy  <= '0';

                        state <= waitDevBusy;
                    end if;

                when waitDevBusy =>
                    devExec     <= '0';
                    rstFifo     <= '1';
                    rstBrstBuff <= '1';

                    state <= waitDevBusy;

                    if devBusy(devIdSig) = '0' and devBusyChk = '0' then
                        devBusyChk <= '1';

                        state      <= waitDevBusy;
                    elsif devBusy(devIdSig) = '0' and devBusyChk = '1' then
                        rstDataOut <= '1';
                        devBusyChk <= '0';

                        state      <= waitRstFifo;
                    end if;

                when waitRstFifo =>
                    rstFifo     <= '0';
                    rstBrstBuff <= '0';

                    state       <= waitRstFifo;

                    if brstFifoRstBusy = '0' and dataFifoRstBusy = '0' then
                        state <= idle;
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
                    devBrstSig    <= '0';
                    busy          <= '0';
                    rstDataOut    <= '1';
                    rstFifo       <= '1';
                    rstBrstBuff   <= '1';
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
                    devBrstSig    <= '0';
                    busy          <= '0';
                    rstDataOut    <= '1';
                    rstFifo       <= '1';
                    rstBrstBuff   <= '1';
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
                    devBrstSig    <= '0';
                    busy          <= '0';
                    rstDataOut    <= '1';
                    rstFifo       <= '1';
                    rstBrstBuff   <= '1';
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
                    devBrstSig    <= '0';
                    busy          <= '0';
                    rstDataOut    <= '1';
                    rstFifo       <= '1';
                    rstBrstBuff   <= '1';
                    error         <= "111";

                    state         <= idle;
            end case;
        end if;
    end if;
end process;

tOutCntInst: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' or tOutRst = '1' or tOutSig = '1' then
            tOutCnt <= to_unsigned(tOut-1, tOutCnt'length);
        else
            tOutCnt <= tOutCnt-1;
        end if;
    end if;
end process;

brstBuffInst: xpm_fifo_sync
generic map(
    FIFO_WRITE_DEPTH  => maxBrstLen,
    READ_DATA_WIDTH   => 32,
    WRITE_DATA_WIDTH  => 8,
    READ_MODE         => "std",
    USE_ADV_FEATURES  => "1010",
    FIFO_MEMORY_TYPE  => "block"
)
port map(
    wr_clk        => clk,
    rst           => rstBrstBuff,
    din           => dataIn,
    wr_en         => loadBrstBuff,
    dout          => dataBrstOut,
    rd_en         => readBrstBuff,
    data_valid    => brstBuffValid,
    wr_rst_busy   => brstWrRstBusy,
    rd_rst_busy   => brstRdRstBusy,
    empty         => open,
    full          => open,
    sleep         => '0',
    injectdbiterr => '0',
    injectsbiterr => '0'
);

dataFifoInst : xpm_fifo_sync
generic map(
    FIFO_WRITE_DEPTH  => maxBrstLen,
    PROG_FULL_THRESH  => 4,
    READ_DATA_WIDTH   => 8,
    WRITE_DATA_WIDTH  => 8,
    READ_MODE         => "std",
    USE_ADV_FEATURES  => "0012",
    FIFO_MEMORY_TYPE  => "block"
)
port map(
    wr_clk        => clk,
    rst           => rstFifo,
    din           => dataToFifo,
    wr_en         => wEnFifo,
    dout          => dataOut,
    rd_en         => rEnFifo,
    wr_ack        => wAckFifo,
    wr_rst_busy   => dataWrRstBusy,
    rd_rst_busy   => dataRdRstBusy,
    empty         => emptyFifo,
    full          => open,
    prog_full     => wordWrt,
    sleep         => '0',
    injectdbiterr => '0',
    injectsbiterr => '0'
);

end Behavioral;