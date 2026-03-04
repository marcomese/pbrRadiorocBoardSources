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
    nExtFF     : out std_logic_vector(bitsNum(extenderFF,1)-1 downto 0);
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
              regTrgExt);

constant addrNum  : natural := addr'pos(addr'right)+1;

constant regModes : regModeRec_t(0 to addrNum-1) := (0      => ro,  -- regStatus
                                                     1      => rw,  -- regTrgExt
                                                     others => ro);

constant reg      : regsRec_t := initRegs(regModes);

constant regsNum  : integer := reg(reg'high).rAddr+1;

--------------------------------------------------------------------

constant idleStatus     : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "00" & x"001", '0');
constant errAddrStatus  : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"500", '0');
constant errROnlyStatus : std_logic_vector(31 downto 0) := initSlv(32, 13, 0, "11" & x"A00", '0');

begin

end Behavioral;
