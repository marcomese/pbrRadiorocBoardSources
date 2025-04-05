-------------------------------------------------------------------------------
-- Title      : FIFO logic (pointers & counter)
-- Project    : 
-------------------------------------------------------------------------------
-- File       : fifo_logic.vhd
-- Author     : Nicolas Matringe  <nmatringe@alciom.com>
-- Company    : Alciom
-- Created    : 2020-06-09
-- Last update: 2020-08-14
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

entity fifo_logic is
  generic (
    G_AW  : natural := 16;              -- Largeur du bus d'adresses
    G_DWW : natural := 32;              -- Largeur du bus de données d'écriture
    G_DWR : natural := 8;               -- Largeur du bus de données de lecture
    G_THD : natural := 266);            -- Seuil pour le signal thd
  port (
    waddr   : out std_logic_vector(G_AW-3 downto 0); --4
    wr      : in  std_logic;
    raddr   : out std_logic_vector(G_AW-3 downto 0); --4
    dout    : in  std_logic_vector(G_DWW-1 downto 0);
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
end entity fifo_logic;

architecture rtl of fifo_logic is
  signal i_full  : std_logic;
  signal i_empty : std_logic;

begin  -- architecture rtl

  full  <= i_full;
  empty <= i_empty;

  p : process (clk, rst) is
    variable v_wa  : unsigned(waddr'range);
    variable v_ra  : unsigned(G_AW-1 downto 0);
    variable v_cnt : unsigned(G_AW-1 downto 0);
    variable v_ovr : std_logic;         -- Overrun flag
    variable i     : natural range 0 to 3; --7
  begin  -- process p
    if rst = '1' then                   -- asynchronous reset (active high)
      v_wa    := (others => '0');
      v_ra    := (others => '0');
      v_cnt   := (others => '0');
      i_empty <= '1';
      thd     <= '0';
      i_full  <= '0';
      v_ovr   := '0';
    elsif rising_edge(clk) then         -- rising clock edge
      i       := to_integer(v_ra(1 downto 0)); --2
      rdata   <= dout(8*i+7 downto 8*i);
      thd     <= '0';
      if v_cnt > 0 then
        i_empty <= '0';
      end if;
      if v_cnt < 2**G_AW-8 then
        i_full <= '0';
      end if;
      if v_cnt > G_THD then
        thd <= '1';
      end if;
      if wr = '1' then
        if v_cnt > 2**G_AW-9 then
          i_full <= '1';
        end if;
        if (i_full or v_ovr) = '0' then
          v_wa  := v_wa + 1;
          v_cnt := v_cnt + 4; --8;
        else
          v_ovr := '1';
        end if;
      end if;
      if rd = '1' then
        if v_cnt = 1 or i = 3 then --7
          i_empty <= '1';
        end if;
        if i_empty = '0' then
          v_ra  := v_ra + 1;
          v_cnt := v_cnt - 1;
        end if;
      end if;
      if clr = '1' then
        v_wa    := (others => '0');
        v_ra    := (others => '0');
        v_cnt   := (others => '0');
        i_empty <= '1';
        thd     <= '0';
        i_full  <= '0';
        v_ovr   := '0';
      end if;
    end if;
    waddr              <= std_logic_vector(v_wa);
    raddr              <= std_logic_vector(v_ra(G_AW-1 downto 2)); --3
    count              <= (others => '0');
    count(v_cnt'range) <= std_logic_vector(v_cnt);
    overrun            <= v_ovr;
  end process p;

end architecture rtl;
