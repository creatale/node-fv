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

mergeRegions = (items, predicate) ->
	# Initialize regions with unique indices.
	regions = [0...items.length]
	# Merge regions until predicate can no longer be applied.
	done = false
	while not done
		done = true
		# Merge regions (non-transitive).
		for item, i in items
			for otherItem, j in items[i + 1..] 
				jj = j + i + 1
				if regions[jj] isnt regions[i] and predicate(item, otherItem)
					region = Math.min(regions[jj], regions[i])
					regions[i] = regions[jj] = region
					done = false
		# Propagate merges (transitive).
		for i in [0..regions.length]
			while regions[regions[i]] isnt regions[i]
				regions[i] = regions[regions[i]]
	return regions

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
	# Merge letter boxes to text regions.
	regions = mergeRegions boxes, isSameBlock(fontWidth, fontHeight)
	boxesByRegion = {}
	for region, boxIndex in regions
		boxesByRegion[region] ?= []
		boxesByRegion[region].push(boxes[boxIndex])
	candidates = (boxes for _, boxes of boxesByRegion)
	return candidates

# Clone area of an image from boxes
cloneUsingRegion = (image, boxes) ->
	cloneBox = boundingBox boxes
	cloneImage = new dv.Image cloneBox.width, cloneBox.height, image.depth
	cloneImage.clearBox
		x: 0
		y: 0
		width: cloneBox.width
		height: cloneBox.height
	for box in boxes
		cloneImage.drawImage image.crop(box.x, box.y, box.width + 25, box.height),
			x: box.x - cloneBox.x
			y: box.y - cloneBox.y
			width: box.width + 25
			height: box.height
	return [cloneImage, cloneBox]

findWords = (candidates, image, tesseract) ->
	words = []
	for candidateBoxes in candidates
		# Crop and recognize.
		[cloneImage, cloneBox] = cloneUsingRegion image, candidateBoxes
		tesseract.image = cloneImage
		tesseract.pageSegMode = if cloneBox.height < 60 then 'single_line' else 'single_block'
		localWords = tesseract.findWords()
		for word in localWords
			# Transform back.
			word.box.x += cloneBox.x
			word.box.y += cloneBox.y
			# Store candidate.
			word.candidate = candidateBoxes[..]
		words = words.concat(localWords)
	# Filter words with tiny boxes.
	words = words.filter (word) -> word.box.width > 5 and word.box.height > 5
	return words

# Use given *Tesseract* instance to find all text grouped as words along with
# confidence and boxes.
module.exports.findText = (image, tesseract) ->
	clearedImage = new dv.Image image
	# Remove long lines.
	lineMask = detectLineMask image, 45
	textImage = image.toColor().add lineMask.toColor()
	# Find words using Tesseract's thresholding.
	tesseract.image = textImage
	candidates = detectCandidates image.toGray().otsuAdaptiveThreshold(128, 128, 0, 0, 0).image
	words = findWords candidates, image, tesseract
	# Remove words from image, but safeguard against removing 'noise' that may be a checkmark.
	for word in words when word.text.length >= 6 or (word.text.length >= 3 and word.confidence >= 30)
		clearedImage.clearBox word.box
	return [words, clearedImage]
