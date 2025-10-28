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

parser.add_argument(
	'threshold',
	default=127,
	type=int,
	help='Threshold value between 0 and 255 that determines what will be kept and what will not')

parser.add_argument(
		'--invert',
		action = 'store_true',
		help = 'Inverts the black and white')
	
args = parser.parse_args()

image = cv2.imread(args.imagefile)
gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
thresh_type = None
if args.invert == True:
	thresh_type = cv2.THRESH_BINARY_INV
else:
	thresh_type = cv2.THRESH_BINARY

ret, thresh = cv2.threshold(gray, args.threshold, 255, thresh_type)
cv2.imwrite(args.outputfile, thresh)