import cv2
import argparse


parser = argparse.ArgumentParser(
	description='Takes an image input and turns it into a 3-layer array of pixels')

parser.add_argument(
	'imagefile',
	metavar='input_file',
	help='Path of input picture file')
	
parser.add_argument(
	'outputfile',
	metavar='output_file',
	help='Path of output picture file. Please give it a .png file extention.')

	
args = parser.parse_args()

# OpenCV is in BGR ordering
red = [36, 28, 237]

image = cv2.imread(args.imagefile)

rows, cols, colors = image.shape

for r in range(rows):
	for c in range(cols):
		pix = image[r, c]
		if pix[0] == red[0] and pix[1] == red[1] and pix[2] == red[2]:
			image[r, c] = [0, 0, 0]
		else:
			image[r, c] = [255, 255, 255]
			
ret, thresh = cv2.threshold(image, 128, 255, cv2.THRESH_BINARY)
cv2.imwrite(args.outputfile, thresh)