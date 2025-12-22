library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;

entity multi_acq is
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

	type state_t is (idle, rst1, rst2, acq, nxt, rst_acq, finish);
	signal current_state, next_state : state_t;
	
	signal cpt_acq, nb_acq_nat : natural range 0 to 255;

begin

	nb_acq_nat <= to_integer(unsigned(nb_acq));

	process(rst, clk_200M)
	begin
	if rst = '1' then
		current_state <= idle;
		cpt_acq <= 0;
	elsif rising_edge(clk_200M) then
		current_state <= next_state;
		if current_state = idle then
			cpt_acq <= 0;
		elsif current_state = nxt then
			cpt_acq <= cpt_acq + 1;
		end if;
	end if;
	end process;
	
	process(current_state, start, end_acq, cpt_acq)
	begin
		case(current_state) is 
			when idle => 
				if start = '1' then
					next_state <= rst1;
				else 
					next_state <= idle;
				end if;
			when rst1 =>
		          next_state <= rst2;
		      when rst2 => 
		          next_state <= acq;
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
					next_state <= rst_acq;
				end if;
		    when rst_acq =>
		         next_state <= acq;
			when finish =>
				next_state <= finish;
			when others =>
				next_state <= idle;
		end case;
	end process;
	
	process(current_state)
	begin
		case(current_state) is 
			when idle =>
				en_acq 		<= '0';
				end_multi_acq 	<= '0';
				rst_n <= '1';
		     when rst1 =>
				en_acq 		<= '0';
				end_multi_acq 	<= '0';
				rst_n <= '0';
			when rst2 =>
				en_acq 		<= '0';
				end_multi_acq 	<= '0';
				rst_n <= '0';
			when acq =>
				en_acq 		<= '1';
				end_multi_acq 	<= '0';
				rst_n <= '1';
			when nxt =>
				en_acq 		<= '1';
				end_multi_acq 	<= '0';
				rst_n <= '0';
			when rst_acq =>
			    en_acq 		<= '0';
				end_multi_acq 	<= '0';
				rst_n <= '0';
			when finish =>
				en_acq 		<= '0';
				end_multi_acq 	<= '1';
				rst_n <= '1';
			when others =>
				en_acq 		<= '0';
				end_multi_acq 	<= '0';
				rst_n <= '1';
		end case;
	end process;
				
	
end Behavioral;