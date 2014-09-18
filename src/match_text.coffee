unpack = require './unpack'
{boundingBox, manhattanVector, length} = require './math'

# Find two closest words next to top-left point.
findTwoClosestWords = (words, topLeft) ->
	wordDistances = words.map (word) -> {distance: Math.abs(word.box.x - topLeft.x) + Math.abs(word.box.y - topLeft.y), word}
	wordDistances = wordDistances.filter (item) -> item.distance < 200
	wordDistances.sort (a, b) -> a.distance - b.distance
	return wordDistances[...2].map (item) -> item.word

# Filter words using a box.
filterWordsInBox = (words, box) ->
	candidateWords = []
	right = box.x + box.width
	bottom = box.y + box.height
	for word in words
		# Select all words that are at least 50% within box in x direction,
		# touch box in y direction, and are none of the typical 'character garbage'.
		if (word.box.x + word.box.width / 2) < right and (word.box.x + word.box.width / 2) > box.x and
				word.box.y < bottom and word.box.y + word.box.height > box.y and
				word.text not in ['I', '|', '_', '—']
			candidateWords.push word

	# Decide which words in y-direction to take: First line is the one which is nearest to specified y.
	firstLine = undefined
	firstLineDiff = Infinity

	for word in candidateWords
		diff = Math.abs box.y - word.box.y
		if diff < firstLineDiff
			firstLine = word.box.y
			firstLineDiff = diff

	return (word for word in candidateWords when firstLine - 10 <= word.box.y < firstLine + box.height - 5)

# Estimate character width from word.
estimateCharWidth = (word) ->
	charWidth = word.box.width / word.text.length
	# Compensate for padding of outermost characters
	charWidth += 0.2*charWidth / word.text.length
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

# Match fields to word variants based on validation.
createVariants = (textFields, words, schemaToPage) ->
	variants = []
	for field in textFields
		# Build some variants of an enclosing box in order of importance.
		pageBox = schemaToPage field.box
		closeWords = findTwoClosestWords words, pageBox
		boxVariants = []
		for word in closeWords.concat(words)
			boxVariants = boxVariants.concat [
				x: word.box.x
				y: word.box.y
				width: word.box.width
				height: word.box.height
			,
				x: word.box.x
				y: word.box.y
				width: pageBox.width
				height: pageBox.height
			,
				x: word.box.x
				y: word.box.y
				width: pageBox.width * 0.9
				height: pageBox.height * 0.9
			,
				x: word.box.x
				y: word.box.y
				width: pageBox.width * 1.1
				height: pageBox.height * 1.1
			]
		# Validate variants.
		for box in boxVariants
			candidateWords = filterWordsInBox words, box
			candidateText = wordsToText candidateWords, field.extendedGapDetection
			isDuplicate = variants.some((variant) -> variant.value is candidateText and variant.field is field)
			isValid = field.fieldValidator?(candidateText) ? true
			if not isDuplicate and isValid
				if candidateWords.length > 0
					candidateBox = boundingBox (word.box for word in candidateWords)
					candidateConfidence = Math.round Math.min(candidateWords.map((word) -> word.confidence)...)
				else
					candidateBox = box
					candidateConfidence = 100
				variants.push
					field: field
					words: candidateWords
					confidence: candidateConfidence
					text: candidateText
					box: candidateBox
	return variants

# Select variant using field selector or fallback.
selectVariant = (variants, field) ->
	if field.fieldSelector?
		# Sophisticated conflict solving using buisness logic.
		chosenVariant = field.fieldSelector(variants.map((variant) -> {
			confidence: variant.confidence
			value: variant.text
			box: variant.box
		}))
	else
		# Less sophisticated conflict solving.
		chosenVariant = variants[0]
		if variants.length > 1
			#XXX: -10% might not be a smart idea, but should be okay for now.
			chosenVariant.confidence = Math.max(0, chosenVariant.confidence - 10)
	return chosenVariant

# Filter variants to match unambiguously with least amount of errors.
filterVariants = (fields, variants) ->
	result = []
	for field, i in fields
		otherFields = fields[i + 1..]
		fieldVariants = variants.filter (variant) -> variant.field is field
		fieldVariant = selectVariant fieldVariants, field
		otherFieldVariants = variants.filter (variant) -> 
			return false if variant.field is field
			return false for word in variant.words when word in fieldVariant.words
			return true
		subResult = filterVariants otherFields, otherFieldVariants
		if result.length < subResult.length + 1 
			result = [fieldVariant].concat subResult
	return result

# Compute confidence from pixels inside box.
boxToConfidence = (box, image) ->
	# Text allegedly empty; look whether there are any letter-sized blobs in actual image
	unless box? and 0 < box.y < image.height and 0 < box.x < image.width
		# Sanity check: Box is undefined or off-paper. TODO warning?
		return 0
	cropped = image.crop box.x - 5, box.y - 5,
			box.width + 10, box.height + 10
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

# Match text to form schema.
module.exports.matchText = (formData, formSchema, words, schemaToPage, rawImage) ->
	textFields = formSchema.fields.filter((field) -> field.type is 'text')
	
	allVariants = createVariants textFields, words, schemaToPage

	bestVariants = filterVariants textFields, allVariants

	# Assign variants.
	grayImage = rawImage.toGray()
	for variant in bestVariants
		fieldData = unpack formData, variant.field.path
		fieldData.value = variant.text
		if variant.words.length > 0 
			fieldData.confidence = variant.confidence
		else
			fieldData.confidence = boxToConfidence variant.box, grayImage
		fieldData.box = variant.box
