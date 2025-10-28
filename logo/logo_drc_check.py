import numpy as np
import cv2
import argparse


def checkwhite(pixel):
	if pixel[0] == 255 and pixel[1] == 255 and pixel[2] == 255:
		return True
	else:
		return False

parser = argparse.ArgumentParser(
	description='Takes an image input and provides drc pointers')

parser.add_argument(
	'imagefile',
	metavar='input_file',
	help='Path of input picture file')
	
parser.add_argument(
	'outputfile',
	metavar='output_file',
	help='Path of output picture file. Please give it a .png file extention.')
	
args = parser.parse_args()

image = cv2.imread(args.imagefile)

white = np.array([255, 255, 255])
red = np.array([0, 0, 255])

dims = image.shape
sizeY = dims[0]
sizeX = dims[1]

print('X Pixels:', sizeX)
print('Y Pixels:', sizeY)

# Find all pixels with a caddycorner pixel
count = 0
for i in range(1, sizeX - 1):
	for j in range(1, sizeY - 1):
		# If this pixel is not white, check it.
		bad = False
		if checkwhite(image[j, i]) == False:
			# Top left
			if checkwhite(image[j - 1, i - 1]) == False:
				# check left and top
				if checkwhite(image[j, i - 1]) == True and checkwhite(image[j - 1, i]) == True:
					# We have a bad pixel!
					bad = True
			
			# Top right
			if checkwhite(image[j - 1, i + 1]) == False:
				# check right and top
				if checkwhite(image[j, i + 1]) == True and checkwhite(image[j - 1, i]) == True:
					# We have a bad pixel!
					bad = True
			
			# Bottom left
			if checkwhite(image[j + 1, i - 1]) == False:
				# check left and bottom
				if checkwhite(image[j, i - 1]) == True and checkwhite(image[j + 1, i]) == True:
					# We have a bad pixel!
					bad = True
			
			# Bottom right
			if checkwhite(image[j + 1, i + 1]) == False:
				# check right and bottom
				if checkwhite(image[j, i + 1]) == True and checkwhite(image[j + 1, i]) == True:
					# We have a bad pixel!
					bad = True
			
		if bad == True:
			image[j, i] = red
			count += 1

whitecount = 0
blackcount = 0

for i in range(0, sizeX):
	for j in range(0, sizeY):
		if checkwhite(image[j, i]) == True:
			whitecount += 1
		else:
			blackcount += 1

print('DRC Error Count:', count)
print('Number of white pixels:', whitecount)
print('Number of non-white pixels:', blackcount)
print('Total number of pixels:', whitecount + blackcount)
print('Fill density: ' + str(100.0 * blackcount / (1.0 * (blackcount + whitecount))) + '%')
cv2.imwrite(args.outputfile, image)