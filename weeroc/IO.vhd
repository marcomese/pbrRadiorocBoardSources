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
    T : out std_logic_vector(63 downto 0);
    readRq   : in std_logic;
    readRq_p : out std_logic;
    readRq_n : out std_logic;
    cs       : out std_logic;
    cs_p     : in std_logic;
    cs_n     : in std_logic;
    sclk     : out std_logic;
    sclk_p   : in std_logic;
    sclk_n   : in std_logic;
    mosi     : out std_logic;
    mosi_p   : in std_logic;
    mosi_n   : in std_logic;
    miso     : in std_logic;
    miso_p   : out std_logic;
    miso_n   : out std_logic
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

readRqOBUF: OBUFDS
port map(
    I  => readRq,
    O  => readRq_p,
    OB => readRq_n
);

csIBUF: IBUFDS
generic map(
    DIFF_TERM => TRUE
)
port map(
    O  => cs,
    I  => cs_p,
    IB => cs_n
);

sclkIBUF: IBUFDS
generic map(
    DIFF_TERM => TRUE
)
port map(
    O  => sclk,
    I  => sclk_p,
    IB => sclk_n
);

mosiIBUF: IBUFDS
generic map(
    DIFF_TERM => TRUE
)
port map(
    O  => mosi,
    I  => mosi_p,
    IB => mosi_n
);

misoOBUT: OBUFDS
port map(
    I  => miso,
    O  => miso_p,
    OB => miso_n
);

end Behavioral;
