----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: trgLogicCtrl
-- Create Date: 02.03.2026 15:50:25
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
use work.pixelMappingPkg.all;

library UNISIM;
use UNISIM.VComponents.all;

entity trgLogicCtrl is
generic(
    t1Len      : integer;
    t2Len      : integer;
    extenderFF : integer
);
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    id         : in  std_logic_vector(2 downto 0);
    t1In       : in  std_logic_vector(t1Len-1 downto 0);
    t2In       : in  std_logic_vector(t2Len-1 downto 0);
    t1Sync     : out std_logic_vector(t1Len-1 downto 0);
    t1Edge     : out std_logic_vector(t1Len-1 downto 0);
    t2Sync     : out std_logic_vector(t2Len-1 downto 0);
    t2Edge     : out std_logic_vector(t2Len-1 downto 0);
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
end trgLogicCtrl;

architecture Behavioral of trgLogicCtrl is

--------------------- registers definitions ------------------------

type addr is (regStatus,
              regConf);

constant addrNum  : natural := addr'pos(addr'right)+1;

constant regModes : regModeRec_t(0 to addrNum-1) := (0      => ro,  -- regStatus
                                                     1      => rw,  -- regConf
                                                     others => ro);

constant reg      : regsRec_t := initRegs(regModes);

constant regsNum  : integer := reg(reg'high).rAddr+1;

--------------------------------------------------------------------

constant idleStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant errAddrStatus  : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');

signal   t1E        : std_logic_vector(t1Len-1 downto 0);
signal   t2E        : std_logic_vector(t2Len-1 downto 0);
signal   nExtFF     : std_logic_vector(bitsNum(extenderFF,1)-1 downto 0);
signal   pixDist    : std_logic_vector(7 downto 0);
signal   sampleNClk : std_logic_vector(7 downto 0);
signal   lastCol    : unsigned(7 downto 0);
signal   t1,
         v1,
         m1         : std_logic_vector(t1Len-1 downto 0);
signal   t1Pixels   : pixels_t;

begin

t1Edge   <= t1E;

t2Edge   <= t2E;

t1Pixels <= slvToPixels(t1E);

inTrg1Sync: entity work.trgSync
generic map(
    trgNum     => t1In'length,
    extenderFF => extenderFF
)
port map(
    clk    => clk,
    rst    => rst,
    tIn    => t1In,
    tOut   => t1Sync,
    tEdge  => t1E,
    nExtFF => nExtFF
);

inTrg2Sync: entity work.trgSync
generic map(
    trgNum     => t2In'length,
    extenderFF => extenderFF
)
port map(
    clk    => clk,
    rst    => rst,
    tIn    => t2In,
    tOut   => t2Sync,
    tEdge  => t2E,
    nExtFF => nExtFF
);

colsSigGen: for c in 0 to nCols-1 generate
begin
    rowsSigGen: for r in 0 to nRows-1 generate
    begin
        trgProc: process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    t1 <= (others => '0');
                    v1 <= (others => '0');
                    m1 <= (others => '0');
                elsif c <= lastCol then
                    t1(r,c) <= t1E(pixel(c,r)) and (t1E(pixel(c+2,r-1)) or
                                                    t1E(pixel(c+2,r))   or 
                                                    t1E(pixel(c+2,r+1)));
                    v1(r,c) <= t1E(pixel(c+1,r+1)) or 
                               t1E(pixel(c+1,r))   or 
                               t1E(pixel(c+1,r-1));
                    m1(r,c) <= t1(r,c) and not v1(r,c);
                end if;
            end if;
        end process;
    end generate;
end generate;

end Behavioral;
