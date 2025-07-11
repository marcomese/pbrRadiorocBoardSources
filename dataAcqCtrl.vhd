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

entity dataAcqCtrl is
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
    resetAcq   : out std_logic;
    startAcq   : out std_logic;
    rdAcq      : out std_logic;
    endAcq     : in  std_logic;
    nbAcq      : out std_logic;
    selAdc     : out std_logic;
    doutAcq    : in  std_logic_vector(7 downto 0);
    emptyAcq   : in  std_logic;
    rdDCntAcq  : in  std_logic_vector(15 downto 0)
);
end dataAcqCtrl;

architecture Behavioral of dataAcqCtrl is

type state_t is (idle,
                 getEvtNum,
                 waitData,
                 sendData,
                 acqEnd);

signal state   : state_t;

signal evtNum  : unsigned(32 downto 0); -- msb used for lastEvt

signal dataOut : devData_t;

signal dataIn  : devData_t;

signal exec,
       lastEvt : std_logic;

begin

lastEvt <= evtNum(evtNum'left);

FSM: process(clk, rst, devExec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            exec       <= '0';
            devReady   <= '0';
            busy       <= '0';
            evtNum     <= (others => '0');
            devDataOut <= (others => (others => '0'));

            state      <= idle;
        else
            case state is
                when idle =>
                    if devExec = '1' and devId = acqSystem then
                        exec     <= '1';
                        dataIn   <= devDataIn;
                        devReady <= '0';
                        busy     <= '1';

                        state    <= getEvtNum;
                    else
                        devReady <= '0';
                        busy     <= '0';

                        state    <= idle;
                    end if;

                when getEvtNum =>
                    evtNum <= devDataToUnsigned(dataIn);

                    state <= waitData;

                when waitData =>
                    if lastEvt = '0' and unsigned(rdDCntAcq) > 0 then
                        state <= sendData;
                    elsif lastEvt = '1' then
                        state <= acqEnd;
                    else
                    end if;

                when sendData =>

                when acqEnd =>
                    devReady   <= '1';
                    busy       <= '0';
                    devDataOut <= dataOut;

                    state      <= idle;

                when others =>
                    exec     <= '0';
                    rAddr    <= (others => (others => '0'));
                    devReady <= '0';
                    busy     <= '0';

                    state    <= idle;
            end case;
        end if;
    end if;
end process;


end Behavioral;
