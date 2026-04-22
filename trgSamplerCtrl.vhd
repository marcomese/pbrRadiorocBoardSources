----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: trgSamplerCtrl
-- Create Date: 01.01.2026 11:50:30
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

entity trgSamplerCtrl is
generic(
    trgNum        : natural;
    nSAfterTrgDef : integer
);
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    evtTrigger : in  std_logic;
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
end trgSamplerCtrl;

architecture Behavioral of trgSamplerCtrl is

--------------------- registers definitions ------------------------

type addr is (regStatus,
              regSAfterTrg);

constant addrNum    : natural := addr'pos(addr'right)+1;

constant regModes   : regModeRec_t(0 to trgNum+addrNum-1) := (0      => ro,  -- regStatus
                                                              1      => rw,  -- regSAfterTrg
                                                              others => ro); -- sampled channels

constant regBorders : rBorders_t(0 to trgNum+addrNum-1) := (0      => (rAddr => 0,         rBegin => 31, rEnd =>  0),
                                                            1      => (rAddr => 1,         rBegin => 31, rEnd =>  0),
                                                            others => (rAddr => AUTO_ADDR, rBegin => 31, rEnd =>  0));

constant reg        : regsRec_t := initRegs(regModes, regBorders);

constant regsNum    : integer := reg(reg'high).rAddr+1;

signal   rData      : regsData_t(regsNum-1 downto 0);

--------------------------------------------------------------------

type state_t is (init,
                 idle,
                 execute,
                 errAddr,
                 errReadOnly);

type sampledTrg_t is array(0 to trgNum-1) of std_logic_vector(31 downto 0);

constant idleStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant errAddrStatus  : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');

signal state           : state_t;

signal lastData        : devData_t;

signal dataIn          : devData_t;

signal dAddr,
       lastAddr        : integer range 0 to trgNum+addrNum-1;

signal sampledTrg      : sampledTrg_t;

signal nSAfterTrgMax   : unsigned(15 downto 0);

signal cntNSAfterTrg   : unsigned(nSAfterTrgMax'length downto 0); -- MSB = overflow

signal cntNSAftTrgSig,
       cntNSAftTrgSet,
       cntNSAftTrgEn,
       loadDataOut,
       loadReg,
       locRst          : std_logic;

begin

dAddr          <= devAddrToInt(devAddr);

cntNSAftTrgSig <= cntNSAfterTrg(cntNSAfterTrg'left);

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
            devDataOut <= (others => (others => '0'));
        elsif loadDataOut = '1' then
            devDataOut <= slvToDevData(rData(lastAddr));
        end if;
    end if;
end process;

rDataCtrl: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            rData <= (1 => initSlv(32, 15, 0, std_logic_vector(nSAfterTrgMax), '0'),
                      others => (others => '0'));
        elsif loadReg = '1' then
            rData(lastAddr) <= devDataToSlv(lastData);
        elsif cntNSAftTrgSig = '1' then
            trgMtrsToRDataLoop: for i in 0 to trgNum-1 loop
                rData(i+addrNum) <= sampledTrg(i);
            end loop;
        end if;
    end if;
end process;

trgSamplerCtrlFSM: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            devReady       <= '0';
            busy           <= '0';
            loadReg        <= '0';
            loadDataOut    <= '0';
            devBrstRst     <= '0';
            nSAfterTrgMax  <= to_unsigned(nSAfterTrgDef-2, nSAfterTrgMax'length);
            cntNSAftTrgSet <= '0';
            lastAddr       <= 0;
            lastData       <= (others => (others => '0'));

            state          <= init;
        else
            case state is
                when idle =>
                    devReady       <= '0';
                    busy           <= '0';
                    loadReg        <= '0';
                    loadDataOut    <= '0';
                    cntNSAftTrgSet <= '0';

                    state          <= idle;

                    if devExec = '1' and devId = trgSampler then
                        if dAddr > trgNum+addrNum-1 then
                            state    <= errAddr;
                        elsif devRw = devRead and devBrst = '0' then
                            lastAddr    <= dAddr;
                            loadDataOut <= '1';
                            devReady    <= '1';
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
                    state <= idle;

                    if lastAddr = addr'pos(regSAfterTrg) then
                        nSAfterTrgMax  <= resize(unsigned(devDataToSlv(lastData)), nsAfterTrgMax'length);
                        cntNSAftTrgSet <= '1';
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
                    devReady <= '0';
                    busy     <= '0';

                    state    <= idle;
            end case;
        end if;
    end if;
end process;

trgSmplGen: for i in 0 to trgNum-1 generate
begin
    trgICnt: process(clk)
    begin
        if rising_edge(clk) then
            if locRst = '1' then
                sampledTrg(i) <= (others => '0');
            else
                sampledTrg(i) <= sampledTrg(i)(sampledTrg(i)'left-1 downto 0) & trgIn(i);
            end if;
        end if;
    end process;
end generate;

nSAfterTrgProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            cntNSAfterTrg <= to_unsigned(nSAfterTrgDef-2, cntNSAfterTrg'length);
            cntNSAftTrgEn <= '0';
        elsif cntNSAftTrgSig = '1' or cntNSAftTrgSet = '1' then
            cntNSAfterTrg <=  resize(nSAfterTrgMax-2, cntNSAfterTrg'length);
            cntNSAftTrgEn <= '0';
        elsif evtTrigger = '1' and cntNSAftTrgEn = '0' then
            cntNSAftTrgEn <= '1';
        elsif cntNSAftTrgEn = '1' then
            cntNSAfterTrg <= cntNSAfterTrg - 1;
        end if;
    end if;
end process;

end Behavioral;
