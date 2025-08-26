library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

package utilsPkg is
    type byteArray_t is array(integer range <>) of std_logic_vector(7 downto 0);

    function refCMD(intRef: boolean) return std_logic_vector;

    function boolToStdLogic(val: boolean) return std_logic;
    
    function intToStdLogic(val: integer) return std_logic;

    function stdLogicToInt(val: std_logic) return integer;

    function slvToInt(val: std_logic_vector) return integer;

    function bitsNum(val: integer) return integer;

    function max(a,b: integer) return integer;

    function ones(size: integer) return std_logic_vector;

    function zeroes(size: integer) return std_logic_vector;

    function ones(size: integer) return unsigned;

    function zeroes(size: integer) return unsigned;

    function initSlv(lenSlv: integer; beginSlvVal: integer; endSlvVal: integer; slvVal: std_logic_vector; othSlv: std_logic) return std_logic_vector;
end package utilsPkg;

package body utilsPkg is

    function refCMD(intRef: boolean) return std_logic_vector is
    begin
        if intRef = True then
            return "0110";
        else
            return "0111";
        end if;
    end refCMD;

    function boolToStdLogic(val: boolean) return std_logic is
    begin
        if val = True then
            return '1';
        else
            return '0';
        end if;
    end boolToStdLogic;

    function intToStdLogic(val: integer) return std_logic is
    begin
        if val = 0 then
            return '0';
        else
            return '1';
        end if;
    end intToStdLogic;

    function stdLogicToInt(val: std_logic) return integer is
    begin
        if val = '0' then
            return 0;
        end if;

        return 1;
    end stdLogicToInt;

    function slvToInt(val: std_logic_vector) return integer is
    begin
        return to_integer(unsigned(val));
    end slvToInt;

    function bitsNum(val: integer) return integer is
    begin
        return integer(ceil(log2(real(val + 1))));
    end bitsNum;

    function max(a,b: integer) return integer is
    begin
        if a > b then
            return a;
        end if;

        return b;
    end max;

    function ones(size: integer) return std_logic_vector is
        variable slv : std_logic_vector(size-1 downto 0) := (others => '1');
    begin
        return slv;
    end ones;

    function zeroes(size: integer) return std_logic_vector is
        variable slv : std_logic_vector(size-1 downto 0) := (others => '0');
    begin
        return slv;
    end zeroes;

    function ones(size: integer) return unsigned is
        variable slv : unsigned(size-1 downto 0) := (others => '1');
    begin
        return slv;
    end ones;

    function zeroes(size: integer) return unsigned is
        variable slv : unsigned(size-1 downto 0) := (others => '0');
    begin
        return slv;
    end zeroes;

    function initSlv(lenSlv: integer; beginSlvVal: integer; endSlvVal: integer; slvVal: std_logic_vector; othSlv: std_logic) return std_logic_vector is
        variable slv : std_logic_vector(lenSlv-1 downto 0);
    begin
        for i in lenSlv-1 downto 0 loop
            slv(i) := othSlv;
        end loop;

        slv(beginSlvVal downto endSlvVal) := slvVal;

        return slv;
    end initSlv;

end package body;