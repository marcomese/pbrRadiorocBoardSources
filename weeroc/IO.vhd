library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity IO is
  Port ( 
    ADC_SCKHG : in std_logic;
    ADC_SCKLG : in std_logic;
    ADC_HG    : out std_logic;
    ADC_LG    : out std_logic;
    T_p     : in std_logic_vector(63 downto 0);
    T_n : in std_logic_vector(63 downto 0);
    ADC_SCKHG_p : out std_logic;
    ADC_SCKHG_n : out std_logic;
    ADC_SCKLG_p : out std_logic;
    ADC_SCKLG_n : out std_logic;
    ADC_HG_p    : in std_logic;
    ADC_HG_n    : in std_logic;
    ADC_LG_p : in std_logic;
    ADC_LG_n : in std_logic;
    T : out std_logic_vector(63 downto 0)
  );
end IO;

architecture Behavioral of IO is

begin

TRIG : for I in 0 to 63 generate
   IBUF : IBUFDS_DIFF_OUT
   Generic map (
   DIFF_TERM => TRUE
   )
   Port map (
   OB => T(I),--O => T(I) pour radio OB => T(I) pour psiroc
   I => T_p(I),
   IB => T_n(I)
   );
end generate;

OBUF2 : OBUFDS
Port map (
    I => ADC_SCKHG ,
    O => ADC_SCKHG_p,
    OB => ADC_SCKHG_n
    );
   
OBUF3 : OBUFDS
Port map (
    I => ADC_SCKLG ,
    O => ADC_SCKLG_p,
    OB => ADC_SCKLG_n
    );
    
IBUF4 : IBUFDS
Generic map (
DIFF_TERM => TRUE
)
Port map (
    O => ADC_HG ,
    I => ADC_HG_p,
    IB => ADC_HG_n
    );
    
IBUF5 : IBUFDS
Generic map (
DIFF_TERM => TRUE
)
Port map (
    O => ADC_LG ,
    I => ADC_LG_p,
    IB => ADC_LG_n
    );

end Behavioral;
