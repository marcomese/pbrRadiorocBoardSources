-------------------------------------------------------------------------------
-- Title      : FIFO
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fifo.vhd
-- Author     : Nicolas Matringe  <nmatringe@alciom.com>
-- Company    : Alciom
-- Created    : 2020-06-09
-- Last update: 2020-08-12
-- Platform   : 
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2020 Alciom
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-06-09  1.0      DELL PRECISION T7500	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity fifo is
  generic (
    G_AW  : natural := 16;
    G_DWW : natural := 32;
    G_DWR : natural := 8;
    G_THD : natural := 266);
  port (
    wdata   : in  std_logic_vector(G_DWW-1 downto 0);
    wr      : in  std_logic;
    rdata   : out std_logic_vector(G_DWR-1 downto 0);
    rd      : in  std_logic;
    count   : out std_logic_vector(15 downto 0);
    empty   : out std_logic;
    thd     : out std_logic;
    full    : out std_logic;
    overrun : out std_logic;
    clr     : in  std_logic;
    clk     : in  std_logic;
    rst     : in  std_logic);
end entity fifo;

architecture str of fifo is
  signal waddr : std_logic_vector(G_AW-3 downto 0);   -- [out] --4
  signal raddr : std_logic_vector(G_AW-3 downto 0);   -- [out] --4
  signal dout  : std_logic_vector(G_DWW-1 downto 0);  -- [in]
  signal q     : std_logic_vector(31 downto 0);

begin  -- architecture str

  fifo_logic_inst_1: entity work.fifo_logic
    generic map (
      G_AW  => G_AW,                    -- [natural]
      G_DWW => G_DWW,                   -- [natural]
      G_DWR => G_DWR,                   -- [natural]
      G_THD => G_THD)                   -- [natural]
    port map (
      waddr   => waddr,    -- [out std_logic_vector(G_AW-3 downto 0)]
      wr      => wr,                    -- [in  std_logic]
      raddr   => raddr,    -- [out std_logic_vector(G_AW-3 downto 0)]
      dout    => dout,     -- [in  std_logic_vector(G_DWW-1 downto 0)]
      rdata   => rdata,    -- [out std_logic_vector(G_DWR-1 downto 0)]
      rd      => rd,                    -- [in  std_logic]
      count   => count,                 -- [out std_logic_vector(15 downto 0)]
      empty   => empty,                 -- [out std_logic]
      thd     => thd,                   -- [out std_logic]
      full    => full,                  -- [out std_logic]
      overrun => overrun,               -- [out std_logic]
      clr     => clr,                   -- [in  std_logic]
      clk     => clk,                   -- [in  std_logic]
      rst     => rst);                  -- [in  std_logic]

  fifo_mem_inst_1: entity work.fifo_mem
    generic map (
      G_AW => G_AW-2,    --3               -- [natural]
      G_DW => G_DWW)                    -- [natural]
    port map (
      waddr => waddr,  -- [in  std_logic_vector(G_AW-1 downto 0)]
      wr    => wr,                      -- [in  std_logic]
      raddr => raddr,  -- [in  std_logic_vector(G_AW-1 downto 0)]
      din   => wdata,  -- [in  std_logic_vector(G_DW-1 downto 0)]
      dout  => dout,   -- [out std_logic_vector(G_DW-1 downto 0)]
      clk   => clk,                     -- [in  std_logic]
      rst   => rst);                    -- [in  std_logic]

end architecture str;
