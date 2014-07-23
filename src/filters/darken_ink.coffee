dv = require 'dv'

# Darken very light ink to enhance readability.
module.exports = (image) ->
	# Transform to HSV.
	hsv = image.toColor().toHSV()
	# Select desatured (grayish) and dark pixels.
	desaturatedMask = hsv.inRange(
		0, 0, 0,
		239, 0.1 * 255, 255)
	darkValueMask = hsv.inRange(
		0, 0, 0
		239, 255, 0.5 * 255).invert()
	# Split HSV channels.
	h = hsv.toGray(1, 0, 0)
	s = hsv.toGray(0, 1, 0)
	v = hsv.toGray(0, 0, 1)
	vOrig = new dv.Image(v)
	# Compute "fuzzy value protection mask" and apply linear spline.
	curve = [0..255]
	for x in [0..199]
		curve[x] = 0
	for x in [0..54]
		curve[x + 200] = x / 54 * 220
	protectionMask = desaturatedMask.and(darkValueMask.erode(5, 5))
	v.applyCurve(curve, protectionMask)
	# Extract changes to value channel.
	deltaV = vOrig.subtract(v)
	# Filter undesired changes (blobs and noise).
	deltaV = deltaV.invert()
	for rect in deltaV.threshold(254).dilate(5, 5).connectedComponents(8)
		if rect.height > 100 or rect.width < 5 or rect.height < 5
			deltaV.clearBox rect
	deltaV = deltaV.invert()
	# Apply filtered changes to unmodified value channel.
	v = vOrig.subtract(deltaV)
	# Merge HSV channels.
	return new dv.Image(h, s, v).toRGB()
