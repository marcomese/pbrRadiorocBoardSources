----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: sipmHvTmpCtrl
-- Create Date: 20.11.2024 11:47:50
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
use work.devicesPkg.all;
use work.registersPkg.all;
use work.caenA7585DPkg.all;

entity sipmHvTmpCtrl is
generic(
    clkFreq    : real;
    readPeriod : real;
    tmpAddr    : std_logic_vector(6 downto 0);
    sipmHvAddr : std_logic_vector(6 downto 0)
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
end sipmHvTmpCtrl;

architecture Behavioral of sipmHvTmpCtrl is

--------------------- registers definitions ------------------------

type addr is (rStatus,
              rTemp,
              rVout,
              rIout);

constant reg : regsRec_t := (
    addr'pos(rStatus) => (rAddr => 0, rBegin => 31, rEnd => 12, rMode => ro),
    addr'pos(rTemp)   => (rAddr => 0, rBegin => 11, rEnd => 0,  rMode => ro),
    addr'pos(rVout)   => (rAddr => 1, rBegin => 31, rEnd => 0,  rMode => ro),
    addr'pos(rIout)   => (rAddr => 2, rBegin => 31, rEnd => 0,  rMode => ro)
);

constant regsNum  : integer := reg(reg'high).rAddr+1;

signal   rData    : regsData_t(regsNum-1 downto 0);

--------------------------------------------------------------------

type i2cSel_t is (temp, hv);

type state_t is (init,
                 idle,
                 waitReady,
                 store);

constant readCmd    : std_logic := '1';
constant writeCmd   : std_logic := '0';

constant readCount  : integer := integer(readPeriod*clkFreq);

signal   state      : state_t;

signal   i2cSel     : i2cSel_t;

signal   readCnt    : integer range 0 to readCount-1;

signal   dAddr      : integer;

signal   i2cEnaTMP,    i2cEnaHV,
         i2cBusyTMP,   i2cBusyHV,
         i2cRwTMP,     i2cRwHV,
         execTMP,      execHV,
         busyTMP,      busyHV,
         dataReadyTMP, dataReadyHV,
         rw,
         autoRead                  : std_logic;

signal   i2cAddrTMP,   i2cAddrHV   : std_logic_vector(6 downto 0);

signal   i2cDataWrTMP, i2cDataWrHV,
         i2cDataRdTMP, i2cDataRdHV,
         rAddr                     : std_logic_vector(7 downto 0);

signal   dataOutTMP                : std_logic_vector(15 downto 0);

signal   dataIn,
         dataOutHV,
         dataOutTMP32              : std_logic_vector(31 downto 0);

begin

dAddr        <= slvToInt(devAddr(0));

dataOutTMP32 <= x"00000" & dataOutTMP(15 downto 4);

i2cMux: process(clk, rst, i2cSel)
begin
    if rising_edge(clk) then
        if rst = '1' then
            i2cEna       <= i2cEnaTMP;
            i2cAddr      <= i2cAddrTMP;
            i2cRw        <= i2cRwTMP;
            i2cDataWr    <= i2cDataWrTMP;
            i2cDataRdTMP <= (others => '0');
            i2cDataRdHV  <= (others => '0');
            i2cBusyTMP   <= '0';
            i2cBusyHV    <= '0';
        else
            i2cDataRdTMP <= i2cDataRd;
            i2cDataRdHV  <= i2cDataRd;
            i2cBusyTMP   <= i2cBusy;
            i2cBusyHV    <= i2cBusy;

            case i2cSel is
                when temp =>
                    i2cEna     <= i2cEnaTMP;
                    i2cAddr    <= i2cAddrTMP;
                    i2cRw      <= i2cRwTMP;
                    i2cDataWr  <= i2cDataWrTMP;
                when hv =>
                    i2cEna     <= i2cEnaHV;
                    i2cAddr    <= i2cAddrHV;
                    i2cRw      <= i2cRwHV;
                    i2cDataWr  <= i2cDataWrHV;
                when others =>
                    i2cEna     <= i2cEnaTMP;
                    i2cAddr    <= i2cAddrTMP;
                    i2cRw      <= i2cRwTMP;
                    i2cDataWr  <= i2cDataWrTMP;
            end case;
        end if;
    end if;
end process;

hvTmpFSM: process(clk, rst, devExec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            i2cSel     <= temp;
            execTMP    <= '0';
            execHV     <= '0';
            rw         <= readCmd;
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
                    if busyTMP = '0' and busyHV = '0' then
                        autoRead <= '1';
                        busy     <= '0';

                        state    <= idle;
                    else
                        state    <= init;
                    end if;

                when idle =>
                    if readCnt = readCount-1 and busyTMP = '0' then
                        i2cSel   <= temp;
                        execTMP  <= '1';
                        rw       <= readCmd;
                        rAddr    <= (others => '0');
                        autoRead <= '1';
                        devReady <= '0';
                        busy     <= '1';

                        state    <= waitReady;
                    elsif devExec = '1' then
                        if devAddr(1) = x"00" and devId = tmp275 and busyTMP = '0' then
                            i2cSel   <= temp;
                            execTMP  <= '1';
                            rw       <= devRw;
                            rAddr    <= devAddr(0);
                            dataIn   <= devDataToSlv(devDataIn);
                            autoRead <= '0';
                            devReady <= '0';
                            busy     <= '1';
    
                            state    <= waitReady;
                        elsif devAddr(1) = x"00" and devId = a7585d and busyHV = '0' then
                            i2cSel   <= hv;
                            execHV   <= '1';
                            rw       <= devRw;
                            rAddr    <= devAddr(0);
                            dataIn   <= devDataToSlv(devDataIn);
                            autoRead <= '0';
                            devReady <= '0';
                            busy     <= '1';
    
                            state    <= waitReady;
                        elsif devAddr(1) = x"01" then -- add devId=caen and tmp
                            if dAddr > addr'pos(addr'high) then
                                state    <= idle;
                            elsif devRw = devRead then
                                devReady   <= '1';
                                devDataOut <= readReg(reg, rData, dAddr);
                                busy       <= '1';
    
                                state      <= idle;
                            end if;
                        end if;
                    else
                        devReady <= '0';
                        busy     <= '0';

                        state    <= idle;
                    end if;

                when waitReady =>
                    if autoRead = '1' then
                        if i2cSel = temp and dataReadyTMP = '1' then
                            writeReg(reg, rData, addr'pos(rTemp), dataOutTMP32);
                            i2cSel  <= hv;
                            execTMP <= '0';
                            execHV  <= '1';
                            rw      <= readCmd;
                            rAddr   <= regVout;
    
                            state   <= waitReady;
                        elsif i2cSel = hv and dataReadyHV = '1' then
                            writeReg(reg, rData, addr'pos(rVout), dataOutHV);
                            i2cSel  <= hv;
                            execTMP <= '0';
                            execHV  <= '0';
                            rw      <= readCmd;
                            rAddr   <= regIout;
    
                            state   <= store;
                        else
                            execTMP <= '0';
                            execHV  <= '0';

                            state <= waitReady;
                        end if;
                    elsif (i2cSel = temp and dataReadyTMP = '1') or 
                           (i2cSel = hv and dataReadyHV = '1') then
                        execTMP <= '0';
                        execHV  <= '0';

                        state <= store;
                    else
                        execTMP <= '0';
                        execHV  <= '0';

                        state <= waitReady;
                    end if;

                when store =>
                    if autoRead = '1' then--and dataReadyHV = '1' then
                        writeReg(reg, rData, addr'pos(rIout), dataOutHV);

                        state   <= idle;
                    elsif i2cSel = temp then--and dataReadyTMP = '1' then
                        autoRead   <= '0';--'1';
                        devReady   <= '1';
                        --busy       <= '0';
                        devDataOut <= (dataOutTMP32(31 downto 24),
                                       dataOutTMP32(23 downto 16),
                                       dataOutTMP32(15 downto 8), 
                                       dataOutTMP32(7  downto 0)); 

                        state      <= idle;
                    elsif i2cSel = hv then--and dataReadyHV = '1' then
                        autoRead   <= '0';--'1';
                        devReady   <= '1';
                        --busy       <= '0';
                        devDataOut <= (dataOutHV(31 downto 24),
                                       dataOutHV(23 downto 16),
                                       dataOutHV(15 downto 8), 
                                       dataOutHV(7  downto 0)); 

                        state      <= idle;
                    else
                        state   <= idle;--store;
                    end if;

                when others =>
                    i2cSel   <= temp;
                    execTMP  <= '0';
                    execHV   <= '0';
                    rw       <= readCmd;
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
    tmpAddr      => tmpAddr
)
port map(
    clk          => clk,
    rst          => rst,      
    exec         => execTMP,
    rw           => rw,
    addr         => rAddr,
    dataIn       => dataIn(15 downto 0),
    dataOut      => dataOutTMP,
    busy         => busyTMP,
    dataReady    => dataReadyTMP,
    i2cEna       => i2cEnaTMP,
    i2cAddr      => i2cAddrTMP,
    i2cRw        => i2cRwTMP,
    i2cDataWr    => i2cDataWrTMP,
    i2cBusy      => i2cBusy,
    i2cDataRd    => i2cDataRd
);

hvFSMInst: entity work.caenA7585DFSM
generic map(
    caenAddr  => sipmHvAddr
)
port map(
    clk       => clk,
    rst       => rst,
    exec      => execHV,
    rw        => rw,
    addr      => rAddr,
    dataIn    => dataIn,
    dataOut   => dataOutHV,
    busy      => busyHV,
    dataReady => dataReadyHV,
    i2cEna    => i2cEnaHV,
    i2cAddr   => i2cAddrHV,
    i2cRw     => i2cRwHV,
    i2cDataWr => i2cDataWrHV,
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