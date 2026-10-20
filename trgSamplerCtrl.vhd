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
-- Revision 0.02 - rData holds only the config/status registers; samples are
--                 read directly from sampledTrgSnap through a 2-stage
--                 registered mux (devReady one clock later than before);
--                 no reset on the snapshot array; cntNSAftTrgSig fanout limited
-- Revision 0.03 - extra read stage: rdIdx copied in one register per group
--                 (placed close to the group's snapshot), devReady one
--                 more clock later
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

signal   rData      : regsData_t(addrNum-1 downto 0); -- config/status only

constant grpSize    : natural := 16;                         -- first mux stage width
constant grpNum     : natural := (trgNum+grpSize-1)/grpSize; -- second mux stage width
constant idxBits    : natural := bitsNum(grpNum*grpSize-1);

--------------------------------------------------------------------

type state_t is (idle,
                 execute,
                 errAddr,
                 errReadOnly);

type sampledTrg_t is array(0 to trgNum-1) of std_logic_vector(31 downto 0);

type grpData_t is array(0 to grpNum-1) of std_logic_vector(31 downto 0);

type grpIdx_t is array(0 to grpNum-1) of unsigned(3 downto 0);

constant idleStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant errAddrStatus  : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');

signal state           : state_t;

signal lastData        : devData_t;

signal dataIn          : devData_t;

signal dAddr           : integer;

signal lastAddr        : integer range 0 to trgNum+addrNum-1;

signal pipeAddr        : integer range 0 to addrNum-1;

signal sampledTrg      : sampledTrg_t;

signal sampledTrgSnap  : sampledTrg_t := (others => (others => '0'));

signal rdIdx           : unsigned(idxBits-1 downto 0);

signal rdHiSel         : integer range 0 to grpNum-1;

signal rdGrpData       : grpData_t;

signal rdCfgData       : std_logic_vector(31 downto 0);

signal rdIsCfg,
       rdIsCfg0,
       rdIsCfgPipe,
       rdPipeEn0,
       rdPipeEn        : std_logic;

signal rdIdxGrp        : grpIdx_t;

signal rdHiSel0        : integer range 0 to grpNum-1;

signal pipeData        : std_logic_vector(31 downto 0);

signal nSAfterTrgMax   : unsigned(15 downto 0);

signal cntNSAfterTrg   : unsigned(nSAfterTrgMax'length downto 0); -- MSB = overflow

signal cntNSAftTrgSig,
       cntNSAftTrgSet,
       cntNSAftTrgEn,
       loadDataOut,
       loadReg,
       locRst,
       pipeEn          : std_logic;

attribute max_fanout : integer;

attribute keep : string;

attribute keep of rdIdxGrp : signal is "true"; -- one copy per group, do not merge

attribute max_fanout of cntNSAftTrgSig : signal is 64;

begin

dAddr          <= devAddrToInt(devAddr);

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
        elsif rdPipeEn = '1' then
            devReady <= '1';

            if rdIsCfgPipe = '1' then
                devDataOut <= slvToDevData(rdCfgData);
            else
                devDataOut <= slvToDevData(rdGrpData(rdHiSel));
            end if;
        else
            devReady <= '0';
        end if;
    end if;
end process;

-- stage 0: copy of the read index for every group (short routes to the
-- group muxes); config registers selected here
rdStage0Proc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            rdPipeEn0 <= '0';
            rdIsCfg0  <= '0';
            rdHiSel0  <= 0;
            rdIdxGrp  <= (others => (others => '0'));
            rdCfgData <= (others => '0');
        else
            rdPipeEn0 <= loadDataOut;
            rdIsCfg0  <= rdIsCfg;
            rdHiSel0  <= to_integer(rdIdx(idxBits-1 downto 4));
            rdIdxGrp  <= (others => rdIdx(3 downto 0));

            if lastAddr < addrNum then
                rdCfgData <= rData(lastAddr);
            end if;
        end if;
    end if;
end process;

rdStage1Proc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            rdPipeEn    <= '0';
            rdIsCfgPipe <= '0';
            rdHiSel     <= 0;
        else
            rdPipeEn    <= rdPipeEn0;
            rdIsCfgPipe <= rdIsCfg0;
            rdHiSel     <= rdHiSel0;
        end if;
    end if;
end process;

-- first read stage: 16:1 mux inside each group of channels (the snapshot is
-- stable until the next event, so the extra clock does not affect coherency)
rdGrpGen: for g in 0 to grpNum-1 generate
begin
    rdGrpProc: process(clk)
        variable cIdx : integer;
    begin
        if rising_edge(clk) then
            cIdx := g*grpSize + to_integer(rdIdxGrp(g));

            if cIdx < trgNum then
                rdGrpData(g) <= sampledTrgSnap(cIdx);
            else
                rdGrpData(g) <= (others => '0');
            end if;
        end if;
    end process;
end generate;

regPipeProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            pipeEn   <= '0';
            pipeAddr <= 0;
            pipeData <= (others => '0');
        else
            pipeEn   <= loadReg;
            pipeData <= devDataToSlv(lastData);

            if loadReg = '1' then
                pipeAddr <= lastAddr; -- only status/config addresses get here
            end if;
        end if;
    end if;
end process;

snapProc: process(clk)
begin
    if rising_edge(clk) then
        if cntNSAftTrgSig = '1' then
            sampledTrgSnap <= sampledTrg;
        end if;
    end if;
end process;

rDataCtrl: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            rData <= (1 => initSlv(32, 15, 0, std_logic_vector(nSAfterTrgMax), '0'),
                      others => (others => '0'));
        elsif pipeEn = '1' then
            rData(pipeAddr) <= pipeData;
        end if;
    end if;
end process;

trgSamplerCtrlFSM: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            busy           <= '0';
            loadReg        <= '0';
            loadDataOut    <= '0';
            devBrstRst     <= '0';
            nSAfterTrgMax  <= to_unsigned(nSAfterTrgDef-2, nSAfterTrgMax'length);
            cntNSAftTrgSet <= '0';
            lastAddr       <= 0;
            rdIdx          <= (others => '0');
            rdIsCfg        <= '1';
            lastData       <= (others => (others => '0'));

            state          <= idle;
        else
            case state is
                when idle =>
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
                            busy        <= '1';

                            if dAddr < addrNum then
                                rdIsCfg <= '1';
                                rdIdx   <= (others => '0');
                            else
                                rdIsCfg <= '0';
                                rdIdx   <= to_unsigned(dAddr-addrNum, idxBits);
                            end if;

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
                    busy     <= '0';

                    state    <= idle;
            end case;
        end if;
    end if;
end process;

trgSmplGen: for i in 0 to trgNum-1 generate
begin
    trgSmplInst: entity work.trgSamplerDSP
    port map(
        clk        => clk,
        rst        => locRst,
        trgIn      => trgIn(i),
        trgSmplOut => sampledTrg(i)
    );
--    trgICnt: process(clk)
--    begin
--        if rising_edge(clk) then
--            if locRst = '1' then
--                sampledTrg(i) <= (others => '0');
--            else
--                sampledTrg(i) <= sampledTrg(i)(sampledTrg(i)'left-1 downto 0) & trgIn(i);
--            end if;
--        end if;
--    end process;
end generate;

cntNSAftTrgProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            cntNSAftTrgSig <= '0';
        else
            cntNSAftTrgSig <= cntNSAfterTrg(cntNSAfterTrg'left);
        end if;
    end if;
end process;

nSAfterTrgProc: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            cntNSAfterTrg <= to_unsigned(nSAfterTrgDef-2, cntNSAfterTrg'length);
            cntNSAftTrgEn <= '0';
        elsif cntNSAfterTrg(cntNSAfterTrg'left) = '1' or cntNSAftTrgSet = '1' then
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
