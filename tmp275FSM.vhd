----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: tmp275FSM
-- Create Date: 22.11.2024 18:33:04
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
-- Revision 0.02 - Modified for using with deviceInterface
--
-- TODO:
--  1) add error states
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use work.utilsPkg.all;

entity tmp275FSM is
generic(
    tmpAddr   : std_logic_vector(6 downto 0)
);
port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    exec      : in  std_logic;
    rw        : in  std_logic;
    addr      : in  std_logic_vector(7 downto 0);
    dataIn    : in  std_logic_vector(15 downto 0);
    dataOut   : out std_logic_vector(15 downto 0);
    busy      : out std_logic;
    dataReady : out std_logic;
    i2cEna    : out std_logic;
    i2cAddr   : out std_logic_vector(6 downto 0);
    i2cRw     : out std_logic;
    i2cDataWr : out std_logic_vector(7 downto 0);
    i2cBusy   : in  std_logic;
    i2cDataRd : in  std_logic_vector(7 downto 0)
);
end tmp275FSM;

architecture Behavioral of tmp275FSM is

type state_t is (init,
                 idle,
                 writePtrReg,
                 writeBytes,
                 readBytes,
                 waitBusy,
                 transEnd);

constant bytesNum    : integer   := 2;
constant readCmd     : std_logic := '1';
constant writeCmd    : std_logic := '0';
constant initConf    : std_logic_vector(7 downto 0) := x"60"; -- 12 bit resolution
constant confAddr    : std_logic_vector(7 downto 0) := x"01";

signal   state       : state_t;
signal   bytesCnt    : unsigned(bitsNum(bytesNum) downto 0);
signal   dataBytes   : byteArray_t(bytesNum-1 downto 0);
signal   rwSig,
         i2cBusyOld,
         i2cBusyRise,
         i2cBusyFall,
         lastByte    : std_logic;

begin

i2cAddr     <= tmpAddr;

i2cBusyRise <= (not i2cBusyOld) and i2cBusy;

i2cBusyFall <= i2cBusyOld and not i2cBusy;

lastByte    <= bytesCnt(bytesCnt'left);

tmpFSM: process(clk, rst, exec)
    variable rI : integer range 0 to bytesNum-1 := 0;
begin
    if rising_edge(clk) then
        if rst = '1' then
            i2cEna        <= '0';
            i2cRw         <= '0';
            i2cDataWr     <= confAddr;
            i2cBusyOld    <= '0';
            rwSig         <= '0';
            bytesCnt      <= (others => '0');
            dataBytes     <= (x"00", initConf);
            busy          <= '1';
            dataReady     <= '0';
            dataOut       <= (others => '0');

            state         <= init;
        else
            i2cBusyOld <= i2cBusy;

            case state is
                when init =>
                    if i2cBusy = '0' then
                        i2cEna    <= '1';
                        i2cRw     <= writeCmd;

                        state     <= writePtrReg;
                    else
                        state     <= init;
                    end if;

                when idle =>
                    if exec = '1' and i2cBusy = '0' then
                        i2cEna    <= '1';
                        i2cRw     <= writeCmd;
                        i2cDataWr <= addr;
                        rwSig     <= rw;
                        bytesCnt  <= to_unsigned(bytesNum-1, bytesCnt'length);
                        dataBytes <= (dataIn(15 downto 8), dataIn(7 downto 0));
                        busy      <= '1';
                        dataReady <= '0';

                        state     <= writePtrReg;
                    else
                        i2cEna    <= '0';
                        dataReady <= '0';

                        state     <= idle;
                    end if;

                when writePtrReg =>
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
                        state <= writePtrReg;
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
                    if i2cBusyFall = '1' and rwSig = readCmd then
                        busy      <= '0';
                        dataReady <= '1';--rwSig;
                        dataOut   <= dataBytes(1) & i2cDataRd;
                        dataBytes <= (x"00", x"00");

                        state     <= idle;
                    elsif i2cBusyFall = '1' and rwSig = writeCmd then
                        busy      <= '0';
                        dataReady <= '1';--rwSig;
                        dataOut   <= (others => '0');
                        dataBytes <= (x"00", x"00");

                        state     <= idle;
                    else
                        state <= transEnd;
                    end if;

                when others =>
                    i2cEna        <= '0';
                    rwSig         <= '0';
                    i2cDataWr     <= (others => '0');
                    bytesCnt      <= to_unsigned(bytesNum-1, bytesCnt'length);
                    dataBytes     <= ((others => '0'), (others => '0'));
                    busy          <= '0';
                    dataReady     <= '0';
                    dataOut       <= (others => '0');

                    state         <= idle;
            end case;
        end if;
    end if;
end process;

end Behavioral;