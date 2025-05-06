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
    chipID     : std_logic_vector(3 downto 0);
    maxBrstLen : natural -- maximum number of bytes to read/write in burst mode
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
constant maxBrstSlv   : std_logic_vector(bitsNum(maxBrstLen)-1 downto 0) := std_logic_vector(to_unsigned(maxBrstLen, bitsNum(maxBrstLen)));

signal   state        : state_t;
signal   rwSig,
         brstOnSig,
         brstVal,
         i2cBusyOld,
         i2cBusyRise,
         loadBuff,
         shiftBuff,
         emptyBuff,
         lastBuff,
         lastBrst,
         lastLeft     : std_logic;
signal   dataInVec    : std_logic_vector(devDataBytes*8-1 downto 0);
signal   dataOutBuff  : std_logic_vector(dataInVec'left downto 0);
signal   brstByteNum  : std_logic_vector(maxBrstSlv'left-2 downto 0);
signal   leftBNum     : std_logic_vector(1 downto 0);
signal   brstCnt      : unsigned(brstByteNum'left+1 downto 0); --adding 1 for lastBrst signal
signal   leftBCnt     : unsigned(2 downto 0);

attribute mark_debug : string;
attribute mark_debug of state       : signal is "true";
attribute mark_debug of i2cDataWr   : signal is "true";
attribute mark_debug of i2cDataRd   : signal is "true";
attribute mark_debug of dataOutBuff : signal is "true";
attribute mark_debug of loadBuff    : signal is "true";
attribute mark_debug of shiftBuff   : signal is "true";
attribute mark_debug of dataInVec   : signal is "true";

begin

brstOn       <= brstOnSig;

i2cBusyRise  <= (not i2cBusyOld) and i2cBusy;

lastBrst     <= brstCnt(brstCnt'left);

lastLeft     <= leftBCnt(leftBCnt'left);

dataInVec    <= devDataToSlv(dataIn);

brstBytesProc: process(clk, rst)
begin
    if rising_edge(clk) then
        if rst = '1' then
            brstByteNum <= (others => '0');
            leftBNum    <= (others => '0');
            brstVal     <= '0';
        else
            if unsigned(dataInVec) = 0 then
                brstByteNum <= (others => '0');
                leftBNum    <= (others => '0');
                brstVal     <= '0';
            elsif unsigned(dataInVec) > maxBrstLen then
                brstByteNum <= maxBrstSlv(maxBrstSlv'left downto 2);
                leftBNum    <= maxBrstSlv(1 downto 0);
                brstVal     <= '1';
            elsif unsigned(dataInVec) < 4 then
                brstByteNum <= (others => '0');
                leftBNum    <= dataInVec(1 downto 0);
                brstVal     <= '1';
            else
                brstByteNum  <= dataInVec(brstByteNum'left+2 downto 2);
                leftBNum     <= dataInVec(1 downto 0);
                brstVal     <= '1';
            end if;
        end if;
    end if;
end process;

radioFSM: process(clk, rst, exec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            i2cEna        <= '0';
            i2cAddr       <= (others => '0');
            i2cRw         <= '0';
            i2cDataWr     <= (others => '0');
            i2cBusyOld    <= '0';
            rwSig         <= '0';
            brstOnSig     <= '0';
            busy          <= '0';
            dataReady     <= '0';
            dataOut       <= (others => (others => '0'));
            brstCnt       <= (others => '0');
            leftBCnt      <= (others => '0');
            loadBuff      <= '0';
            shiftBuff     <= '0';

            state         <= idle;
        else
            i2cBusyOld  <= i2cBusy;

            case state is
                when idle =>
                    if exec = '1' and i2cBusy = '0' then
                        i2cEna    <= '1';
                        i2cAddr   <= chipID & R0;
                        i2cRw     <= devWrite;
                        i2cDataWr <= addr(0);
                        rwSig     <= rw;
                        busy      <= '1';
                        dataReady <= '0';

                        state     <= writeSubAddr;
                    else
                        i2cEna    <= '0';
                        dataReady <= '0';

                        state     <= idle;
                    end if;

                when writeSubAddr =>
                    if i2cBusyRise = '1' then
                        i2cEna    <= '1';
                        i2cAddr   <= chipID & R1;
                        i2cRw     <= devWrite;
                        i2cDataWr <= addr(1);

                        state     <= writeAddr;
                    else
                        i2cEna    <= '1';

                        state     <= writeSubAddr;
                    end if;

                when writeAddr =>
                    if i2cBusyRise = '1' then
                        i2cEna    <= '1';
                        i2cAddr   <= chipID & R2;
                        i2cRw     <= rwSig;
                        i2cDataWr <= dataIn(0);
                        brstOnSig <= brst and brstVal;
                        brstCnt   <= resize(unsigned(brstByteNum), brstCnt'length);
                        leftBCnt  <= resize(unsigned(leftBNum), leftBCnt'length);

                        state     <= waitBusy;
                    elsif i2cBusy = '0' then
                        i2cEna <= '1';

                        state  <= writeAddr;
                    else
                        i2cEna <= '0';

                        state  <= writeAddr;                        
                    end if;

                when waitBusy =>
                    if i2cBusyRise = '1' and brstOnSig = '0' then
                        i2cEna    <= '0';
                        busy      <= '0';

                        state     <= transEnd;
                    elsif i2cBusy = '0' and brstOnSig = '0' then
                        i2cEna <= '1';

                        state  <= waitBusy;
                    elsif i2cBusy = '0' and brstOnSig = '1' and rwSig = devWrite then
                        i2cEna    <= '0';
                        i2cAddr   <= chipID & R3;
                        i2cRw     <= rwSig;
                        dataReady <= '1';
                        brstOnSig <= '1';
                        brstCnt   <= brstCnt - 1;
                        leftBCnt  <= leftBCnt - 1;

                        state     <= burstWrite;
                    elsif i2cBusy = '0' and brstOnSig = '1' and rwSig = devRead then
                        i2cEna    <= '1';
                        i2cAddr   <= chipID & R3;
                        i2cRw     <= devWrite;
                        dataReady <= '0';
                        brstOnSig <= '1';
                        brstCnt   <= brstCnt - 1;
                        leftBCnt  <= leftBCnt - 1;

                        state     <= burstRead;
                    else
                        i2cEna <= '0';

                        state  <= waitBusy;
                    end if;

                when burstRead =>
                    if exec = '1' then
                        i2cEna    <= '1';
                        loadBuff  <= '1';

                        state     <= burstWrite;
                    elsif lastBrst = '0' then
                        if i2cBusyRise = '1' and lastBuff = '0' then
                            shiftBuff <= '1';

                            state     <= burstWrite;
                        elsif i2cBusyRise = '1' and lastBuff = '1' then
                            dataReady <= '1';
                            brstCnt   <= brstCnt - 1;

                            state     <= burstWrite;
                        else
                            dataReady <= '0';
                            loadBuff  <= '0';
                            shiftBuff <= '0';
    
                            state     <= burstWrite;
                        end if;
                    elsif lastBrst = '1' then
                        if i2cBusyRise = '1' and lastLeft = '0' then
                            dataReady <= '0';
                            shiftBuff <= '1';
                            leftBCnt  <= leftBCnt - 1;

                            state     <= burstWrite;
                        elsif lastLeft = '1' then
                            i2cEna    <= '0';
                            dataReady <= '0';
                            brstOnSig <= '0';
                            brstCnt   <= resize(unsigned(brstByteNum), brstCnt'length);
                            leftBCnt  <= resize(unsigned(leftBNum), leftBCnt'length);
                            shiftBuff <= '0';

                            state     <= transEnd;
                        else
                            dataReady <= '0';
                            loadBuff  <= '0';
                            shiftBuff <= '0';
    
                            state     <= burstWrite;
                        end if;
                    end if;

                when burstWrite =>
                    if exec = '1' then
                        i2cEna    <= '1';
                        loadBuff  <= '1';

                        state     <= burstWrite;
                    elsif lastBrst = '0' then
                        if i2cBusyRise = '1' and lastBuff = '0' then
                            shiftBuff <= '1';

                            state     <= burstWrite;
                        elsif i2cBusyRise = '1' and lastBuff = '1' then
                            dataReady <= '1';
                            brstCnt   <= brstCnt - 1;

                            state     <= burstWrite;
                        else
                            i2cDataWr <= dataOutBuff(dataOutBuff'left downto dataOutBuff'left-7);
                            dataReady <= '0';
                            loadBuff  <= '0';
                            shiftBuff <= '0';
    
                            state     <= burstWrite;
                        end if;
                    elsif lastBrst = '1' then
                        if i2cBusyRise = '1' and lastLeft = '0' then
                            dataReady <= '0';
                            shiftBuff <= '1';
                            leftBCnt  <= leftBCnt - 1;

                            state     <= burstWrite;
                        elsif lastLeft = '1' then
                            i2cEna    <= '0';
                            dataReady <= '0';
                            brstOnSig <= '0';
                            brstCnt   <= resize(unsigned(brstByteNum), brstCnt'length);
                            leftBCnt  <= resize(unsigned(leftBNum), leftBCnt'length);
                            shiftBuff <= '0';

                            state     <= transEnd;
                        else
                            i2cDataWr <= dataOutBuff(dataOutBuff'left downto dataOutBuff'left-7);
                            dataReady <= '0';
                            loadBuff  <= '0';
                            shiftBuff <= '0';
    
                            state     <= burstWrite;
                        end if;
                    end if;

                when transEnd =>
                    if i2cBusy = '0' and rwSig = devRead then
                        busy      <= '0';
                        dataReady <= '1';
                        dataOut   <= (0      => i2cDataRd,
                                      others => (others => '0'));

                        state     <= idle;
                    elsif i2cBusy = '0' and rwSig = devWrite then
                        busy      <= '0';
                        dataReady <= '1';
                        dataOut   <= (others => (others => '0'));

                        state     <= idle;
                    else
                        dataReady <= '0';

                        state     <= transEnd;
                    end if;

                when others =>
                    i2cEna        <= '0';
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
    rst        => rst,
    load       => loadBuff,
    shift      => shiftBuff,
    empty      => emptyBuff,
    last       => lastBuff,
    parDataIn  => dataInVec,
    serDataIn  => i2cDataRd,
    dataOut    => dataOutBuff
);

end Behavioral;
