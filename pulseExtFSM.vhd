----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: pulseExtFSM
-- Create Date: 18.09.2025 11:26:50
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
use work.utilsPkg.bitsNum;

entity pulseExtFSM is
generic(
    syncStages  : integer;
    clkOrigFreq : real;
    clkDestFreq : real
);
port(
    clkOrig     : in  std_logic;
    rstOrig     : in  std_logic;
    clkDest     : in  std_logic;
    rstDest     : in  std_logic;
    sigOrig     : in  std_logic;
    sigDest     : out std_logic
);
end pulseExtFSM;

architecture Behavioral of pulseExtFSM is

type state_t is (idle,
                 pulseOn);

constant cntVal   : integer := integer(clkOrigFreq/clkDestFreq);

constant cntWidth : integer := bitsNum(cntVal);

signal   state    : state_t;

signal   pCnt     : unsigned(cntWidth downto 0);

signal   endCnt,
         pSig,
         sOrigO,
         sOrigR   : std_logic;

signal   syncFF   : std_logic_vector(syncStages-1 downto 0);

begin

endCnt <= pCnt(pCnt'left);

sOrigR <= sigOrig and not sOrigO;

noSyncStages: if syncStages = 0 generate
begin
    sigDest <= pSig;
end generate;

nSyncStages: if syncStages > 0 generate
begin
    sigDest    <= syncFF(syncFF'left);

    syncProc: process(clkDest, rstDest)
    begin
        if rising_edge(clkDest) then
            if rstDest = '1' then
                syncFF <= (others => '0');
            else
                syncFF(0) <= pSig;

                for n in 1 to syncStages-1 loop
                    syncFF(n) <= syncFF(n-1);
                end loop;
            end if;
        end if;
    end process;
end generate;

pulseFSM: process(clkOrig, rstOrig)
begin
    if rising_edge(clkOrig) then
        if rstOrig = '1' then
            pSig  <= '0';
            pCnt  <= to_unsigned(cntVal-1, pCnt'length);

            state <= idle;
        else
            sOrigO <= sigOrig;

            case state is
                when idle =>
                    state <= idle;

                    if sOrigR = '1' then
                        pCnt  <= pCnt - 1;
                        pSig  <= '1';

                        state <= pulseOn;
                    end if;

                when pulseOn =>
                    pCnt  <= pCnt - 1;

                    state <= pulseOn;

                    if endCnt = '1' then
                        pSig  <= '0';
                        pCnt  <= to_unsigned(cntVal-1, pCnt'length);

                        state <= idle;
                    end if;

                when others =>
                    pSig  <= '0';
                    pCnt  <= to_unsigned(cntVal-1, pCnt'length);

                    state <= idle;
            end case;
        end if;
    end if;
end process;

end Behavioral;
