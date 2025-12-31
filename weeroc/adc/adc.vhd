library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_MISC.ALL;
library UNISIM;
use UNISIM.vcomponents.all;
library xil_defaultlib;

entity adc is
	Port (
		rst 	 : in std_logic;
		clk_100M : in std_logic;
		clkN_100M : in std_logic;
		clk_200M : in std_logic;
		clkN_200M : in std_logic;
		start    : in std_logic;
		sdo_hg	 : IN STD_LOGIC;
		sdo_lg	 : IN STD_LOGIC;
		NORT1	 : in std_logic;
		NORT2 	 : in std_logic;
		NORTQ    : in std_logic;
		nb_acq   : in std_logic_vector(7 downto 0);
		t		 : in std_logic_vector(63 downto 0);
        sel_adc : in std_logic_vector(63 downto 0);
		rd_en 	 : in std_logic;
		dout 	 : out std_logic_vector(7 downto 0);
		reset_n    : out std_logic;
		rstb_rd  : out std_logic;
		ck_read  : out std_logic;
		n_cnv 	 : out std_logic;
		adc_sck  : out std_logic;
		empty_acq : out std_logic;
		end_multi_acq : out std_logic;
		rd_data_count_acq : out std_logic_vector(15 downto 0);
		hold_ext : out std_logic;
		trig_ext : out std_logic;
		trig_out : out std_logic;
		pulsing : in std_logic;
		pulse : in std_logic;
		extTrg : in std_logic;
		endAcq : out std_logic;
		rdValid : out std_logic;
		test : out std_logic
	);
end adc;

architecture Behavioral of adc is

	component fifo_acq
	Port (
		rst : in std_logic;
		wr_clk : in std_logic;
		rd_clk : in std_logic;
		din : in std_logic_vector(31 downto 0);
		wr_en : in std_logic;
		rd_en : in std_logic;
		dout : out std_logic_vector(7 downto 0);
		full : out std_logic;
		empty : out std_logic;
		valid : OUT STD_LOGIC;
		rd_data_count : out std_logic_vector(15 downto 0)
	);
	end component;

	type state_t is (idle, wait_hold, rst_cpt, wait_conv, asrt_rd_high, asrt_rd_low, nxt, read_asic, start_conv, end_conv, read_adc, end_read_adc, write_fifo, finish);
	signal current_state, next_state : state_t;
	
	signal cpt : natural range 0 to 4095;
	signal cpt_adc_sck : natural range 0 to 31;
	signal ch : natural range 0 to 80;
	signal hold_delay : natural range 0 to 4095;
	signal conv_delay : natural range 0 to 2047;
	
	signal hit0, hit1, hit, en_acq : std_logic;
	signal end_acq : std_logic;
	signal wr_en : std_logic;
	
	signal sdo_hg_des, sdo_lg_des : std_logic_vector(15 downto 0);
	signal din, din_l : std_logic_vector(31 downto 0);
	
	signal en_adc_sck, adc_sck_s, rstb_rd_s, rst_n : std_logic;
	signal t0, t1, trigger, trigger_sft,  holdext, trgEdge, trgSftEdge : std_logic;
	
	signal adc_sck_vector :  std_logic_vector(1 downto 0);
	
	signal NORT_FPGA : std_logic;
	
	signal  en_trigext : std_logic;
	signal hd : std_logic_vector(11 downto 0);
    signal cd : std_logic_vector(10 downto 0);
    
    signal endAcqSig, endAcqOut : std_logic_vector(0 downto 0);
    signal rdValidSig : std_logic;

begin

trig_out     <= trigger_sft;
endAcqSig(0) <= end_acq;
endAcq       <= endAcqOut(0);
rdValid      <= rdValidSig;
NORT_FPGA    <= and_reduce(t);

clkSyncEndAcqInst: entity work.pulseSync
generic map(
    width       => endAcqSig'length
)
port map(
    clkOrig => clk_200M,
    rstOrig => rst,
    clkDest => clk_100M,
    rstDest => rst,
    sigOrig => endAcqSig,
    sigDest => endAcqOut
);

ma : entity xil_defaultlib.multi_acq
Port map (
    rst 	 => rst,
    clk_200M => clk_200M,
    start	 => start,
    end_acq  => end_acq,
    nb_acq 	 => nb_acq,
    en_acq => en_acq,
    end_multi_acq => end_multi_acq,
    rst_n => rst_n
);
	
adcSckBufInst: BUFGCE
port map(
    O => adc_sck_s,
    CE => en_adc_sck,
    I => clk_100M
);

	adc_sck <= adc_sck_s;
	rstb_rd <= rstb_rd_s;
	
	process(rstb_rd_s, adc_sck_s)
	begin
		if rstb_rd_s = '0' then
			sdo_hg_des <= (others => '0');
			sdo_lg_des <= (others => '0');
		elsif rising_edge(adc_sck_s) then
			sdo_hg_des <= sdo_hg_des(14 downto 0) & sdo_hg;
			sdo_lg_des <= sdo_lg_des(14 downto 0) & sdo_lg;
		end if;
	end process;
	
	ff : fifo_acq
	port map (
		rst    => rst,
		wr_clk => clkN_200M,
		rd_clk => clkN_100M,
		din    => din_l,
		wr_en  => wr_en,
		rd_en  => rd_en,
		dout   => dout,
		full   => open,
		empty  => empty_acq,
		valid => rdValidSig,
		rd_data_count => rd_data_count_acq
	);
	
	process(clk_200M)
	begin
	if rising_edge(clk_200M) then
	   din <= sdo_hg_des & sdo_lg_des;
	   din_l <= din;
	end if;
	end process;
	
	hit0 <= t(to_integer(unsigned(sel_adc(5 downto 0))));
	
	with sel_adc(31 downto 29) select 
		t0 <=  NORT1 when "000",
			  NORT2 when "001",
			  NORTQ when "010",
			 hit0    when "011",
			 NORT_FPGA when "100",
			 '0'  when others;		
			 
	hit1 <= t(to_integer(unsigned(sel_adc(13 downto 8))));
	
	with sel_adc(50 downto 48) select 
		t1 <=  NORT1 when "000",
			  NORT2 when "001",
			  NORTQ when "010",
			 hit1    when "011",
			 NORT_FPGA when "100",
			 '0'  when others;		 
    
    with sel_adc(25 downto 24) select
        hit <= not t0 when "00",
               '0'    when others;
               
    trig_ext <=      '0' when sel_adc(26) = '0' else (trigger or en_trigext);
    hold_ext <=      sel_adc(27) and holdext; 
    reset_n <=       sel_adc(6) when sel_adc(28) = '0' else rst_n;
    
    hd <= sel_adc(54 downto 51) & sel_adc(39 downto 32); 
    hold_delay <= to_integer(unsigned(hd));   
    cd <=   sel_adc(63 downto 56) & "000";  
    conv_delay <= to_integer(unsigned(cd));
    
    trigger <= en_acq and (hit or extTrg or pulse);
    trigger_sft <= sel_adc(7);

trgEdgeInst: entity work.edgeDetector
generic map(
    clockEdge => "falling",
    edge      => "rising"
)
port map(
    clk       => clk_200M,
    rst       => rst,
    signalIn  => trigger,
    signalOut => trgEdge
);

trgSftEdgeInst: entity work.edgeDetector
generic map(
    clockEdge => "falling",
    edge      => "rising"
)
port map(
    clk       => clk_200M,
    rst       => rst,
    signalIn  => trigger_sft,
    signalOut => trgSftEdge
);

	process(rst, clk_200M)
	begin
	if rst = '1' then
		current_state <= idle;
		cpt <= hold_delay;
		ch <= 0;
		cpt_adc_sck <= 0;
		adc_sck_vector <= "11";
	elsif rising_edge(clk_200M) then
		current_state <= next_state;
		adc_sck_vector <= adc_sck_vector(0) & adc_sck_s;
		if current_state = idle then
		  cpt <= hold_delay;
	    elsif current_state = rst_cpt then
		  cpt <= conv_delay + 40;
	    elsif current_state = nxt then
	      cpt <= 46;
		else
		  cpt <= cpt - 1;
		end if;
		if current_state = idle then
		  ch <= 0;
		elsif current_state = end_conv then
		  ch <= ch + 1;
		end if;
		if current_state = end_conv then
		  cpt_adc_sck <= 0;
		elsif adc_sck_vector = "01" then
		  cpt_adc_sck <= cpt_adc_sck + 1;
		end if;
	end if;
	end process;
	
	process(current_state, trgEdge, trgSftEdge, cpt, ch, cpt_adc_sck)
	begin
		case current_state is 
			when idle => 
				if trgEdge = '1' or trgSftEdge = '1' then
					next_state <= wait_hold;
				else 
					next_state <= idle;
				end if;
		    when wait_hold =>
              if cpt = 0 then
                  next_state <= rst_cpt;
              else 
                  next_state <= wait_hold;
              end if;
                --next_state <= rst_cpt;
            when rst_cpt =>
                next_state <= wait_conv;
            when wait_conv =>
                if cpt = 40 then
                    next_state <= asrt_rd_high;
                else 
                    next_state <= wait_conv;
                end if;
            when asrt_rd_high =>
                if cpt = 20 then
                    next_state <= asrt_rd_low;
                else 
                    next_state <= asrt_rd_high;
                end if;
            when asrt_rd_low =>
                if cpt = 0 then
                    next_state <= nxt;
                else 
                    next_state <= asrt_rd_low;
                end if;
			when nxt => 
				if ch >= 66 then
					next_state <= finish;
				elsif ch < 2 then
				    next_state <= start_conv;
				else 
					next_state <= read_asic;
				end if;
			when read_asic => 
				if cpt = 26 then
					next_state <= start_conv;
				else 
					next_state <= read_asic;
				end if;
			when start_conv => 
				if cpt = 0 then
					next_state <= end_conv;
				else 
					next_state <= start_conv;
				end if;
			when end_conv =>
				next_state <= read_adc;
			when read_adc =>
				if cpt_adc_sck >= 15 then
                    next_state <= end_read_adc;
				else 
					next_state <= read_adc;
				end if;
			when end_read_adc =>
               if ch < 3 then
                   next_state <= nxt;
               else 
                   next_state <= write_fifo;
                end if;
			when write_fifo =>
				next_state <= nxt;
			when finish =>
				next_state <= idle;
			when others =>
				next_state <= idle;
		end case;
	end process;
	
	process(current_state)
	begin
		case current_state is
			when idle =>
			     test<='1';
				rstb_rd_s 	<= '1';
				holdext    <= '0';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';
				wr_en		<= '0';
				end_acq		<= '0';
				en_trigext  <= '0';
		    when wait_hold =>
			     test<='0';
		        rstb_rd_s 	<= '0';
		        holdext    <= '0';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';
				wr_en		<= '0';
				end_acq		<= '0';
				en_trigext  <= '1';
		    when rst_cpt =>
			     test<='1';
		        rstb_rd_s 	<= '1';
		        holdext    <= '1';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';
				wr_en		<= '0';
				end_acq		<= '0';
				en_trigext  <= '1';
		    when wait_conv =>
			     test<='1';
		        rstb_rd_s 	<= '1';
		        holdext    <= '1';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';
				wr_en		<= '0';
				end_acq		<= '0';  
				en_trigext  <= '1';   
			when asrt_rd_high =>
			     test<='1';
			    rstb_rd_s 	<= '1';
		        holdext    <= '1';
				ck_read 	<= '1';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';
				wr_en		<= '0';
				end_acq		<= '0'; 
				en_trigext  <= '0';
			when asrt_rd_low =>
			     test<='1';
			    rstb_rd_s 	<= '1';
		        holdext    <= '1';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';
				wr_en		<= '0';
				end_acq		<= '0'; 
				en_trigext  <= '0';
			when nxt =>
				rstb_rd_s 	<= '1';
				holdext    <= '1';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';	
				wr_en		<= '0';
				end_acq		<= '0';	
				en_trigext  <= '0';			
			when read_asic =>
				rstb_rd_s 	<= '1';
				holdext    <= '1';
				ck_read 	<= '1';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';
				wr_en		<= '0';
				end_acq		<= '0';
				en_trigext  <= '0';
			when start_conv =>
				rstb_rd_s 	<= '1';
				holdext    <= '1';
				ck_read 	<= '0';
				n_cnv 		<= '1';
				en_adc_sck 	<= '0';
				wr_en		<= '0';
				end_acq		<= '0';
				en_trigext  <= '0';
			when end_conv =>
				rstb_rd_s 	<= '1';
				holdext    <= '1';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';
				wr_en		<= '0';
				end_acq		<= '0';
				en_trigext  <= '0';
			when read_adc =>
				rstb_rd_s 	<= '1';
				holdext    <= '1';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '1';	
				wr_en		<= '0';
				end_acq		<= '0';
				en_trigext  <= '0';	
			when end_read_adc =>
			 	rstb_rd_s 	<= '1';
			 	holdext    <= '1';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';	
				wr_en		<= '0';
				end_acq		<= '0';
				en_trigext  <= '0';	
			when write_fifo =>
				rstb_rd_s 	<= '1';
				holdext    <= '1';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';
				wr_en		<= '1';
				end_acq		<= '0';
				en_trigext  <= '0';	
			when finish =>
			     test<='0';
				rstb_rd_s 	<= '1';
				holdext    <= '0';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';
				wr_en		<= '0';
				end_acq		<= '1';
				en_trigext  <= '0';	
			when others =>
				rstb_rd_s 	<= '1';
				holdext    <= '0';
				ck_read 	<= '0';
				n_cnv 		<= '0';
				en_adc_sck 	<= '0';	
				wr_en		<= '0';
				end_acq		<= '0';	
				en_trigext  <= '0';	
		end case;			
		
	end process;
	
end Behavioral;