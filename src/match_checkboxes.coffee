unpack = require './unpack'
{estimateTransform} = require './estimate_transform'
dv = require 'dv'

# Match checkboxes to form schema.
#
module.exports.matchCheckboxes = (formData, formSchema, checkboxes, words, schemaToPage, schemaToData) ->
	checkboxFields = formSchema.fields.filter((field) -> field.type is 'checkbox')

	#for word in words when word.text.length < 3
	#	logImage.drawBox word.box, 1, 255, 255, 0
	#for checkbox in checkboxes
	#	logImage.drawBox checkbox.box, 1, 255, 0, 255

	assignedFields = matchByWordsAndContentOffset formData, checkboxFields, words, schemaToPage, schemaToData
	remainingFields = (field for field in checkboxFields when field not in assignedFields)
	matchByCheckboxCandidates formData, remainingFields, checkboxes, schemaToPage
	return
	
matchByWordsAndContentOffset = (formData, fields, words, schemaToPage, schemaToData) ->
	assignedByWord = []
	assignedWords = []
	for field in fields
		# Position of checkbox according to field content offsets
		dataPos = schemaToData field.box
		#logImage.drawBox dataPos, 2, 255, 0, 0
		closeWord = findClosestShortWord words, dataPos, dataPos.width
		closeWord ?= findClosestShortWord words, schemaToPage(field.box), dataPos.width
		#logImage.drawBox closeWord.box, 3, 0, 255, 0 if closeWord?
		fieldData = unpack formData, field.path

		if closeWord? and field.fieldValidator? closeWord.text
			if closeWord in assignedWords
				index = assignedWords.indexOf closeWord
				#console.log 'Conflict: ' + closeWord.text + ' might match ' + assignedByWord[index]?.path + ' and ' + field.path
				assignedByWord[index] = null
				continue
			#console.log field.path, 'Decision from words at content offset'
			#logImage.drawBox closeWord.box, 3, 0, 255, 0
			fieldData.value = closeWord.text
			fieldData.confidence = closeWord.confidence
			fieldData.box = closeWord.box
			assignedByWord.push field
			assignedWords.push closeWord
			
	return assignedByWord

matchByCheckboxCandidates = (formData, fields, checkboxes, schemaToPage) ->
	for field in fields
		pos = schemaToPage field.box
		fieldData = unpack formData, field.path
		#logImage.drawBox pos, 3, 0, 0, 255
		# FIXME: Because words are removed before findCheckbox runs, this may be false negative
		# Only accept candidates closer than CLOSE_DISTANCE, but reduce confidence when less than FAR_DISTANCE.
		CLOSE_DISTANCE = pos.width * 1
		FAR_DISTANCE = pos.width * 3
		chosenCheckbox = findClosestCheckbox checkboxes, pos, FAR_DISTANCE

		if chosenCheckbox? and distance(chosenCheckbox.box, pos) <= CLOSE_DISTANCE
			#console.log field.path, 'Checkbox candidate found close', chosenCheckbox
			fieldData.value = chosenCheckbox.checked
			fieldData.confidence = chosenCheckbox.confidence
			fieldData.box = chosenCheckbox.box
		else
			if not chosenCheckbox?
				confidence = 99
			else
				confidence = (distance(chosenCheckbox.box, pos) / FAR_DISTANCE) * 99
			#console.log field.path, 'No checkbox candidate'
			fieldData.value = false
			fieldData.confidence = confidence
			fieldData.box = pos
	#require('fs').writeFileSync('checkboxes.png', logImage.toBuffer('png'))
	
distance = (box1, box2) ->
	center1X = box1.x + (box1.width ? 0) / 2
	center1Y = box1.y + (box1.height ? 0) / 2
	center2X = box2.x + (box2.width ? 0) / 2
	center2Y = box2.y + (box2.height ? 0) / 2
	return Math.abs(center1X - center2X) + Math.abs(center1Y - center2Y)

findClosestShortWord = (words, pos, maxDistance) ->
	minDistance = maxDistance
	closest = null
	for word in words when word.text.length < 3
		dist = distance(word.box, pos)
		if dist < minDistance
			minDistance = dist
			closest = word
	return closest

findClosestCheckbox = (checkboxes, pos, maxDistance) ->
	minDistance = maxDistance
	closest = null
	for checkbox in checkboxes
		dist = distance(checkbox.box, pos)
		if dist < minDistance
			minDistance = dist
			closest = checkbox
	return closest
