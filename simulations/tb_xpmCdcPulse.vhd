library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xpm;
use xpm.vcomponents.all;

entity tb_xpmCdcPulse is
end tb_xpmCdcPulse;

architecture Behavioral of tb_xpmCdcPulse is

component trgSync is
generic(
    trgNum : natural
);
port(
    clk   : in  std_logic;
    rst   : in  std_logic;
    tIn   : in  std_logic_vector(trgNum-1 downto 0);
    tOut  : out std_logic_vector(trgNum-1 downto 0);
    tEdge : out std_logic_vector(trgNum-1 downto 0)
);
end component;

constant clkPeriod25M  : time := 40 ns;
constant clkPeriod100M : time := 10 ns;
constant trgNum        : natural := 1;

signal dest_pulse      : std_logic := '0';
signal dest_clk        : std_logic := '1';
signal dest_rst        : std_logic := '1';
signal src_clk         : std_logic := '1';
signal src_pulse       : std_logic := '1';
signal src_rst         : std_logic := '1';

signal tIn             : std_logic_vector(trgNum-1 downto 0);
signal tOut            : std_logic_vector(trgNum-1 downto 0);
signal tEdge           : std_logic_vector(trgNum-1 downto 0);

begin

stimProc: process
begin
    wait for clkPeriod25M*5;
    src_rst  <= '0';
    dest_rst <= '0';

    wait for clkPeriod100M*4;

    src_pulse <= '0';

    wait for clkPeriod100M*6;

    src_pulse <= '1', '0' after clkPeriod100M*4;

    wait;
end process;

src_clk  <= not src_clk  after clkPeriod100M/2;

dest_clk <= not dest_clk after clkPeriod25M/2;

xpm_cdc_single_inst : xpm_cdc_single
generic map (
  DEST_SYNC_FF   => 2,
  INIT_SYNC_FF   => 1,
  SIM_ASSERT_CHK => 1,
  SRC_INPUT_REG  => 0
)
port map (
  dest_out => dest_pulse,
  dest_clk => src_clk,
  src_clk  => '0',
  src_in   => src_pulse
);

tIn(0) <= src_pulse;

trgSyncInst: trgSync
generic map(
    trgNum => trgNum
)
port map(
    clk   => src_clk,
    rst   => src_rst,
    tIn   => tIn,
    tOut  => tOut,
    tEdge => tEdge
);

--xpm_cdc_pulse_inst : xpm_cdc_pulse
--generic map (
--    DEST_SYNC_FF => 2,
--    INIT_SYNC_FF => 0,
--    REG_OUTPUT   => 0,
--    RST_USED     => 1
--)
--port map (
--    dest_pulse => dest_pulse,
--    dest_clk   => dest_clk,
--    dest_rst   => dest_rst,
--    src_clk    => src_clk,
--    src_pulse  => src_pulse,
--    src_rst    => src_rst
--);

end Behavioral;