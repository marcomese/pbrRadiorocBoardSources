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
                 waitData,
                 readFifo,
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
       emptyAcqFall,
       emptyAcqRise   : std_logic;

signal nbAcqSig       : std_logic_vector(7 downto 0);

signal sync100to25In,
       sync100to25Out : std_logic_vector(2 downto 0);

begin

-- DEBUG --
selAdc        <= "00011001" &
                 "00000000" &
                 "00000010" &
                 "00000000" &
                 "01110100" &
                 "00000001" &
                 "00000000" &
                 swTrg &"0000000";
-----------

nbAcq         <= nbAcqSig;

lastByte      <= byteCnt(byteCnt'left);

resetAcq      <= sync100to25Out(2);
startAcq      <= sync100to25Out(1);
rdAcq         <= sync100to25Out(0);

sync100to25In <= resetAcqSig & startAcqSig & rdAcqSig;

syncPulsesInst: xpm_cdc_array_single
generic map (
    DEST_SYNC_FF   => 2,
    INIT_SYNC_FF   => 0,
    SIM_ASSERT_CHK => 0,
    SRC_INPUT_REG  => 1,
    WIDTH          => 3
)
port map (
    src_clk  => clk100M,
    dest_clk => clk25M,
    src_in   => sync100to25In,
    dest_out => sync100to25Out
);

emptyAcqRiseInst: entity work.edgeDetector
generic map(
    clockEdge => "falling",
    edge      => "rising"
)
port map(
    clk       => clk100M,
    rst       => rst,
    signalIn  => emptyAcq,
    signalOut => emptyAcqRise
);

emptyAcqFallInst: entity work.edgeDetector
generic map(
    clockEdge => "falling",
    edge      => "falling"
)
port map(
    clk       => clk100M,
    rst       => rst,
    signalIn  => emptyAcq,
    signalOut => emptyAcqFall
);

dataAcqCtrlFSM: process(clk100M, rst, devExec)
    variable i : integer := 0;
begin
    if rising_edge(clk100M) then
        if rst = '1' then
            devReady    <= '0';
            busy        <= '0';
            resetAcqSig <= '0';
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

                        state    <= getNbAcq;
                    else
                        devReady <= '0';
                        busy     <= '0';

                        state    <= idle;
                    end if;

                when getNbAcq =>
                    nbAcqSig    <= devAddr(0);
                    resetAcqSig <= '1';

                    state       <= sendRstAcq;

                when sendRstAcq =>
                    if nbAcqSig = x"00" then
                        resetAcqSig <= '0';
                        swTrg       <= '1';

                        state       <= waitData;
                    else
                        resetAcqSig <= '0';
                        startAcqSig <= '1';
    
                        state       <= sendStartAcq;
                    end if;

                when sendStartAcq =>
                    startAcqSig <= '0';

                    state       <= waitData;

                when waitData =>
                    if emptyAcqFall = '1' then
                        rdAcqSig <= '1';
                        swTrg    <= '0';
                        devReady <= '0';

                        state    <= readFifo;
                    else
                        rdAcqSig <= '0';
                        swTrg    <= '0';
                        devReady <= '0';

                        state    <= waitData;
                    end if;

                when readFifo =>
                    i := to_integer(byteCnt);

                    if lastByte = '1' or emptyAcqRise = '1' then
                        rdAcqSig   <= '0';
                        devDataOut <= dataOut;

                        state      <= sendData;
                    else
                        dataOut(i) <= doutAcq;
                        byteCnt    <= byteCnt - 1;

                        state      <= readFifo;
                    end if;

                when sendData =>
                    if emptyAcqRise = '1' then
                        devReady   <= '1';
                        devDataOut <= dataOut;

                        byteCnt  <= to_unsigned(3, byteCnt'length);

                        state    <= acqEnd;
                    else
                        devReady   <= '1';
                        devDataOut <= dataOut;
                        byteCnt    <= to_unsigned(3, byteCnt'length);

                        state      <= waitData;
                    end if;

                when acqEnd =>
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