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
	help='Path of output picture file. Please give it a .png file extension.')

	
args = parser.parse_args()

# OpenCV is in BGR ordering
black = [0, 0, 0]

image = cv2.imread(args.imagefile)
rows, cols, colors = image.shape

ret, thresh = cv2.threshold(image, 128, 255, cv2.THRESH_BINARY)
image2 = thresh.copy()
print(thresh.shape)

for r in range(rows - 1):
	for c in range(cols):
		pix = image[r, c]
		if pix[0] == black[0] and pix[1] == black[1] and pix[2] == black[2]:
			image2[r + 1, c] = [0, 0, 0]
			
cv2.imwrite(args.outputfile, image2)