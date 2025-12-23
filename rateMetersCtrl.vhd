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

entity rateMetersCtrl is
generic(
    trgNum     : natural
);
port(
    clk        : in  std_logic;
    clkTmr     : in  std_logic;
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

constant regModes : regModeRec_t(0 to trgNum+1) := (0      => ro,  -- regStatus
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

signal state     : state_t;

signal dataIn    : devData_t;

signal dAddr     : integer;

signal trgMeters : rateMeters_t;

signal cntTmrMax : unsigned(31 downto 0);

signal cntTmr    : unsigned(cntTmrMax'length downto 0); -- MSB = overflow

signal cntTmrSig,
       cntTmrSet : std_logic;

signal t         : std_logic_vector(63 downto 0);

begin

dAddr     <= devAddrToInt(devAddr);

cntTmrSig <= cntTmr(cntTmr'left);

trgEdgeGen: for i in 0 to trgNum-1 generate
begin
    trgEdgeInst: entity work.edgeDetector
    generic map(
        clockEdge => "rising",
        edge      => "falling"
    )
    port map(
        clk       => clk,
        rst       => rst,
        signalIn  => trgIn(i),
        signalOut => t(i)
    );
end generate;

rateMetersCtrlFSM: process(clk, rst, devExec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            devReady   <= '0';
            busy       <= '0';
            devDataOut <= (others => (others => '0'));
            devBrstRst <= '0';
            cntTmrMax  <= (others => '0');
            cntTmrSet  <= '0';
            rData      <= (others => (others => '0'));

            state      <= idle;
        else

            trgMtrsToRDataLoop: for i in 0 to trgNum-1 loop
                if cntTmrSig = '1' then
                    rData(i+2) <= std_logic_vector(trgMeters(i));
                end if;
            end loop;

            case state is
                when idle =>
                    devReady   <= '0';
                    busy       <= '0';
                    cntTmrSet  <= '0';

                    state      <= idle;

                    if devExec = '1' and devId = rateMeters then
                        if dAddr > addr'pos(addr'high)+trgNum then
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
                        cntTmrMax <= readReg(reg, rData, addr'pos(regTmrBase));
                        cntTmrSet <= '1';
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

trgCntGen: for i in 0 to trgNum-1 generate
begin
    trgICnt: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                trgMeters(i) <= (others => '0');
            elsif cntTmrSig = '1' then
                trgMeters(i) <= (others => '0');
            elsif t(i) = '1' then
                trgMeters(i) <= trgMeters(i) + 1;
            end if;
        end if;
    end process;
end generate;

cntTmrGen: process(clkTmr, rst)
begin
    if rising_edge(clkTmr) then
        if rst = '1' or cntTmrSig = '1' or cntTmrSet = '1' then
            cntTmr <= resize(cntTmrMax-2, cntTmr'length);
        else
            cntTmr <= cntTmr - 1;
        end if;
    end if;
end process;

end Behavioral;
