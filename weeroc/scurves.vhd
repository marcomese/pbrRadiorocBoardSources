-- scurves.vhd
-- Author : Weeroc
-- Description : Counts trigger pulses and sample clock pulses 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity scurves is
	port
	(
		rst     : in std_logic;
		clk     : in std_logic; -- 10MHz
		fq_clk  : in std_logic_vector(1 downto 0);
		nb      : in std_logic_vector (1 downto 0);
		enable  : in std_logic;
		trigger : in std_logic;
		on_edge : in std_logic;

		cpt_pulse : out std_logic_vector(15 downto 0);
		cpt_trig  : out std_logic_vector(15 downto 0);
		ready     : out std_logic;
		raz_chn   : out std_logic;
		clk_scurves : out std_logic
	);
end scurves;

architecture scurves_arch of scurves is

	signal cpt, cpt_ovf    : natural range 0 to 5000;
	signal pulser          : std_logic;
	signal EnableCountP    : std_logic;
	signal EnableCountT    : std_logic;
	signal CptFull, EndCpt : std_logic;
	signal Reset_Int       : std_logic;
	signal temp0, temp1    : std_logic;
	signal RS, RS_0            : std_logic := '0';
	signal RS_0bar         : std_logic := '1';
	signal RS_1, RS_2      : std_logic;
	signal bascule_RS      : std_logic;
	signal sel_word        : std_logic_vector (7 downto 0);
	signal sel_scurves     : std_logic_vector (15 downto 0);
	signal pulse_cnt       : std_logic_vector (15 downto 0);
	signal trigger_cnt     : std_logic_vector (15 downto 0);
	signal cpt_p       : integer range 0 to 65535;
	signal cpt_t       : integer range 0 to 65535;
begin

    clk_scurves <= pulser;
	ready <= EndCpt;

	-- Pulser clock generation
	with fq_clk select
		cpt_ovf <= 5000 when "00", -- 1kHz
		500 when "01",             -- 10kHz
		50 when "10",             -- 100kHz
		5 when "11",              -- 1MHz
		500 when others;

	process (rst, clk)
	begin
		if rst = '1' then
			cpt    <= 0;
			pulser <= '0';
		elsif rising_edge(clk) then
			if (cpt /= cpt_ovf) then
				cpt <= cpt + 1;
			else
				cpt    <= 0;
				pulser <= not(pulser);
			end if;
		end if;
	end process;
	-- Total number of scurves selection
	make_nb_scurve : process (nb)
	begin
		case nb is
			when "00"   => sel_scurves   <= "0000000011001000"; -- 200
			when "01"   => sel_scurves   <= "0000001111101000"; -- 1000
			when "10"   => sel_scurves   <= "0010011100010000"; -- 10000
			when "11"   => sel_scurves   <= "1100001101010000"; -- 50000
			when others => sel_scurves <= "0000000011001000";
		end case;
	end process make_nb_scurve;

	-- 
	EndCpt <= '1' when (sel_scurves <= pulse_cnt) else
		'0';

	process (rst, pulser)
	begin
		if rst = '1' then
			CptFull <= '0';
		elsif falling_edge(pulser) then
			CptFull <= EndCpt;
		end if;
	end process;

	Reset_Int <= '1' when (rst = '1' or enable = '0' or CptFull = '1') else
		'0';

	process (Reset_Int, pulser)
	begin
		if Reset_Int = '1' then
			temp0 <= '0';
			temp1 <= '0';
		elsif falling_edge(pulser) then
			temp0 <= '1';
			temp1 <= temp0;
		end if;
	end process;

	EnableCountP <= temp1;

	-- Pulse counter
	process (rst, pulser)
	begin
		if rst = '1' then
			cpt_p <= 0;
		elsif rising_edge(pulser) then
			if EnableCountP = '1' then
				if cpt_p = 65535 then
					cpt_p <= 0;
				else
					cpt_p <= cpt_p + 1;
				end if;
			end if;
		end if;
	end process;

	pulse_cnt <= std_logic_vector(to_unsigned(cpt_p, 16));
	cpt_pulse <= pulse_cnt;

	EnableCountT <= pulser and EnableCountP;

	process(EnableCountT, trigger)
	begin
	if EnableCountT = '0' then
	   RS <= '0';
	elsif rising_edge(trigger) then
	   RS <= '1';
	end if;
	end process;
	
--    RS_0 <= (RS or trigger) and EnableCountT;
      RS_0 <= RS when on_edge = '1' else (RS or trigger) and EnableCountT;

	process (EnableCountT, clk)
	begin
		if EnableCountT = '0' then
			RS_1 <= '0';
			RS_2 <= '0';
		elsif rising_edge(clk) then
			RS_1 <= RS_0;
			RS_2 <= RS_1;
		end if;
	end process;

	process (rst, RS_2)
	begin
		if rst = '1' then
			cpt_t <= 0;
		elsif rising_edge(RS_2) then
			if EnableCountT = '1' then
				if cpt_t = 65535 then
					cpt_t <= 0;
				else
					cpt_t <= cpt_t + 1;
				end if;
			end if;
		end if;
	end process;

	cpt_trig <= std_logic_vector(to_unsigned(cpt_t, 16));
    Raz_chn<=not(EnableCountT);
end scurves_arch;
