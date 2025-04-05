-------------------------------------------------------------------------------
-- Title      : User data multiplexer
-- Project    : MAuD v2
-------------------------------------------------------------------------------
-- File       : usr_data_mux.vhd
-- Author     :   <Nico@MUSTANG>
-- Company    : 
-- Created    : 2020-07-17
-- Last update: 2020-08-11
-- Platform   : 
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-- Multiplexeur de donn�es entre registres, FIFO et interruptions
-------------------------------------------------------------------------------
-- Copyright (c) 2020 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-07-17  1.0      Nico    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity usr_data_mux is
  generic (
    G_IRQ_SUPPORT : boolean := false); -- Support des interruptions
  port (
    reg_data     : in  std_logic_vector(7 downto 0);
    acq_data     : in  std_logic_vector(7 downto 0);
    int_data     : in  std_logic_vector(7 downto 0);
    user_data_in : out std_logic_vector(7 downto 0);
    busy         : in  std_logic;
    subadd       : in  std_logic_vector(6 downto 0));
end entity usr_data_mux;

architecture rtl of usr_data_mux is

begin  -- architecture rtl

  mux : process (acq_data, busy, int_data, reg_data, subadd) is
  begin  -- process mux
    -- Par d�faut, donn�es en provenance des registres
    user_data_in <= reg_data;
    if subadd = "1111111" then
      if G_IRQ_SUPPORT then
      -- Interruption ou lecture �tendue --
        if busy = '1' then               --
          -- Lecture �tendue             --
          user_data_in <= acq_data;      --
        else                             --
          -- Interruption                --
          user_data_in <= int_data;      --
        end if;                          --
        -----------------------------------
      else
        -- Interruptions non support�es ---
        user_data_in <= acq_data;        --
      end if;                            --
    ---------------------------------------
    end if;
  end process mux;

end architecture rtl;
