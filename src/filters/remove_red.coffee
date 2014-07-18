filterBackground = require './filter_background'

# Remove red tones from given *image* and return the result (grayscale).
module.exports = (image) ->
	# Compute desaturated weak text with guessed font-size.
	hsv = filterBackground(image, 25, 35).toHSV()
	# Select 11x11 area around all groups of at least 3 connected gray pixels.
	nearInkMask = hsv.inRange(0, 0, 0, 255, 10, 0.9 * 255).dilate(9,11)
		.erode(11,11).dilate(11,11).toGray()
	desaturatedMask = hsv.inRange(
		0, 0, 0,
		239, 0.3 * 255, 0.9 * 255
		)
	# Select desaturated pixels with a high probability to be ink.
	desaturatedMask = desaturatedMask.toGray().convolve(2, 2)
		.invert().subtract nearInkMask

	# Compute preprinted form (saturated red color).
	red = image.toGray(1, 0, 0)
	cyan = image.toGray(0, 0.5, 0.5)
	redMask = red.subtract(cyan).convolve(1, 1)

	# Remove red and preserve desaturated colors.
	formMask = redMask.add(redMask).subtract(desaturatedMask)
	foreground = image.toGray().add(formMask)

	return foreground
