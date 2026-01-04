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
    clkTmr     : in  std_logic;
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
              regTmrBase,
              regSAfterTrg);

constant addrNum    : natural := addr'pos(addr'right)+1;

constant regModes   : regModeRec_t(0 to trgNum+addrNum-1) := (0      => ro,  -- regStatus
                                                              1      => rw,  -- regTmrBase
                                                              2      => rw,  -- regSAfterTrg
                                                              others => ro); -- sampled channels

constant regBorders : rBorders_t(0 to trgNum+addrNum-1) := (0      => (rAddr => 0,         rBegin => 31, rEnd =>  0),
                                                            1      => (rAddr => 1,         rBegin => 31, rEnd => 16),
                                                            2      => (rAddr => 1,         rBegin => 15, rEnd =>  0),
                                                            others => (rAddr => AUTO_ADDR, rBegin => 31, rEnd =>  0));

constant reg        : regsRec_t := initRegs(regModes, regBorders);

constant regsNum    : integer := reg(reg'high).rAddr+1;

signal   rData      : regsData_t(regsNum-1 downto 0);

--------------------------------------------------------------------

type state_t is (idle,
                 execute,
                 errAddr,
                 errReadOnly);

type sampledTrg_t is array(0 to trgNum-1) of std_logic_vector(31 downto 0);

constant idleStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant errAddrStatus  : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');

signal state           : state_t;

signal dataIn          : devData_t;

signal dAddr           : integer;

signal sampledTrg      : sampledTrg_t;

signal cntTmrMax,
       nSAfterTrgMax   : unsigned(15 downto 0);

signal cntTmr          : unsigned(cntTmrMax'length downto 0); -- MSB = overflow

signal cntNSAfterTrg   : unsigned(nSAfterTrgMax'length downto 0); -- MSB = overflow

signal cntTmrSig,
       cntTmrSet,
       cntNSAftTrgSig,
       cntNSAftTrgSet,
       cntNSAftTrgEn   : std_logic;

begin

dAddr          <= devAddrToInt(devAddr);

cntTmrSig      <= cntTmr(cntTmr'left);

cntNSAftTrgSig <= cntNSAfterTrg(cntNSAfterTrg'left);

trgSamplerCtrlFSM: process(clk, rst, devExec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            devReady       <= '0';
            busy           <= '0';
            devDataOut     <= (others => (others => '0'));
            devBrstRst     <= '0';
            cntTmrMax      <= (others => '0');
            cntTmrSet      <= '0';
            nSAfterTrgMax  <= to_unsigned(nSAfterTrgDef, nSAfterTrgMax'length);
            cntNSAftTrgSet <= '0';
            rData          <= (1 => initSlv(32, 15, 0, std_logic_vector(nSAfterTrgMax), '0'),
                               others => (others => '0'));

            state          <= idle;
        else

            trgMtrsToRDataLoop: for i in 0 to trgNum-1 loop
                if cntNSAftTrgSig = '1' then
                    writeReg(reg, rData, i+addrNum, sampledTrg(i));
                end if;
            end loop;

            case state is
                when idle =>
                    devReady       <= '0';
                    busy           <= '0';
                    cntTmrSet      <= '0';
                    cntNSAftTrgSet <= '0';

                    state          <= idle;

                    if devExec = '1' and devId = trgSampler then
                        if dAddr > trgNum+addrNum-1 then
                            state    <= errAddr;
                        elsif devRw = devRead and devBrst = '0' then
                            writeReg(reg, rData, addr'pos(regStatus), idleStatus);
                            devReady   <= '1';
                            devDataOut <= readReg(reg, rData, dAddr);
                            busy       <= '1';

                            state      <= idle;
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

                    if readReg(reg, rData, addr'pos(regStatus)) = addrToSlv(addr'pos(regTmrBase)) then
                        cntTmrMax <= resize(readReg(reg, rData, addr'pos(regTmrBase)), cntTmrMax'length);
                        cntTmrSet <= '1';
                    elsif readReg(reg, rData, addr'pos(regStatus)) = addrToSlv(addr'pos(regSAfterTrg)) then
                        nSAfterTrgMax  <= resize(readReg(reg, rData, addr'pos(regSAfterTrg)), nsAfterTrgMax'length);
                        cntNSAftTrgSet <= '1';
                    end if;

                when errAddr =>
                    writeReg(reg, rData, addr'pos(regStatus), errAddrStatus);
                    busy  <= '0';

                    state <= idle;

                when errReadOnly =>
                    writeReg(reg, rData, addr'pos(regStatus), errROnlyStatus);
                    busy  <= '0';

                    state <= idle;

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
    trgICnt: process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sampledTrg(i) <= (others => '0');
            elsif cntTmrSig = '1' then
                sampledTrg(i) <= sampledTrg(i)(sampledTrg(i)'left-1 downto 0) & trgIn(i);
            end if;
        end if;
    end process;
end generate;

nSAfterTrgProc: process(clkTmr, rst)
variable reloadVal : unsigned(cntTmr'range);
begin
    if rising_edge(clkTmr) then
        if nSAfterTrgMax < 2 then
            reloadVal := (others => '0');
        else
            reloadVal := resize(nSAfterTrgMax-2, cntNSAfterTrg'length);
        end if;

        if rst = '1' or cntNSAftTrgSig = '1' or cntNSAftTrgSet = '1' then
            cntNSAfterTrg <= reloadVal;
            cntNSAftTrgEn <= '0';
        elsif evtTrigger = '1' then
            cntNSAftTrgEn <= '1';
        elsif cntNSAftTrgEn = '1' and cntTmrSig = '1' then
            cntNSAfterTrg <= cntNSAfterTrg - 1;
        end if;
    end if;
end process;

cntTmrGen: process(clkTmr, rst)
variable reloadVal : unsigned(cntTmr'range);
begin
    if rising_edge(clkTmr) then
        if cntTmrMax < 2 then
            reloadVal := (others => '1'); -- cntTmrSig always at '1'
        else
            reloadVal := resize(cntTmrMax - 2, cntTmr'length);
        end if;

        if rst = '1' or cntTmrSig = '1' or cntTmrSet = '1' then
            cntTmr <= reloadVal;
        elsif cntTmrMax >= 2 then
            cntTmr <= cntTmr - 1;
        end if;
    end if;
end process;

end Behavioral;
