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
    pulsing      : out std_logic;
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
    addr'pos(regStatus)  => (rAddr => 0, rBegin => 31, rEnd => 0, rMode => ro),
    addr'pos(regOutEn)   => (rAddr => 1, rBegin => 31, rEnd => 0, rMode => rw),
    addr'pos(regRefSet)  => (rAddr => 2, rBegin => 31, rEnd => 0, rMode => rw),
    addr'pos(regPwrSave) => (rAddr => 3, rBegin => 31, rEnd => 0, rMode => rw),
    addr'pos(regVSet)    => (rAddr => 4, rBegin => 31, rEnd => 0, rMode => rw),
    addr'pos(regWSet)    => (rAddr => 5, rBegin => 31, rEnd => 0, rMode => rw),
    addr'pos(regTSet)    => (rAddr => 6, rBegin => 31, rEnd => 0, rMode => rw)
);

constant regsNum : integer := reg(reg'high).rAddr+1;

signal   rData   : regsData_t(regsNum-1 downto 0);

--------------------------------------------------------------------

constant settlingCount  : integer                       := integer(settlingTime*clkFreq);
constant pwrOnCount     : integer                       := integer(pwrOnTime*clkFreq);
constant sleepPwrOn     : std_logic                     := boolToStdLogic(sleepOnPwrOn);

constant dacSetVUpdtCMD : std_logic_vector(3 downto 0)  := "0011";
constant dacOffCMD      : std_logic_vector(3 downto 0)  := "0100";
constant dacRefCMD      : std_logic_vector(2 downto 0)  := "011";

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
                 errAddr,
                 errReadOnly,
                 errVWT);

signal   state      : state_t;
signal   lastData   : devData_t;
signal   dAddr,
         lastAddr   : integer;
signal   settlCnt   : unsigned(bitsNum(max(settlingCount, pwrOnCount)) downto 0);
signal   dacSend,
         dacBusySig,
         endSettl,
         execSig,
         pGenEn,
         start,
         loadDataOut,
         loadReg,
         loadDac,
         locRst     : std_logic;
signal   dacCmd     : std_logic_vector(3 downto 0);
signal   dacValue   : std_logic_vector(11 downto 0);
signal   periodSig,
         widthSig   : std_logic_vector(31 downto 0);
signal   settled    : std_logic_vector(1 downto 0);

begin

dAddr    <= devAddrToInt(devAddr);
endSettl <= settlCnt(settlCnt'left);
start    <= devExec or execSig;

locRstProc: process(clk)
begin
    if rising_edge(clk) then
        locRst <= rst;
    end if;
end process;

devDataOutCtrl: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            devReady   <= '0';
            devDataOut <= (others => (others => '0'));
        elsif loadDataOut = '1' then
            devReady   <= '1';
            devDataOut <= slvToDevData(rData(lastAddr));
        else
            devReady <= '0';
        end if;
    end if;
end process;

rDataCtrl: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            rData <= (others => (others => '0'));
        elsif loadReg = '1' then
            rData(lastAddr) <= devDataToSlv(lastData);
        end if;
    end if;
end process;

dacCtrl: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            dacSend  <= '0';
            dacCmd   <= (others => '0');
            dacValue <= (others => '0');
        elsif loadDac = '1' and lastAddr = addr'pos(regVSet) then
            dacSend  <= '1';
            dacCmd   <= dacSetVUpdtCMD;
            dacValue <= rData(addr'pos(regVSet))(11 downto 0);
        elsif loadDac = '1' and lastAddr = addr'pos(regRefSet) then
            dacSend  <= '1';
            dacCmd   <= dacRefCMD & rData(addr'pos(regRefSet))(0);
            dacValue <= (others => '0');
        elsif loadDac = '1' and lastAddr = addr'pos(regPwrSave) then
            dacSend  <= '1';
            dacCmd   <= dacOffCMD;
            dacValue <= (others => '0');
        else
            dacSend <= '0';
        end if;
    end if;
end process;

pGenFSM: process(clk)
    variable ampl   : std_logic_vector(31 downto 0) := (others => '0');
    variable period : std_logic_vector(31 downto 0) := (others => '0');
    variable width  : std_logic_vector(31 downto 0) := (others => '0');
begin
    if rising_edge(clk) then
        if locRst = '1' then
            settlCnt    <= to_unsigned(settlingCount-2, settlCnt'length);
            execSig     <= '0';
            busy        <= '0';
            loadDac     <= '0';
            loadDataOut <= '0';
            loadReg     <= '0';
            pGenEn      <= '0';
            settled     <= "00";
            lastAddr    <= 0;
            lastData    <= (others => (others => '0'));
            periodSig   <= (others => '0');
            widthSig    <= (others => '0');

            state       <= idle;
        else
            case state is
                when idle =>
                    loadReg <= '0';
                    execSig <= '0';

                    state   <= idle;

                    if start = '1' and devID = pulseGen then
                        if dAddr > addr'pos(addr'high) then
                            state    <= errAddr;
                        elsif devRw = devRead then
                            lastAddr    <= dAddr;
                            loadDataOut <= '1';
                            busy        <= '1';

                            state       <= idle;
                        elsif devRw = devWrite and reg(dAddr).rMode = ro then
                            state   <= errReadOnly;
                        elsif devRw = devWrite and reg(dAddr).rMode = rw then
                            lastAddr <= dAddr;
                            lastData <= devDataIn;
                            loadReg  <= '1';
                            busy     <= '1';

                            state    <= execute;
                        end if;
                    end if;

                when execute =>
                    loadReg <= '0';

                    state   <= execute;

                    if dacBusySig = '0' then
                        if lastAddr = addr'pos(regVSet) then
                            loadDac <= '1';

                            state   <= setVDac;
                        elsif lastAddr = addr'pos(regRefSet) then
                            loadDac <= '1';

                            state   <= setRef;
                        elsif lastAddr = addr'pos(regPwrSave) then
                            loadDac <= '1';

                            state   <= pwrSave;
                        elsif rData(addr'pos(regOutEn))(0) = '0' then ---- rData not updated yet!
                            pGenEn <= '0';
                            busy   <= '0';

                            state  <= idle;
                        elsif rData(addr'pos(regOutEn))(0) = '1' and rData(addr'pos(regPwrSave))(0) = '0' then
                            state    <= checkVWT;
                        elsif rData(addr'pos(regOutEn))(0) = '1' and rData(addr'pos(regPwrSave))(0) = '1' then
                            state    <= waitSettlingTime;
                        else
                            busy     <= '0';

                            state    <= idle;
                        end if;
                    end if;

                when setVDac =>
                    loadDac <= '0';

                    state   <= setVDac;

                    if dacBusySig = '1' then
                        loadReg  <= '1';
                        lastAddr <= addr'pos(regStatus);
                        lastData <= slvToDevData(settlStatus);
                        settlCnt <= to_unsigned(settlingCount-2, settlCnt'length);
                        settled  <= "01";

                        state    <= waitSettlingTime;
                    elsif devExec = '1' and devID = pulseGen then
                        busy    <= '0';
                        execSig <= '1';

                        state   <= idle;
                    end if;

                when setRef =>
                    loadDac <= '0';

                    state   <= setRef;

                    if dacBusySig = '1' then
                        loadReg  <= '1';
                        lastAddr <= addr'pos(regOutEn);
                        lastData <= (others => (others => '0'));
                        busy     <= '0';

                        state    <= idle;
                    elsif devExec = '1' and devID = pulseGen then
                        busy    <= '0';
                        execSig <= '1';

                        state   <= idle;
                    end if;

                when pwrSave =>
                    loadDac <= '0';

                    state   <= pwrSave;

                    if dacBusySig = '1' then
                        loadReg  <= '1';
                        lastAddr <= addr'pos(regOutEn);
                        lastData <= (others => (others => '0'));
                        busy     <= '0';

                        state    <= idle;
                    elsif devExec = '1' and devID = pulseGen then
                        busy    <= '0';
                        execSig <= '1';

                        state   <= idle;
                    end if;

                when waitSettlingTime =>
                    loadReg  <= '0';
                    settlCnt <= settlCnt - 1;
                    settled  <= "01";

                    state    <= waitSettlingTime;

                    if endSettl = '1' and rData(addr'pos(regPwrSave))(0) = '1' then
                        loadReg  <= '1';
                        lastAddr <= addr'pos(regStatus);
                        lastData <= slvToDevData(settlPwrStatus);
                        settlCnt <= to_unsigned(pwrOnCount-2, settlCnt'length);
                        settled  <= "10";

                        state    <= waitPwrOnTime;
                    elsif endSettl = '1' and rData(addr'pos(regOutEn))(0) = '1' then
                        settlCnt <= to_unsigned(settlingCount-2, settlCnt'length);
                        settled  <= "00";

                        state    <= checkVWT;
                    elsif endSettl = '1' and not rData(addr'pos(regOutEn))(0) = '0' then
                        settlCnt <= to_unsigned(settlingCount-2, settlCnt'length);
                        busy     <= '0';
                        execSig  <= '0';
                        settled  <= "00";

                        state    <= idle;
                    elsif devExec = '1' and devID = pulseGen then
                        busy     <= '0';
                        execSig  <= '1';

                        state    <= idle;
                    end if;

                when waitPwrOnTime =>
                    loadReg  <= '0';
                    settlCnt <= settlCnt - 1;
                    settled  <= "10";

                    state    <= waitPwrOnTime;

                    if endSettl = '1' and rData(addr'pos(regOutEn))(0) = '1' then
                        loadReg  <= '1';        
                        lastAddr <= addr'pos(regPwrSave);
                        lastData <= (others => (others => '0'));
                        settlCnt <= to_unsigned(settlingCount-2, settlCnt'length);
                        settled  <= "00";

                        state    <= checkVWT;
                    elsif endSettl = '1' and rData(addr'pos(regOutEn))(0) = '0' then
                        loadReg  <= '1';        
                        lastAddr <= addr'pos(regPwrSave);
                        lastData <= (others => (others => '0'));
                        settlCnt <= to_unsigned(settlingCount-2, settlCnt'length);
                        busy     <= '0';
                        execSig  <= '0';
                        settled  <= "00";

                        state    <= idle;
                    elsif devExec = '1' and devID = pulseGen then
                        busy     <= '0';
                        execSig  <= '1';

                        state    <= idle;
                    end if;

                when checkVWT =>
                    ampl   := rData(addr'pos(regVSet));
                    period := rData(addr'pos(regTSet));
                    width  := rData(addr'pos(regWSet));

                    state  <= errVWT;

                    if settled = "01" then
                        state <= waitSettlingTime;
                    elsif settled = "10" then
                        state <= waitPwrOnTime;
                    elsif unsigned(period) > unsigned(width) and unsigned(width) > 0 and unsigned(ampl) > 0 then
                        loadReg   <= '1';
                        lastAddr  <= addr'pos(regStatus);
                        lastData  <= slvToDevData(pOnStatus);
                        periodSig <= period;
                        widthSig  <= width;
                        pGenEn    <= '1';

                        state     <= idle;
                    end if;

                when errAddr =>
                    loadReg  <= '1';
                    lastAddr <= addr'pos(regStatus);
                    lastData <= slvToDevData(errAddrStatus);
                    pGenEn   <= '0';
                    busy     <= '0';

                    state    <= idle;

                when errReadOnly =>
                    loadReg  <= '1';
                    lastAddr <= addr'pos(regStatus);
                    lastData <= slvToDevData(errROnlyStatus);
                    pGenEn   <= '0';
                    busy     <= '0';

                    state    <= idle;

                when errVWT =>
                    loadReg  <= '1';
                    lastAddr <= addr'pos(regStatus);
                    lastData <= slvToDevData(errVWTStatus);
                    pGenEn   <= '0';
                    busy     <= '0';

                    state    <= idle;

                when others =>
                    busy       <= '0';

                    state      <= idle;
            end case;
        end if;
    end if;
end process;

pGenFSMInst: entity work.pulseGenFSM
port map(
    clk     => clk,
    rst     => locRst,
    en      => pGenEn,
    period  => periodSig,
    width   => widthSig,
    pulsing => pulsing,
    pulse   => pulse
);

dacSerInst: entity work.dacSerialInterface
port map(
    clk      => clk,
    rst      => locRst,
    send     => dacSend,
    dacCmd   => dacCmd,
    dacValue => dacValue,
    dacBusy  => dacBusySig,
    dacSDI   => dacSDI,
    dacSCLK  => dacSCLK,
    dacCS    => dacCS
);

end Behavioral;