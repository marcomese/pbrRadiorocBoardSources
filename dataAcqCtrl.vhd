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

library xpm;
use xpm.vcomponents.all;

entity dataAcqCtrl is
port(
    clk100M    : in  std_logic;
    clk25M     : in  std_logic;
    rst        : in  std_logic;
    extTrg     : in  std_logic;
    valTrg     : in  std_logic;
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
    rdValid    : in  std_logic;
    rdAcq      : out std_logic;
    emptyAcq   : in  std_logic;
    nbAcq      : out std_logic_vector(7 downto 0);
    selAdc     : out std_logic_vector(63 downto 0);
    doutAcq    : in  std_logic_vector(7 downto 0)
);
end dataAcqCtrl;

architecture Behavioral of dataAcqCtrl is

type state_t is (idle,
                 getNbAcq,
                 sendRstAcq,
                 sendStartAcq,
                 sendSftTrg,
                 waitData,
                 collectData,
                 readFifo,
                 waitRdValid,
                 getLastByte,
                 sendData,
                 acqEnd);

signal state          : state_t;

signal dataOut        : devData_t;

signal dataIn         : devData_t;

signal byteCnt        : unsigned(2 downto 0);

signal swTrg,
       lastByte,
       resetAcqSig,
       startAcqSig,
       rdAcqSig,
       readSent       : std_logic;

signal nbAcqSig       : std_logic_vector(7 downto 0);

signal selAdcSig      : std_logic_vector(63 downto 0);

signal sync100to25In,
       sync100to25Out : std_logic_vector(66 downto 0);

begin

-- DEBUG --
selAdcSig     <= "00011001" &
                 "00000000" &
                 "00000010" &
                 "00000000" &
                 "01110100" &
                 "00000001" &
                 "00000000" &
                 swTrg &"0000000";
-----------

nbAcq         <= nbAcqSig;

lastByte      <= '1' when byteCnt = 0 else '0';

selAdc        <= sync100to25Out(66 downto 3);
resetAcq      <= sync100to25Out(2);
startAcq      <= sync100to25Out(1);
rdAcq         <= sync100to25Out(0);

sync100to25In <= selAdcSig & resetAcqSig & startAcqSig & rdAcqSig;

clkSyncInst: entity work.pulseExtenderSync
generic map(
    width       => sync100to25Out'length,
    syncStages  => 1,
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
            devReady    <= '0';
            busy        <= '0';
            resetAcqSig <= '1';
            startAcqSig <= '0';
            rdAcqSig    <= '0';
            nbAcqSig    <= (others => '0');
            devDataOut  <= (others => (others => '0'));
            swTrg       <= '0';
            byteCnt     <= to_unsigned(3, byteCnt'length);
            state       <= idle;
        else
            case state is
                when idle =>
                    if devExec = '1' and devId = acqSystem then
                        dataIn   <= devDataIn;
                        devReady <= '0';
                        busy     <= '1';
                        swTrg    <= '0';
                        resetAcqSig <= '0';

                        state    <= getNbAcq;
                    else
                        devReady <= '0';
                        busy     <= '0';
                        swTrg    <= '0';
                        resetAcqSig <= '0';

                        state    <= idle;
                    end if;

                when getNbAcq =>
                    nbAcqSig    <= devAddr(0);

                    state       <= sendRstAcq;

                when sendRstAcq =>
                    if nbAcqSig = x"00" then
                        resetAcqSig <= '1';

                        state       <= sendSftTrg;
                    elsif nbAcqSig = x"FF" then
                        resetAcqSig <= '0';
                        rdAcqSig <= '1';
                        --byteCnt    <= byteCnt - 1;

                        state       <= readFifo;
                    else
                        resetAcqSig <= '0';
                        startAcqSig <= '1';
    
                        state       <= sendStartAcq;
                    end if;

                when sendSftTrg =>
                    if sync100to25Out(2) = '1' then
                        resetAcqSig <= '0';
                        swTrg    <= '1';
                        devReady <= '1';

                        state <= idle;
                    else
                        resetAcqSig <= '0';

                        state <= sendSftTrg;
                    end if;

                when sendStartAcq =>
                    startAcqSig <= '0';

                    state       <= waitData;

                when waitData =>
                    if endAcq = '1' then
                        swTrg <= '0';

                        state <= collectData;
                    else
                        swTrg <= '0';

                        state <= waitData;
                    end if;

                when collectData =>
                    if emptyAcq = '0' then
                        rdAcqSig <= '1';
                        devReady <= '0';

                        state    <= readFifo;
                    else
                        rdAcqSig <= '0';
                        devReady <= '0';

                        state    <= acqEnd; -- add error state
                    end if;

                when readFifo =>
                    i := to_integer(byteCnt);

                    if (lastByte = '1' or emptyAcq = '1') and readSent = '1' then
                        state <= getLastByte;
                    elsif readSent = '1' then
                        rdAcqSig   <= '1';

                        state      <= waitRdValid;
                    else
                        rdAcqSig   <= '0';
                        state <= readFifo;
                    end if;

                when getLastByte =>
--                    if rdValid = '1' then
                        rdAcqSig   <= '0';
                        dataOut(i) <= doutAcq;
                        devDataOut <= dataOut;

                        state      <= sendData;
--                    else
--                        dataOut(i) <= doutAcq;
--                        state <= getLastByte;
--                    end if;

                when waitRdValid =>
                    if rdValid = '1' then
                        rdAcqSig   <= '0';
                        dataOut(i) <= doutAcq;
                        byteCnt    <= byteCnt - 1;

                        state      <= readFifo;
                    else
                        rdAcqSig   <= '0';
                        state      <= waitRdValid;
                    end if;

                when sendData =>
                    if emptyAcq = '1' then
                        devReady   <= '1';
                        devDataOut <= dataOut;

                        byteCnt  <= to_unsigned(3, byteCnt'length);

                        state    <= acqEnd;
                    else
                        devReady   <= '1';
                        devDataOut <= dataOut;
                        byteCnt    <= to_unsigned(3, byteCnt'length);

                        state      <= acqEnd;--collectData;
                    end if;

                when acqEnd =>
                    busy       <= '0';
                    
                    if emptyAcq = '1' then
                        resetAcqSig <= '1';
                    else
                        resetAcqSig <= '0';
                    end if;

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