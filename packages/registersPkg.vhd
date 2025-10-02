library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.devicesPkg.all;

package registersPkg is

    constant regsLen : natural := 32;

    type regMode_t is (ro, rw);
    
    type regSub_t is record
        rAddr  : integer;
        rBegin : integer;
        rEnd   : integer;
        rMode  : regMode_t;
    end record regSub_t;

    type regsRec_t is array(integer range <>) of regSub_t;

    type regsData_t is array(integer range <>) of std_logic_vector(regsLen-1 downto 0);

    function slvToAddr(sAddr: std_logic_vector) return integer;

    function addrToSlv(a: integer) return std_logic_vector;
    
    function readReg(reg: regsRec_t; r: regsData_t; a: integer) return std_logic_vector;
    
    function readReg(reg: regsRec_t; r: regsData_t; a: integer) return unsigned;
    
    function readReg(reg: regsRec_t; r: regsData_t; a: integer) return devData_t;
    
    procedure writeReg(constant reg : in regsRec_t;
                       signal   r   : out regsData_t;
                       constant a   : in integer;
                       constant val : in devData_t);
    
    procedure writeReg(constant reg : in regsRec_t;
                       signal   r   : out regsData_t;
                       constant a   : in integer;
                       constant val : in std_logic_vector(regsLen-1 downto 0));
    
    procedure writeReg(constant reg : in regsRec_t;
                       signal   r   : out regsData_t;
                       constant a   : in integer;
                       constant val : in unsigned);
    
    procedure writeReg(constant reg : in regsRec_t;
                       signal   r   : out regsData_t;
                       constant a   : in integer;
                       constant val : in integer);
    
    procedure clearReg(constant reg : in regsRec_t;
                       signal   r   : out regsData_t;
                       constant a   : in  integer);
    
    function isSet(reg: regsRec_t; r: regsData_t; a: integer) return boolean;
    
    function isSet(reg: regsRec_t; r: regsData_t; a: integer) return std_logic;
    
    function isSet(reg: regsRec_t; r: regsData_t; a: integer; bitPos: integer) return boolean;

end package registersPkg;

package body registersPkg is

        function slvToAddr(sAddr: std_logic_vector) return integer is
        begin
            return to_integer(unsigned(sAddr));
        end function slvToAddr;
        
        function addrToSlv(a: integer) return std_logic_vector is
        begin
            return std_logic_vector(to_unsigned(a, regsLen));
        end function addrToSlv;
        
        function readReg(reg: regsRec_t; r: regsData_t; a: integer) return std_logic_vector is
        begin
            return std_logic_vector(resize(unsigned(r(reg(a).rAddr)(reg(a).rBegin downto reg(a).rEnd)), regsLen));
        end function readReg;
        
        function readReg(reg: regsRec_t; r: regsData_t; a: integer) return unsigned is
        begin
            return resize(unsigned(r(reg(a).rAddr)(reg(a).rBegin downto reg(a).rEnd)), regsLen);
        end function readReg;
        
        function readReg(reg: regsRec_t; r: regsData_t; a: integer) return devData_t is
            variable regData : std_logic_vector(regsLen-1 downto 0);
            variable retData : devData_t;
        begin
            regData := std_logic_vector(resize(unsigned(r(reg(a).rAddr)(reg(a).rBegin downto reg(a).rEnd)), regsLen));

            for i in 0 to devDataBytes-1 loop
                retData(i) := regData(8*i+7 downto i*8);
            end loop;

            return retData;
        end function readReg;
        
        procedure writeReg(constant reg : in regsRec_t;
                           signal   r   : out regsData_t;
                           constant a   : in integer;
                           constant val : in devData_t) is
            constant regVal : std_logic_vector(regsLen-1 downto 0) := devDataToSlv(val);
            constant regLen : integer                              := reg(a).rBegin - reg(a).rEnd + 1;
        begin
            r(reg(a).rAddr)(reg(a).rBegin downto reg(a).rEnd) <= regVal(regLen-1 downto 0);
        end procedure writeReg;

        procedure writeReg(constant reg : in regsRec_t;
                           signal   r   : out regsData_t;
                           constant a   : in integer;
                           constant val : in std_logic_vector(regsLen-1 downto 0)) is
            variable regLen : integer := reg(a).rBegin - reg(a).rEnd + 1;
        begin
            r(reg(a).rAddr)(reg(a).rBegin downto reg(a).rEnd) <= val(regLen-1 downto 0);
        end procedure writeReg;
        
        procedure writeReg(constant reg : in regsRec_t;
                           signal   r   : out regsData_t;
                           constant a   : in integer;
                           constant val : in unsigned) is
            variable regVal : std_logic_vector(regsLen-1 downto 0) := std_logic_vector(resize(val,regsLen));
            variable regLen : integer := reg(a).rBegin - reg(a).rEnd + 1;
        begin
            r(reg(a).rAddr)(reg(a).rBegin downto reg(a).rEnd) <= regVal(regLen-1 downto 0);
        end procedure writeReg;
        
        procedure writeReg(constant reg : in regsRec_t;
                           signal   r   : out regsData_t;
                           constant a   : in integer;
                           constant val : in integer) is
            variable regVal : std_logic_vector(regsLen-1 downto 0) := std_logic_vector(to_unsigned(val,regsLen));
            variable regLen : integer := reg(a).rBegin - reg(a).rEnd + 1;
        begin
            r(reg(a).rAddr)(reg(a).rBegin downto reg(a).rEnd) <= regVal(regLen-1 downto 0);
        end procedure writeReg;
        
        procedure clearReg(constant reg : in regsRec_t;
                           signal   r   : out regsData_t;
                           constant a   : in  integer) is
        begin
            for i in reg(a).rBegin to reg(a).rEnd loop
                r(reg(a).rAddr)(i) <= '0';
            end loop;
        end procedure clearReg;
        
        function isSet(reg: regsRec_t; r: regsData_t; a: integer) return boolean is
        begin
            return r(reg(a).rAddr)(reg(a).rBegin) = '1';
        end function isSet;
        
        function isSet(reg: regsRec_t; r: regsData_t; a: integer) return std_logic is
        begin
            return r(reg(a).rAddr)(reg(a).rBegin);
        end function isSet;
        
        function isSet(reg: regsRec_t; r: regsData_t; a: integer; bitPos: integer) return boolean is
            variable regLen : integer := reg(a).rBegin - reg(a).rEnd + 1;
            variable regVal : std_logic_vector(regLen-1 downto 0) := r(reg(a).rAddr)(reg(a).rBegin downto reg(a).rEnd);
        begin
            return regVal(bitPos) = '1';
        end function isSet;

end package body;