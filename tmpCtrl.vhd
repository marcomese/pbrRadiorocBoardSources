----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: tmpCtrl
-- Create Date: 01.10.2025 15:04:18
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use work.utilsPkg.all;
use work.devicesPkg.all;
use work.registersPkg.all;

entity tmpCtrl is
generic(
    tmpAddr    : std_logic_vector(6 downto 0)
);
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    devExec    : in  std_logic;
    devId      : in  devices_t;
    devRw      : in  std_logic;
    devAddr    : in  devAddr_t;
    devDataIn  : in  devData_t;
    devDataOut : out devData_t;
    devReady   : out std_logic;
    busy       : out std_logic;
    i2cEna     : out std_logic;
    i2cAddr    : out std_logic_vector(6 downto 0);
    i2cRw      : out std_logic;
    i2cDataWr  : out std_logic_vector(7 downto 0);
    i2cBusy    : in  std_logic;
    i2cDataRd  : in  std_logic_vector(7 downto 0)
);
end tmpCtrl;

architecture Behavioral of tmpCtrl is

type state_t is (init,
                 idle,
                 waitReady);

signal state         : state_t;

signal dAddr         : integer;

signal   exec,
         dataReady,
         rw,
         busyTmp,
         loadDataOut,
         loadTmpFsm,
         locRst      : std_logic;

signal   rAddr       : std_logic_vector(7 downto 0);

signal   dataOut     : std_logic_vector(15 downto 0);

signal   dataIn,
         dataOut32   : std_logic_vector(31 downto 0);

begin

dAddr     <= devAddrToInt(devAddr);

dataOut32 <= x"00000" & dataOut(15 downto 4);

locRstProc: process(clk)
begin
    if rising_edge(clk) then
        locRst <= rst;
    end if;
end process;

devDataOutCtrl: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            devDataOut <= (others => (others => '0'));
        elsif loadDataOut = '1' then
            devDataOut <= slvToDevData(dataOut32);
        end if;
    end if;
end process;

tmpFsmCtrl: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            exec   <= '0';
            rw     <= devRead;
            rAddr  <= (others => '0');
            dataIn <= (others => '0');
        elsif loadTmpFsm = '1' then
            exec   <= '1';
            rw     <= devRw;
            rAddr  <= devAddr(0);
            dataIn <= devDataToSlv(devDataIn);
        else
            exec <= '0';
        end if;
    end if;
end process;

hvTmpFSM: process(clk)
begin
    if rising_edge(clk) then
        if locRst = '1' then
            devReady    <= '0';
            loadDataOut <= '0';
            loadTmpFsm  <= '0';
            busy        <= '1';

            state       <= init;
        else
            case state is
                when init =>
                    if busyTmp = '0' then
                        busy     <= '0';

                        state    <= idle;
                    else
                        state    <= init;
                    end if;

                when idle =>
                    devReady    <= '0';
                    loadDataOut <= '0';
                    loadTmpFsm  <= '0';
                    busy        <= '0';

                    state       <= idle;

                    if devExec = '1' and devId = tmp275 then
                        if dAddr = 0 and busyTmp = '0' then
                            loadTmpFsm <= '1';
                            busy       <= '1';
    
                            state      <= waitReady;
                        end if;
                    end if;

                when waitReady =>
                    loadTmpFsm  <= '0';

                    state       <= waitReady;

                    if dataReady = '1' then
                        devReady    <= '1';
                        loadDataOut <= '1';

                        state       <= idle;
                    end if;

                when others =>
                    devReady    <= '0';
                    loadDataOut <= '0';
                    loadTmpFsm  <= '0';

                    state       <= init;
            end case;
        end if;
    end if;
end process;

tempFSMInst: entity work.tmp275FSM
generic map(
    tmpAddr   => tmpAddr
)
port map(
    clk       => clk,
    rst       => locRst,
    exec      => exec,
    rw        => rw,
    addr      => rAddr,
    dataIn    => dataIn(15 downto 0),
    dataOut   => dataOut,
    busy      => busyTmp,
    dataReady => dataReady,
    i2cEna    => i2cEna,
    i2cAddr   => i2cAddr,
    i2cRw     => i2cRw,
    i2cDataWr => i2cDataWr,
    i2cBusy   => i2cBusy,
    i2cDataRd => i2cDataRd
);

end Behavioral;