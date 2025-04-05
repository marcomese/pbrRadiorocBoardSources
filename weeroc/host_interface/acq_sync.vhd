-------------------------------------------------------------------------------
-- Title      : Synchronisation des compteurs d'acquisition (multi-BE)
-- Project    : 
-------------------------------------------------------------------------------
-- File       : acq_sync.vhd
-- Author     :   <Nico@MUSTANG>
-- Company    : 
-- Created    : 2020-06-11
-- Last update: 2020-08-11
-- Platform   : 
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-- Gestion de la synchronisation des acquisition entre plusieurs cartes BE
-------------------------------------------------------------------------------
-- Copyright (c) 2020 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-06-11  1.0      Nico    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity acq_sync is
  port (
    sync_rst_in     : in  std_logic;
    sync_rst_out    : out std_logic;
    sync_rst_oen    : out std_logic;
    set_sync_master : in  std_logic;
    set_sync_slave  : in  std_logic;
    do_sync         : in  std_logic;
    acq_cnt_clr     : out std_logic;
    clk             : in  std_logic;
    rst             : in  std_logic);
end entity acq_sync;

architecture rtl of acq_sync is

begin  -- architecture str

  -- Automate maître
  master : process (clk, rst) is
    constant C_RST_CNT      : natural := 7;
    type t_master_state is (idle, armed, active, inactive);
    variable v_master_state : t_master_state;
    variable v_cnt          : natural range 0 to C_RST_CNT;
  begin  -- process master
    if rst = '1' then                   -- asynchronous reset (active high)
      v_master_state := idle;
      v_cnt          := 0;
      sync_rst_out   <= '1';
      sync_rst_oen   <= '0';
    elsif rising_edge(clk) then         -- rising clock edge
      case v_master_state is
        when idle =>                    -- Inactif
          sync_rst_out <= '1';
          sync_rst_oen <= '0';          -- Sortie en haute impédance
          v_cnt        := 0;
          if set_sync_master = '1' then
            v_master_state := armed;
          end if;
        when armed =>                   -- Armé, attente de déclenchement
          sync_rst_oen <= '1';          -- La sortie est activement tirée à 1
          v_cnt        := C_RST_CNT;
          if do_sync = '1' then         -- Déclenchement
            v_master_state := active;
          end if;
        when active =>                  -- Actif
          sync_rst_out <= '0';          -- La sortie est activement tirée à 0
          if v_cnt = 0 then             --  pendant C_RST_CNT cycles d'horloge
            v_master_state := inactive;
            v_cnt          := C_RST_CNT;
          else
            v_cnt := v_cnt - 1;
          end if;
        when inactive =>                -- Fin
          sync_rst_out <= '1';          -- La sortie est activement tirée à 1
          if v_cnt = 0 then             --  pendant C_RST_CNT cycles d'horloge
            v_master_state := idle;     --  puis retour à l'état inactif
          else
            v_cnt := v_cnt - 1;
          end if;
        when others => null;
      end case;
    end if;
  end process master;

  -- Automate esclave
  slave : process (clk, rst) is
    type t_slave_state is (idle, armed, active);
    variable v_slave_state : t_slave_state;
    variable v_rst_in      : std_logic;
  begin  -- process slave
    if rst = '1' then                   -- asynchronous reset (active high)
      v_slave_state := idle;
      v_rst_in      := '1';
      acq_cnt_clr   <= '0';
    elsif rising_edge(clk) then         -- rising clock edge
      case v_slave_state is
        when idle =>                    -- Inactif, attente
          acq_cnt_clr <= '0';
          if (set_sync_slave or set_sync_master) = '1' then
            -- Armé seul ou avec l'automate maître
            v_slave_state := armed;
          end if;
        when armed =>
          -- Attente du passage à 0 du signal de synchro
          acq_cnt_clr <= not v_rst_in;
          if v_rst_in = '0' then
            v_slave_state := active;
          end if;
        when active =>
          -- Attente e mla remontée du signal de synchro
          acq_cnt_clr <= not v_rst_in;
          if v_rst_in = '1' then
            v_slave_state := idle;
          end if;
        when others => null;
      end case;
      -- Resynchronisation de l'entrée de synchr avec l'horloge locale
      v_rst_in := sync_rst_in;
    end if;
  end process slave;

end architecture rtl;
