----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: trgSamplerDSP
-- Create Date: 02.05.2026 22:35:50
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
--   Wrapper for using DSP48E1 as shift register to sample input triggers.
--   Configured for minimum latency (1 clock cycle): no multiplier, feedback
--   shifted via the C port (combinatorial), CARRYIN bypassed.
--
-- Revision:
-- Revision 0.01 - File Created
-- Revision 0.02 - Switched to no-multiplier configuration for 1-cycle latency
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity trgSamplerDSP is
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    trgIn      : in  std_logic;
    trgSmplOut : out std_logic_vector(31 downto 0)
);
end trgSamplerDSP;

architecture Behavioral of trgSamplerDSP is

signal trgShiftFdbk : std_logic_vector(47 downto 0);

signal trgShift     : std_logic_vector(47 downto 0);

begin

trgShiftFdbk <= trgShift(46 downto 0) & '0';

trgSmplOut   <= trgShift(31 downto 0);

dsp48e1TrgSampler: DSP48E1
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
    ACASCREG           => 0,
    ADREG              => 1,
    ALUMODEREG         => 1,
    AREG               => 0,
    BCASCREG           => 0,
    BREG               => 0,
    CARRYINREG         => 0,
    CARRYINSELREG      => 1,
    CREG               => 0,
    DREG               => 1,
    INMODEREG          => 1,
    MREG               => 0,
    OPMODEREG          => 1,
    PREG               => 1
)
port map(
    CLK            => clk,
    RSTP           => rst,
    RSTINMODE      => rst,
    RSTCTRL        => rst,
    RSTALUMODE     => rst,
    C              => trgShiftFdbk,
    CARRYIN        => trgIn,
    P              => trgShift,
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
    OPMODE         => "0110000",
    A              => (others => '0'),
    B              => (others => '0'),
    D              => (others => '0'),
    RSTA           => '0',
    RSTALLCARRYIN  => '0',
    RSTB           => '0',
    RSTC           => '0',
    RSTD           => '0',
    RSTM           => '0',
    CEA1           => '0',
    CEA2           => '0',
    CEAD           => '0',
    CEALUMODE      => '1',
    CEB1           => '0',
    CEB2           => '0',
    CEC            => '0',
    CECARRYIN      => '0',
    CECTRL         => '1',
    CED            => '0',
    CEINMODE       => '1',
    CEM            => '0',
    CEP            => '1'
);

end Behavioral;