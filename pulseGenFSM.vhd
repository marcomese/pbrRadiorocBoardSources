----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: pulseGenFSM
-- Create Date: 31.10.2025 09:54:25
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
--
------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.utilsPkg.all;

entity pulseGenFSM is
port(
    clk     : in  std_logic;
    rst     : in  std_logic;
    en      : in  std_logic;
    period  : in  std_logic_vector(31 downto 0);
    width   : in  std_logic_vector(31 downto 0);
    pulsing : out std_logic;
    pulse   : out std_logic
);
end pulseGenFSM;

architecture Behavioral of pulseGenFSM is

type state_t is (idle,
                 pulseOn,
                 pulseOff);

signal state     : state_t;
signal endOnCnt,
       endOffCnt,
       start     : std_logic;
signal wBuff,
       tBuff     : unsigned(31 downto 0);
signal onCnt,
       offCnt    : unsigned(32 downto 0);

begin

endOnCnt  <= onCnt(32);
endOffCnt <= offCnt(32);

pGenFSM: process(clk, rst)
begin
    if rising_edge(clk) then
        if rst = '1' then
            pulse   <= '0';
            pulsing <= '0';
            wBuff   <= (others => '0');
            tBuff   <= (others => '0');
            onCnt   <= (others => '0');
            offCnt  <= (others => '0');

            state   <= idle;
        else
            case state is
                when idle =>
                    pulse   <= '0';
                    pulsing <= '0';
                    wBuff   <= unsigned(width);
                    tBuff   <= unsigned(period);

                    state   <= idle;

                    if en = '1' then
                        pulse   <= '1';
                        pulsing <= '1';

                        state   <= pulseOn;
                    end if;

                when pulseOn =>
                    pulse <= '1';
                    onCnt <= onCnt - 1;

                    state <= pulseOn;

                    if en = '0' then
                        pulse   <= '0';
                        pulsing <= '0';
                        onCnt   <= (others => '0');
                        offCnt  <= (others => '0');

                        state   <= idle;
                    elsif endOnCnt = '1' then
                        pulse  <= '0';
                        onCnt  <= '0' & wBuff-2;
                        offCnt <= '0' & tBuff-wBuff-2;

                        state  <= pulseOff;
                    end if;

                when pulseOff =>
                    pulse  <= '0';
                    offCnt <= offCnt - 1;

                    state  <= pulseOff;

                    if en = '0' then
                        pulse   <= '0';
                        pulsing <= '0';
                        onCnt   <= (others => '0');
                        offCnt  <= (others => '0');

                        state   <= idle;
                    elsif endOffCnt = '1' then
                        pulse  <= '1';
                        onCnt  <= '0' & wBuff-2;
                        offCnt <= '0' & tBuff-wBuff-2;

                        state  <= pulseOn;
                    end if;

                when others =>
                    pulse   <= '0';
                    pulsing <= '0';
                    wBuff   <= (others => '0');
                    tBuff   <= (others => '0');
                    onCnt   <= (others => '0');
                    offCnt  <= (others => '0');

                    state   <= idle;
            end case;
        end if;
    end if;
end process;

end Behavioral;
