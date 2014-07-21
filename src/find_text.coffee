dv = require 'dv'
{boundingBox, isOverlapping} = require './math'

isSameTextline = (boxA, boxB) ->
	centerA = 
		x: boxA.x + boxA.width / 2
		y: boxA.y + boxA.height / 2
	centerB = 
		x: boxB.x + boxB.width / 2
		y: boxB.y + boxB.height / 2
	delta =
		x: centerA.x - centerB.x
		y: centerA.x - centerB.y
	distance = Math.sqrt(delta.x * delta.x + delta.y * delta.y)
	if Math.abs(delta.x) > Math.abs(delta.y)
		# Horizontal
		return distance < 50
	else
		# Vertical.
		return distance < 2
	
mergeBoxes = (boxes, predicate) ->
	# Initialize a (region, box)-tuple set.
	regions = (region for _, region in boxes)
	# Merge regions until predicate can no longer be applied.
	done = false
	while not done
		done = true
		# Merge adjacent regions.
		for box, i in boxes
			for otherBox, j in boxes[i + 1..] 
				jj = j + i + 1
				if regions[jj] isnt regions[i] and predicate(box, otherBox)
					region = Math.min(regions[jj], regions[i])
					regions[i] = regions[jj] = region
					done = false
		# Propagate merges to non-adjacent regions.
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

filterBoxes = (boxes, predicate) ->
	result = []
	# Merge adjacent regions.
	for box, i in boxes
		pass = true
		for otherBox, j in boxes
			if i isnt j and not predicate(box, otherBox)
				pass = false
		result.push box if pass
	return result

isOverlappingAndSmaller = (a, b) -> isOverlapping(a, b) and a.width * a.height < b.width * b.height

detectCandidates = (binarizedImage) ->
	boxes = binarizedImage.dilate(11, 1).connectedComponents(8)
	#boxes = boxes.filter((box) -> 2 < box.width < 66 and 2 < box.height < 66)
	#return mergeBoxes boxes, isSameTextline
	return boxes# filterBoxes boxes, isOverlappingAndSmaller

# Use given *Tesseract* instance to find all text grouped as words along with
# confidence and boxes.
module.exports.findText = (image, tesseract) ->
	words = []
	clearedImage = new dv.Image image
	tesseract.image = image
	binarizedImage = tesseract.thresholdImage()
	logImage = new dv.Image image.width, image.height, 32
	logImage.drawImage binarizedImage.toColor(), {x: 0, y: 0, width: binarizedImage.width, height: binarizedImage.height}
	#	for candidate in tesseract.findTextLines(false) #detectCandidates binarizedImage
	
	for candidate in detectCandidates binarizedImage
		tesseract.image = binarizedImage.crop candidate
		words = words.concat(tesseract.findWords())
		logImage.drawBox candidate, 2, 255, 0, 0

	fs = require 'fs'
	fs.writeFileSync 'bla.png', logImage.toBuffer 'png'
	#console.log words.map((word) -> word.text)
	for word in words when word.text.length >= 3
		clearedImage.clearBox word.box
	return [words, clearedImage]
