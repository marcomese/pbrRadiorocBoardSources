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
use work.utilsPkg.bitsNum;

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
                 sendBrstToDev,
                 readDev,
                 sendDevData,
                 done,
                 errFifo,
                 errTOut,
                 errBrstPar);

type brstBuff_t is array(maxBrstLen-1 downto 0) of std_logic_vector(7 downto 0);

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
         endCnt        : std_logic;
signal   devIdSig      : devices_t;
signal   tOutCnt       : unsigned(bitsNum(tOut) downto 0);
signal   byteCnt       : unsigned(bitsNum(bytesNum) downto 0);
signal   brstByteNum   : unsigned(bitsNum(bytesNum)-1 downto 0);
signal   brstBuff      : brstBuff_t;
signal   devDataOutSig : devData_t;

attribute mark_debug : string;
attribute mark_debug of state     : signal is "true";
attribute mark_debug of error     : signal is "true";
attribute mark_debug of dataIn    : signal is "true";
attribute mark_debug of rxRead    : signal is "true";
attribute mark_debug of rxPresent : signal is "true";
attribute mark_debug of txWrite   : signal is "true";
attribute mark_debug of txWrAck   : signal is "true";
attribute mark_debug of rxEna     : signal is "true";


begin

rxRead     <= rxRdSig and not endCnt;
devRw      <= devRwSig;
devBurst   <= devBrstSig;
devId      <= devIdSig;
devDataOut <= devDataOutSig;
endCnt     <= byteCnt(byteCnt'left);
tOutSig    <= tOutCnt(tOutCnt'left);
lastBrst   <= not or_reduce(std_logic_vector(byteCnt(byteCnt'left downto 2)));

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
            dataOut        <= (others => '0');
            rxRdSig        <= '0';
            txWrite        <= '0';
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
            brstBuff       <= (others => (others => '0'));
            brstCollect    <= '0';
            error          <= (others => '0');

            state          <= idle;
        else
            case state is
                when idle =>
                    if rxPresent = '1' and validSig = '1' then
                        tOutRst    <= '1';
                        rxRdSig    <= '1';
                        devRwSig   <= rwSig;
                        devBrstSig <= brstSig;
                        devIdSig   <= slvToDev(dataIn(3 downto 0));
                        busy       <= '1';
                        error      <= (others => '0');

                        state      <= getDev;
                    elsif rxPresent = '1' and validSig = '0' then
                        tOutRst    <= '1';
                        rxRdSig    <= '1';

                        state      <= idle;
                    else
                        tOutRst <= '1';
                        busy    <= '0';
                        devExec <= '0';

                        state   <= idle;
                    end if;

                when getDev =>
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
                    else
                        tOutRst <= '0';

                        state   <= getDev;
                    end if;

                when getAddr =>
                    i := to_integer(byteCnt);

                    if endCnt = '1' and devRwSig = devWrite then
                        tOutRst    <= '1';
                        byteCnt    <= to_unsigned(devDataBytes-1, byteCnt'length);

                        state      <= getData;
                    elsif endCnt = '1' and devRwSig = devRead then
                        tOutRst    <= '1';
                        byteCnt    <= to_unsigned(devDataBytes-1, byteCnt'length);
                        rxRdSig    <= '0';
                        devExec    <= '1';

                        state      <= readDev;
                    elsif rxPresent = '1' then
                        tOutRst    <= '1';
                        byteCnt    <= byteCnt - 1;
                        devAddr(i) <= dataIn;

                        state      <= getAddr;
                    elsif tOutSig = '1' then
                        tOutRst <= '1';
                        rxRdSig <= '0';

                        state   <= errFifo;
                    else
                        tOutRst    <= '0';

                        state      <= getAddr;
                    end if;

                when getData =>
                    i := to_integer(byteCnt);

                    if endCnt = '1' and devBrstSig = '0' then
                        tOutRst <= '1';
                        rxRdSig <= '0';

                        state   <= done;
                    elsif endCnt = '1' and devBrstSig = '1' and brstCollect = '0' then
                        tOutRst     <= '1';
                        rxRdSig     <= '0';

                        state       <= checkBrstPar;
                    elsif endCnt = '1' and devBrstSig = '1' and brstCollect = '1' then
                        tOutRst     <= '1';
                        rxRdSig     <= '0';
                        devExec     <= '1';
                        brstCollect <= '0';
                        byteCnt     <= resize(brstByteNum, byteCnt'length);

                        state       <= sendBrstToDev;
                    elsif rxPresent = '1' and brstCollect = '0' then
                        tOutRst          <= '1';
                        rxRdSig          <= '1';
                        byteCnt          <= byteCnt - 1;
                        devDataOutSig(i) <= dataIn;

                        state            <= getData;
                    elsif rxPresent = '1' and brstCollect = '1' then
                        tOutRst     <= '1';
                        rxRdSig     <= '1';
                        byteCnt     <= byteCnt - 1;
                        brstBuff(i) <= dataIn;

                        state       <= getData;
                    elsif tOutSig = '1' then
                        tOutRst <= '1';
                        rxRdSig <= '0';

                        state   <= errTOut;
                    else
                        tOutRst <= '0';

                        state   <= getData;
                    end if;

                when checkBrstPar =>
                   if unsigned(devDataToSlv(devDataOutSig)) = 0 then
                        state <= errBrstPar;
                    elsif unsigned(devDataToSlv(devDataOutSig)) > maxBrstLen then
                        rxRdSig     <= '1';
                        brstByteNum <= to_unsigned(maxBrstLen-1, brstByteNum'length);
                        byteCnt     <= to_unsigned(maxBrstLen-1, byteCnt'length);
                        brstCollect <= '1';

                        state       <= getData;
                    else
                        rxRdSig      <= '1';
                        brstByteNum  <= resize(unsigned(devDataToSlv(devDataOutSig))-1, brstByteNum'length);
                        byteCnt      <= resize(unsigned(devDataToSlv(devDataOutSig))-1, byteCnt'length);
                        brstCollect  <= '1';

                        state        <= getData;
                    end if;

                when sendBrstToDev =>
                    i := to_integer(byteCnt);

                    if devReady(devIdSig) = '1' and lastBrst = '0' then
                        devExec <= '1';
                        byteCnt <= byteCnt - devDataBytes;

                        for j in 0 to devDataBytes-1 loop
                            devDataOutSig(devDataBytes-j-1) <= brstBuff(i-j);
                        end loop;

                        state <= sendBrstToDev;
                    elsif devReady(devIdSig) = '1' and lastBrst = '1' and devBrstSig = '1' then
                        devBrstSig    <= '0';
                        devDataOutSig <= (0      => std_logic_vector(resize(brstByteNum(1 downto 0), 8)),
                                          others => (others => '0'));

                        state         <= sendBrstToDev;
                    elsif lastBrst = '1' and devBrstSig = '0' then
                        for j in devDataBytes-1 downto devDataBytes-1-i loop
                            devDataOutSig(j) <= brstBuff(j-(devDataBytes-1-i));
                        end loop;

                        state <= done;
                    else
                        devExec <= '0';

                        state   <= sendBrstToDev;
                    end if;

                when readDev =>
                    i := to_integer(byteCnt);

                    if devReady(devIdSig) = '1' then
                        tOutRst <= '1';
                        devExec <= '0';
                        byteCnt <= byteCnt - 1;
                        dataOut <= devDataIn(devIdSig)(i);
                        txWrite <= '1';
                        rxEna   <= '0';

                        state   <= sendDevData;
                    elsif tOutSig = '1' then
                        tOutRst <= '1';
                        devExec <= '0';
                        rxEna   <= '1';

                        state   <= errTOut;
                    else
                        tOutRst <= '0';
                        devExec <= '0';

                        state   <= readDev;
                    end if;

                when sendDevData =>
                    i := to_integer(byteCnt);

                    if endCnt = '1' then
                        rxRdSig <= '0';
                        txWrite <= '0';
                        byteCnt <= to_unsigned(devAddrBytes-1, byteCnt'length);

                        state   <= done;
                    elsif txWrAck = '1' then
                        tOutRst <= '0';
                        byteCnt <= byteCnt - 1;
                        txWrite <= '1';
                        dataOut <= devDataIn(devIdSig)(i);

                        state   <= sendDevData;
                    else
                        tOutRst <= '0';
                        txWrite <= '0';

                        state   <= sendDevData;
                    end if;

                when done =>
                    if devBrstSig = '0' then
                        devExec <= not devRwSig;
                        rxEna   <= '1';
                        busy    <= '0';
                        error   <= (others => '0');
                        byteCnt <= to_unsigned(devAddrBytes-1, byteCnt'length);
       
                        state   <= idle;
                    elsif devBrstSig = '1' and devReady(devIdSig) = '1' then
                        devExec <= '0';
                        rxEna   <= '1';
                        busy    <= '0';
                        error   <= (others => '0');
                        byteCnt <= to_unsigned(devAddrBytes-1, byteCnt'length);
       
                        state   <= idle;
                    else
                        devExec <= '0';

                        state   <= done;
                    end if;

                when errTOut =>
                    tOutRst       <= '1';
                    byteCnt       <= to_unsigned(devAddrBytes-1, byteCnt'length);
                    dataOut       <= (others => '0');
                    rxRdSig       <= '0';
                    txWrite       <= '0';
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
                    dataOut       <= (others => '0');
                    rxRdSig       <= '0';
                    txWrite       <= '0';
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
                    dataOut       <= (others => '0');
                    rxRdSig       <= '0';
                    txWrite       <= '0';
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
                    dataOut       <= (others => '0');
                    rxRdSig       <= '0';
                    txWrite       <= '0';
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

end Behavioral;