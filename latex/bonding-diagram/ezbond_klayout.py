import pya
import sys
import math
import operator

# When running in batch mode, we need to load the GDS file directly
# Get the GDS filename from command line arguments
if len(sys.argv) > 1:
    gds_file = sys.argv[1]
else:
    print("Error: No GDS file specified")
    sys.exit(1)

# Create a new layout and load the GDS file
layout = pya.Layout()
layout.read(gds_file)

# Open output files.  The first contains the polygon vertices for drawing the
# die using tikz.  The second contains the center coordinates of the bond pad
# geometries, used for drawing the bond wires.
chip_file    = open('ezbond_die.tex', 'w')
bondpad_file = open('ezbond_bondwire.tex', 'w')

CSR_WIDTH        = 15000          # Width in nm of the chip seal ring, which omits the layers in this region.
BONDPAD_AREA_MIN = 50000 * 50000  # Minimum area in nm x nm of a bond pad.

# Find silicon die dimensions
layout_bbox = layout.top_cell().bbox()
die_width  = layout_bbox.width()
die_height = layout_bbox.height()

# Start recording changes
layout.start_changes()

# Delete all layers except for bond pad openings.  Possibly this can be sped up
# by simply reading only this layer to begin with.
layers_to_delete = []
for layer_id in layout.layer_indices():
    layer_info = layout.get_info(layer_id)
    # This string comparison is terrible.  Someone please fix this up!
    if layer_info.to_s() != '76/0':
        layers_to_delete.append(layer_id)

# Delete layers after collecting them to avoid modifying during iteration
for layer_id in layers_to_delete:
    layout.delete_layer(layer_id)

# Flatten all levels of the main layout.  This makes the CIF easier to read,
# and may speed up the script moving forward.  Note the CIF output is not used
# anymore, so this may not be needed, but is left as an example.
layout.flatten(layout.top_cell().cell_index(), -1, True)

# End recording changes
layout.end_changes()

# Print tikz header that shifts the chip coordinates to have their origin at
# (0,0).  Update units.  Using the tikz shift instead of mathematically
# recalculating in this script allows simpler comparison of the generated to
# the actual GDS layout if debugging is necessary.
x = die_width / 1e6
y = die_height / 1e6
chip_file.write('\\begin{scope}[shift={(%0.6f,%0.6f)}]\n' % (-x/2, -y/2))

# Draw the rectangular die outline
chip_file.write('    \\draw (%0.6f,%0.6f) rectangle (%0.6f,%0.6f);\n' % (0, 0, x, y))

# Generate a search region that omits the outer CSR to avoid detecting its metal as a bond pad.
search_bbox = layout.top_cell().bbox_per_layer(layout.layer(76,0)).enlarge(-CSR_WIDTH,-CSR_WIDTH) # Note that this modifies the original

# List of the (x,y) center coordinates of each bondpad.
bondpad_centers = []

shape_iter = layout.begin_shapes_touching(layout.top_cell(), layout.layer(76,0), search_bbox)
while shape_iter.at_end() == False:
    shape = shape_iter.shape()
    if shape.is_polygon() and shape.polygon.area() > BONDPAD_AREA_MIN:

        # Save the center of the geometry which will be where the bond wire is
        # attached.  Note that, to make the tikz easier, these coordinates are
        # recalculated to be centered at (0,0) instead of their true positions
        # in the GDS.
        bp_x = shape.bbox().center().x - die_width / 2
        bp_y = shape.bbox().center().y - die_height / 2

        # Save the angle relative to pin 1 (top left corner, 135 degrees).  The
        # locations will be sorted in order based on this.  atan2 outputs +-180 
        # degrees, so add 180 degree to shift this to 0->360 degrees.
        bp_angle = math.atan2(bp_y, bp_x) * 180 / math.pi
        bondpad_centers.append([bp_angle, bp_x, bp_y])

        # Output the polygon to a file in tikz format
        chip_file.write('    \\draw ')
        for p in shape.polygon.each_point_hull():
            #print shape.bbox().center().x, shape.bbox().center().y, shape.polygon.area()
            chip_file.write('(%0.6f,%0.6f) -- ' % (p.x/1e6, p.y/1e6))
        chip_file.write('cycle;\n')

    shape_iter.next()

# End the translated scope block
chip_file.write('\\end{scope}')
chip_file.close()

# Take the bondpad coordinates and sort them in counterclockwise order.
sorted_bondpad_centers = sorted(bondpad_centers, key=lambda x: x[0])

# Rearrange list so that pin 1 appears first (located at 135 degrees).  This
# will fail if the chip aspect ratio deviates from 1:1.  Could use atan2() to
# actually calculate the correct corner angle.
pin_1_index = 0
pin_1_index_found = False
for i,bp in enumerate(sorted_bondpad_centers):
    if pin_1_index_found == False and sorted_bondpad_centers[i][0] > 135:
        pin_1_index_found = True
        pin_1_index = i

# Cut and swap the two ends of the list to move pin 1 to the start.
sorted_bondpad_centers = sorted_bondpad_centers[pin_1_index:] + sorted_bondpad_centers[:pin_1_index]

# Save the coordinates into a format ready for import into tikz.
bondpad_file.write('\\def\\bpx{{')
for i,coordinate in enumerate(sorted_bondpad_centers):
    bondpad_file.write('%0.6f,' % (coordinate[1]/1e6))
bondpad_file.write('}}%\n')
bondpad_file.write('\\def\\bpy{{')
for i,coordinate in enumerate(sorted_bondpad_centers):
    bondpad_file.write('%0.6f,' % (coordinate[2]/1e6))
bondpad_file.write('}}%')
bondpad_file.close()

print("Successfully processed %s" % gds_file)
print("Generated ezbond_die.tex and ezbond_bondwire.tex")


# import pya
# import sys
# import math
# import operator

# #layout = pya.Layout()
# #layout.read('layout.gds', pya.LoadLayoutOptions())

# layout = pya.CellView.active().layout()

# # Open output files.  The first contains the polygon vertices for drawing the
# # die using tikz.  The second contains the center coordinates of the bond pad
# # geometries, used for drawing the bond wires.
# chip_file    = open('ezbond_die.tex', 'w')
# bondpad_file = open('ezbond_bondwire.tex', 'w')

# CSR_WIDTH        = 15000          # Width in nm of the chip seal ring, which omits the layers in this region.
# BONDPAD_AREA_MIN = 50000 * 50000  # Minimum area in nm x nm of a bond pad.

# # Find silicon die dimensions
# layout_bbox = layout.top_cell().bbox()
# die_width  = layout_bbox.width()
# die_height = layout_bbox.height()

# # Delete all layers except for bond pad openings.  Possibly this can be sped up
# # by simply reading only this layer to begin with.
# for layer_id in layout.layer_indices():
#     layer_info = layout.get_info(layer_id)
#     # This string comparison is terrible.  Someone please fix this up!
#     if layer_info.to_s() != '76/0':
#         layout.delete_layer(layer_id)

# layout.start_changes()

# # Flatten all levels of the main layout.  This makes the CIF easier to read,
# # and may speed up the script moving forward.  Note the CIF output is not used
# # anymore, so this may not be needed, but is left as an example.
# layout.flatten(layout.top_cell().cell_index(),-1,True)

# # Print tikz header that shifts the chip coordinates to have their origin at
# # (0,0).  Update units.  Using the tikz shift instead of mathematically
# # recalculating in this script allows simpler comparison of the generated to
# # the actual GDS layout if debugging is necessary.
# x = die_width / 1e6
# y = die_height / 1e6
# chip_file.write('\\begin{scope}[shift={(%0.6f,%0.6f)}]\n' % (-x/2, -y/2))

# # Draw the rectangular die outline
# chip_file.write('    \\draw (%0.6f,%0.6f) rectangle (%0.6f,%0.6f);\n' % (0, 0, x, y))

# # Generate a search region that omits the outer CSR to avoid detecting its metal as a bond pad.
# search_bbox = layout.top_cell().bbox_per_layer(layout.layer(76,0)).enlarge(-CSR_WIDTH,-CSR_WIDTH) # Note that this modifies the original

# # List of the (x,y) center coordinates of each bondpad.
# bondpad_centers = []

# shape_iter = layout.begin_shapes_touching(layout.top_cell(), layout.layer(76,0), search_bbox)
# while shape_iter.at_end() == False:
#     shape = shape_iter.shape()
#     if shape.is_polygon() and shape.polygon.area() > BONDPAD_AREA_MIN:

#         # Save the center of the geometry which will be where the bond wire is
#         # attached.  Note that, to make the tikz easier, these coordinates are
#         # recalculated to be centered at (0,0) instead of their true positions
#         # in the GDS.
#         bp_x = shape.bbox().center().x - die_width / 2
#         bp_y = shape.bbox().center().y - die_height / 2

#         # Save the angle relative to pin 1 (top left corner, 135 degrees).  The
#         # locations will be sorted in order based on this.  atan2 outputs +-180 
#         # degrees, so add 180 degree to shift this to 0->360 degrees.
#         bp_angle = math.atan2(bp_y, bp_x) * 180 / math.pi
#         bondpad_centers.append([bp_angle, bp_x, bp_y])

#         # Output the polygon to a file in tikz format
#         chip_file.write('    \\draw ')
#         for p in shape.polygon.each_point_hull():
#             #print shape.bbox().center().x, shape.bbox().center().y, shape.polygon.area()
#             chip_file.write('(%0.6f,%0.6f) -- ' % (p.x/1e6, p.y/1e6))
#         chip_file.write('cycle;\n')

#     shape_iter.next()

# # End the translated scope block
# chip_file.write('\\end{scope}')
# chip_file.close()

# # Take the bondpad coordinates and sort them in counterclockwise order.
# sorted_bondpad_centers = sorted(bondpad_centers, key=lambda x: x[0])

# # Rearrange list so that pin 1 appears first (located at 135 degrees).  This
# # will fail if the chip aspect ratio deviates from 1:1.  Could use atan2() to
# # actually calculate the correct corner angle.
# pin_1_index = 0
# pin_1_index_found = False
# for i,bp in enumerate(sorted_bondpad_centers):
#     if pin_1_index_found == False and sorted_bondpad_centers[i][0] > 135:
#         pin_1_index_found = True
#         pin_1_index = i

# # Cut and swap the two ends of the list to move pin 1 to the start.
# sorted_bondpad_centers = sorted_bondpad_centers[pin_1_index:] + sorted_bondpad_centers[:pin_1_index]

# # Save the coordinates into a format ready for import into tikz.
# bondpad_file.write('\\def\\bpx{{')
# for i,coordinate in enumerate(sorted_bondpad_centers):
#     bondpad_file.write('%0.6f,' % (coordinate[1]/1e6))
# bondpad_file.write('}}%\n')
# bondpad_file.write('\\def\\bpy{{')
# for i,coordinate in enumerate(sorted_bondpad_centers):
#     bondpad_file.write('%0.6f,' % (coordinate[2]/1e6))
# bondpad_file.write('}}%')
# bondpad_file.close()
