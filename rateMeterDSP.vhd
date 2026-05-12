----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: rateMeterDSP
-- Create Date: 02.05.2026 18:37:53
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
--
--   Wrapper for using DSP48E1 as rate meters
--
--
-- Revision:
-- Revision 0.01 - File Created
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity rateMeterDSP is
port(
    clk      : in  std_logic;
    rst      : in  std_logic;
    trgIn    : in  std_logic;
    clrIn    : in  std_logic;
    rateOut  : out std_logic_vector(31 downto 0);
    overflow : out std_logic
);
end rateMeterDSP;

architecture Behavioral of rateMeterDSP is

signal locRst : std_logic;

signal P      : std_logic_vector(47 downto 0);

begin

locRstProc: process(clk)
begin
    if rising_edge(clk) then
        locRst <= rst or clrIn;
    end if;
end process;

overflow <= or_reduce(P(P'left downto 32));

rateOut  <= P(31 downto 0);

dps48e1RateMeter: DSP48E1
generic map(
    A_INPUT            => "DIRECT",
    B_INPUT            => "DIRECT",
    USE_DPORT          => FALSE,
    USE_MULT           => "NONE",
    USE_SIMD           => "ONE48",
    AUTORESET_PATDET   => "NO_RESET",
    MASK               => X"3fffffffffff",
    PATTERN            => X"000000000000",
    SEL_MASK           => "MASK",
    SEL_PATTERN        => "PATTERN",
    USE_PATTERN_DETECT => "NO_PATDET",
    ACASCREG           => 1,
    ADREG              => 1,
    ALUMODEREG         => 1,
    AREG               => 1,
    BCASCREG           => 1,
    BREG               => 1,
    CARRYINREG         => 0,
    CARRYINSELREG      => 1,
    CREG               => 1,
    DREG               => 1,
    INMODEREG          => 1,
    MREG               => 0,
    OPMODEREG          => 1,
    PREG               => 1
)
port map(
    CLK            => clk,
    RSTP           => locRst,
    P              => P,
    CARRYIN        => trgIn,
    ACOUT          => open,
    BCOUT          => open,
    CARRYCASCOUT   => open,
    MULTSIGNOUT    => open,
    PCOUT          => open,
    OVERFLOW       => open,
    PATTERNBDETECT => open,
    PATTERNDETECT  => open,
    UNDERFLOW      => open,
    CARRYOUT       => open,
    ACIN           => (others => '0'),
    BCIN           => (others => '0'),
    CARRYCASCIN    => '0',
    MULTSIGNIN     => '0',
    PCIN           => (others => '0'),
    ALUMODE        => "0000",
    CARRYINSEL     => "000",
    INMODE         => "00000",
    OPMODE         => "0100000",
    A              => (others => '0'),
    B              => (others => '0'),
    C              => (others => '0'),
    D              => (others => '0'),
    CEA1           => '0',
    CEA2           => '0',
    CEAD           => '0',
    CEALUMODE      => '1',
    CEB1           => '0',
    CEB2           => '0',
    CEC            => '0',
    CECARRYIN      => '1',
    CECTRL         => '1',
    CED            => '0',
    CEINMODE       => '1',
    CEM            => '0',
    CEP            => '1',
    RSTA           => '0',
    RSTALLCARRYIN  => '0',
    RSTALUMODE     => '0',
    RSTB           => '0',
    RSTC           => '0',
    RSTCTRL        => '0',
    RSTD           => '0',
    RSTINMODE      => '0',
    RSTM           => '0'
);

end Behavioral;