----------------------------------------------------------------------------------
-- PBR Cherenkov Telescope MPPC acquisition board
--
-- Module Name: devicesPkg
-- Create Date: 12.12.2024 16:18:19
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

package devicesPkg is

    type devices_t is (none,
                       tmp275,
                       a7585d,
                       radioroc,
                       pulseGen,
                       dataReg,
                       acqSystem);

    constant  devDataBytes : integer   := 4;
    constant  devAddrBytes : integer   := 2;
    constant  devWrite     : std_logic := '0';
    constant  devRead      : std_logic := '1';

    type devAddr_t    is array(devAddrBytes-1 downto 0)         of std_logic_vector(7 downto 0);
    type devData_t    is array(devDataBytes-1 downto 0)         of std_logic_vector(7 downto 0);
    type devDataVec_t is array(devices_t'low to devices_t'high) of devData_t;
    type devReady_t   is array(devices_t'low to devices_t'high) of std_logic;
    type devBusy_t    is array(devices_t'low to devices_t'high) of std_logic;

    function devToSlv(d: devices_t) return std_logic_vector;

    function slvToDev(s: std_logic_vector) return devices_t;

    function devAddrToSlv(a: devAddr_t) return std_logic_vector;

    function devAddrToInt(a: devAddr_t) return integer;

    function devDataToSlv(d: devData_t) return std_logic_vector;

    function devDataToSlice(d: devData_t; left: integer; right: integer) return std_logic_vector;
end package devicesPkg;

package body devicesPkg is

    function devToSlv(d: devices_t) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(devices_t'pos(d),8));
    end function devToSlv;

    function slvToDev(s: std_logic_vector) return devices_t is
        variable sInt : integer;
    begin
        sInt := to_integer(unsigned(s));

        if sInt > devices_t'pos(devices_t'high) then
            return none;
        end if;
            
        return devices_t'val(sInt);
    end function slvToDev;

    function devAddrToSlv(a: devAddr_t) return std_logic_vector is
        variable sAddr : std_logic_vector(devAddrBytes*8-1 downto 0);
    begin
        for i in 0 to devAddrBytes-1 loop
            sAddr(8*i+7 downto 8*i) := a(i);
        end loop;
        
        return sAddr;
    end function devAddrToSlv;

    function devAddrToInt(a: devAddr_t) return integer is
        variable sAddr : std_logic_vector(devAddrBytes*8-1 downto 0);
    begin
        for i in 0 to devAddrBytes-1 loop
            sAddr(8*i+7 downto 8*i) := a(i);
        end loop;
        
        return to_integer(unsigned(sAddr));
    end function devAddrToInt;


    function devDataToSlv(d: devData_t) return std_logic_vector is
        variable sData : std_logic_vector(devDataBytes*8-1 downto 0);
    begin
        for i in 0 to devDataBytes-1 loop
            sData(8*i+7 downto 8*i) := d(i);
        end loop;
        
        return sData;
    end function devDataToSlv;

    function devDataToSlice(d: devData_t; left: integer; right: integer) return std_logic_vector is
        variable sData : std_logic_vector(devDataBytes*8-1 downto 0);
    begin
        for i in 0 to devDataBytes-1 loop
            sData(8*i+7 downto 8*i) := d(i);
        end loop;
        
        return sData(left downto right);
    end function devDataToSlice;

end package body;
