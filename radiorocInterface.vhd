----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: radiorocInterface
-- Create Date: 04.02.2025 19:02:38
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
use work.utilsPkg.all;
use work.devicesPkg.all;

entity radiorocInterface is
generic(
    chipID     : std_logic_vector(3 downto 0);
    maxBrstLen : natural
);
port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    devExec    : in  std_logic;
    devId      : in  devices_t;
    devRw      : in  std_logic;
    devBurst   : in  std_logic;
    devAddr    : in  devAddr_t;
    devDataIn  : in  devData_t;
    devDataOut : out devData_t;
    devReady   : out std_logic;
    busy       : out std_logic;
    i2cEnClk   : out std_logic;
    i2cEna     : out std_logic;
    i2cAddr    : out std_logic_vector(6 downto 0);
    i2cRw      : out std_logic;
    i2cDataWr  : out std_logic_vector(7 downto 0);
    i2cBusy    : in  std_logic;
    i2cDataRd  : in  std_logic_vector(7 downto 0)
);
end radiorocInterface;

architecture Behavioral of radiorocInterface is

type state_t is (idle,
                 waitReady,
                 store);

constant readCmd    : std_logic := '1';

signal   state      : state_t;

signal   dataReady,
         rw,
         brst,
         brstOn,
         exec,
         busyRad    : std_logic;

signal   rAddr      : devAddr_t;

signal   dataOut    : devData_t;

signal   dataIn     : devData_t;

begin

radioFSM: process(clk, rst, devExec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            exec       <= '0';
            rw         <= readCmd;
            brst       <= '0';
            rAddr      <= (others => (others => '0'));
            devReady   <= '0';
            busy       <= '0';
            i2cEnClk   <= '0';
            devDataOut <= (others => (others => '0'));

            state      <= idle;
        else
            case state is
                when idle =>
                    if devExec = '1' and devId = radioroc and busyRad = '0' then
                        exec     <= '1';
                        rw       <= devRw;
                        brst     <= devBurst;
                        rAddr    <= devAddr;
                        dataIn   <= devDataIn;
                        devReady <= '0';
                        busy     <= '1';
                        i2cEnClk <= '1';

                        state    <= waitReady;
                    else
                        devReady <= '0';
                        busy     <= '0';
                        i2cEnClk <= '0';

                        state    <= idle;
                    end if;

                when waitReady =>
                    if dataReady = '1' and brstOn = '0' then
                        exec  <= '0';

                        state <= store;
                    elsif dataReady = '1' and brstOn = '1' then
                        exec     <= '0';
                        devReady <= '1';

                        state    <= waitReady;
                    elsif brstOn = '0' then
                        exec     <= '0';
                        devReady <= '0';

                        state    <= waitReady;
                    elsif brstOn = '1' then
                        exec     <= devExec;
                        devReady <= '0';
                        dataIn   <= devDataIn;

                        state    <= waitReady;
                    end if;

                when store =>
                    devReady   <= '1';
                    busy       <= '0';
                    i2cEnClk   <= '0';
                    devDataOut <= dataOut;

                    state      <= idle;

                when others =>
                    exec     <= '0';
                    rw       <= readCmd;
                    brst     <= '0';
                    rAddr    <= (others => (others => '0'));
                    devReady <= '0';
                    busy     <= '0';
                    i2cEnClk <= '0';

                    state    <= idle;
            end case;
        end if;
    end if;
end process;


radioFSMInst: entity work.radiorocFSM
generic map(
    chipID     => chipID,
    maxBrstLen => maxBrstLen
)
port map(
    clk          => clk,
    rst          => rst,      
    exec         => exec,
    rw           => rw,
    brst         => brst,
    addr         => rAddr,
    dataIn       => dataIn,
    dataOut      => dataOut,
    busy         => busyRad,
    brstOn       => brstOn,
    dataReady    => dataReady,
    i2cEna       => i2cEna,
    i2cAddr      => i2cAddr,
    i2cRw        => i2cRw,
    i2cDataWr    => i2cDataWr,
    i2cBusy      => i2cBusy,
    i2cDataRd    => i2cDataRd
);

end Behavioral;
