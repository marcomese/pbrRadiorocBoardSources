library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.utilsPkg.all;

entity edgeDetector is
generic(
    inputFF     : integer;
    edge        : string;
    inputRstVal : std_logic := '0';
    extenderFF  : integer   := 0
);
port(
    clk      : in  std_logic;
    rst      : in  std_logic;
    signalIn : in  std_logic;
    edgeOut  : out std_logic;
    syncOut  : out std_logic;
    nExtFF   : in  std_logic_vector(bitsNum(extenderFF,1)-1 downto 0)
);
end edgeDetector;

architecture Behavioral of edgeDetector is

signal sync,
       edgeSig : std_logic;

signal ff      : std_logic_vector(inputFF downto 0);

begin

noInFFGen: if inputFF = 0 generate
begin
    sync    <= signalIn;

    ffProc: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ff(0) <= inputRstVal;
            else
                ff(0) <= sync;
            end if;
        end if;
    end process;
end generate;

inFFGen: if inputFF > 0 generate
begin
    sync    <= ff(1);

    fLeftProc: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ff <= (others => inputRstVal);
            else
                ff <= signalIn & ff(ff'left downto 1);
            end if;
        end if;
    end process;
end generate;

risingEdgeGen: if edge = "rising" generate
begin
    edgeSig <= sync and not ff(0);
end generate;

fallingEdgeGen: if edge = "falling" generate
begin
    edgeSig <= not sync and ff(0);
end generate;

noShapGen: if extenderFF = 0 generate
begin
    edgeOut <= edgeSig;
    syncOut <= sync;
end generate;

shapGen: if extenderFF > 0 generate
    signal ffMux   : std_logic;
    signal ffDelay : std_logic_vector(extenderFF-2 downto 0); -- one clock cycles is lost in the mux
begin

    ffMuxInst: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ffMux <= '0';
            elsif unsigned(nExtFF) = 0 or unsigned(nExtFF) = 1 then
                ffMux <= edgeSig;
            elsif unsigned(nExtFF) > extenderFF then
                ffMux <= ffDelay(ffDelay'left);
            else
                ffMux <= ffDelay(slvToInt(nExtFF)-2);
            end if;
        end if;
    end process;

    extInst: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                edgeOut <= '0';
            elsif edgeSig = '1' and ffMux = '0' then
                edgeOut <= '1';
            elsif edgeSig = '0' and ffMux = '1' then
                edgeOut <= '0';
            elsif edgeSig = '1' and ffMux = '1' then
                edgeOut <= '0';
            end if;
        end if;
    end process;

    ffDelInst: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ffDelay <= (others => '0');
                syncOut <= '0';
            else
                ffDelay <= ffDelay(ffDelay'left-1 downto 0) & edgeSig;
                syncOut <= sync;
            end if;
        end if;
    end process;
end generate;

end Behavioral;