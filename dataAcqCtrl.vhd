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
use work.registersPkg.all;

library xpm;
use xpm.vcomponents.all;

entity dataAcqCtrl is
port(
    clk100M    : in  std_logic;
    rst        : in  std_logic;
    devExec    : in  std_logic;
    devId      : in  devices_t;
    devRw      : in  std_logic;
    devBrst    : in  std_logic;
    devBrstWrt : in  std_logic;
    devBrstSnd : in  std_logic;
    devBrstRst : out std_logic;
    devAddr    : in  devAddr_t;
    devDataIn  : in  devData_t;
    devDataOut : out devData_t;
    devReady   : out std_logic;
    busy       : out std_logic;
    resetAcq   : out std_logic;
    startAcq   : out std_logic;
    endAcq     : in  std_logic;
    endMAcq    : out std_logic;
    rdValid    : in  std_logic;
    rdAcq      : out std_logic;
    rdDataCnt  : in  std_logic_vector(15 downto 0);
    emptyAcq   : in  std_logic;
    nbAcq      : out std_logic_vector(7 downto 0);
    selAdc     : out std_logic_vector(63 downto 0);
    doutAcq    : in  std_logic_vector(7 downto 0)
);
end dataAcqCtrl;

architecture Behavioral of dataAcqCtrl is

--------------------- registers definitions ------------------------

type addr is (regStatus,
              regAcqEn,
              regSwTrg,
              regFifoCnt,
              regAcqNb);

constant reg : regsRec_t := (
    addr'pos(regStatus)  => (rAddr => 0, rBegin => 31, rEnd => 2,  rMode => ro),
    addr'pos(regAcqEn)   => (rAddr => 0, rBegin => 1,  rEnd => 1,  rMode => rw),
    addr'pos(regSwTrg)   => (rAddr => 0, rBegin => 0,  rEnd => 0,  rMode => rw),
    addr'pos(regFifoCnt) => (rAddr => 1, rBegin => 31, rEnd => 16, rMode => ro),
    addr'pos(regAcqNb)   => (rAddr => 1, rBegin => 7,  rEnd => 0,  rMode => rw)
);

constant regsNum : integer := reg(reg'high).rAddr+1;

signal   rData   : regsData_t(regsNum-1 downto 0);

--------------------------------------------------------------------

type state_t is (idle,
                 execute,
                 sendStartAcq,
                 readFifo,
                 waitBrstSent,
                 sendData,
                 acqEnd,
                 errAddr,
                 errReadOnly,
                 errFifoEmpty);

constant idleStatus         : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant errAddrStatus      : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');
constant errFifoEmptyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"B00", '0');

signal state          : state_t;

signal dataIn         : devData_t;

signal dAddr          : integer;

signal swTrg,
       rstAcqSig,
       strtAcqSig,
       rdAcqSig       : std_logic;

signal nbAcqSig       : std_logic_vector(7 downto 0);

attribute mark_debug : string;
attribute mark_debug of state,
                        devDataOut : signal is "true";

begin

-- DEBUG --
selAdc <= "00011001" & -- 63 downto 56
          "00000000" & -- 55 downto 48
          "00000010" & -- 47 downto 40
          "00000000" & -- 39 downto 32
          "01110111" & -- 31 downto 24 -- hit = 0
          "00000001" & -- 23 downto 16
          "00000000" & -- 15 downto 8
          swTrg      & -- 7
          "0000000";   -- 6 downto 0
-----------

dAddr    <= devAddrToInt(devAddr);
nbAcq    <= nbAcqSig;
resetAcq <= rstAcqSig;
startAcq <= strtAcqSig;
rdAcq    <= rdAcqSig and not devBrstSnd;

dataAcqCtrlFSM: process(clk100M, rst, devExec)
    variable i : integer := 0;
begin
    if rising_edge(clk100M) then
        if rst = '1' then
            devReady   <= '0';
            busy       <= '0';
            rstAcqSig  <= '1';
            strtAcqSig <= '0';
            rdAcqSig   <= '0';
            nbAcqSig   <= (others => '0');
            devDataOut <= (others => (others => '0'));
            devBrstRst <= '0';
            swTrg      <= '0';

            state      <= idle;
        else
            writeReg(reg, rData, addr'pos(regFifoCnt), resize(unsigned(rdDataCnt), regsLen));

            case state is
                when idle =>
                    devReady   <= '0';
                    rstAcqSig  <= '0';
                    strtAcqSig <= '0';
                    swTrg      <= '0';
                    busy       <= '0';

                    state      <= idle;

                    if devExec = '1' and devId = acqSystem then
                        if dAddr > addr'pos(addr'high) then
                            state    <= errAddr;
                        elsif devRw = devRead and devBrst = '0' then
                            writeReg(reg, rData, addr'pos(regStatus), idleStatus);
                            devReady   <= '1';
                            devDataOut <= readReg(reg, rData, dAddr);
                            busy       <= '1';

                            state      <= idle;
                        elsif devRw = devRead and devBrst = '1' and emptyAcq = '0' then
                            rdAcqSig <= '1';

                            state    <= readFifo;
                        elsif devRw = devRead and devBrst = '1' and emptyAcq = '1' then
                            devBrstRst <= '1';

                            state      <= errFifoEmpty;
                        elsif devRw = devWrite and reg(dAddr).rMode = ro then
                            state    <= errReadOnly;
                        elsif devRw = devWrite and reg(dAddr).rMode = rw then
                            writeReg(reg, rData, addr'pos(regStatus), dAddr);
                            writeReg(reg, rData, dAddr, devDataIn);
                            busy  <= '1';

                            state <= execute;
                        end if;
                    end if;

                when execute =>
                    state <= idle;

                    if isSet(reg, rData, addr'pos(regAcqEn)) then
                        rstAcqSig <= '1';

                        state     <= sendStartAcq;
                    elsif isSet(reg, rData, addr'pos(regSwTrg)) then
                        clearReg(reg, rData, addr'pos(regSwTrg));
                        swTrg <= '1';
                    elsif readReg(reg, rData, addr'pos(regStatus)) = addrToSlv(addr'pos(regAcqNb)) then
                        nbAcqSig <= readReg(reg, rData, addr'pos(regAcqNb))(7 downto 0);
                    end if;

                when sendStartAcq =>
                    rstAcqSig  <= '0';
                    strtAcqSig <= '1';

                    state      <= idle;

                when readFifo =>
                    devDataOut(0) <= doutAcq;
                    devReady      <= rdValid;
                    rdAcqSig      <= devBrstWrt;

                    state         <= readFifo;

                    if devBrstSnd = '1' then
                        rdAcqSig <= '0';

                        state    <= waitBrstSent; 
                    elsif devBrst = '0' and devBrstWrt = '1' then
                        rdAcqSig <= '0';

                        state    <= acqEnd;
                    end if;

                when waitBrstSent =>
                    state <= waitBrstSent;

                    if devBrstSnd = '0' then
                        rdAcqSig <= '1';

                        state    <= readFifo;
                    elsif emptyAcq = '1' then
                        devBrstRst <= '1';

                        state      <= errFifoEmpty;
                    end if;

                when acqEnd =>
                    busy      <= '0';
                    rstAcqSig <= '0';
                    devReady  <= '0';

                    state     <= idle;                    

                    if emptyAcq = '1' then
                        rstAcqSig <= '1';
                    end if;

                when errAddr =>
                    writeReg(reg, rData, addr'pos(regStatus), errAddrStatus);
                    busy  <= '0';

                    state <= idle;

                when errReadOnly =>
                    writeReg(reg, rData, addr'pos(regStatus), errROnlyStatus);
                    busy  <= '0';

                    state <= idle;

                when errFifoEmpty =>
                    writeReg(reg, rData, addr'pos(regStatus), errFifoEmptyStatus);
                    devBrstRst <= '0';
                    busy       <= '0';

                    state      <= idle;                    

                when others =>
                    devReady <= '0';
                    busy     <= '0';

                    state    <= idle;
            end case;
        end if;
    end if;
end process;

end Behavioral;