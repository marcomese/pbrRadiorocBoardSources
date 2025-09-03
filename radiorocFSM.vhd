----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: radiorocFSM
-- Create Date: 06.03.2025 11:13:30
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
use IEEE.STD_LOGIC_MISC.ALL;
use work.devicesPkg.all;
use work.utilsPkg.all;

entity radiorocFSM is
generic(
    chipID     : std_logic_vector(3 downto 0)
);
port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    exec      : in  std_logic;
    rw        : in  std_logic;
    brst      : in  std_logic;
    addr      : in  devAddr_t;
    dataIn    : in  devData_t;
    dataOut   : out devData_t;
    busy      : out std_logic;
    brstOn    : out std_logic;
    dataReady : out std_logic;
    i2cEna    : out std_logic;
    i2cAddr   : out std_logic_vector(6 downto 0);
    i2cRw     : out std_logic;
    i2cDataWr : out std_logic_vector(7 downto 0);
    i2cBusy   : in  std_logic;
    i2cDataRd : in  std_logic_vector(7 downto 0)
);
end radiorocFSM;

architecture Behavioral of radiorocFSM is

type state_t is (idle,
                 writeSubAddr,
                 writeAddr,
                 waitBusy,
                 burstRead,
                 burstWrite,
                 transEnd);

constant R0           : std_logic_vector(2 downto 0) := "000";
constant R1           : std_logic_vector(2 downto 0) := "001";
constant R2           : std_logic_vector(2 downto 0) := "010";
constant R3           : std_logic_vector(2 downto 0) := "011";

signal   state        : state_t;
signal   rwSig,
         brstOnSig,
         i2cBusyOld,
         i2cBusyRise,
         i2cBusyFall,
         i2cEnaSig,
         rstBuff,
         loadBuff,
         shiftBuff,
         emptyBuff,
         lastBuff,
         lastLeft,
         lastByte,
         brstOld,
         brstFall     : std_logic;
signal   dataInVec    : std_logic_vector(devDataBytes*8-1 downto 0);
signal   dataOutBuff  : std_logic_vector(dataInVec'left downto 0);
signal   leftBCnt     : unsigned(2 downto 0);

attribute mark_debug : string;
attribute mark_debug of state,
                        dataOutBuff : signal is "true";

begin

brstOn      <= brstOnSig;

i2cBusyRise <= (not i2cBusyOld) and i2cBusy;

i2cBusyFall <= i2cBusyOld and not i2cBusy;

i2cEna      <= i2cEnaSig;

dataInVec   <= devDataToSlv(dataIn);

lastLeft    <= leftBCnt(leftBCnt'left);

brstFall    <= brstOld and not brst;

radioFSM: process(clk, rst, exec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            i2cEnaSig  <= '0';
            i2cAddr    <= (others => '0');
            i2cRw      <= '0';
            i2cDataWr  <= (others => '0');
            i2cBusyOld <= '0';
            rwSig      <= '0';
            brstOnSig  <= '0';
            brstOld    <= '0';
            busy       <= '0';
            dataReady  <= '0';
            dataOut    <= (others => (others => '0'));
            rstBuff    <= '1';
            loadBuff   <= '0';
            shiftBuff  <= '0';
            leftBCnt   <= (others => '0');
            lastByte   <= '0';

            state      <= idle;
        else
            i2cBusyOld <= i2cBusy;
            brstOld    <= brst;

            case state is
                when idle =>
                    i2cEnaSig <= '0';
                    dataReady <= '0';
                    rstBuff   <= '1';

                    state     <= idle;

                    if exec = '1' and i2cBusy = '0' then
                        i2cEnaSig <= '1';
                        i2cAddr   <= chipID & R0;
                        i2cRw     <= devWrite;
                        i2cDataWr <= addr(0);
                        rwSig     <= rw;
                        busy      <= '1';
                        rstBuff   <= '0';

                        state     <= writeSubAddr;
                    end if;

                when writeSubAddr =>
                    i2cEnaSig <= '1';

                    state     <= writeSubAddr;

                    if i2cBusyRise = '1' then
                        i2cAddr   <= chipID & R1;
                        i2cRw     <= devWrite;
                        i2cDataWr <= addr(1);

                        state     <= writeAddr;
                    end if;

                when writeAddr =>
                    i2cEnaSig <= '0';

                    state     <= writeAddr;

                    if i2cBusyRise = '1' then
                        i2cEnaSig <= '1';
                        i2cAddr   <= chipID & R2;
                        i2cRw     <= rwSig;
                        i2cDataWr <= dataIn(0);
                        brstOnSig <= brst;

                        state     <= waitBusy;
                    elsif i2cBusy = '0' then
                        i2cEnaSig <= '1';
                    end if;

                when waitBusy =>
                    i2cEnaSig <= '0';

                    state     <= waitBusy;

                    if i2cBusyRise = '1' and brst = '0' then
                        busy      <= '0';

                        state     <= transEnd;
                    elsif i2cBusy = '0' and brst = '0' then
                        i2cEnaSig <= '1';
                    elsif i2cBusy = '0' and brst = '1' and rwSig = devWrite then
                        i2cAddr   <= chipID & R3;
                        i2cRw     <= rwSig;
                        dataReady <= '1';

                        state     <= burstWrite;
                    elsif i2cBusy = '0' and brst = '1' and rwSig = devRead then
                        i2cEnaSig <= '1';
                        i2cAddr   <= chipID & R3;
                        i2cRw     <= devWrite;
                        dataReady <= '0';
                        rstBuff   <= '1';

                        state     <= burstRead;
                    end if;

                when burstWrite =>
                    i2cDataWr <= dataOutBuff(dataOutBuff'left downto dataOutBuff'left-7);
                    lastByte  <= brstFall;
                    loadBuff  <= lastByte or exec;
                    shiftBuff <= i2cBusyRise and ((brst and not lastBuff) or (not brst and not lastLeft));
                    dataReady <= i2cBusyRise and brst and lastBuff;
                    brstOnSig <= brst or i2cEnaSig;

                    state     <= burstWrite;

                    if lastByte = '1' then
                        leftBCnt  <= unsigned(dataIn(0)(2 downto 0))-1;
                    elsif exec = '1' then
                        i2cEnaSig    <= '1';
                    elsif i2cBusyRise = '1' and brst = '0' then
                        leftBCnt  <= leftBCnt - 1;
                        i2cEnaSig <= not lastLeft;

                        if lastLeft = '1' then
                            state     <= transEnd;
                        end if;
                    end if;

                when burstRead =>
                    i2cRw     <= devRead;
                    dataOut   <= slvToDevData(dataOutBuff);
                    dataReady <= emptyBuff;
                    rstBuff   <= emptyBuff;
                    shiftBuff <= i2cBusyFall and i2cEnaSig and not lastLeft;
                    brstOnSig <= brst or i2cEnaSig;

                    state     <= burstRead;

                    if exec = '1' then
                        i2cEnaSig <= '1';
                    elsif i2cBusyFall = '1' and  brst = '0' then
                        leftBCnt  <= leftBCnt - 1;
                        i2cEnaSig <= not lastLeft;

                        if lastLeft = '1' then
                            state     <= transEnd;
                        end if;
                    end if;

                when transEnd =>
                    dataReady <= '0';
                    shiftBuff <= '0';
                    leftBCnt  <= (others => '0');
                    dataOut   <= (others => (others => '0'));

                    state     <= transEnd;

                    if i2cBusy = '0' then
                        brstOnSig <= '0';
                        busy      <= '0';
                        dataReady <= '1';
    
                        if rwSig = devRead then
                            dataOut(0) <= i2cDataRd;
                        end if;

                        state     <= idle;
                    end if;

                when others =>
                    i2cEnaSig     <= '0';
                    i2cAddr       <= chipID & R0;
                    rwSig         <= '0';
                    i2cDataWr     <= (others => '0');
                    busy          <= '0';
                    dataReady     <= '0';
                    dataOut       <= (others => (others => '0'));

                    state         <= idle;
            end case;
        end if;
    end if;
end process;

shiftBuffInst: entity work.shiftReg
generic map(
    direction  => "left",
    regLen     => dataInVec'length,
    shiftLen   => 8
)
port map(
    clk        => clk,
    rst        => rstBuff,
    load       => loadBuff,
    shift      => shiftBuff,
    empty      => emptyBuff,
    last       => lastBuff,
    parDataIn  => dataInVec,
    serDataIn  => i2cDataRd,
    dataOut    => dataOutBuff
);

end Behavioral;