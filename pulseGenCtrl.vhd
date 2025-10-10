----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: pulseGenCtrl
-- Create Date: 03.09.2024 14:38:38
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
-- Revision 0.02 - Modified for using with deviceInterface.vhd
--
--  TODO:
--
--  1) add watchdog for states waiting external signals
--  2) test commands receiving during dacBusy = '1'
--  3) change dacSerialInterface to change clk frequency
--  4) add power on wait and dacRef setting
--  5) add state ID to status register for all states
--  6) writing '0' to pwrSave register shouldn't do anything
--
------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use IEEE.MATH_REAL.ALL;
use work.utilsPkg.all;
use work.devicesPkg.all;
use work.registersPkg.all;

entity pulseGenCtrl is
generic(
    clkFreq      : real;
    sleepOnPwrOn : boolean;
    pwrOnTime    : real;
    settlingTime : real
);
port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    devExec      : in  std_logic;
    devId        : in  devices_t;
    devRw        : in  std_logic;
    devAddr      : in  devAddr_t;
    devDataIn    : in  devData_t;
    devDataOut   : out devData_t;
    devReady     : out std_logic;
    busy         : out std_logic;
    pulse        : out std_logic;
    dacSDI       : out std_logic;
    dacSCLK      : out std_logic;
    dacCS        : out std_logic
);
end pulseGenCtrl;

architecture Behavioral of pulseGenCtrl is

--------------------- registers definitions ------------------------

type addr is (regStatus,
              regOutEn,
              regRefSet,
              regPwrSave,
              regVSet,
              regWSet,
              regTSet);

constant reg : regsRec_t := (
    addr'pos(regStatus)  => (rAddr => 0, rBegin => 31, rEnd => 18, rMode => ro),
    addr'pos(regOutEn)   => (rAddr => 0, rBegin => 17, rEnd => 17, rMode => rw),
    addr'pos(regRefSet)  => (rAddr => 0, rBegin => 16, rEnd => 16, rMode => rw),
    addr'pos(regPwrSave) => (rAddr => 0, rBegin => 15, rEnd => 15, rMode => rw),
    addr'pos(regVSet)    => (rAddr => 0, rBegin => 14, rEnd => 0,  rMode => rw),
    addr'pos(regWSet)    => (rAddr => 1, rBegin => 31, rEnd => 0,  rMode => rw),
    addr'pos(regTSet)    => (rAddr => 2, rBegin => 31, rEnd => 0,  rMode => rw)
);

constant regsNum  : integer := reg(reg'high).rAddr+1;

signal   rData    : regsData_t(regsNum-1 downto 0);

--------------------------------------------------------------------

constant settlingCount  : integer   := integer(settlingTime*clkFreq);
constant pwrOnCount     : integer   := integer(pwrOnTime*clkFreq);
constant sleepPwrOn     : std_logic := boolToStdLogic(sleepOnPwrOn);

constant dacSetVUpdtCMD : std_logic_vector(3 downto 0) := "0011";
constant dacOffCMD      : std_logic_vector(3 downto 0) := "0100";
constant dacRefCMD      : std_logic_vector(2 downto 0) := "011";

constant idleStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant settlStatus    : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"002", '0');
constant settlPwrStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"004", '0');
constant pOnStatus      : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"008", '0');
constant pOffStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"010", '0');
constant errAddrStatus  : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');
constant errVWTStatus   : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"B00", '0');
constant errOthStatus   : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"F00", '0');

type state_t is (idle,
                 execute,
                 waitPwrOnTime,
                 waitSettlingTime,
                 setVDac,
                 setRef,
                 pwrSave,
                 checkVWT,
                 pulseOff,
                 pulseOn,
                 errAddr,
                 errReadOnly,
                 errVWT);

signal   state          : state_t;
signal   dAddr          : integer;
signal   settlCnt       : unsigned(bitsNum(max(settlingCount, pwrOnCount)) downto 0);
signal   onCnt,
         offCnt         : unsigned(32 downto 0);
signal   dacSend,
         dacBusySig,
         endPwrOn,
         endSettl,
         endOnCnt,
         endOffCnt,
         execSig,
         start          : std_logic;
signal   dacCmd         : std_logic_vector(3 downto 0);
signal   dacValue       : std_logic_vector(11 downto 0);
signal   settled        : std_logic_vector(1 downto 0);

attribute mark_debug : string;
attribute mark_debug of state,
                        pulse : signal is "true";

begin

dAddr     <= devAddrToInt(devAddr);
endSettl  <= settlCnt(settlCnt'left);
endOnCnt  <= onCnt(32);
endOffCnt <= offCnt(32);
start     <= devExec or execSig;

pGenFSM: process(clk, rst, devExec, start)
    variable period : unsigned(31 downto 0) := (others => '0');
    variable width  : unsigned(31 downto 0) := (others => '0');
    variable ampl   : unsigned(31 downto 0) := (others => '0');
begin
    if rising_edge(clk) then
        if rst = '1' then
            devReady   <= '0';
            devDataOut <= (others => (others => '0'));
            rData      <= (others => (others => '0'));
            settlCnt   <= to_unsigned(settlingCount-2, settlCnt'length);
            onCnt      <= (others => '0');
            offCnt     <= (others => '0');
            execSig    <= '0';
            busy       <= '0';
            pulse      <= '0';
            dacSend    <= '0';
            dacCmd     <= (others => '0');
            dacValue   <= (others => '0');
            settled    <= "00";

            state      <= idle;
        else
            case state is
                when idle =>
                    if start = '1' and devID = pulseGen then
                        if dAddr > addr'pos(addr'high) then
                            execSig  <= '0';

                            state    <= errAddr;
                        elsif devRw = devRead then
                            devReady   <= '1';
                            devDataOut <= readReg(reg, rData, dAddr);
                            execSig    <= '0';
                            busy       <= '1';

                            state      <= execute;
                        elsif devRw = devWrite and reg(dAddr).rMode = ro then
                            execSig  <= '0';

                            state    <= errReadOnly;
                        elsif devRw = devWrite and reg(dAddr).rMode = rw then
                            writeReg(reg, rData, addr'pos(regStatus), dAddr);
                            writeReg(reg, rData, dAddr, devDataIn);
                            execSig  <= '0';
                            busy     <= '1';

                            state    <= execute;
                        else
                            writeReg(reg, rData, addr'pos(regStatus), idleStatus);
                            execSig  <= '0';
    
                            state    <= idle;
                        end if;
                    else
                        writeReg(reg, rData, addr'pos(regStatus), idleStatus);
                        execSig  <= '0';

                        state    <= idle;
                    end if;

                when execute =>
                    if dacBusySig = '0' then
                        if readReg(reg, rData, addr'pos(regStatus)) = addrToSlv(addr'pos(regVSet)) then
                            devReady <= '0';
                            dacSend  <= '1';
                            dacCmd   <= dacSetVUpdtCMD;
                            dacValue <= readReg(reg, rData, addr'pos(regVSet))(11 downto 0);
    
                            state    <= setVDac;
                        elsif readReg(reg, rData, addr'pos(regStatus)) = addrToSlv(addr'pos(regRefSet)) then
                            devReady <= '0';
                            dacSend  <= '1';
                            dacCmd   <= dacRefCMD & isSet(reg, rData, addr'pos(regRefSet));
                            dacValue <= (others => '0');
    
                            state    <= setRef;
                        elsif readReg(reg, rData, addr'pos(regStatus)) = addrToSlv(addr'pos(regPwrSave)) then
                            devReady <= '0';
                            dacSend  <= '1';
                            dacCmd   <= dacOffCMD;
                            dacValue <= (others => '0');
    
                            state    <= pwrSave;
                        elsif isSet(reg, rData, addr'pos(regOutEn)) and not isSet(reg, rData, addr'pos(regPwrSave)) then
                            devReady <= '0';
    
                            state    <= checkVWT;
                        elsif isSet(reg, rData, addr'pos(regOutEn)) and isSet(reg, rData, addr'pos(regPwrSave)) then
                            devReady <= '0';
    
                            state    <= waitSettlingTime;
                        else
                            devReady <= '0';
                            busy     <= '0';
    
                            state    <= idle;
                        end if;
                    else
                        state <= execute;
                    end if;

                when setVDac =>
                    if dacBusySig = '1' then
                        settlCnt <= to_unsigned(settlingCount-2, settlCnt'length);
                        dacSend  <= '0';
                        settled  <= "01";

                        state    <= waitSettlingTime;
                    elsif devExec = '1' and devID = pulseGen then
                        busy     <= '0';
                        execSig  <= '1';

                        state    <= idle;
                    else
                        dacSend <= '0';

                        state   <= setVDac;
                    end if;

                when setRef =>
                    if dacBusySig = '1' then
                        clearReg(reg, rData, addr'pos(regOutEn));
                        busy    <= '0';
                        dacSend <= '0';

                        state   <= idle;
                    elsif devExec = '1' and devID = pulseGen then
                        busy     <= '0';
                        execSig  <= '1';

                        state    <= idle;
                    else
                        dacSend <= '0';

                        state   <= setRef;
                    end if;

                when pwrSave =>
                    if dacBusySig = '1' then
                        writeReg(reg, rData, addr'pos(regStatus), idleStatus);
                        clearReg(reg, rData, addr'pos(regOutEn));
                        busy    <= '0';
                        dacSend <= '0';

                        state   <= idle;
                    elsif devExec = '1' and devID = pulseGen then
                        busy     <= '0';
                        execSig  <= '1';

                        state    <= idle;
                    else
                        dacSend <= '0';

                        state   <= pwrSave;
                    end if;

                when waitSettlingTime =>
                    period := readReg(reg, rData, addr'pos(regTSet));
                    width  := readReg(reg, rData, addr'pos(regWSet));

                    if endSettl = '1' and isSet(reg, rData, addr'pos(regPwrSave)) then
                        settlCnt <= to_unsigned(pwrOnCount-2, settlCnt'length);
                        settled  <= "10";

                        state    <= waitPwrOnTime;
                    elsif endSettl = '1' and isSet(reg, rData, addr'pos(regOutEn)) then
                        writeReg(reg, rData, addr'pos(regStatus), pOnStatus);
                        settlCnt <= to_unsigned(settlingCount-2, settlCnt'length);
                        settled  <= "00";

                        state    <= checkVWT;
                    elsif endSettl = '1' and not isSet(reg, rData, addr'pos(regOutEn)) then
                        settlCnt <= to_unsigned(settlingCount-2, settlCnt'length);
                        busy     <= '0';
                        execSig  <= '0';
                        settled  <= "00";

                        state    <= idle;
                    elsif devExec = '1' and devID = pulseGen then
                        busy     <= '0';
                        execSig  <= '1';

                        state    <= idle;
                    else
                        writeReg(reg, rData, addr'pos(regStatus), settlStatus);
                        settlCnt <= settlCnt - 1;
                        settled  <= "01";

                        state    <= waitSettlingTime;
                    end if;

                when waitPwrOnTime =>
                    period := readReg(reg, rData, addr'pos(regTSet));
                    width  := readReg(reg, rData, addr'pos(regWSet));

                    if endSettl = '1' and isSet(reg, rData, addr'pos(regOutEn)) then
                        writeReg(reg, rData, addr'pos(regStatus), pOnStatus);
                        clearReg(reg, rData, addr'pos(regPwrSave));
                        settlCnt <= to_unsigned(settlingCount-2, settlCnt'length);
                        settled  <= "00";

                        state    <= checkVWT;
                    elsif endSettl = '1' and not isSet(reg, rData, addr'pos(regOutEn)) then
                        clearReg(reg, rData, addr'pos(regPwrSave));
                        settlCnt <= to_unsigned(settlingCount-2, settlCnt'length);
                        busy     <= '0';
                        execSig  <= '0';
                        settled  <= "00";

                        state    <= idle;
                    elsif devExec = '1' and devID = pulseGen then
                        busy     <= '0';
                        execSig  <= '1';

                        state    <= idle;
                    else
                        writeReg(reg, rData, addr'pos(regStatus), settlPwrStatus);
                        settlCnt <= settlCnt - 1;
                        settled  <= "10";

                        state    <= waitPwrOnTime;
                    end if;

                when checkVWT =>
                    ampl   := readReg(reg, rData, addr'pos(regVSet));
                    period := readReg(reg, rData, addr'pos(regTSet));
                    width  := readReg(reg, rData, addr'pos(regWSet));

                    if settled = "01" then
                        state <= waitSettlingTime;
                    elsif settled = "10" then
                        state <= waitPwrOnTime;
                    elsif period > width and width > 0 and ampl > 0 then
                        onCnt  <= '0' & width-2;
                        offCnt <= '0' & period-width-2;
                        pulse  <= '1';

                        state  <= pulseOn;
                    else
                        state  <= errVWT;
                    end if;

                when pulseOn =>
                    period := readReg(reg, rData, addr'pos(regTSet));
                    width  := readReg(reg, rData, addr'pos(regWSet));

                    if devExec = '1' and devID = pulseGen then
                        writeReg(reg, rData, addr'pos(regStatus), idleStatus);
                        busy    <= '0';
                        pulse   <= '0';
                        onCnt   <= (others => '0');
                        offCnt  <= (others => '0');
                        execSig <= '1';

                        state   <= idle;
                    elsif endOnCnt = '1' then
                        writeReg(reg, rData, addr'pos(regStatus), pOffStatus);
                        pulse  <= '0';
                        onCnt  <= '0' & width-2;
                        offCnt <= '0' & period-width-2;

                        state  <= pulseOff;
                    else
                        writeReg(reg, rData, addr'pos(regStatus), pOnStatus);
                        pulse <= '1';
                        onCnt <= onCnt - 1;

                        state <= pulseOn;
                    end if;

                when pulseOff =>
                    period := readReg(reg, rData, addr'pos(regTSet));
                    width  := readReg(reg, rData, addr'pos(regWSet));

                    if devExec = '1' and devID = pulseGen then
                        writeReg(reg, rData, addr'pos(regStatus), idleStatus);
                        busy    <= '0';
                        pulse   <= '0';
                        onCnt   <= (others => '0');
                        offCnt  <= (others => '0');
                        execSig <= '1';

                        state   <= idle;
                    elsif endOffCnt = '1' then
                        writeReg(reg, rData, addr'pos(regStatus), pOnStatus);
                        pulse  <= '1';
                        onCnt  <= '0' & width-2;
                        offCnt <= '0' & period-width-2;

                        state  <= pulseOn;
                    else
                        writeReg(reg, rData, addr'pos(regStatus), pOffStatus);
                        pulse  <= '0';
                        offCnt <= offCnt - 1;

                        state  <= pulseOff;
                    end if;

                when errAddr =>
                    writeReg(reg, rData, addr'pos(regStatus), errAddrStatus);
                    busy  <= '0';

                    state <= idle;

                when errReadOnly =>
                    writeReg(reg, rData, addr'pos(regStatus), errROnlyStatus);
                    busy  <= '0';

                    state <= idle;

                when errVWT =>
                    writeReg(reg, rData, addr'pos(regStatus), errVWTStatus);
                    clearReg(reg, rData, addr'pos(regOutEn));
                    busy  <= '0';

                    state <= idle;

                when others =>
                    writeReg(reg, rData, addr'pos(regStatus), errOthStatus);
                    devReady   <= '0';
                    devDataOut <= (others => (others => '0'));
                    busy       <= '0';

                    state      <= idle;
            end case;
        end if;
    end if;
end process;

dacSerInst: entity work.dacSerialInterface
port map(
    clk      => clk,
    rst      => rst,
    send     => dacSend,
    dacCmd   => dacCmd,
    dacValue => dacValue,
    dacBusy  => dacBusySig,
    dacSDI   => dacSDI,
    dacSCLK  => dacSCLK,
    dacCS    => dacCS
);

end Behavioral;