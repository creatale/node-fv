filterBackground = require './filter_background'

# Remove red tones from given *image* and return the result (grayscale)
module.exports = (image) ->
	# Compute desaturated weak text with guessed font-size.
	hsv = filterBackground(image, 25, 35).toHSV()
	# Select 11x11 area around all groups of at least 3 connected gray pixels
	nearInkMask = hsv.inRange(0, 0, 0, 255, 10, 0.9 * 255).dilate(9,11).erode(11,11).dilate(11,11).toGray()
	desaturatedMask = hsv.inRange(
		0, 0, 0,
		239, 0.3 * 255, 0.9 * 255
		)
	# Restrict desaturatedMask to nearInkMask, i.e. where a probable ink pixel is near
	desaturatedMask = desaturatedMask.toGray().convolve(2, 2).invert().subtract nearInkMask

	# Compute preprinted form (saturated red color).
	red = image.toGray(1, 0, 0)
	cyan = image.toGray(0, 0.5, 0.5)
	redMask = red.subtract(cyan).convolve(1, 1)

	# Remove red and preserve desaturated colors.
	formMask = redMask.add(redMask).subtract(desaturatedMask)
	foreground = image.toGray().add(formMask)
	
	#now = Date.now()
	#fs.writeFileSync 'log/filter-image' + now + '-1desaturated.png', desaturatedMask.toBuffer 'png'
	#fs.writeFileSync 'log/filter-image' + now + '-1red.png', redMask.toBuffer 'png'
	#fs.writeFileSync 'log/filter-image' + now + '-2form.png', formMask.toBuffer 'png'
	#fs.writeFileSync 'log/filter-image' + now + '-3in.png', image.toGray().toBuffer 'png'
	#fs.writeFileSync 'log/filter-image' + now + '-3out.png', foreground.toBuffer 'png'
	#fs.writeFileSync 'log/filter-image' + now + '-3outb.png', module.exports.binarize(foreground).toBuffer 'png'
	return foreground
