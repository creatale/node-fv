dv = require 'dv'
{boundingBox} = require './box_math'

# Find potential barcodes in *image*.
detectCandidates = (image) ->
	open = image.thin('bg', 8, 5).dilate(3, 3)
	openMap = open.distanceFunction(8)
	openMask = openMap.threshold(10).erode(11*2, 11*2)
	return openMask.invert().connectedComponents(8)

cloneWithQuietZone = (image, rect) ->
	cropped = image.crop rect
	clone = new dv.Image cropped.width + 50, cropped.height, cropped.depth
	clone.clearBox 0, 0, clone.width, clone.height
	clone.drawImage cropped, 25, 0, cropped.width, cropped.height
	return clone

# Find all barcodes in *image* using the given *zxing* instance.
# Always returns an array; see `zxing.findCode()` for format.
module.exports.findBarcodes = (image, zxing) ->
	clearedImage = new dv.Image image
	grayImage = image.toGray()
	codes = []
	for candidate in detectCandidates grayImage
		try
			zxing.image = cloneWithQuietZone grayImage, candidate
			code = zxing.findCode()
			# Test if its worth a retry using some image morphing magic.
			if not code? and candidate.width < 0.3 * grayImage.width
				# Apply some magic image morphing and retry.
				zxing.image = zxing.image.scale(2).open(5, 3).scale(0.5).otsuAdaptiveThreshold(400, 400, 0, 0, 0.1).image
				code = zxing.findCode()
			if code?
				# Test if removal is sane
				if candidate.width < 0.3 * grayImage.width
					clearedImage.clearBox candidate
				code.box = boundingBox ({x: point.x, y: point.y, width: 1, height: 1} for point in code.points)
				code.box.x += candidate.x - 25
				code.box.y += candidate.y
				delete code.points
				codes.push code
		catch exception
			if exception.message.indexOf('Too little dynamic range') isnt 0
				console.error exception
	return [codes, clearedImage]
