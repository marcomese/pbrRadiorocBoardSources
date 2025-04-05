-------------------------------------------------------------------------------
-- Title      : Acquisition FIFO
-- Project    : MAuD v2
-------------------------------------------------------------------------------
-- File       : acq_fifo.vhd
-- Author     : Nicolas Matringe  <nmatringe@alciom.com>
-- Company    : Alciom
-- Created    : 2020-09-16
-- Last update: 2020-10-06
-- Platform   : 
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2020 Alciom
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-09-16  1.0      DELL PRECISION T7500	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity acq_fifo is
  generic (
    G_FIFO_AW : natural := 16);         -- Largeur du bus d'adresse
  port (
    fifo_in      : in  std_logic_vector(31 downto 0);
    fifo_wr      : in  std_logic;
    fifo_out     : out std_logic_vector(7 downto 0);
    fifo_rd      : in  std_logic;
    fifo_count   : out std_logic_vector(15 downto 0);
    fifo_empty   : out std_logic;
    fifo_fr_rdy  : out std_logic;
    fifo_full    : out std_logic;
    fifo_overrun : out std_logic;
    fifo_clr     : in  std_logic;
    clk_25M          : in  std_logic;
    clk_50M           : in std_logic;
    rst              : in  std_logic
    );
end entity acq_fifo;

architecture str of acq_fifo is
  signal wdata : std_logic_vector(31 downto 0);
  signal wr    : std_logic;
  signal wr_safe : std_logic;
  signal fifo_full_int : std_logic;

begin

--    fifo_inseq_inst_1 : entity work.fifo_inseq
--    port map (
--      fifo_in => fifo_in, 
--      fifo_wr => fifo_wr, 
--      wdata       => wdata,  
--      wr          => wr,    
--      tdc_clk     => clk_50M,  
--      fifo_clk    => clk_25M,       
--      rst         => rst
--      );    
  
  wr_safe <= fifo_wr and not fifo_full_int;    
  fifo_full <= fifo_full_int; 

  fifo_inst_1 : entity work.fifo
    generic map (
      G_AW  => G_FIFO_AW,           
      G_DWW => 32,     --32            
      G_DWR => 8,                  
      G_THD => 509)            --509       
    port map (
      wdata   => fifo_in,            
      wr      => wr_safe,      --wr             
      rdata   => fifo_out,     
      rd      => fifo_rd,         
      count   => fifo_count,        
      empty   => fifo_empty,     
      thd     => fifo_fr_rdy,      
      full    => fifo_full_int,     --fifo_full   
      overrun => fifo_overrun,    
      clr     => fifo_clr,       
      clk     => clk_25M,         
      rst     => rst);               


end architecture str;
