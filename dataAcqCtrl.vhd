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
    clk25M     : in  std_logic;
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
    resetAcq   : out std_logic;
    startAcq   : out std_logic;
    endAcq     : in  std_logic;
    endMAcq    : out std_logic;
    rdValid    : in  std_logic;
    rdAcq      : out std_logic;
    rdDataCnt  : in  std_logic_vector(15 downto 0);
    emptyAcq   : in  std_logic;
    nbAcq      : out std_logic_vector(7 downto 0);
    selAdc     : out std_logic_vector(63 downto 0);
    doutAcq    : in  std_logic_vector(7 downto 0)
);
end dataAcqCtrl;

architecture Behavioral of dataAcqCtrl is

--------------------- registers definitions ------------------------

type addr is (regStatus,
              regAcqEn,
              regSwTrg,
              regFifoCnt);

constant reg : regsRec_t := (
    addr'pos(regStatus)   => (rAddr => 0, rBegin => 31, rEnd => 2, rMode => ro),
    addr'pos(regAcqEn)    => (rAddr => 0, rBegin => 1,  rEnd => 1, rMode => rw),
    addr'pos(regSwTrg)    => (rAddr => 0, rBegin => 0,  rEnd => 0, rMode => rw),
    addr'pos(regFifoCnt)  => (rAddr => 1, rBegin => 15, rEnd => 0, rMode => ro)
);

constant regsNum  : integer := reg(reg'high).rAddr+1;

signal   rData    : regsData_t(regsNum-1 downto 0);

--------------------------------------------------------------------

type state_t is (idle,
                 getNbAcq,
                 sendStartAcq,
                 sendSftTrg,
                 readFifo,
                 waitRdValid,
                 getLastByte,
                 sendData,
                 acqEnd,
                 errAddr,
                 errReadOnly);

constant idleStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant errAddrStatus  : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');

signal state          : state_t;

signal dataOut        : devData_t;

signal dataIn         : devData_t;

signal byteCnt        : unsigned(2 downto 0);

signal dAddr          : integer;

signal swTrg,
       lastByte,
       rstAcqSig,
       strtAcqSig,
       rdAcqSig,
       readSent,
       contAcq        : std_logic;

signal nbAcqSig       : std_logic_vector(7 downto 0);

signal sync100to25In,
       sync100to25Out : std_logic_vector(3 downto 0);

attribute mark_debug : string;
attribute mark_debug of state,
                        sync100to25Out : signal is "true";


begin

-- DEBUG --
selAdc <= "00011001"        & -- 63 downto 56
          "00000000"        & -- 55 downto 48
          "00000010"        & -- 47 downto 40
          "00000000"        & -- 39 downto 32
          "01110111"        & -- 31 downto 24 -- hit = 0
          "00000001"        & -- 23 downto 16
          "00000000"        & -- 15 downto 8
          sync100to25Out(3) & -- 7
          "0000000";          -- 6 downto 0
-----------

dAddr         <= devAddrToInt(devAddr);
nbAcq         <= nbAcqSig;
lastByte      <= '1' when byteCnt = 0 else '0';
resetAcq      <= sync100to25Out(2);
startAcq      <= sync100to25Out(1);
rdAcq         <= sync100to25Out(0);
sync100to25In <= swTrg & rstAcqSig & strtAcqSig & rdAcqSig;
 
clkSyncInst: entity work.pulseExtenderSync
generic map(
    width       => sync100to25Out'length,
    syncStages  => 2,
    clkOrigFreq => 100.0e6,
    clkDestFreq => 25.0e6
)
port map(
    clkOrig     => clk100M,
    rstOrig     => rst,
    clkDest     => clk25M,
    rstDest     => rst,
    sigOrig     => sync100to25In,
    sigDest     => sync100to25Out
);

sclkRiseInst: entity work.edgeDetector
generic map(
    clockEdge => "falling",
    edge      => "rising"
)
port map(
    clk       => clk100M,
    rst       => rst,
    signalIn  => sync100to25Out(0),
    signalOut => readSent
);

dataAcqCtrlFSM: process(clk100M, rst, devExec)
    variable i : integer := 0;
begin
    if rising_edge(clk100M) then
        if rst = '1' then
            devReady   <= '0';
            busy       <= '0';
            rstAcqSig  <= '1';
            strtAcqSig <= '0';
            rdAcqSig   <= '0';
            nbAcqSig   <= (others => '0');
            devDataOut <= (others => (others => '0'));
            swTrg      <= '0';
            contAcq    <= '0';
            byteCnt    <= to_unsigned(3, byteCnt'length);

            state      <= idle;
        else
            writeReg(reg, rData, addr'pos(regFifoCnt), resize(unsigned(rdDataCnt), regsLen));

            case state is
                when idle =>
                    devReady   <= '0';
                    rstAcqSig  <= '0';
                    strtAcqSig <= '0';
                    busy       <= '0';

                    state      <= idle;

                    if devExec = '1' and devId = acqSystem then
                        if dAddr > addr'pos(addr'high) then
                            state    <= errAddr;
                        elsif devRw = devRead then
                            writeReg(reg, rData, addr'pos(regStatus), idleStatus);
                            devReady   <= '1';
                            devDataOut <= readReg(reg, rData, dAddr);
                            busy       <= '1';

                            state      <= idle;
                        elsif devRw = devWrite and reg(dAddr).rMode = ro then
                            state    <= errReadOnly;
                        elsif devRw = devWrite and reg(dAddr).rMode = rw then
                            writeReg(reg, rData, addr'pos(regStatus), dAddr);
                            writeReg(reg, rData, dAddr, devDataIn);
                            busy  <= '1';

                            state <= idle;
                        end if;
                    elsif contAcq = '1' and endAcq = '1' then
                        rdAcqSig   <= '1';
                        strtAcqSig <= '1';

                        state      <= readFifo;
                    end if;

                when getNbAcq =>
                    nbAcqSig <= devAddr(0);

                    state    <= sendStartAcq;

                when sendStartAcq =>
                    rstAcqSig  <= '0';
                    strtAcqSig <= '1';

                    state      <= sendStartAcq;

                    if nbAcqSig = x"00" then
                        rstAcqSig <= '1';

                        state     <= sendSftTrg;
                    elsif nbAcqSig = x"FF" then
                        rdAcqSig <= '1';

                        state    <= readFifo;
                    elsif nbAcqSig = x"AA" then
                        contAcq    <= '1';
                        strtAcqSig <= '1';
                        nbAcqSig   <= x"FF";

                        state      <= idle;
                    elsif nbAcqSig = x"EE" then
                        contAcq   <= '0';
                        rstAcqSig <= '1';

                        state     <= idle;
                    end if;

                when sendSftTrg =>
                    rstAcqSig <= '0';

                    state     <= sendSftTrg;

                    if sync100to25Out(2) = '1' then
                        swTrg    <= '1';
                        devReady <= '1';

                        state    <= idle;
                    end if;

                when readFifo =>
                    rdAcqSig <= '0';

                    state    <= readFifo;

                    if (lastByte = '1' or emptyAcq = '1') and readSent = '1' then
                        state <= getLastByte;
                    elsif readSent = '1' then
                        rdAcqSig <= '1';

                        state    <= waitRdValid;
                    end if;

                when waitRdValid =>
                    i := to_integer(byteCnt);

                    rdAcqSig <= '0';

                    state    <= waitRdValid;

                    if rdValid = '1' then
                        dataOut(i) <= doutAcq;
                        byteCnt    <= byteCnt - 1;

                        state      <= readFifo;
                    end if;

                when getLastByte =>
                    i := to_integer(byteCnt);

                    rdAcqSig   <= '0';
                    dataOut(i) <= doutAcq;
                    devDataOut <= dataOut;

                    state      <= sendData;

                when sendData =>
                    devReady   <= '1';
                    devDataOut <= dataOut;
                    byteCnt    <= to_unsigned(3, byteCnt'length);

                    state      <= acqEnd;

                when acqEnd =>
                    busy      <= '0';
                    rstAcqSig <= '0';

                    state     <= idle;                    

                    if emptyAcq = '1' then
                        rstAcqSig <= '1';
                    end if;

                when errAddr =>
                    writeReg(reg, rData, addr'pos(regStatus), errAddrStatus);
                    busy  <= '0';

                    state <= idle;

                when errReadOnly =>
                    writeReg(reg, rData, addr'pos(regStatus), errROnlyStatus);
                    busy  <= '0';

                    state <= idle;

                when others =>
                    devReady <= '0';
                    busy     <= '0';

                    state    <= idle;
            end case;
        end if;
    end if;
end process;

end Behavioral;