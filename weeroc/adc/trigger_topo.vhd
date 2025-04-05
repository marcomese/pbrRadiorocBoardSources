library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity trigger_topo is
Port ( 
    clk : in std_logic;
    NORT_FPGA : in std_logic;
    fast_clk : in std_logic;
    t : in std_logic_vector(63 downto 0);
    window_size : in std_logic_vector(7 downto 0);
    nb_trig : in std_logic_vector(5 downto 0);
    tout : out std_logic
    );
end trigger_topo;

architecture Behavioral of trigger_topo is

    function count_ones(input : std_logic_vector) return integer is
      variable r : natural := 0;
    begin
      for i in input'range loop
        if input(i) = '1' then r := r + 1; 
        end if;
      end loop;    
      return r;
    end function count_ones;

    signal wdw : std_logic;
    signal cpt, wdw_s : natural range 0 to 255;
    signal res : std_logic_vector(63 downto 0);
    signal sum, nb : natural range 0 to 63;

begin

    wdw_s <= to_integer(unsigned(window_size));
    nb <= to_integer(unsigned(nb_trig));

    process(NORT_FPGA, clk)
    begin
    if NORT_FPGA = '0' then
        wdw <= '1';
    elsif rising_edge(clk) then
        if cpt = wdw_s then
            wdw <= '0';
            cpt <= 0;
        else 
            cpt <= cpt + 1;
        end if;
    end if;
    end process;
    
    gen0 :  for I in 0 to 63 generate 
        process(wdw, fast_clk)
        begin
            if wdw = '0' then
                res(I) <= '0';
            elsif rising_edge(fast_clk) then
                if t(I) = '0' then
                    res(I) <= '1';
                end if;
            end if;
        end process;   
--        process(wdw, t(I))
--        begin
--            if wdw = '0' then
--                res(I) <= '0';
--            elsif falling_edge(t(I)) then
--                res(I) <= '1';
--            end if;
--        end process;
    end generate;
    
    process(clk)
    begin
    if rising_edge(clk) then
        sum <= count_ones(res);
    end if;
    end process;

    tout <= '0' when sum < nb else '1';

end Behavioral;
