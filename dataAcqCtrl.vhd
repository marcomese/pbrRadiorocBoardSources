----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: dataAcqCtrl
-- Create Date: 08.07.2025 15:47:20
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

entity dataAcqCtrl is
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
    resetAcq   : out std_logic;
    startAcq   : out std_logic;
    rdAcq      : out std_logic;
    endAcq     : in  std_logic;
    nbAcq      : out std_logic;
    selAdc     : out std_logic;
    doutAcq    : in  std_logic_vector(7 downto 0);
    emptyAcq   : in  std_logic;
    rdDCntAcq  : in  std_logic
);
end dataAcqCtrl;

architecture Behavioral of dataAcqCtrl is

begin

FSM: process(clk, rst, devExec)
begin
    if rising_edge(clk) then
        if rst = '1' then
            exec       <= '0';
            devReady   <= '0';
            busy       <= '0';
            devDataOut <= (others => (others => '0'));

            state      <= idle;
        else
            case state is
                when idle =>
                    if devExec = '1' and devId = acqSystem then
                        exec     <= '1';
                        dataIn   <= devDataIn;
                        devReady <= '0';
                        busy     <= '1';

                        state    <= waitReady;
                    else
                        devReady <= '0';
                        busy     <= '0';

                        state    <= idle;
                    end if;

                when waitReady =>
                    if dataReady = '1' then
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
                    rAddr    <= (others => (others => '0'));
                    devReady <= '0';
                    busy     <= '0';
                    i2cEnClk <= '0';

                    state    <= idle;
            end case;
        end if;
    end if;
end process;


end Behavioral;
