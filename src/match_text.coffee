unpack = require './unpack'
{boundingBox, length} = require './math'

# Find close words in a box.
findTwoClosestWords = (pageBox, words) ->
	wordDistances = words.map (word) -> {distance: Math.abs(word.box.x - pageBox.x) + Math.abs(word.box.y - pageBox.y), word}
	wordDistances = wordDistances.filter (i) -> i.distance < 200
	wordDistances.sort (a, b) -> a.distance - b.distance
	return wordDistances[...2].map (item) -> item.word

# Select words in a box.
selectWords = (words, box) ->
	selectedWords = []
	right = box.x + box.width
	bottom = box.y + box.height
	for word in words
		# Select all words that are at least 50% within box in x direction,
		# touch box in y direction, and are none of the typical 'character garbage'.
		if (word.box.x + word.box.width / 2) < right and (word.box.x + word.box.width / 2) > box.x and
				word.box.y < bottom and word.box.y + word.box.height > box.y and
				word.text not in ['I', '|', '_', '—']
			selectedWords.push word

	# Now decide which words in y direction to take: First line is the one which is nearest to specified y.
	firstLine = undefined
	firstLineDiff = Infinity

	for word in selectedWords
		diff = Math.abs box.y - word.box.y
		if diff < firstLineDiff
			firstLine = word.box.y
			firstLineDiff = diff
	#console.log 'Chosen as first line:', firstLine
	return (word for word in selectedWords when firstLine - 10 <= word.box.y < firstLine + box.height - 5)

# Estimate width of symbols from a word.
estimateSymbolWidth = (word) ->
	charWidth = word.box.width / word.text.length
	# Compensate for padding of outermost characters
	charWidth += 0.2 * charWidth / word.text.length
	return charWidth
	
# Convert words in random order to a single block of text.
wordsToText = (words, extendedGapDetection = false) ->
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
				charWidth = (estimateSymbolWidth(lastWord) + estimateSymbolWidth(word)) / 2
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

# Compute confidence from words.
wordsToConfidence = (words) ->
	return words.reduce(((sum, word) -> sum + word.confidence), 0) / words.length

# Compute confidence from pixels inside box.
boxToConfidence = (box, image) ->
	# Text allegedly empty; look whether there are any letter-sized blobs in actual image
	unless box? and 0 < box.y < image.height and 0 < box.x < image.width
		# Sanity check: Box is undefined or off-paper. TODO warning?
		return 0
	cropped = image.crop box.x - 5, box.y - 5, box.width + 10, box.height + 10
	processed = cropped.dilate(3, 5).threshold(220)
	blobs = (component for component in processed.connectedComponents(8) when component.width > 8 and component.height > 14)
	if blobs.length is 0
		return 100
	else if blobs.length is 1
		return 70
	else if blobs.length is 2
		return 30
	else
		return 0

# Find anchor words (unique matches).
findAnchors = (textFields, words, schemaToPage) ->
	anchors = []
	anchorFields = []
	anchorWords = []
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
			pageBox = schemaToPage textField.box
			continue if Math.abs(word.box.x - pageBox.x) + Math.abs(word.box.y - pageBox.y) > 400
			#console.log 'Unique match:', textField, word
			anchor =
				acceptedBy: textField.path
				offset:
					x: pageBox.x - word.box.x
					y: pageBox.y - word.box.y
				word: word
			anchors.push anchor
			anchorWords.push word

	return anchors

# Find closest anchor.
findClosestAnchor = (anchors, pageBox) ->
	minDistance = Infinity
	closest = null
	for anchor in anchors
		dist = Math.abs(anchor.word.box.x - pageBox.x) + Math.abs(anchor.word.box.y - pageBox.y)
		if dist < minDistance
			minDistance = dist
			closest = anchor
	return closest

# Find validating text variants.
findVariants = (field, anchors, words, schemaToPage) ->
	pageBox = schemaToPage field.box

	closestAnchor = findClosestAnchor anchors, pageBox
	if closestAnchor?
		pageBox.x -= closestAnchor.offset.x
		pageBox.y -= closestAnchor.offset.y

	wordsByPage = findTwoClosestWords pageBox, words
	
	# Build some box variants of an enclosing box in order of importance.
	boxVariants = [pageBox]
	for word in wordsByPage
		boxVariants.push
			x: word.box.x
			y: word.box.y
			width: pageBox.width
			height: pageBox.height
		boxVariants.push
			x: word.box.x
			y: word.box.y
			width: pageBox.width * 0.9
			height: pageBox.height * 0.9
		boxVariants.push
			x: word.box.x
			y: word.box.y
			width: pageBox.width * 1.1
			height: pageBox.height * 1.1

	# Interpret available words using box variants.
	variants = []
	for box in boxVariants
		candidateWords = selectWords words, box
		candidateText = wordsToText candidateWords, field.extendedGapDetection
		isDuplicate = variants.some (variant) -> variant.text is candidateText
		isValid = not field.fieldValidator? or field.fieldValidator(candidateText)
		if not isDuplicate and isValid
			if candidateWords.length > 0
				candidateBox = boundingBox (word.box for word in candidateWords)
			else
				candidateBox = box
			variants.push
				box: candidateBox
				text: candidateText
				words: candidateWords

	# Ensure at least one variant is returned.
	if variants.length is 0
		variants.push
			box: pageBox
			text: ''
			words: []

	return variants

# Match text to form schema.
#
# This process is content- and location-sensitive.
module.exports.matchText = (formData, formSchema, words, schemaToPage, rawImage) ->
	textFields = formSchema.fields.filter((field) -> field.type is 'text')
	image = rawImage.toGray()

	# Find anchors to compensate for *very* inaccurate printing.
	anchors = findAnchors textFields, words, schemaToPage
	nonAnchorWords = words.filter (word) -> not anchors.some (anchor) -> anchor.word is word

	matches = []
	wordUsage = []

	# Map to matches and usage.
	for field, fieldIndex in textFields
		variants = findVariants field, anchors, nonAnchorWords, schemaToPage

		if variants.length > 1 and field.fieldSelector?
			values = variants.map (variant) -> variant.text
			choice = field.fieldSelector values
			if choice not of values
				throw new Error('Returned choice index out of bounds')
		else
			choice = 0

		for word in variants[choice].words
			wordIndex = nonAnchorWords.indexOf word
			wordUsage[wordIndex] ?= []
			wordUsage[wordIndex].push field.path

		matches[fieldIndex] =
			variants: variants
			choice: choice

	# Reduce to fields.
	for field, fieldIndex in textFields
		variants = matches[fieldIndex].variants
		choice = matches[fieldIndex].choice
		chosenVariant = variants[choice]

		# Compute confidence.
		if chosenVariant.words.length > 0
			confidence = wordsToConfidence chosenVariant.words
		else
			confidence = boxToConfidence chosenVariant.box, image

		# Compute conflicts.
		conflicts = []
		for word in chosenVariant.words
			wordIndex = nonAnchorWords.indexOf word
			for path in wordUsage[wordIndex] when path not in conflicts
				conflicts.push path

		# Assign variant to field.
		fieldData = unpack formData, field.path
		fieldData.value = chosenVariant.text
		fieldData.confidence = confidence
		fieldData.box = chosenVariant.box
		fieldData.conflicts = conflicts.filter (path) -> path isnt field.path

	return {anchors}
