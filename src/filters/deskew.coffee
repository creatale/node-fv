dv = require 'dv'

module.exports = (image) ->
	grayImage = image.toGray()
	skew = grayImage.otsuAdaptiveThreshold(400, 400, 0, 0, 0.1).image.findSkew().angle
	skew = 0 if Math.abs(skew) < 0.15
	if skew
		return image.rotate skew
	else
		return new dv.Image(image)
