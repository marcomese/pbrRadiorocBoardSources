library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

package caenA7585DPkg is
    constant tInt            : std_logic_vector(7 downto 0) := x"00";
    constant tFloat          : std_logic_vector(7 downto 0) := x"03";

    constant regHVEn         : std_logic_vector(7 downto 0) := x"00";
    constant regMode         : std_logic_vector(7 downto 0) := x"01";
    constant regVTarget      : std_logic_vector(7 downto 0) := x"02";
    constant regRampSpeed    : std_logic_vector(7 downto 0) := x"03";
    constant regMaxV         : std_logic_vector(7 downto 0) := x"04";
    constant regMaxI         : std_logic_vector(7 downto 0) := x"05";
    constant regCTempM2      : std_logic_vector(7 downto 0) := x"07";
    constant regCTempM       : std_logic_vector(7 downto 0) := x"08";
    constant regCTempQ       : std_logic_vector(7 downto 0) := x"09";
    constant regAlfaVout     : std_logic_vector(7 downto 0) := x"0A";
    constant regAlfaIout     : std_logic_vector(7 downto 0) := x"0B";
    constant regAlfaVref     : std_logic_vector(7 downto 0) := x"0C";
    constant regAlfaTref     : std_logic_vector(7 downto 0) := x"0D";
    constant regTCoef        : std_logic_vector(7 downto 0) := x"1C";
    constant regLUTEn        : std_logic_vector(7 downto 0) := x"1D";
    constant regEnablePi     : std_logic_vector(7 downto 0) := x"1E";
    constant regEmrgStop     : std_logic_vector(7 downto 0) := x"1F";
    constant regIZero        : std_logic_vector(7 downto 0) := x"20";
    constant regLUTAddr      : std_logic_vector(7 downto 0) := x"24";
    constant regLUTProgT     : std_logic_vector(7 downto 0) := x"25";
    constant regLUTProgOV    : std_logic_vector(7 downto 0) := x"26";
    constant regLUTLength    : std_logic_vector(7 downto 0) := x"27";
    constant regI2CBaseAddr  : std_logic_vector(7 downto 0) := x"28";
    constant regCurrRange    : std_logic_vector(7 downto 0) := x"51";
    constant regPinStatus    : std_logic_vector(7 downto 0) := x"E5";
    constant regVIn          : std_logic_vector(7 downto 0) := x"E6";
    constant regVout         : std_logic_vector(7 downto 0) := x"E7";
    constant regIout         : std_logic_vector(7 downto 0) := x"E8";
    constant regVref         : std_logic_vector(7 downto 0) := x"E9";
    constant regTref         : std_logic_vector(7 downto 0) := x"EA";
    constant regVTargetOut   : std_logic_vector(7 downto 0) := x"EB";
    constant regRTarget      : std_logic_vector(7 downto 0) := x"EC";
    constant regCVT          : std_logic_vector(7 downto 0) := x"ED";
    constant regComplV       : std_logic_vector(7 downto 0) := x"F9";
    constant regComplI       : std_logic_vector(7 downto 0) := x"FA";
    constant regProdCode     : std_logic_vector(7 downto 0) := x"FB";
    constant regFWVer        : std_logic_vector(7 downto 0) := x"FC";
    constant regHWVer        : std_logic_vector(7 downto 0) := x"FD";
    constant regSerialNum    : std_logic_vector(7 downto 0) := x"FE";
    constant regStoreOnFlash : std_logic_vector(7 downto 0) := x"FF";

    function getDType(a: std_logic_vector) return std_logic_vector;

end package caenA7585DPkg;

package body caenA7585DPkg is

    function getDType(a: std_logic_vector) return std_logic_vector is
    begin
        case a is
            when regHVEn        | regMode      | regLUTEn     | regEnablePi     |
                 regEmrgStop    | regIZero     | regLUTAddr   | regLUTLength    |
                 regI2CBaseAddr | regCurrRange | regPinStatus | regComplV       |
                 regComplI      | regProdCode  | regSerialNum | regStoreOnFlash =>
                return tInt;
            when others =>
                return tFloat;
        end case;
    end function getDType;

end package body;