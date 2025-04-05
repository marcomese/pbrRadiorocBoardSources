----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: dacSerialInterface
-- Create Date: 03.09.2024 15:14:12
-- Target Devices: Artix 7 xc7a200tfbg484-2
--
-- Created by: Marco Mese
--
-- Revision:
-- Revision 0.01 - File Created
-- Revision 0.02 - Converted to Mealy FSM
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.utilsPkg.all;

entity dacSerialInterface is
port(
    clk      : in  std_logic;
    rst      : in  std_logic;
    send     : in  std_logic;
    dacCmd   : in  std_logic_vector(3 downto 0);
    dacValue : in  std_logic_vector(11 downto 0);
    dacBusy  : out std_logic;
    dacSDI   : out std_logic;
    dacSCLK  : out std_logic;
    dacCS    : out std_logic
);
end dacSerialInterface;

architecture Behavioral of dacSerialInterface is

type state_t is (idle,
                 loadBit,
                 sendBit);

constant frameLen   : integer := 24;

signal   state      : state_t;
signal   bitCounter : unsigned(bitsNum(frameLen) downto 0);
signal   frame      : std_logic_vector(frameLen-1 downto 0);
signal   endFrame   : std_logic;

begin

endFrame <= bitCounter(bitCounter'left);

dacSerialFSM: process(clk, rst, send, endFrame, dacCmd, dacValue)
begin
    if rising_edge(clk) then
        if rst = '1' then
            frame      <= (others => '0');
            dacSDI     <= '0';
            dacSCLK    <= '0';
            dacCS      <= '1';
            dacBusy    <= '0';
            bitCounter <= to_unsigned(frameLen-1, bitCounter'length);

            state      <= idle;
        else
            case state is
                when idle =>
                    if send = '1' then
                        frame   <= dacCmd   &
                                   "0000"   &
                                   dacValue &
                                   "0000";
                        dacSDI  <= frame(to_integer(bitCounter));
                        dacCS   <= '0';
                        dacBusy <= '1';

                        state   <= loadBit;
                    else
                        state <= idle;
                    end if;

                when loadBit =>
                    bitCounter <= bitCounter - 1;
                    dacSCLK    <= '1';

                    state      <= sendBit;

                when sendBit =>
                    if endFrame = '1' then
                        dacSDI     <= '0';
                        dacSCLK    <= '0';
                        dacCS      <= '1';
                        dacBusy    <= '0';
                        bitCounter <= to_unsigned(frameLen-1, bitCounter'length);

                        state      <= idle;
                    else
                        dacSDI  <= frame(to_integer(bitCounter));
                        dacSCLK <= '0';

                        state   <= loadBit;
                    end if;

                when others =>
                    frame      <= (others => '0');
                    dacSDI     <= '0';
                    dacSCLK    <= '0';
                    dacCS      <= '1';
                    dacBusy    <= '0';
                    bitCounter <= to_unsigned(frameLen-1, bitCounter'length);

                    state      <= idle;
            end case;
        end if;
    end if;
end process;

end Behavioral;
