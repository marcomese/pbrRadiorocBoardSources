library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types.all;

library xil_defaultlib;

entity adc is
	Port (
		rst 	 : in std_logic;
		clk_100M : in std_logic;
		clk_200M : in std_logic;
		clk_500M : in std_logic;
		clk_25M  : in std_logic;
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
		extTrg : in std_logic;
		endAcq : out std_logic;
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
	
	signal en_adc_sck, adc_sck_s, rstb_rd_s, t_window, rst_n, t_topo : std_logic;
	signal t0, t1, trigger, trigger_sft,  holdext : std_logic;
	
	signal adc_sck_vector :  std_logic_vector(1 downto 0);
	
	signal NORT_FPGA : std_logic;
	
	signal clk_200M_n, clk_25M_n, en_trigext : std_logic;
	signal signal_in_pulse, signal_in_pulse2, latch, signal_in_delayed, reset_delay_cntr : std_logic;
	constant delay_so : integer := 5;
	signal delay_cntr : natural range 0 to 5;
	signal hd : std_logic_vector(11 downto 0);
    signal cd : std_logic_vector(10 downto 0);
    
    signal trigger_shrunk, trigger_sft_shrunk, trigger_latched, trigger_sft_latched, trigger_latched2,  trigger_sft_latched2: std_logic;

    signal endAcqSig, endAcqOut : std_logic_vector(0 downto 0);

	attribute fsm_encoding : string;
    attribute fsm_encoding of next_state : signal is "gray";
    attribute fsm_encoding of current_state : signal is "gray";

begin

    clk_200M_n <= not clk_200M;
    clk_25M_n <= not clk_25M;
    trig_out <= trigger_sft;

endAcqSig(0) <= end_acq;
endAcq       <= endAcqOut(0);

clkSyncInst: entity work.pulseExtender
port map(
    clkOrig => clk_200M,
    rstOrig => rst,
    clkDest => clk_100M,
    rstDest => rst,
    sigOrig => endAcqSig,
    sigDest => endAcqOut
);

    NORT_FPGA <= t(63) and t(62) and t(61) and t(60) and t(59) and t(58) and t(57) and t(56)
            and t(55) and t(54) and t(53) and t(52) and t(51) and t(50) and t(49) and t(48)
            and t(47) and t(46) and t(45) and t(44) and t(43) and t(42) and t(41) and t(40)
            and t(39) and t(38) and t(37) and t(36) and t(35) and t(34) and t(33) and t(32)
            and t(31) and t(30) and t(29) and t(28) and t(27) and t(26) and t(25) and t(24)
            and t(23) and t(22) and t(21) and t(20) and t(19) and t(18) and t(17) and t(16)
            and t(15) and t(14) and t(13) and t(12) and t(11) and t(10) and t(9) and t(8)
            and t(7) and t(6) and t(5) and t(4) and t(3) and t(2) and t(1) and t(0);

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
	
	adc_sck_s <= clk_100M and en_adc_sck;
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
		wr_clk => clk_200M_n,
		rd_clk => clk_25M_n,
		din    => din_l,
		wr_en  => wr_en,
		rd_en  => rd_en,
		dout   => dout,
		full   => open,
		empty  => empty_acq,
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
			 
    tw  : entity xil_defaultlib.trigger_window 
    Port map ( 
        clk => clk_100M,
        t0  => t0,
        t1  => t1,
        window_size => sel_adc(23 downto 16),
        tout   => t_window
    );
    
    tt : entity xil_defaultlib.trigger_topo
    Port map ( 
        clk => clk_100M,
        NORT_FPGA => NORT_FPGA,
        fast_clk => clk_500M,
        t   => t,
        window_size => sel_adc(23 downto 16),
        nb_trig     => sel_adc(45 downto 40),
        tout        => t_topo
    );
    
    with sel_adc(25 downto 24) select
        hit <= not t0 when "00",
               t_window when "01",
               t_topo when "10",
               '0'        when others;
               
    trig_ext <=      '0' when sel_adc(26) = '0' else (trigger or en_trigext);
    hold_ext <=      sel_adc(27) and holdext; 
    reset_n <=       sel_adc(6) when sel_adc(28) = '0' else rst_n;
    
    hd <= sel_adc(54 downto 51) & sel_adc(39 downto 32); 
    hold_delay <= to_integer(unsigned(hd));   
    cd <=   sel_adc(63 downto 56) & "000";  
    conv_delay <= to_integer(unsigned(cd));
    
    trigger <= (en_acq and (hit or extTrg));
    trigger_sft <= sel_adc(7);--signal_in_pulse or signal_in_pulse2 or latch;
    
    process(trigger_shrunk, trigger)
    begin
    if trigger_shrunk = '1' then
        trigger_shrunk <= '0';
    elsif rising_edge(trigger) then
        trigger_shrunk <= '1';
    end if; 
    end process;
    
    process(trigger_sft_shrunk, trigger_sft)
    begin
    if trigger_sft_shrunk = '1' then
        trigger_sft_shrunk <= '0';
    elsif rising_edge(trigger_sft) then
        trigger_sft_shrunk <= '1';
    end if;
    end process;
    
    process(trigger_shrunk, clk_200M)
    begin
    if trigger_shrunk = '1' then
        trigger_latched <= '1';
    elsif rising_edge(clk_200M) then
        trigger_latched <= '0';
    end if;
    end process;
    
    process(trigger_sft_shrunk, clk_200M)
    begin
    if trigger_sft_shrunk = '1' then
        trigger_sft_latched <= '1';
    elsif rising_edge(clk_200M) then
        trigger_sft_latched <= '0';
    end if;
   end process;
    
--    signal_in_pulse <= sel_adc(7) and not(signal_in_delayed);

--    process(rst, clk_200M)
--    begin
--      if (rst = '1') then
--        delay_cntr <= 0;
--        latch <= '0';
--        reset_delay_cntr <= '0';
--        signal_in_pulse2 <= '0';
--        signal_in_delayed <= '0';
--      elsif rising_edge(clk_200M) then
--        if sel_adc(7) = '1' then 
--          latch <= '1';
--        end if;  
--        if reset_delay_cntr = '1' then
--          delay_cntr <= 0;
--          latch <= '0'; 
--        elsif latch = '1' then
--          delay_cntr <= delay_cntr + 1;
--        end if;
--        signal_in_delayed <= sel_adc(7);
--        signal_in_pulse2 <= signal_in_pulse; 
        
--    if (delay_cntr = delay_so) then
--        reset_delay_cntr  <= '1';
--      elsif signal_in_pulse = '1' then
--        reset_delay_cntr  <= '0';     
--      end if;
--     end if;
--    end process;
    
	process(rst, clk_200M)
	begin
	if rst = '1' then
		current_state <= idle;
		cpt <= hold_delay;
		ch <= 0;
		cpt_adc_sck <= 0;
		adc_sck_vector <= "11";
		trigger_latched2 <= '0';
		trigger_sft_latched2 <= '0';
	elsif rising_edge(clk_200M) then
	    trigger_latched2 <= trigger_latched;
	    trigger_sft_latched2 <= trigger_sft_latched;
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
	
	process(current_state, trigger_latched2, trigger_sft_latched2, cpt, ch, cpt_adc_sck)
	begin
		case current_state is 
			when idle => 
				if trigger_latched2 = '1' or trigger_sft_latched2 = '1' then
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