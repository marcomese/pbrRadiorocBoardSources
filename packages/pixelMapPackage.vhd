library ieee;
use ieee.std_logic_1164.all;

package pixelMappingPkg is

    type pixelmap_t is array (0 to 7, 0 to 7) of integer range 0 to 63;

    constant pixelmap : pixelmap_t :=
    (
        ( 53, 58, 13, 26, 31,  8,  4, 23 ),
        ( 51, 44, 39, 52, 56,  7, 11,  1 ),
        ( 62, 47, 61, 63, 32, 10,  6,  5 ),
        ( 57, 54, 55, 59, 30,  3,  2,  0 ),
        ( 49, 50, 46, 38, 36, 25, 18,  9 ),
        ( 43, 40, 60, 27, 28, 17, 16, 15 ),
        ( 45, 41, 42, 22, 24, 37, 14, 12 ),
        ( 48, 33, 35, 34, 29, 21, 20, 19 )
    );

    function pixel(name : string) return integer;

end package pixelMappingPkg;

package body pixelMappingPkg is

    function pixel(name : string) return integer is
    begin
        case name is
            when "A1" => return 53;
            when "A2" => return 58;
            when "A3" => return 13;
            when "A4" => return 26;
            when "A5" => return 31;
            when "A6" => return 8;
            when "A7" => return 4;
            when "A8" => return 23;
            when "B1" => return 51;
            when "B2" => return 44;
            when "B3" => return 39;
            when "B4" => return 52;
            when "B5" => return 56;
            when "B6" => return 7;
            when "B7" => return 11;
            when "B8" => return 1;
            when "C1" => return 62;
            when "C2" => return 47;
            when "C3" => return 61;
            when "C4" => return 63;
            when "C5" => return 32;
            when "C6" => return 10;
            when "C7" => return 6;
            when "C8" => return 5;
            when "D1" => return 57;
            when "D2" => return 54;
            when "D3" => return 55;
            when "D4" => return 59;
            when "D5" => return 30;
            when "D6" => return 3;
            when "D7" => return 2;
            when "D8" => return 0;
            when "E1" => return 49;
            when "E2" => return 50;
            when "E3" => return 46;
            when "E4" => return 38;
            when "E5" => return 36;
            when "E6" => return 25;
            when "E7" => return 18;
            when "E8" => return 9;
            when "F1" => return 43;
            when "F2" => return 40;
            when "F3" => return 60;
            when "F4" => return 27;
            when "F5" => return 28;
            when "F6" => return 17;
            when "F7" => return 16;
            when "F8" => return 15;
            when "G1" => return 45;
            when "G2" => return 41;
            when "G3" => return 42;
            when "G4" => return 22;
            when "G5" => return 24;
            when "G6" => return 37;
            when "G7" => return 14;
            when "G8" => return 12;
            when "H1" => return 48;
            when "H2" => return 33;
            when "H3" => return 35;
            when "H4" => return 34;
            when "H5" => return 29;
            when "H6" => return 21;
            when "H7" => return 20;
            when "H8" => return 19;
            when others =>
                report "Invalid pixel name" severity failure;
                return 0;
        end case;
    end function;

end package body pixelMappingPkg;
