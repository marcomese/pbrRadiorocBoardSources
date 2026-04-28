----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: rateMetersCtrl
-- Create Date: 22.12.2025 17:15:46
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

library UNISIM;
use UNISIM.vcomponents.all;

library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity rateMetersCtrl is
generic(
    trgNum     : natural
);
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    trgIn      : in  std_logic_vector(trgNum-1 downto 0);
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
    busy       : out std_logic
);
end rateMetersCtrl;

architecture Behavioral of rateMetersCtrl is

--------------------- registers definitions ------------------------

type addr is (regStatus,
              regTmrBase);

constant addrNum  : natural := addr'pos(addr'right)+1;

constant regModes : regModeRec_t(0 to trgNum+addrNum-1) := (0      => ro,  -- regStatus
                                                            1      => rw,  -- regTmrBase
                                                            others => ro); -- counters

constant reg      : regsRec_t := initRegs(regModes);

constant regsNum  : integer := reg(reg'high).rAddr+1;

signal   rData    : regsData_t(regsNum-1 downto 0);

--------------------------------------------------------------------

type state_t is (idle,
                 execute,
                 errAddr,
                 errReadOnly);

type rateMeters_t is array(0 to trgNum-1) of unsigned(31 downto 0);

constant idleStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant errAddrStatus  : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');

signal state       : state_t;

signal lastData    : devData_t;

signal dAddr,
       lastAddr,
       pipeAddr      : integer;

signal trgMeters,
       trgMetersSnap : rateMeters_t;

signal pipeData      : std_logic_vector(31 downto 0);

signal cntTmrMax     : unsigned(31 downto 0);

signal cntTmr        : unsigned(cntTmrMax'length downto 0); -- MSB = overflow

signal cntTmrSig,
       cntTmrSet,
       loadDataOut,
       loadReg,
       locRst,
       pipeEn,
       snapEn        : std_logic;

begin

dAddr     <= devAddrToInt(devAddr);

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

regPipeProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            pipeEn   <= '0';
            pipeAddr <= 0;
            pipeData <= (others => '0');
        else
            pipeEn   <= loadReg;
            pipeAddr <= lastAddr;
            pipeData <= devDataToSlv(lastData);
        end if;
    end if;
end process;

snapProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            snapEn        <= '0';
            trgMetersSnap <= (others => (others => '0'));
        else
            snapEn <= cntTmrSig;

            if cntTmrSig = '1' then
                trgMetersSnap <= trgMeters;
            end if;
        end if;
    end if;
end process;

rDataCtrl: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            rData <= (others => (others => '0'));
        elsif pipeEn = '1' then
            rData(pipeAddr) <= pipeData;
        elsif snapEn = '1' then
            for i in 0 to trgNum-1 loop
                rData(i+addrNum) <= std_logic_vector(trgMetersSnap(i));
            end loop;
        end if;
    end if;
end process;

rateMetersCtrlFSM: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            busy        <= '0';
            loadDataOut <= '0';
            loadReg     <= '0';
            devBrstRst  <= '0';
            cntTmrMax   <= (others => '0');
            cntTmrSet   <= '0';
            lastAddr    <= 0;
            lastData    <= (others => (others => '0'));

            state       <= idle;
        else
            case state is
                when idle =>
                    busy        <= '0';
                    loadReg     <= '0';
                    loadDataOut <= '0';
                    cntTmrSet   <= '0';

                    state       <= idle;

                    if devExec = '1' and devId = rateMeters then
                        if dAddr > trgNum+addrNum-1 then
                            state    <= errAddr;
                        elsif devRw = devRead and devBrst = '0' then
                            lastAddr    <= dAddr;
                            loadDataOut <= '1';
                            busy        <= '1';

                            state       <= idle;
                        elsif devRw = devWrite and reg(dAddr).rMode = ro then
                            state    <= errReadOnly;
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

                    state   <= idle;

                    if lastAddr = addr'pos(regTmrBase) then
                        cntTmrMax <= resize(unsigned(devDataToSlv(lastData)), cntTmrMax'length);
                        cntTmrSet <= '1';
                    end if;

                when errAddr =>
                    lastAddr <= addr'pos(regStatus);
                    lastData <= slvToDevData(errAddrStatus);
                    loadReg  <= '1';
                    busy     <= '0';

                    state    <= idle;

                when errReadOnly =>
                    lastAddr <= addr'pos(regStatus);
                    lastData <= slvToDevData(errROnlyStatus);
                    loadReg  <= '1';
                    busy     <= '0';

                    state    <= idle;

                when others =>
                    busy     <= '0';

                    state    <= idle;
            end case;
        end if;
    end if;
end process;

trgCntGen: for i in 0 to trgNum-1 generate
begin
    trgICnt: process(clk)
    begin
        if rising_edge(clk) then
            if locRst = '1' then
                trgMeters(i) <= (others => '0');
            elsif cntTmrSig = '1' then
                trgMeters(i) <= (others => '0');
            elsif trgIn(i) = '1' then
                trgMeters(i) <= trgMeters(i) + 1;
            end if;
        end if;
    end process;
end generate;

cntTmrSigProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            cntTmrSig <= '0';
        else
            cntTmrSig <= cntTmr(cntTmr'left);
        end if;
    end if;
end process;

cntTmrGen: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' or cntTmr(cntTmr'left) = '1' or cntTmrSet = '1' then
            cntTmr <= resize(cntTmrMax-2, cntTmr'length);
        else
            cntTmr <= cntTmr - 1;
        end if;
    end if;
end process;

end Behavioral;