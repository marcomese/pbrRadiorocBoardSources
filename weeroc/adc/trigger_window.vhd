library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity trigger_window is 
Port ( 
    clk : in std_logic;
    t0  : in std_logic;
    t1  : in std_logic;
    window_size : in std_logic_vector(7 downto 0);
    tout : out std_logic
);
end trigger_window;

architecture Behavioral of trigger_window is

    signal cpt0, cpt1, wdw_s : natural range 0 to 127;
    signal valid0, valid1 : std_logic;
    

begin

    wdw_s <= to_integer(unsigned(window_size));
    tout <= valid0 and valid1;
    
    process(t0, clk)
    begin
    if t0 = '0' then
        valid0 <= '1';
        cpt0 <= 0;
    elsif rising_edge(clk) then
        if cpt0 = wdw_s then
            valid0 <= '0';
            cpt0 <= 0;
        else
            cpt0 <= cpt0 + 1;
        end if;
    end if;
    end process;
    
    process(t1, clk)
    begin
    if t1 = '0' then
        valid1 <= '1';
        cpt1 <= 0;
    elsif rising_edge(clk) then
        if cpt1 = wdw_s then
            valid1 <= '0';
            cpt1 <= 0;
        else
            cpt1 <= cpt1 + 1;
        end if;
   end if;
   end process;
    

end Behavioral;
