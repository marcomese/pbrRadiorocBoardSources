----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: caenA7585DFSM
-- Create Date: 23.11.2024 20:53:33
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
-- Revision 0.02 - Modified for using with deviceInterface
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use work.utilsPkg.all;
use work.caenA7585DPkg.all;

entity caenA7585DFSM is
generic(
    caenAddr  : std_logic_vector(6 downto 0)
);
port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    exec      : in  std_logic;
    rw        : in  std_logic;
    addr      : in  std_logic_vector(7 downto 0);
    dataIn    : in  std_logic_vector(31 downto 0);
    dataOut   : out std_logic_vector(31 downto 0);
    busy      : out std_logic;
    dataReady : out std_logic;
    i2cEna    : out std_logic;
    i2cAddr   : out std_logic_vector(6 downto 0);
    i2cRw     : out std_logic;
    i2cDataWr : out std_logic_vector(7 downto 0);
    i2cBusy   : in  std_logic;
    i2cDataRd : in  std_logic_vector(7 downto 0)
);
end caenA7585DFSM;

architecture Behavioral of caenA7585DFSM is

type state_t is (idle,
                 writeDType,
                 transStart,
                 writeBytes,
                 readBytes,
                 waitBusy,
                 transEnd);

constant bytesNum    : integer   := 4;
constant readCmd     : std_logic := '1';
constant writeCmd    : std_logic := '0';

signal   state       : state_t;
signal   bytesCnt    : unsigned(bitsNum(bytesNum) downto 0);
signal   dataBytes   : byteArray_t(bytesNum-1 downto 0);
signal   addrSig     : std_logic_vector(7 downto 0);
signal   rwSig,
         i2cBusyOld,
         i2cBusyRise,
         i2cBusyFall,
         lastByte    : std_logic;

begin

i2cAddr     <= caenAddr;

i2cBusyRise <= (not i2cBusyOld) and i2cBusy;

i2cBusyFall <= i2cBusyOld and not i2cBusy;

lastByte    <= bytesCnt(bytesCnt'left);

hvFSM: process(clk, rst, exec)
    variable rI  : integer range 0 to bytesNum-1 := 0;
begin
    if rising_edge(clk) then
        if rst = '1' then
            i2cEna     <= '0';
            i2cRw      <= '0';
            i2cDataWr  <= (others => '0');
            i2cBusyOld <= '0';
            rwSig      <= '0';
            addrSig    <= (others => '0');
            bytesCnt   <= (others => '0');
            dataBytes  <= (others => (others => '0'));
            busy       <= '1';
            dataReady  <= '0';
            dataOut    <= (others => '0');

            state      <= idle;
        else
            i2cBusyOld <= i2cBusy;

            case state is
                when idle =>
                    if exec = '1' and i2cBusy = '0' then
                        i2cEna    <= '1';
                        i2cRw     <= writeCmd;
                        i2cDataWr <= addr;
                        rwSig     <= rw;
                        addrSig   <= addr;
                        bytesCnt  <= to_unsigned(bytesNum-1, bytesCnt'length);
                        dataBytes <= (dataIn(7  downto 0),
                                      dataIn(15 downto 8),
                                      dataIn(23 downto 16),
                                      dataIn(31 downto 24));
                        busy      <= '1';
                        dataReady <= '0';

                        state     <= writeDType;
                    else
                        i2cEna    <= '0';
                        dataReady <= '0';
                        busy      <= '0';

                        state     <= idle;
                    end if;

                when writeDType =>
                    if i2cBusyRise = '1' then
                        i2cDataWr <= getDType(addrSig);
 
                        state     <= transStart;
                    else
                        state <= writeDType;
                    end if;

                when transStart =>
                    rI := to_integer(bytesCnt);

                    if i2cBusyRise = '1' and rwSig = writeCmd then
                        i2cRw     <= rwSig;
                        i2cDataWr <= dataBytes(rI);
                        bytesCnt  <= bytesCnt - 1;

                        state     <= writeBytes;
                    elsif i2cBusyRise = '1' and rwSig = readCmd then
                        i2cRw         <= rwSig;

                        state         <= waitBusy;
                    else
                        state <= transStart;
                    end if;

                when writeBytes =>
                    rI := to_integer(bytesCnt);

                    if lastByte = '0' and i2cBusyRise = '1' then
                        i2cRw     <= rwSig;
                        i2cDataWr <= dataBytes(rI);
                        bytesCnt  <= bytesCnt - 1;

                        state     <= writeBytes;
                    elsif lastByte = '1' and i2cBusyRise = '1' then
                        i2cEna    <= '0';
                        bytesCnt  <= to_unsigned(bytesNum-1, bytesCnt'length);

                        state     <= transEnd;
                    else
                        state <= writeBytes;
                    end if;

                when waitBusy =>
                    if i2cBusyRise = '1' then
                        state <= readBytes;
                    else
                        state <= waitBusy;
                    end if;

                when readBytes =>
                    rI := to_integer(bytesCnt);

                    if lastByte = '0' and i2cBusyFall = '1' then
                        i2cRw          <= rwSig;
                        dataBytes(rI)  <= i2cDataRd;
                        bytesCnt       <= bytesCnt - 1;

                        state          <= readBytes;
                    elsif bytesCnt = 0 then
                        i2cEna    <= '0';
                        bytesCnt  <= to_unsigned(bytesNum-1, bytesCnt'length);

                        state     <= transEnd;
                    else
                        state <= readBytes;
                    end if;

                when transEnd =>
                    if rwSig = readCmd and i2cBusyFall = '1' then
                        busy      <= '0';
                        dataReady <= '1';
                        dataOut   <= i2cDataRd & dataBytes(1) & dataBytes(2) & dataBytes(3);

                        state     <= idle;
                    elsif rwSig = writeCmd and i2cBusyFall = '1' then
                        busy      <= '0';
                        dataReady <= '1';
                        dataOut   <= (others => '0');

                        state     <= idle;
                    else
                        state <= transEnd;
                    end if;

                when others =>
                    i2cEna    <= '0';
                    rwSig     <= '0';
                    i2cDataWr <= (others => '0');
                    bytesCnt  <= to_unsigned(bytesNum-1, bytesCnt'length);
                    dataBytes <= (others => (others => '0'));
                    busy      <= '0';
                    dataReady <= '0';
                    dataOut   <= (others => '0');

                    state     <= idle;
            end case;
        end if;
    end if;
end process;

end Behavioral;