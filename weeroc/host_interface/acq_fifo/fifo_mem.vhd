-------------------------------------------------------------------------------
-- Title      : Simple duart-port memory for FIFO
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fifo_mem.vhd
-- Author     : Nicolas Matringe  <nmatringe@alciom.com>
-- Company    : Alciom
-- Created    : 2020-06-09
-- Last update: 2020-08-04
-- Platform   : 
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2020 Alciom
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-06-09  1.0      DELL PRECISION T7500    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_mem is
  generic (
    G_AW : natural := 14;
    G_DW : natural := 32);
  port (
    waddr : in  std_logic_vector(G_AW-1 downto 0);
    wr    : in  std_logic;
    raddr : in  std_logic_vector(G_AW-1 downto 0);
    din   : in  std_logic_vector(G_DW-1 downto 0);
    dout  : out std_logic_vector(G_DW-1 downto 0);
    clk   : in  std_logic;
    rst   : in  std_logic);
end entity fifo_mem;

architecture rtl of fifo_mem is

begin  -- architecture rtl

  p : process (clk, rst) is
    type t_mem is array (natural range <>) of std_logic_vector(G_DW-1 downto 0);
    variable v_mem : t_mem(0 to 2**G_AW-1);
  begin  -- process p
    if rst = '1' then                   -- asynchronous reset (active high)
--      v_mem := (others => (others => '0'));
      dout  <= (others => '0');
    elsif rising_edge(clk) then         -- rising clock edge
      dout <= v_mem(to_integer(unsigned(raddr)));
      if wr = '1' then
        v_mem(to_integer(unsigned(waddr))) := din;
      end if;
    end if;
  end process p;

end architecture rtl;
