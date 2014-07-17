dv = require 'dv'
{boundingBox} = require './box_math'

# Width of the quiet zone around a barcode.
QUIETZONE_WIDTH = 25

# Find potential barcodes in *image*.
detectCandidates = (image) ->
	blobImage = image.thin('bg', 8, 5).dilate(3, 3)
	blobMap = blobImage.distanceFunction(8)
	blobMask = blobMap.threshold(10).invert().dilate(22, 22)
	return blobMask.connectedComponents(8)

# Clone image with artificial quiet zone.
cloneWithQuietZone = (image, rect) ->
	cropped = image.crop rect
	clone = new dv.Image cropped.width + QUIETZONE_WIDTH * 2, cropped.height + QUIETZONE_WIDTH * 2, cropped.depth
	clone.clearBox 0, 0, clone.width, clone.height
	clone.drawImage cropped, QUIETZONE_WIDTH, QUIETZONE_WIDTH, cropped.width, cropped.height
	return clone

# Find all barcodes in *image* using the given *zxing* instance.
# Always returns an array; see `zxing.findCode()` for format.
module.exports.findBarcodes = (image, zxing) ->
	clearedImage = new dv.Image image
	grayImage = image.toGray()
	codes = []
	for candidate in detectCandidates grayImage
		try
			couldBeRotated = candidate.height * 1.75 > candidate.width
			zxing.image = cloneWithQuietZone grayImage, candidate
			zxing.tryHarder = couldBeRotated
			code = zxing.findCode()
			# Test if its worth a retry using some image morphing magic.
			if not code? and candidate.width < 0.3 * grayImage.width
				# Apply some magic image morphing and retry.
				zxing.image = zxing.image.scale(2).open(5, 3).scale(0.5).otsuAdaptiveThreshold(400, 400, 0, 0, 0.1).image
				code = zxing.findCode()
			if code?
				# Test if removal is sane.
				if candidate.width < 0.3 * grayImage.width
					clearedImage.clearBox candidate
				code.box = boundingBox ({x: point.x, y: point.y, width: 1, height: 1} for point in code.points)
				code.box.x += candidate.x - QUIETZONE_WIDTH
				code.box.y += candidate.y - QUIETZONE_WIDTH
				delete code.points
				codes.push code
		catch exception
			if exception.message.indexOf('Too little dynamic range') isnt 0
				console.error exception
	return [codes, clearedImage]
