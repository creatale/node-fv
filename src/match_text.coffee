unpack = require './unpack'
{boundingBox, manhattanVector, length} = require './math'

# Match text to form schema.
module.exports.matchText = (formData, formSchema, words, schemaToPage, rawImage) ->
	grayImage = rawImage.toGray()
	textFields = formSchema.fields.filter((field) -> field.type is 'text')
	anchors = []
	anchorFields = []
	anchorWords = []
	# Try to find anchor words (unique matches).
	for textField, fieldIndex in textFields
		matches = []
		for word, wordIndex in words when word.text.length > 0
			if not textField.fieldValidator? or textField.fieldValidator(word.text)
				matches.push wordIndex
		if matches.length is 1
			word = words[matches[0]]
			if word in anchorWords
				# Uniqueness check failed: This is at least the second field subscribing to `word`.
				# Pull the existing one from anchors and skip this one completely.
				#console.log 'Duplicate subscription on', word.text
				for anchor, index in anchors
					if anchor.word is word
						anchors.splice index, 1
						anchorFields.splice index, 1
						break
				continue

			# Safeguard: Disregard matches that are too far off
			fieldPos = schemaToPage textField.box
			continue if Math.abs(word.box.x - fieldPos.x) + Math.abs(word.box.y - fieldPos.y) > 400
			#console.log 'Unique match:', textField, word
			anchor =
				acceptedBy: textField.path
				offset:
					x: fieldPos.x - word.box.x
					y: fieldPos.y - word.box.y
				word: word
			anchors.push anchor
			anchorWords.push word
			fieldData = unpack formData, textField.path
			fieldData.value = word.text
			fieldData.confidence = word.confidence
			fieldData.box = word.box
			anchorFields.push fieldIndex
			
	#console.log 'Anchors: ', anchors

	# Remove all words we used as anchor.
	for fieldIndex in anchorFields by -1
		textFields.splice fieldIndex, 1
	words = words.filter((word) -> not anchors.some((a) -> a.word is word))

	# Fill in remaining fields
	for field in textFields
		pos = schemaToPage(field.box)
		closestAnchor = findClosestAnchor anchors, pos
		if closestAnchor?
			pos.x -= closestAnchor.offset.x
			pos.y -= closestAnchor.offset.y

		startWords = findTwoClosestWords pos, words
		
		#console.log field.path, 'uses anchor', closestAnchor?.acceptedBy

		# Build some variants of an enclosing box
		boxVariants = [pos]
		for upperLeftWord in startWords
			boxVariants.push
				x: upperLeftWord.box.x
				y: upperLeftWord.box.y
				width: pos.width
				height: pos.height
			boxVariants.push
				x: upperLeftWord.box.x
				y: upperLeftWord.box.y
				width: pos.width * 0.9
				height: pos.height * 0.9
			boxVariants.push
				x: upperLeftWord.box.x
				y: upperLeftWord.box.y
				width: pos.width * 1.1
				height: pos.height * 1.1


		# Interpret available words using all variants and remember which would validate
		validatingVariants = []
		for box in boxVariants
			selectedWords = selectWords words, box
			fieldContentCandidate = toText selectedWords, field.extendedGapDetection
			# Don't try the exact same value twice
			continue if validatingVariants.some (v) -> v.value is fieldContentCandidate

			if not field.fieldValidator? or field.fieldValidator(fieldContentCandidate)
				selectedArea = selectedWords[0]?.box
				for word in selectedWords[1..]
					selectedArea = boundingBox [selectedArea, word.box]
				confidence = getConfidence selectedWords, box, grayImage

				validatingVariants.push
					value: fieldContentCandidate
					confidence: confidence
					box: selectedArea
					words: selectedWords

		# Extremely sophisticated conflict solving algorithm
		chosenVariant = validatingVariants[0]

		if validatingVariants.length > 1
			chosenVariant.confidence = Math.max 0, chosenVariant.confidence - 10

		# Set value of target field and remove selected words from candidates
		if chosenVariant?
			fieldData = unpack formData, field.path
			fieldData.value = chosenVariant.value
			fieldData.confidence = Math.round chosenVariant.confidence
			fieldData.box = chosenVariant.box
			for word in chosenVariant.words
				words.splice words.indexOf(word), 1

findClosestAnchor = (anchors, pos) ->
	minDistance = Infinity
	closest = null
	for anchor in anchors
		dist = Math.abs(anchor.word.box.x - pos.x) + Math.abs(anchor.word.box.y - pos.y)
		if dist < minDistance
			minDistance = dist
			closest = anchor
	return closest

findTwoClosestWords = (pos, words) ->
	wordDistances = words.map (word) -> {distance: Math.abs(word.box.x - pos.x) + Math.abs(word.box.y - pos.y), word}
	wordDistances = wordDistances.filter (i) -> i.distance < 200
	wordDistances.sort (a, b) -> a.distance - b.distance
	return wordDistances[...2].map (item) -> item.word

selectWords = (words, placement) ->
	selectedWords = []
	right = placement.x + placement.width
	bottom = placement.y + placement.height
	for word in words
		# Select all words that are at least 50% within placement in x direction,
		# touch placement in y direction, and are none of the typical 'character garbage'.
		if (word.box.x + word.box.width / 2) < right and (word.box.x + word.box.width / 2) > placement.x and
				word.box.y < bottom and word.box.y + word.box.height > placement.y and
				word.text not in ['I', '|', '_', '—']
			selectedWords.push word

	# Now decide which words in y direction to take: First line is the one which is nearest to specified y.
	firstLine = undefined
	firstLineDiff = Infinity

	for word in selectedWords
		diff = Math.abs placement.y - word.box.y
		if diff < firstLineDiff
			firstLine = word.box.y
			firstLineDiff = diff
	#console.log 'Chosen as first line:', firstLine
	return (word for word in selectedWords when firstLine - 10 <= word.box.y < firstLine + placement.height - 5)

estimateCharWidth = (word) ->
	charWidth = word.box.width / word.text.length
	# Compensate for padding of outermost characters
	charWidth += 0.2*charWidth / word.text.length
	return charWidth
	
# Convert words in random order to a single block of text.
toText = (words, extendedGapDetection = false) ->
	return '' if words.length is 0

	# Extract lines from Y difference peaks.
	lines = [[]]
	lastWord = words[0]
	words.sort((a, b) -> a.box.y + a.box.height - b.box.y - b.box.height)
	for word in words
		if Math.abs(lastWord.box.y + lastWord.box.height - word.box.y - word.box.height) > 15
			lines.push []
		lines[lines.length - 1].push word
		lastWord = word

	# Put lines in reading order and join them.
	text = ''
	# Make an attempt to repair words splitted into characters, e.g. 'J 1 2/ 34 5'.
	fragment = /^(|\w|\d\d)\/?$/
	for line, i in lines
		text += '\n' unless i is 0
		line.sort((a, b) -> a.box.x - b.box.x)
		gap = 0
		minimumGap = 50
		lastWord = null
		for word, i in line
			isFragment = fragment.test word.text
			if lastWord?
				charWidth = (estimateCharWidth(lastWord) + estimateCharWidth(word)) / 2
				gap = word.box.x - (lastWord.box.x + lastWord.box.width)
				minimumGap = charWidth * 1.5 if extendedGapDetection
			if (i is 0) or (isFragment and fragment.test(lastWord.text) and gap < minimumGap)
				text += word.text
			else if extendedGapDetection and gap > charWidth * 2
				# Insert up to three spaces depending on gap
				spaces = Math.max 1, Math.floor(gap / charWidth)
				text += '   '[...spaces] + word.text
			else
				text += ' ' + word.text
			lastWord = word

	return text

getConfidence = (words, placement, grayImage) ->
	if words?.length > 0
		result = 100
		for {confidence} in words
			result = Math.min result, confidence
		return Math.floor result
	else
		# Text allegedly empty; look whether there are any letter-sized blobs in actual image
		unless placement? and 0 < placement.y < grayImage.height and 0 < placement.x < grayImage.width
			# Sanity check: Box is undefined or off-paper. TODO warning?
			return 0
		cropped = grayImage.crop placement.x - 5, placement.y - 5,
				placement.width + 10, placement.height + 10
		processed = cropped.dilate(3, 5).threshold(220)
		blobs = (component for component in processed.connectedComponents(8) when component.width > 8 and component.height > 14)
		if blobs.length is 0
			return 99
		else if blobs.length is 1
			return 70
		else if blobs.length is 2
			return 30
		else
			return 0
