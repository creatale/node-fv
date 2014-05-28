dv = require 'dv'

# Use given *Tesseract* instance to find all text grouped as words along with
# confidence and boxes.
module.exports.findText = (image, tesseract) ->
	tesseract.image = image
	words = tesseract.findWords()
	#console.log words.map((word) -> word.text)
	clearedImage = new dv.Image image
	for word in words when word.text.length >= 3
		clearedImage.clearBox word.box
	return [words, clearedImage]
