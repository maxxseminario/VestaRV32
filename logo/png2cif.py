#!/usr/bin/env python3

import sys
from PIL import Image

# Script constants for foreground and background colors
FG = 0
BG = 255

################################################################################
# Draws a square at the given pixel location
################################################################################
def draw_square (x, y):
	# First transform coordinates to match CIF
	x_cif = x
	y_cif = height - y
	# Find corners of box
	x_sw = x_cif * arg_scale
	y_sw = y_cif * arg_scale
	x_ne = (x_cif + 1) * arg_scale
	y_ne = (y_cif + 1) * arg_scale
	outfile.write('P %d %d %d %d %d %d %d %d;\n' % (x_sw, y_sw, x_ne, y_sw, x_ne, y_ne, x_sw, y_ne))

# Parse input arguements and print the usage message.
if len(sys.argv) != 6:
	print('Too many arguments received: %d' % len(sys.argv))
	print('%s <image.png> <cell-name> <nm-per-pixel> <layer-name> <output-name.cif>' % sys.argv[0])
	sys.exit(1)

arg_image = sys.argv[1]	# Path to image
arg_cell  = sys.argv[2]	# Cell name for CIF file
arg_scale = int(sys.argv[3]) / 10	# nm per rectange (converting from nm to "centimicrons" which is used in CIF)
arg_layer = sys.argv[4]	# layer purpose pair. Syntax: L39P60 for layer 39 purpose 60
arg_cif = sys.argv[5]	# Output CIF path

# Open, convert the image to black and white and get the dimensions.
im = Image.open(arg_image).convert('L')
(width, height) = im.size

# Open the CIF output file and print header
outfile = open(arg_cif, 'w')
outfile.write('DS 1 1 1;\n')
outfile.write('9 %s;\n' % arg_cell)
outfile.write('L %s;\n' % arg_layer)

# Iterate over all pixels and output the CIF file.  Each pixel is its of square,
# so these should be merged together into larger polygons in the layout tool.
for y in range(height):
	for x in range(width):
		if im.getpixel((x, y)) == FG:
			draw_square(x, y)

# Output footer and close file.
outfile.write('DF;\nE;')
outfile.close()
