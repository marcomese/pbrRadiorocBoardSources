library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xpm;
use xpm.vcomponents.all;

entity tb_xpmCdcPulse is
end tb_xpmCdcPulse;

architecture Behavioral of tb_xpmCdcPulse is

constant clkPeriod25M  : time := 40 ns;
constant clkPeriod100M : time := 10 ns;
constant w             : natural := 4;

signal dest_pulse      : std_logic := '0';
signal dest_clk        : std_logic := '1';
signal dest_rst        : std_logic := '1';
signal src_clk         : std_logic := '1';
signal src_pulse       : std_logic := '0';
signal src_rst         : std_logic := '1';

begin

stimProc: process
begin
    wait for clkPeriod25M*5;
    src_rst  <= '0';
    dest_rst <= '0';

    wait for clkPeriod100M*5;

    src_pulse <= '1', '0' after clkPeriod100M*2;

    wait;
end process;

src_clk  <= not src_clk  after clkPeriod100M/2;

dest_clk <= not dest_clk after clkPeriod25M/2;

xpm_cdc_pulse_inst : xpm_cdc_pulse
generic map (
    DEST_SYNC_FF => 2,
    INIT_SYNC_FF => 0,
    REG_OUTPUT   => 0,
    RST_USED     => 1
)
port map (
    dest_pulse => dest_pulse,
    dest_clk   => dest_clk,
    dest_rst   => dest_rst,
    src_clk    => src_clk,
    src_pulse  => src_pulse,
    src_rst    => src_rst
);

end Behavioral;