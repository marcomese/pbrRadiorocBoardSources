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

constant R0 : std_logic_vector(2 downto 0) := "000";
constant R1 : std_logic_vector(2 downto 0) := "001";
constant R2 : std_logic_vector(2 downto 0) := "010";
constant R3 : std_logic_vector(2 downto 0) := "011";

signal   state       : state_t;
signal   rwSig,
         brstOnSig,
         i2cBusyOld,
         i2cBusyRise,
         lastBrst,
         lastBrstOld,
         lastBrstRise,
         lastLeft,
         lastByte    : std_logic;
signal   brstByteNum : std_logic_vector(13 downto 0);
signal   leftBNum    : std_logic_vector(1 downto 0);
signal   brstCnt     : unsigned(brstByteNum'left+1 downto 0); --adding 1 for lastBrst signal
signal   leftBCnt    : unsigned(2 downto 0);
signal   bytesCnt    : unsigned(bitsNum(devDataBytes) downto 0);

attribute MARK_DEBUG : string;
attribute MARK_DEBUG of state     : signal is "true";
attribute MARK_DEBUG of addr      : signal is "true";
attribute MARK_DEBUG of dataIn    : signal is "true";
attribute MARK_DEBUG of dataOut   : signal is "true";
attribute MARK_DEBUG of i2cEna    : signal is "true";
attribute MARK_DEBUG of i2cAddr   : signal is "true";
attribute MARK_DEBUG of i2cRw     : signal is "true";
attribute MARK_DEBUG of i2cDataWr : signal is "true";
attribute MARK_DEBUG of i2cBusy   : signal is "true";
attribute MARK_DEBUG of i2cDataRd : signal is "true";
attribute MARK_DEBUG of exec      : signal is "true";

begin

brstOn       <= brstOnSig;

i2cBusyRise  <= (not i2cBusyOld) and i2cBusy;

lastBrstRise <= (not lastBrstOld) and lastBrst;

lastBrst     <= brstCnt(brstCnt'left);

lastByte     <= bytesCnt(bytesCnt'left);

lastLeft     <= leftBCnt(leftBCnt'left);

brstByteNum  <= dataIn(1) & dataIn(0)(7 downto 2);

leftBNum     <= dataIn(0)(1 downto 0);

radioFSM: process(clk, rst, exec)
    variable i : integer range 0 to devDataBytes-1 := 0;
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
            bytesCnt      <= (others => '0');

            state         <= idle;
        else
            i2cBusyOld  <= i2cBusy;
            
            lastBrstOld <= lastBrst;

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
                        brstOnSig <= brst;
                        brstCnt   <= resize(unsigned(brstByteNum), brstCnt'length);
                        leftBCnt  <= resize(unsigned(leftBNum), leftBCnt'length);
                        bytesCnt  <= to_unsigned(devDataBytes-1, bytesCnt'length);

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
                    else
                        i2cEna <= '0';

                        state  <= waitBusy;
                    end if;

                when burstWrite =>
                    i := to_integer(bytesCnt);

                    if exec = '1' and lastBrst = '0' then
                        i2cEna    <= '1';
                        i2cDataWr <= dataIn(i);
                        bytesCnt  <= bytesCnt - 1;

                        state     <= burstWrite;
                    elsif exec = '1' and lastBrst = '1' then
                        i2cDataWr <= dataIn(i);

                        state     <= burstWrite;
                    elsif lastBrstRise = '1' and i2cBusyRise = '0' then
                        dataReady <= '0';
                        bytesCnt  <= to_unsigned(devDataBytes-1, bytesCnt'length);

                        state     <= burstWrite;
                    elsif lastBrst = '1' and lastLeft = '1' then
                        i2cEna    <= '0';
                        dataReady <= '0';
                        brstOnSig <= '0';
                        brstCnt   <= resize(unsigned(brstByteNum), brstCnt'length);
                        leftBCnt  <= resize(unsigned(leftBNum), leftBCnt'length);
                        bytesCnt  <= to_unsigned(devDataBytes-1, bytesCnt'length);

                        state     <= transEnd;
                    elsif lastBrst = '1' and lastLeft = '0' and i2cBusyRise = '1' then
                        i2cDataWr <= dataIn(i);
                        bytesCnt  <= bytesCnt - 1;
                        leftBCnt  <= leftBCnt - 1;

                        state     <= burstWrite;
                    elsif lastBrst = '1' and lastLeft = '0' and i2cBusyRise = '0' then
                        i2cDataWr <= dataIn(i);

                        state     <= burstWrite;
                    elsif lastByte = '0' and i2cBusyRise = '1' then
                        i2cDataWr <= dataIn(i);
                        dataReady <= '0';
                        bytesCnt  <= bytesCnt - 1;

                        state     <= burstWrite;
                    elsif lastByte = '1' and i2cBusyRise = '1' then
                        dataReady <= '1';
                        brstCnt   <= brstCnt - 1;
                        bytesCnt  <= to_unsigned(devDataBytes-1, bytesCnt'length);

                        state     <= burstWrite;
                    else
                        dataReady <= '0';

                        state     <= burstWrite;
                    end if;

                when transEnd =>
                    if i2cBusy = '0' and rwSig = devRead then
                        dataReady <= '1';
                        dataOut   <= (0      => i2cDataRd,
                                      others => (others => '0'));

                        state     <= idle;
                    elsif i2cBusy = '0' and rwSig = devWrite then
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

end Behavioral;
