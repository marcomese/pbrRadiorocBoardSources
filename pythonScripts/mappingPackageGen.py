# -*- coding: utf-8 -*-
"""
Created on Wed Feb 11 15:09:27 2026

@author: Marco Mese
"""

import numpy as np

pixelmapFile = "pixelmapRadiorocMPPC_v1.txt"

packageFile = "..\\packages\\pixelMapPackage.vhd"

pmap = np.genfromtxt(pixelmapFile,
                     comments = ';',
                     delimiter = ',',
                     dtype=['U2','i4','f','f'],
                     names=['pixel','channel','x','y'])

pixelmap = {k : (v, ((int(v[1])-1), (ord(v[0])-ord('A'))), x, y)
            for (v,k,x,y) in pmap}

pixelToCh = {v[1] : k for k,v in pixelmap.items()}

pixelNameToPixel = {v[0] : v[1] for k,v in pixelmap.items()}

with open(packageFile, "w") as f:
    f.write("library ieee;\n")
    f.write("use ieee.std_logic_1164.all;\n\n")

    f.write("package pixelMappingPkg is\n")

    f.write("   constant nRows : integer := 8;\n\n")

    f.write("   constant nCols : integer := 8;\n\n")

    f.write("   type pixelmap_t is array(integer range <>, integer range <>)  of integer range 0 to (nRows*nCols)-1;\n\n")

    f.write("   type pixels_t is array(integer range <>, integer range <>)  of std_logic;\n\n")

    # f.write("    type pixelCols_t is "
    #         f"({', '.join([f'p{chr(i)}' for i in range(ord('A'),ord('H')+1,1)])});"
    #         "\n\n")

    # f.write(f"    type pixelRows_t is ({', '.join([f'p{n}' for n in range(1,9,1)])});\n\n")

    f.write("   constant pixelmap : pixelmap_t(0 to nRows-1, 0 to nCols-1) := (")
    f.write("\n        (")

    rowStr = ''
    for (r,c),value in sorted(pixelToCh.items()):
        f.write(f"{value:2d}")
        if c == 7 and r < 7:
            f.write("),\n        (")
        elif c == 7 and r == 7:
            f.write(")\n    );\n\n")
        else:
            f.write(", ")

    # f.write("    function pixel(c: pixelCols_t; r: pixelRows_t) return integer;\n\n")

    # f.write("    function pixel(c: integer; r: integer) return integer;\n\n")

    f.write('   function "and"(a : pixels_t; b : pixels_t) return pixels_t;\n\n')

    f.write("   function initPixels(rows: integer := nRows; cols: integer := nCols; initVal: std_logic := '0') return pixels_t;\n\n")

    f.write("   function slvToPixels(slv:  std_logic_vector;\n")
    f.write("                        rows: integer := nRows;\n")
    f.write("                        cols: integer := nCols) return pixels_t;\n")

    f.write("end package pixelMappingPkg;\n\n")

    f.write("package body pixelMappingPkg is\n")

    # f.write("    function pixel(c: pixelCols_t; r: pixelRows_t) return integer is\n")
    # f.write("    begin\n")
    # f.write("        return pixelmap(pixelCols_t'pos(c), pixelRows_t'pos(r)-1);\n")
    # f.write("    end function;\n\n")

    # f.write("    function pixel(c: integer; r: integer) return integer is\n")
    # f.write("    begin\n")
    # f.write("        return pixelmap(r,c);\n")
    # f.write("    end function;\n\n")

    f.write('   function "and"(a : pixels_t; b : pixels_t) return pixels_t is\n')
    f.write('       variable result : pixels_t;\n')
    f.write('   begin\n')
    f.write('       for r in 0 to nRows-1 loop\n')
    f.write('           for c in 0 to nCols-1 loop\n')
    f.write("               result(r, c) := a(r, c) and b(r, c);\n")
    f.write('           end loop;\n')
    f.write('       end loop;\n')
    f.write('       return result;\n')
    f.write('   end function;\n\n')

    f.write("   function initPixels(rows: integer := nRows; cols: integer := nCols; initVal: std_logic := '0') return pixels_t is\n")
    f.write("       variable result : pixels_t;\n")
    f.write("   begin\n")
    f.write("       for r in 0 to rows-1 loop\n")
    f.write("           for c in 0 to cols-1 loop\n")
    f.write("               result(r, c) := initVal;\n")
    f.write("           end loop;\n")
    f.write("       end loop;\n")
    f.write("       return result;\n")
    f.write("   end function;\n\n")

    f.write("   function slvToPixels(slv:  std_logic_vector;\n")
    f.write("                        rows: integer := nRows;\n")
    f.write("                        cols: integer := nCols) return pixels_t is\n")
    f.write("        variable res : pixels_t(0 to rows-1, 0 to cols-1);\n")
    f.write("    begin\n")
    f.write("        for r in 0 to rows-1 loop\n")
    f.write("            for c in 0 to cols-1 loop\n")
    f.write("                res(r, c) := slv(pixelmap(r, c));\n")
    f.write("            end loop;\n")
    f.write("        end loop;\n\n")
    f.write("        return res;\n")
    f.write("    end function;\n")
    f.write("end package body pixelMappingPkg;\n")

