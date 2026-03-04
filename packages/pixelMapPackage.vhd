library ieee;
use ieee.std_logic_1164.all;

package pixelMappingPkg is
    type pixelmap_t is array (0 to 7, 0 to 7) of integer range 0 to 63;

    type pixelCols_t is (pA, pB, pC, pD, pE, pF, pG, pH);

    type pixelRows_t is (p1, p2, p3, p4, p5, p6, p7, p8);

    constant pixelmap : pixelmap_t := (
        (53, 58, 13, 26, 31,  8,  4, 23),
        (51, 44, 39, 52, 56,  7, 11,  1),
        (62, 47, 61, 63, 32, 10,  6,  5),
        (57, 54, 55, 59, 30,  3,  2,  0),
        (49, 50, 46, 38, 36, 25, 18,  9),
        (43, 40, 60, 27, 28, 17, 16, 15),
        (45, 41, 42, 22, 24, 37, 14, 12),
        (48, 33, 35, 34, 29, 21, 20, 19)
    );

    function pixel(c: pixelCols_t; r: pixelRows_t) return integer;

    function pixel(c: integer; r: integer) return integer;

end package pixelMappingPkg;

package body pixelMappingPkg is

    function pixel(c: pixelCols_t; r: pixelRows_t) return integer is
    begin
        return pixelmap(pixelCols_t'pos(c), pixelRows_t'pos(r)-1);
    end function;

    function pixel(c: integer; r: integer) return integer is
    begin
        return pixelmap(c, r-1);
    end function;
end package body pixelMappingPkg;
