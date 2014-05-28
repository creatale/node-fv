# Remove background with guessed font size. Always returns a color image.
module.exports = (image, fontWidth, fontHeight) ->
	# Computes the background by closing glyphs and convolving.
	backgroundMask = image.toGray().close(fontWidth, fontHeight)
	.convolve(fontWidth * 1.33, fontHeight * 1.33)
	.invert()
	backgroundMask = backgroundMask.add(backgroundMask)
	foreground = image.toColor().add(backgroundMask.toColor())
	return foreground
