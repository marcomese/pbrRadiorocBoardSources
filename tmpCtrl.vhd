----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: tmpCtrl
-- Create Date: 01.10.2025 15:04:18
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
use work.utilsPkg.all;
use work.devicesPkg.all;
use work.registersPkg.all;

entity tmpCtrl is
generic(
    clkFreq    : real;
    readPeriod : real;
    tmpAddr    : std_logic_vector(6 downto 0)
);
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    devExec    : in  std_logic;
    devId      : in  devices_t;
    devRw      : in  std_logic;
    devAddr    : in  devAddr_t;
    devDataIn  : in  devData_t;
    devDataOut : out devData_t;
    devReady   : out std_logic;
    busy       : out std_logic;
    i2cEna     : out std_logic;
    i2cAddr    : out std_logic_vector(6 downto 0);
    i2cRw      : out std_logic;
    i2cDataWr  : out std_logic_vector(7 downto 0);
    i2cBusy    : in  std_logic;
    i2cDataRd  : in  std_logic_vector(7 downto 0)
);
end tmpCtrl;

architecture Behavioral of tmpCtrl is

--------------------- registers definitions ------------------------

type addr is (rStatus,
              rTemp);

constant reg : regsRec_t := (
    addr'pos(rStatus) => (rAddr => 0, rBegin => 31, rEnd => 12, rMode => ro),
    addr'pos(rTemp)   => (rAddr => 0, rBegin => 11, rEnd => 0,  rMode => ro)
);

constant regsNum  : integer := reg(reg'high).rAddr+1;

signal   rData    : regsData_t(regsNum-1 downto 0);

--------------------------------------------------------------------

type state_t is (init,
                 idle,
                 waitReady,
                 store);

constant readCount  : integer := integer(readPeriod*clkFreq);

signal   state      : state_t;

signal   readCnt    : integer range 0 to readCount-1;

signal   dAddr      : integer;

signal   exec,
         dataReady,
         rw,
         autoRead,
         busyTmp    : std_logic;

signal   rAddr      : std_logic_vector(7 downto 0);

signal   dataOut    : std_logic_vector(15 downto 0);

signal   dataIn,
         dataOut32  : std_logic_vector(31 downto 0);

begin

dAddr     <= slvToInt(devAddr(0));

dataOut32 <= x"00000" & dataOut(15 downto 4);

hvTmpFSM: process(clk, rst, devExec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            exec       <= '0';
            rw         <= devRead;
            rAddr      <= (others => '0');
            autoRead   <= '0';
            devReady   <= '0';
            busy       <= '1';
            devDataOut <= (others => (others => '0'));
            rData      <= (others => (others => '0'));

            state      <= init;
        else
            case state is
                when init =>
                    if busyTmp = '0' then
                        autoRead <= '1';
                        busy     <= '0';

                        state    <= idle;
                    else
                        state    <= init;
                    end if;

                when idle =>
                    devReady <= '0';
                    busy     <= '0';

                    state    <= idle;

                    if readCnt = readCount-1 and busyTmp = '0' then
                        exec     <= '1';
                        rw       <= devRead;
                        rAddr    <= (others => '0');
                        autoRead <= '1';
                        busy     <= '1';

                        state    <= waitReady;
                    elsif devExec = '1' then
                        if devAddr(1) = x"00" and devId = tmp275 and busyTmp = '0' then
                            exec     <= '1';
                            rw       <= devRw;
                            rAddr    <= devAddr(0);
                            dataIn   <= devDataToSlv(devDataIn);
                            autoRead <= '0';
                            busy     <= '1';
    
                            state    <= waitReady;
                        elsif devAddr(1) = x"01" then
                            if dAddr > addr'pos(addr'high) then
                                state    <= idle;
                            elsif devRw = devRead then
                                devReady   <= '1';
                                devDataOut <= readReg(reg, rData, dAddr);
                                busy       <= '1';
    
                                state      <= idle;
                            end if;
                        end if;
                    end if;

                when waitReady =>
                    exec  <= '0';

                    state <= waitReady;

                    if autoRead = '1' and dataReady = '1' then
                        writeReg(reg, rData, addr'pos(rTemp), dataOut32);
                        exec  <= '0';

                        state <= idle;
                    elsif dataReady = '1' then
                        exec  <= '0';

                        state <= store;
                    end if;

                when store =>
                    autoRead   <= '1';
                    devReady   <= '1';
                    devDataOut <= (dataOut32(31 downto 24),
                                   dataOut32(23 downto 16),
                                   dataOut32(15 downto 8),
                                   dataOut32(7  downto 0));

                    state      <= idle;

                when others =>
                    exec     <= '0';
                    rw       <= devRead;
                    rAddr    <= (others => '0');
                    autoRead <= '0';
                    devReady <= '0';
                    busy     <= '0';

                    state    <= init;
            end case;
        end if;
    end if;
end process;

tempFSMInst: entity work.tmp275FSM
generic map(
    tmpAddr   => tmpAddr
)
port map(
    clk       => clk,
    rst       => rst,
    exec      => exec,
    rw        => rw,
    addr      => rAddr,
    dataIn    => dataIn(15 downto 0),
    dataOut   => dataOut,
    busy      => busyTmp,
    dataReady => dataReady,
    i2cEna    => i2cEna,
    i2cAddr   => i2cAddr,
    i2cRw     => i2cRw,
    i2cDataWr => i2cDataWr,
    i2cBusy   => i2cBusy,
    i2cDataRd => i2cDataRd
);

readCounterInst: process(clk, rst)
begin
    if rising_edge(clk) then
        if rst = '1' or readCnt = readCount-1 or autoRead = '0' then
            readCnt <= 0;
        elsif autoRead = '1' then
            readCnt <= readCnt + 1;
        end if;
    end if;
end process;

end Behavioral;