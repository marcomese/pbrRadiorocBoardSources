-------------------------------------------------------------------------------
-- Title      : Extended read manager
-- Project    : LAL USB for FT2232H
-------------------------------------------------------------------------------
-- File       : ext_rd_mgr.vhd
-- Author     :   <Nico@MUSTANG>
-- Company    : 
-- Created    : 2020-06-01
-- Last update: 2020-08-14
-- Platform   : 
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-- Gestion de la lecture ?tendue
-------------------------------------------------------------------------------
-- Copyright (c) 2020 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-06-01  1.0      Nico    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ext_rd_mgr is
  port (
    fifo_out     : in  std_logic_vector(7 downto 0);
    fifo_rd      : out std_logic;
    fifo_empty   : in  std_logic;
    fifo_full    : in  std_logic;
    fifo_overrun : in  std_logic;
    fifo_fr_rdy  : in  std_logic;
    brd_pos          : in  std_logic_vector(3 downto 0);
    acq_data         : out std_logic_vector(7 downto 0);
    n_read           : in  std_logic;
    read_req         : out std_logic;
    busy             : in  std_logic;
    extrd_en         : in  std_logic;
    clk              : in  std_logic;
    rst              : in  std_logic);
end entity ext_rd_mgr;

architecture rtl of ext_rd_mgr is

begin  -- architecture rtl

  p : process (clk, rst) is
    type t_extrd_state is (idle, req1, size1, status, data1, wait_rdy, req2, size2, data2);
    variable v_extrd_state : t_extrd_state;
    variable v_cnt         : natural range 0 to 255;
    variable v_del_rd      : std_logic;
  begin  -- process p
    if rst = '1' then                   -- asynchronous reset (active high)
      fifo_rd   <= '0';
      acq_data      <= (others => '0');
      read_req      <= '0';
      v_extrd_state := idle;
      v_cnt         := 0;
      v_del_rd      := '0';
    elsif rising_edge(clk) then         -- rising clock edge
      read_req    <= '0';
      acq_data    <= fifo_out;
      fifo_rd <= '0';
      case v_extrd_state is
        when idle =>                    -- Attente
          if (extrd_en and fifo_fr_rdy and not busy) = '1' then
            -- Lecture ?tendue activ?e, au moins 1 paquet entier dans la FIFO,
            --  interface LAL libre
            v_extrd_state := req1;
            read_req      <= '1';       -- Demande de lecture ?tendue
          end if;
        when req1 =>
          -- Demande de lecture ?tendue pour transf?rer 136 octets
          read_req <= '1';
          acq_data <= std_logic_vector(to_unsigned(255, 8)); --255
          if busy = '1' then            -- R?ponse de l'interface LAL
            v_extrd_state := size1;
          end if;
        when size1 =>
          v_cnt    := 255; --135
          acq_data <= std_logic_vector(to_unsigned(255, 8)); --135
          if (n_read and not v_del_rd) = '1' then
            -- L'interface LAL a lu la taille de la requ?te
            v_extrd_state := data1;
          end if;
        when data1 =>
          -- Lecture de la FIFO
          if (n_read and not v_del_rd) = '1' then
            fifo_rd <= '1';
            -- D?comptrage des octets lus
            if v_cnt = 0 then
              v_extrd_state := wait_rdy;
            else
              v_cnt := v_cnt - 1;
            end if;
          end if;
        when wait_rdy =>
          -- Attente de l'interface LAL
          if busy = '0' then            -- pr?te
            read_req      <= '1';       -- Nouvelle demande de lecture ?tendue
            v_extrd_state := req2;
          end if;
        when req2 =>
          read_req <= '1';
          if busy = '1' then            -- R?ponse de l'interface LAL
            v_extrd_state := size2;
          end if;
        when size2 =>
          v_cnt    := 255;              -- 131 Taille de la demande : 133 octets
          acq_data <= std_logic_vector(to_unsigned(255, 8)); --132
          if (n_read and not v_del_rd) = '1' then
            -- l'interface LAL a lu la taille
            v_extrd_state := data2;
          end if;
        when data2 =>
          -- Lecture de la FIFO
          if (n_read and not v_del_rd) = '1' then
            fifo_rd <= '1';
            -- D?compte des octets
            if v_cnt = 0 then
              -- Fin du transfert, retour en attente
              v_extrd_state := idle;
            else
              v_cnt := v_cnt - 1;
            end if;
          end if;
        when status =>
          -- Transfert de l'octet d'?tat de la FIFO
          acq_data <= brd_pos & fifo_overrun & fifo_full &
                      fifo_fr_rdy & fifo_empty;
          if (n_read and not v_del_rd) = '1' then
            -- L'octet a ?t? lu, d?comptage d'1 octet et passage ? la lecture
            -- de la FIFO
            -- v_cnt         := v_cnt - 1;
            v_extrd_state := idle;
          end if;
        when others => null;
      end case;
      v_del_rd := n_read;
    end if;
  end process p;

end architecture rtl;
