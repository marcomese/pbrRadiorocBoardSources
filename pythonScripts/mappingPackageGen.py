# -*- coding: utf-8 -*-
"""
Created on Wed Feb 11 15:09:27 2026

@author: LabSpazio
"""

import numpy as np

pixelmapFile = "pixelmapRadiorocMPPC_v1.txt"

packageFile = "..\\packages\\pixelMapPackage.vhd"

pmap = np.genfromtxt(pixelmapFile,
                     comments = ';',
                     delimiter = ',',
                     dtype=['U2','i4','f','f'],
                     names=['pixel','channel','x','y'])

pixelmap = {k : (v, ((ord(v[0])-ord('A')), (int(v[1])-1)))
            for (v,k,x,y) in pmap}

pixelToCh = {v[1] : k for k,v in pixelmap.items()}

pixelNameToPixel = {v[0] : v[1] for k,v in pixelmap.items()}

matrix = [[None for _ in range(8)] for _ in range(8)]
for (x, y), value in pixelToCh.items():
    row = x
    col = y
    matrix[row][col] = int(value)

with open(packageFile, "w") as f:
    f.write("library ieee;\n")
    f.write("use ieee.std_logic_1164.all;\n\n")

    f.write("package pixelMappingPkg is\n\n")

    f.write("    type pixelmap_t is array (0 to 7, 0 to 7) of integer range 0 to 63;\n\n")

    f.write("    constant pixelmap : pixelmap_t :=\n")
    f.write("    (\n")

    for r in range(8):
        row_str = ", ".join(f"{matrix[r][c]:2d}" for c in range(8))
        if r < 7:
            f.write(f"        ( {row_str} ),\n")
        else:
            f.write(f"        ( {row_str} )\n")

    f.write("    );\n\n")

    f.write("    function pixel(name : string) return integer;\n\n")

    f.write("end package pixelMappingPkg;\n\n")

    f.write("package body pixelMappingPkg is\n\n")

    f.write("    function pixel(name : string) return integer is\n")
    f.write("    begin\n")
    f.write("        case name is\n")

    for name in sorted(pixelNameToPixel.keys()):
        r, c = pixelNameToPixel[name]
        channel = matrix[r][c]
        f.write(f'            when "{name}" => return {channel};\n')

    f.write("            when others =>\n")
    f.write('                report "Invalid pixel name" severity failure;\n')
    f.write("                return 0;\n")

    f.write("        end case;\n")
    f.write("    end function;\n\n")

    f.write("end package body pixelMappingPkg;\n")
