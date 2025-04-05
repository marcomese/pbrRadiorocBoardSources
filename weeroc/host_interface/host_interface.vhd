-------------------------------------------------------------------------------
-- Title      : Host interface block
-- Project    : MAuD v2
-------------------------------------------------------------------------------
-- File       : host_interface.vhd
-- Author     :   
-- Company    : 
-- Created    : 2020-07-17
-- Last update: 2020-10-06
-- Platform   : 
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-- Intefrace wrapper : data FIFO, config & status registers, USB interface
-------------------------------------------------------------------------------
-- Copyright (c) 2020 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-07-17  1.0      Nico    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types.all;

library xil_defaultlib;

entity host_interface is
	generic (
		G_FIFO_AW     : natural          := 16;     -- FIFO address width
		G_IRQ_SUPPORT : boolean          := false;  -- Support des interruptions
		G_FW_VER      : std_logic_vector := x"20"); -- Firmware version
	port
	(
		-- USB
		usb_d     : inout std_logic_vector(7 downto 0);
		usb_rd_n  : out   std_logic;
		usb_wr_n  : out   std_logic;
		usb_rxf_n : in    std_logic;
		usb_txe_n : in    std_logic;
		usb_siwu  : out   std_logic;
		-- LIROC
		val_evt  : out std_logic;
		rstb_i2c : out std_logic;
		rstb_read_sft : out std_logic;
		reset_n_sft : out std_logic;
		rstb_sc : out std_logic;
		-- I2C
		end_i2c   : in  std_logic;
		i2c_in    : out std_logic_vector(7 downto 0);
		i2c_set   : out std_logic_vector(7 downto 0);
		wr_i2c    : out std_logic;
		en_clki2c : out std_logic;
		rd55      : out std_logic;
		q			 : in std_logic_vector(7 downto 0);
		-- Mux
		sel_trigger : out std_logic_vector(7 downto 0);
		sel_io     : out std_logic_vector(23 downto 0);
		-- Scurves
		en_test_Scurve : out std_logic;
		rstb_Scurve    : out std_logic;
		on_edge        : out std_logic;
		clk_S          : out std_logic_vector(1 downto 0);
		nb_scurve      : out std_logic_vector(1 downto 0);
		sel_chn_scurve : out std_logic_vector(7 downto 0);
		P_cnt          : in  std_logic_vector(15 downto 0);
		T_cnt          : in  std_logic_vector(15 downto 0);
		-- Staircases
		rst_staircase : out std_logic;
		enable_stair  : out std_logic;
		data32b       : in  std_logic_vector(31 downto 0);
		-- Probe
		rstb_probe  : out std_logic;
		-- ADC
		reset_acq : out std_logic;
		start_acq : out std_logic;
		rd_acq   :  out std_logic;
		end_acq : in std_logic;
		nb_acq :  out std_logic_vector(7 downto 0);
		sel_adc : out std_logic_vector(63 downto 0);
		dout_acq : in std_logic_vector(7 downto 0);
		empty_acq : in std_logic;
		rd_data_count_acq : in std_logic_vector(15 downto 0);
		-- TDC
		fifo_in  : in  std_logic_vector(31 downto 0);
		fifo_wr  : in  std_logic;
		en_tdc     : out std_logic;
        rst_tdc_sft : out std_logic;
        coincidence_on : out std_logic;
        coincidence_delay : out std_logic_vector(7 downto 0);
        coincidence_width : out std_logic_vector(7 downto 0); 
        master : out std_logic;
        en_l_tdc : out std_logic_vector(63 downto 0);
        -- Temperature
        temp_cfg : out std_logic_vector(7 downto 0);
        temp_ctrl : out std_logic_vector(7 downto 0);
        temperature : in std_logic_vector(15 downto 0);
		--clocks and reset
		clk_25M : in  std_logic;
		clk_50M : in std_logic;
		rst     : in  std_logic;
		rst_tdc : in std_logic;
		spy     : out std_logic_vector(7 downto 0)
	);
end entity host_interface;

architecture str of host_interface is

	-- USB
	signal subadd         : std_logic_vector(6 downto 0);
	signal user_rdata     : std_logic_vector(7 downto 0);
	signal user_wdata     : std_logic_vector(7 downto 0);
	signal user_wdata_oen : std_logic;
	signal n_write        : std_logic;
	signal n_read         : std_logic;
	signal n_sync         : std_logic;
	signal n_wait         : std_logic;
	signal interrupt      : std_logic;
	signal read_req       : std_logic;
	signal busy           : std_logic;
	signal n_reset        : std_logic;
	-- Data
	signal reg_data      : std_logic_vector(7 downto 0);
	signal int_data      : std_logic_vector(7 downto 0);
	signal extrd_fifo_rd : std_logic;
	signal extrd_en      : std_logic;
	signal acq_data      : std_logic_vector(7 downto 0);
	-- Acqusition
	signal fifo_out     : std_logic_vector(7 downto 0);
	signal fifo_rd      : std_logic;
	signal fifo_empty   : std_logic;
	signal fifo_fr_rdy  : std_logic;
	signal fifo_full    : std_logic;
	signal fifo_overrun : std_logic;
	signal fifo_count   : std_logic_vector(15 downto 0);
	signal fifo_clr     : std_logic;
	signal set_sync_master  : std_logic;
	signal set_sync_slave   : std_logic;
	signal do_sync          : std_logic;
	signal rs_nb_acq        : std_logic_vector(15 downto 0);
	signal i_acq_cnt_clr    : std_logic;
	signal r_cmp            : std_logic_vector(1 downto 0);
	-- Registers
	signal word_0, word_1, word_2, word_3, word_4 : std_logic_vector(7 downto 0);
	signal word_22, word_23, word_24, word_25, word_26, word_27, word_30, word_31 : std_logic_vector(7 downto 0);
	signal word_61, word_62, word_63, word_64, word_65, word_66, word_67, word_68 : std_logic_vector(7 downto 0);
	signal word_77, word_78, word_79 : std_logic_vector(7 downto 0);

begin
	
	spy(0) <= fifo_full;
	spy(1) <= n_write;
	spy(2) <= n_read;

	usb_siwu <= '1';
	n_reset  <= not rst;

	usb_full_interface_ft2232h_async_fifo_wrapper_inst_1 : entity work.usb_full_interface_ft2232h_async_fifo_wrapper
		port map
		(
			rxf           => usb_rxf_n,
			rd            => usb_rd_n,
			txe           => usb_txe_n,
			wr            => usb_wr_n,
			usb_data      => usb_d,
			subadd        => subadd,
			user_data_in  => user_rdata,
			user_data_out => user_wdata,
			user_data_oen => user_wdata_oen,
			n_write       => n_write,
			n_read        => n_read,
			n_sync        => n_sync,
			n_wait        => n_wait,
			interrupt     => interrupt,
			read_req      => read_req,
			busy          => busy,
			clk           => clk_25M,
			n_reset       => n_reset);

	usr_data_mux_inst_1 : entity work.usr_data_mux
		generic map(
			G_IRQ_SUPPORT => G_IRQ_SUPPORT)
		port
		map (
		reg_data     => reg_data,
		acq_data     => acq_data,
		int_data     => int_data,
		user_data_in => user_rdata,
		busy         => busy,
		subadd       => subadd);

--	resync_inst_1 : entity work.resync
--		generic map(
--			G_DS => nb_acq'length)
--		port
--		map (
--		d_in  => nb_acq,
--		d_out => rs_nb_acq,
--		iclk  => tdc_clk,
--		oclk  => clk_25M,
--		rst   => rst);

    sel_adc <= word_31 & word_30 & word_27 & word_26 & word_25 & word_24 & word_23 & word_22;
    sel_io <= word_79 & word_78 & word_77;

	reg : entity xil_defaultlib.registers
	generic map(
		G_IRQ_SUPPORT => G_IRQ_SUPPORT,
		G_FW_VER      => G_FW_VER)
	port
	map (
	subadd     => subadd,
	user_rdata => reg_data,
	user_wdata => user_wdata,
	n_write    => n_write,
	n_read     => n_read,
	n_sync     => n_sync,
	n_wait     => n_wait,
	busy       => busy,
	interrupt  => interrupt,
	int_data   => int_data,
	-- Registers (interface with Weeroc functions)
	word_0  => word_0,
	word_1  => word_1,
	word_2  => word_2,
	word_3 => word_3,
	word_4  => word_4,
	word_5  => sel_trigger,
	word_6  => sel_chn_scurve,
	word_8  => P_cnt(7 downto 0),
	word_9  => T_cnt(7 downto 0),
	word_18 => P_cnt(15 downto 8),
	word_19 => T_cnt(15 downto 8),
	word_20 => dout_acq,
	word_21 => nb_acq,
	word_22 => word_22,
	word_23 => word_23,
	word_24 => word_24,
	word_25 => word_25,
	word_26 => word_26,
	word_27 => word_27,
	word_28 => rd_data_count_acq(7 downto 0),
	word_29 => rd_data_count_acq(15 downto 8),
	word_30 => word_30,
	word_31 => word_31,
	word_48 => temp_ctrl,
	word_49 => temp_cfg,
	word_50 => temperature(7 downto 0),
	word_51 => temperature(15 downto 8),
	word_55 => q,
	word_56 => i2c_in,
	word_60 => i2c_set,
	word_61 => word_61,
	word_62 => word_62,
	word_63 => word_63,
	word_64 => word_64,
	word_65 => word_65,
	word_66 => word_66,
	word_67 => word_67,
	word_68 => word_68,
	word_75 => coincidence_delay,
	word_76 => coincidence_width,
	word_77 => word_77,
	word_78 => word_78,
	word_79 => word_79,
	word_96 => data32b(7 downto 0),
	word_97 => data32b(15 downto 8),
	word_98 => data32b(23 downto 16),
	word_99 => data32b(31 downto 24),
	rd_20 => rd_acq,
	rd_55   => rd55,
	wr_56   => wr_i2c,
	-- Acquisition data FIFO interface
	fifo_out     => fifo_out,
	fifo_read      => fifo_rd,
	fifo_count   => fifo_count,
	fifo_empty   => fifo_empty,
	fifo_fr_rdy  => fifo_fr_rdy,
	fifo_full    => fifo_full,
	fifo_overrun => fifo_overrun,
	extrd_en         => extrd_en,
	fifo_clr     => fifo_clr,
	acq_cnt_clr      => i_acq_cnt_clr,
	set_sync_master  => set_sync_master,
	set_sync_slave   => set_sync_slave,
	do_sync          => do_sync,
	extrd_fifo_rd    => extrd_fifo_rd,
	clk              => clk_25M,
	rst              => rst
	);

	val_evt        <= word_0(0);
	rstb_i2c       <= word_0(1);
	rstb_read_sft  <= word_0(2);
	rstb_probe     <= word_0(3);
	reset_n_sft    <= word_0(4);
	rstb_sc        <= word_0(5);
	en_clki2c      <= word_0(6);
	en_test_Scurve <= word_1(0);
	rstb_Scurve    <= word_1(1);
	clk_S          <= word_1(3 downto 2);
	nb_scurve      <= word_1(5 downto 4);
	rst_staircase  <= word_1(6);
	enable_stair   <= word_1(7);
	en_tdc         <= word_2(0);
	rst_tdc_sft    <= word_2(2);
	coincidence_on <= word_2(3);
	master         <= word_2(4);
	reset_acq      <= word_2(5);
    start_acq      <= word_2(6);
    
    on_edge         <= word_3(0);

	word_4(0) <= end_i2c;
	word_4(2) <= end_acq;
	word_4(3) <= empty_acq;
	
	en_l_tdc <= word_68 & word_67 & word_66 & word_65 & word_64 & word_63 & word_62 & word_61;
	
	acq_sync_inst_1 : entity work.acq_sync
		port
	map (
	sync_rst_in     => '0',
	sync_rst_out    => open,
	sync_rst_oen    => open,
	set_sync_master => set_sync_master,
	set_sync_slave  => set_sync_slave,
	do_sync         => do_sync,
	acq_cnt_clr     => i_acq_cnt_clr,
	clk             => clk_25M,
	rst             => rst);

	ext_rd_mgr_inst_1 : entity work.ext_rd_mgr
		port
	map (
	fifo_out     => fifo_out,
	fifo_rd      => extrd_fifo_rd,
	fifo_empty   => fifo_empty,
	fifo_full    => fifo_full,
	fifo_overrun => fifo_overrun,
	fifo_fr_rdy  => fifo_fr_rdy,
	brd_pos          => "0000",
	acq_data         => acq_data,
	n_read           => n_read,
	read_req         => read_req,
	busy             => busy,
	extrd_en         => extrd_en,
	clk              => clk_25M,
	rst              => rst_tdc);
	
	acq_fifo_0 : entity work.acq_fifo
		generic map(
			G_FIFO_AW => 16
		)
		port
		map (
		fifo_in      => fifo_in,
		fifo_wr      => fifo_wr,
		fifo_out     => fifo_out,
		fifo_rd      => fifo_rd,
		fifo_count   => fifo_count,
		fifo_empty   => fifo_empty,
		fifo_fr_rdy  => fifo_fr_rdy,
		fifo_full    => fifo_full,
		fifo_overrun => fifo_overrun,
		fifo_clr     => fifo_clr,
		clk_25M          => clk_25M,
		clk_50M => clk_50M,
		rst              => rst_tdc
		);
end architecture str;
