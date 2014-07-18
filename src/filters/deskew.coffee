dv = require 'dv'

# Rotates image to have less skew. Works only for a limited angle.
module.exports = (image) ->
	grayImage = image.toGray()
	binarizedImage = grayImage.otsuAdaptiveThreshold(400, 400, 0, 0, 0.1).image
	skew = binarizedImage.findSkew().angle
	skew = 0 if Math.abs(skew) < 0.15
	if skew
		return image.rotate skew
	else
		return new dv.Image(image)
