----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: dataAcqCtrl
-- Create Date: 08.07.2025 15:47:20
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
-- Revision 0.02 - selAdc (2 x 32 bit) and the event-number register removed;
--                 registers:
--                 regStatus (0)    : status (ro)
--                 regAcqEn (1)     : [0] acquisition enable; writing 1 while
--                                    disabled clears the FIFO and restarts
--                                    the readout; while enabled every valid
--                                    trigger is acquired (no event limit)
--                 regFifoCnt (2)   : bytes in the FIFO (ro)
--                 regTrgCh (3)     : [5:0] trigger channel (T1)
--                 regHoldDelay (4) : [11:0] external hold delay (5 ns cycles)
--                 regCmd (5)       : write-only strobes, bit 0 software
--                                    trigger, bit 1 RADIOROC reset (reads 0)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.utilsPkg.all;
use work.devicesPkg.all;
use work.registersPkg.all;

library xpm;
use xpm.vcomponents.all;

entity dataAcqCtrl is
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
    acqEn      : out std_logic;
    rdValid    : in  std_logic;
    rdAcq      : out std_logic;
    rdDataCnt  : in  std_logic_vector(16 downto 0);
    emptyAcq   : in  std_logic;
    trgCh      : out std_logic_vector(5 downto 0);
    holdDelay  : out std_logic_vector(11 downto 0);
    swTrg      : out std_logic;
    asicRst    : out std_logic;
    doutAcq    : in  std_logic_vector(7 downto 0)
);
end dataAcqCtrl;

architecture Behavioral of dataAcqCtrl is

--------------------- registers definitions ------------------------

type addr is (regStatus,
              regAcqEn,
              regFifoCnt,
              regTrgCh,
              regHoldDelay,
              regCmd);

constant reg : regsRec_t := (
    addr'pos(regStatus)    => (rAddr => 0, rBegin => 31,  rEnd => 0,  rMode => ro),
    addr'pos(regAcqEn)     => (rAddr => 1, rBegin => 31,  rEnd => 0,  rMode => rw),
    addr'pos(regFifoCnt)   => (rAddr => 2, rBegin => 31,  rEnd => 0,  rMode => ro),
    addr'pos(regTrgCh)     => (rAddr => 3, rBegin => 31,  rEnd => 0,  rMode => rw),
    addr'pos(regHoldDelay) => (rAddr => 4, rBegin => 31,  rEnd => 0,  rMode => rw),
    addr'pos(regCmd)       => (rAddr => 5, rBegin => 31,  rEnd => 0,  rMode => rw)
);

constant regsNum : integer := reg(reg'high).rAddr+1;

-- default external hold delay: 100 cycles = 500 ns
constant holdDelayDef : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(100, 32));

signal   rData   : regsData_t(regsNum-1 downto 0);

--------------------------------------------------------------------

type state_t is (idle,
                 execute,
                 readFifo,
                 waitBrstSent,
                 sendData,
                 acqEnd,
                 errAddr,
                 errReadOnly,
                 errFifoEmpty);

constant idleStatus         : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant errAddrStatus      : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');
constant errFifoEmptyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"B00", '0');

signal state       : state_t;

signal lastData    : devData_t;

signal dAddr,
       lastAddr    : integer;

signal rstAcqSig,
       rdAcqSig,
       loadDataOut,
       loadReg,
       devBrstSig,
       swTrgSig,
       asicRstSig,
       locRst      : std_logic;

begin

dAddr    <= devAddrToInt(devAddr);
resetAcq <= rstAcqSig;
rdAcq    <= rdAcqSig and not devBrstSnd;

locRstProc: process(clk100M)
begin
    if rising_edge(clk100M) then
        locRst <= rst;
    end if;
end process;

devDataOutCtrl: process(clk100M)
begin
    if rising_edge(clk100M) then
        if locRst = '1' then
            devDataOut <= (others => (others => '0'));
        elsif loadDataOut = '1' and devBrstSig = '0' then
            devDataOut <= slvToDevData(rData(lastAddr));
        elsif loadDataOut = '1' and devBrstSig = '1' then
            devDataOut(0) <= doutAcq;
        end if;
    end if;
end process;

rDataCtrl: process(clk100M)
begin
    if rising_edge(clk100M) then
        if locRst = '1' then
            rData <= (others => (others => '0'));

            rData(addr'pos(regHoldDelay)) <= holdDelayDef;
        elsif loadReg = '1' and lastAddr /= addr'pos(regCmd) then
            rData(lastAddr) <= devDataToSlv(lastData);
        else
            rData(addr'pos(regFifoCnt)) <= std_logic_vector(resize(unsigned(rdDataCnt), regsLen));
        end if;
    end if;
end process;

swTrg   <= swTrgSig;
asicRst <= asicRstSig;

acqCfgProc: process(clk100M)
begin
    if rising_edge(clk100M) then
        if locRst = '1' then
            acqEn     <= '0';
            trgCh     <= (others => '0');
            holdDelay <= holdDelayDef(holdDelay'range);
        else
            acqEn     <= rData(addr'pos(regAcqEn))(0);
            trgCh     <= rData(addr'pos(regTrgCh))(5 downto 0);
            holdDelay <= rData(addr'pos(regHoldDelay))(11 downto 0);
        end if;
    end if;
end process;

dataAcqCtrlFSM: process(clk100M)
begin
    if rising_edge(clk100M) then
        if locRst = '1' then
            devReady    <= '0';
            busy        <= '0';
            loadDataOut <= '0';
            loadReg     <= '0';
            rstAcqSig   <= '1';
            rdAcqSig    <= '0';
            devBrstRst  <= '0';
            devBrstSig  <= '0';
            swTrgSig    <= '0';
            asicRstSig  <= '0';
            lastAddr    <= 0;
            lastData    <= (others => (others => '0'));

            state      <= idle;
        else
            case state is
                when idle =>
                    devReady    <= '0';
                    loadDataOut <= '0';
                    loadReg     <= '0';
                    rstAcqSig   <= '0';
                    devBrstSig  <= devBrst;
                    busy        <= '0';
                    swTrgSig    <= '0';
                    asicRstSig  <= '0';

                    state       <= idle;

                    if devExec = '1' and devId = acqSystem then
                        if dAddr > addr'pos(addr'high) then
                            state    <= errAddr;
                        elsif devRw = devRead and devBrst = '0' then
                            lastAddr    <= dAddr;
                            devReady    <= '1';
                            loadDataOut <= '1';
                            busy        <= '1';

                            state       <= idle;
                        elsif devRw = devRead and devBrst = '1' and emptyAcq = '0' then
                            rdAcqSig    <= '1';
                            loadDataOut <= '1';

                            state       <= readFifo;
                        elsif devRw = devRead and devBrst = '1' and emptyAcq = '1' then
                            devBrstRst <= '1';

                            state      <= errFifoEmpty;
                        elsif devRw = devWrite and reg(dAddr).rMode = ro then
                            state    <= errReadOnly;
                        elsif devRw = devWrite and reg(dAddr).rMode = rw then
                            lastAddr <= dAddr;
                            lastData <= devDataIn;
                            loadReg  <= '1';
                            busy     <= '1';

                            state    <= execute;
                        end if;
                    end if;

                when execute =>
                    loadReg <= '0';

                    state   <= idle;

                    -- rData still holds the previous value here
                    if lastAddr = addr'pos(regAcqEn) and lastData(0)(0) = '1' and
                       rData(addr'pos(regAcqEn))(0) = '0' then
                        rstAcqSig <= '1';
                    elsif lastAddr = addr'pos(regCmd) then
                        swTrgSig   <= lastData(0)(0);
                        asicRstSig <= lastData(0)(1);
                    end if;

                when readFifo =>
                    devReady      <= rdValid;
                    rdAcqSig      <= devBrstWrt;

                    state         <= readFifo;

                    if devBrstSnd = '1' then
                        rdAcqSig    <= '0';
                        loadDataOut <= '0';

                        state    <= waitBrstSent; 
                    elsif devBrst = '0' and devBrstWrt = '1' then
                        rdAcqSig    <= '0';
                        loadDataOut <= '0';

                        state    <= acqEnd;
                    end if;

                when waitBrstSent =>
                    state <= waitBrstSent;

                    if devBrstSnd = '0' then
                        rdAcqSig    <= '1';
                        loadDataOut <= '1';

                        state       <= readFifo;
                    elsif emptyAcq = '1' then
                        devBrstRst <= '1';

                        state      <= errFifoEmpty;
                    end if;

                when acqEnd =>
                    busy     <= '0';
                    devReady <= '0';

                    state    <= idle;

                when errAddr =>
                    devReady <= '0';
                    lastAddr <= addr'pos(regStatus);
                    lastData <= slvToDevData(errAddrStatus);
                    loadReg  <= '1';
                    busy     <= '0';

                    state <= idle;

                when errReadOnly =>
                    devReady <= '0';
                    lastAddr <= addr'pos(regStatus);
                    lastData <= slvToDevData(errROnlyStatus);
                    loadReg  <= '1';
                    busy     <= '0';

                    state <= idle;

                when errFifoEmpty =>
                    devReady   <= '0';
                    lastAddr   <= addr'pos(regStatus);
                    lastData   <= slvToDevData(errFifoEmptyStatus);
                    loadReg    <= '1';
                    devBrstRst <= '0';
                    busy       <= '0';

                    state      <= idle;                    

                when others =>
                    devReady <= '0';
                    busy     <= '0';

                    state    <= idle;
            end case;
        end if;
    end if;
end process;

end Behavioral;