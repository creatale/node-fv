dv = require 'dv'
{length, distanceVector, boxDistanceVector, intersectBox, boundingBox} = require './math'

# Compiles a mask with lines that have a certain length.
detectLineMask = (image, minLineLength) ->
	lineMask = new dv.Image(image.width, image.height, 8)
	longLines = image.toGray().lineSegments(0, 0, false).filter (line) ->
		return length(distanceVector(line.p1, line.p2)) >= minLineLength
	for line in longLines
		lineMask.drawLine line.p1, line.p2, 7, 'set'
	return lineMask

mergeBoxes = (boxes, predicate) ->
	# Initialize regions with unique indices.
	regions = [0...boxes.length]
	# Merge regions until predicate can no longer be applied.
	done = false
	while not done
		done = true
		# Merge regions (non-transitive).
		for box, i in boxes
			for otherBox, j in boxes[i + 1..] 
				jj = j + i + 1
				if regions[jj] isnt regions[i] and predicate(box, otherBox)
					region = Math.min(regions[jj], regions[i])
					regions[i] = regions[jj] = region
					done = false
		# Propagate merges (transitive).
		for i in [0..regions.length]
			while regions[regions[i]] isnt regions[i]
				regions[i] = regions[regions[i]]
	# Group boxes by region.
	boxesByRegion = {}
	for region, boxIndex in regions
		boxesByRegion[region] ?= []
		boxesByRegion[region].push(boxes[boxIndex])
	# Compute bounding box of each region.
	boundingBoxes = []
	for region, boxes of boxesByRegion
		boundingBoxes.push(boundingBox(boxes))
	return boundingBoxes

isSameBlock = (fontWidth, fontHeight) ->
	return (boxA, boxB) ->
		bottomA = boxA.y + boxA.height
		bottomB = boxB.y + boxB.height
		delta = boxDistanceVector boxA, boxB
		sameLine = Math.abs(bottomA - bottomB) < fontHeight / 2 and delta.x < fontWidth * 3
		return sameLine or intersectBox(boxA, boxB)

detectCandidates = (binarizedImage, fontWidth = 20, fontHeight = 30) ->
	hasLetterSize = (box) ->
		return fontWidth / 2 < box.width and fontHeight / 2 < box.height < fontHeight * 6
	# Smear text a bit to extract letter boxes.
	smearWidth = (1 * fontWidth) + fontWidth % 2
	smearHeight = (0.25 * fontHeight) + fontHeight % 2
	boxes = binarizedImage.dilate(smearWidth, smearHeight).connectedComponents(8).filter(hasLetterSize)
	# Merge letters to text blocks.
	regions = mergeBoxes boxes, isSameBlock(fontWidth, fontHeight)
	# Merge regions again with simple overlapping test; Tesseract may read content twice otherwise.
	boxes = mergeBoxes regions, intersectBox
	return boxes

isFuzzyEqual = (wordA, wordB) ->
	return Math.abs(wordA.box.x - wordB.box.x) < 5 and
		Math.abs(wordA.box.y - wordB.box.y) < 5 and
		Math.abs(wordA.box.width - wordB.box.width) < 10 and
		Math.abs(wordA.box.height - wordB.box.height) < 10

# Use given *Tesseract* instance to find all text grouped as words along with
# confidence and boxes.
module.exports.findText = (image, tesseract) ->
	words = []
	clearedImage = new dv.Image image
	# Remove long lines.
	lineMask = detectLineMask image, 45
	textImage = image.toColor().add lineMask.toColor()
	# Extract text lines.
	tesseract.image = textImage
	candidates = detectCandidates tesseract.thresholdImage()
	# Test if fallback should be used.
	if candidates.length < 35
		candidatesFallback = detectCandidates textImage.threshold(248)
		if candidates.length * 2 < candidatesFallback.length
			candidates = candidatesFallback
	for candidate in candidates
		# Crop and recognize.
		tesseract.image = textImage.crop candidate
		tesseract.pageSegMode = if candidate.height < 60 then 'single_line' else 'single_block'
		localWords = tesseract.findWords()
		for word in localWords
			# Transform back.
			word.box.x += candidate.x
			word.box.y += candidate.y
			# Store candidate.
			word.candidate = candidate
		words = words.concat(localWords)
	# Remove duplicate words caused by overlapping candidates.
	uniqueWords = []
	for word in words[..]
		if uniqueWords.some(isFuzzyEqual.bind(null, word))
			words.splice(words.indexOf(word), 1)
		else
			uniqueWords.push word
	# Remove words from image, but safeguard against removing 'noise' that may be a checkmark.
	for word in words when word.text.length >= 6 or (word.text.length >= 3 and word.confidence >= 30)
		clearedImage.clearBox word.box
	return [words, clearedImage]
