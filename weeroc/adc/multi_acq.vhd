-------------------------------------------------------------------------------
-- multi_acq
--
-- Sequences the acquisitions and drives the RADIOROC reset (rst_n).
--
-- rev 0.02:
--   * the ASIC reset after each event is held for RST_CYCLES clock cycles
--     (was 2 cycles = 10 ns, below the 20 ns required by the RADIOROC2
--     datasheet to reset the peak detectors and the delay cell)
--   * after the reset is released en_acq stays low for MASK_CYCLES clock
--     cycles, so the transient produced by the reset on the ASIC trigger
--     outputs can no longer start a new acquisition (it produced a spurious
--     event ~28 us after each real one)
--   * en_acq is low in nxt (it was high while rst_n was already low)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;

entity multi_acq is
	Generic (
		RST_CYCLES  : natural := 8;    -- ASIC reset width, 40 ns at 200 MHz (min 20 ns)
		MASK_CYCLES : natural := 400   -- trigger mask after reset, 2 us
	);
	Port (
		rst 	 : in std_logic;
		clk_200M : in std_logic;
		start	 : in std_logic;
		end_acq  : in std_logic;
		nb_acq 	 : in std_logic_vector(7 downto 0);
		en_acq : out std_logic;
		end_multi_acq : out std_logic;
		rst_n      : out std_logic
	);
end multi_acq;

architecture Behavioral of multi_acq is

	type state_t is (idle, rstAsic, settle, acq, nxt, finish);
	signal current_state, next_state : state_t;

	signal cpt_acq, nb_acq_nat : natural range 0 to 255;

	signal tmr     : natural range 0 to RST_CYCLES + MASK_CYCLES;
	signal tmrClr  : std_logic;
	signal rstDone : std_logic;
	signal mskDone : std_logic;

begin

	nb_acq_nat <= to_integer(unsigned(nb_acq));

	rstDone <= '1' when tmr >= RST_CYCLES - 1 else '0';
	mskDone <= '1' when tmr >= MASK_CYCLES - 1 else '0';

	tmrClr <= '1' when current_state /= next_state else '0';

	process(rst, clk_200M)
	begin
	if rst = '1' then
		current_state <= idle;
		cpt_acq <= 0;
		tmr <= 0;
	elsif rising_edge(clk_200M) then
		current_state <= next_state;

		if tmrClr = '1' then
			tmr <= 0;
		elsif tmr < RST_CYCLES + MASK_CYCLES then
			tmr <= tmr + 1;
		end if;

		if current_state = idle then
			cpt_acq <= 0;
		elsif current_state = nxt then
			cpt_acq <= cpt_acq + 1;
		end if;
	end if;
	end process;

	process(current_state, start, end_acq, cpt_acq, nb_acq_nat, rstDone, mskDone)
	begin
		case(current_state) is
			when idle =>
				if start = '1' then
					next_state <= rstAsic;
				else
					next_state <= idle;
				end if;
			when rstAsic =>
				if rstDone = '1' then
					next_state <= settle;
				else
					next_state <= rstAsic;
				end if;
			when settle =>
				if mskDone = '1' then
					next_state <= acq;
				else
					next_state <= settle;
				end if;
			when acq =>
				if end_acq = '1' then
					next_state <= nxt;
				else
					next_state <= acq;
				end if;
			when nxt =>
				if cpt_acq = nb_acq_nat then
					next_state <= finish;
				else
					next_state <= rstAsic;
				end if;
			when finish =>
				next_state <= finish;
			when others =>
				next_state <= idle;
		end case;
	end process;

	process(current_state)
	begin
		en_acq        <= '0';
		end_multi_acq <= '0';
		rst_n         <= '1';

		case(current_state) is
			when rstAsic =>
				rst_n <= '0';
			when acq =>
				en_acq <= '1';
			when finish =>
				end_multi_acq <= '1';
			when others =>
				null;
		end case;
	end process;

end Behavioral;
