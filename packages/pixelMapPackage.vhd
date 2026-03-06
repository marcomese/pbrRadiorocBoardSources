library ieee;
use ieee.std_logic_1164.all;

package pixelMappingPkg is
   constant nRows : integer := 8;

   constant nCols : integer := 8;

   type pixelmap_t is array(integer range <>, integer range <>)  of integer range 0 to (nRows*nCols)-1;

   type pixels_t is array(integer range <>, integer range <>)  of std_logic;

   constant pixelmap : pixelmap_t(0 to nRows-1, 0 to nCols-1) := (
        (53, 51, 62, 57, 49, 43, 45, 48),
        (58, 44, 47, 54, 50, 40, 41, 33),
        (13, 39, 61, 55, 46, 60, 42, 35),
        (26, 52, 63, 59, 38, 27, 22, 34),
        (31, 56, 32, 30, 36, 28, 24, 29),
        ( 8,  7, 10,  3, 25, 17, 37, 21),
        ( 4, 11,  6,  2, 18, 16, 14, 20),
        (23,  1,  5,  0,  9, 15, 12, 19)
    );

   function "and"(a : pixels_t; b : pixels_t) return pixels_t;

   function initPixels(rows: integer := nRows; cols: integer := nCols; initVal: std_logic := '0') return pixels_t;

   function slvToPixels(slv:  std_logic_vector;
                        rows: integer := nRows;
                        cols: integer := nCols) return pixels_t;
end package pixelMappingPkg;

package body pixelMappingPkg is
   function "and"(a : pixels_t; b : pixels_t) return pixels_t is
       variable result : pixels_t;
   begin
       for r in 0 to nRows-1 loop
           for c in 0 to nCols-1 loop
               result(r, c) := a(r, c) and b(r, c);
           end loop;
       end loop;
       return result;
   end function;

   function initPixels(rows: integer := nRows; cols: integer := nCols; initVal: std_logic := '0') return pixels_t is
       variable result : pixels_t;
   begin
       for r in 0 to rows-1 loop
           for c in 0 to cols-1 loop
               result(r, c) := initVal;
           end loop;
       end loop;
       return result;
   end function;

   function slvToPixels(slv:  std_logic_vector;
                        rows: integer := nRows;
                        cols: integer := nCols) return pixels_t is
        variable res : pixels_t(0 to rows-1, 0 to cols-1);
    begin
        for r in 0 to rows-1 loop
            for c in 0 to cols-1 loop
                res(r, c) := slv(pixelmap(r, c));
            end loop;
        end loop;

        return res;
    end function;
end package body pixelMappingPkg;
