library ieee;
use ieee.std_logic_1164.all;

library xil_defaultlib;

entity usb_full_interface_ft2232h_async_fifo_wrapper is 
Port (
	rxf : in std_logic;
	rd : out std_logic;
	txe : in std_logic;
	wr : out std_logic;
	usb_data : inout std_logic_vector(7 downto 0);
	subadd : out std_logic_vector(6 downto 0);
	user_data_in : in std_logic_vector(7 downto 0);
	user_data_out : out std_logic_vector(7 downto 0);
	user_data_oen : out std_logic;
	n_write : out std_logic;
	n_read : out std_logic;
	n_sync : out std_logic;
	n_wait : in std_logic;
	interrupt : in std_logic;
	read_req : in std_logic;
	busy : out std_logic;
	clk : in std_logic;
	n_reset : in std_logic
);
end entity;

architecture bhv of usb_full_interface_ft2232h_async_fifo_wrapper is
	
	signal data: std_logic_vector(7 downto 0);
	signal usb_subadd : std_logic_vector(6 downto 0);
	signal usb_n_write : std_logic;
	signal usb_n_read : std_logic;
	
	component usb_full_interface_ft2232h_async_fifo_v is
	port
	(
		 n_reset       : in std_logic;				
		 clk 				: in std_logic;		
		 RXF				: in std_logic;
		 RD				: out std_logic;
		 TXE				: in std_logic;
		 WR				: out std_logic;
		 USB_DATA	   : inout std_logic_vector(7 downto 0);		
		 single_data_bus	: in std_logic;						
		 subadd				: out std_logic_vector(6 downto 0);
		 data				: inout std_logic_vector(7 downto 0);
		 n_write			: out std_logic;		
		 n_read			: out std_logic;
		 n_sync			: out std_logic;
		 n_wait			: in std_logic;
		 interrupt		: in std_logic;
		 read_req		: in std_logic;
		 busy 			: out std_logic
	);
	end component;
	   
	

begin 

	subadd <= usb_subadd;
	n_read <= usb_n_read;
	n_write <= usb_n_write;

	data <= user_data_in when usb_n_read = '0' else "ZZZZZZZZ";
	user_data_out <= data when usb_n_write = '0' else "ZZZZZZZZ";
	user_data_oen <= '1' when usb_n_write = '0' else '0';
	
	lbl_lal_usb : usb_full_interface_ft2232h_async_fifo_v 
	port map
	(
		 n_reset            => n_reset,								
		 clk 				=> clk,		
		 RXF				=> rxf,	
		 RD					=> rd,
		 TXE				=> TXE,	
		 WR					=> wr,		
		 USB_DATA			=> usb_data,				
		 single_data_bus	=> '0',						
		 subadd				=> usb_subadd,	
		 data				=> data,
		 n_write			=> usb_n_write,		
		 n_read				=> usb_n_read,	
		 n_sync				=> n_sync,
		 n_wait				=> n_wait,	
		 interrupt			=> interrupt,		
		 read_req			=> read_req,		
		 busy               => busy							
	);
	

end bhv;