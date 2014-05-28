unpack = require './unpack'
{boxDistance} = require './box_math'
{estimateTransform} = require './estimate_transform'
dv = require 'dv'

# Match checkboxes to form schema.
#
module.exports.matchCheckboxes = (formData, formSchema, checkboxes, words, schemaToPage, schemaToData) ->
	checkboxFields = formSchema.filter((field) -> field.type is 'checkbox')

	#for word in words when word.text.length < 3
	#	logImage.drawBox word.box, 1, 255, 255, 0
	#for checkbox in checkboxes
	#	logImage.drawBox checkbox.box, 1, 255, 0, 255
	for field in checkboxFields
		# Position of checkbox according to field content offsets
		dataPos = schemaToData field.box
		#logImage.drawBox dataPos, 2, 255, 0, 0
		closeWord = findClosestShortWord words, dataPos, dataPos.width
		#logImage.drawBox closeWord.box, 3, 0, 255, 0 if closeWord?
		fieldData = unpack formData, field.path

		if closeWord? and field.fieldValidator? closeWord.text
			#console.log 'Decision from words at content offset'
			#logImage.drawBox closeWord.box, 3, 0, 255, 0
			fieldData.value = closeWord.text
			fieldData.confidence = closeWord.confidence
			fieldData.box = closeWord.box
		else
			pos = schemaToPage field.box
			#logImage.drawBox pos, 3, 0, 0, 255
			# FIXME: Because words are removed before findCheckbox runs, this may be false negative
			chosenCheckbox = findClosestCheckbox checkboxes, pos, pos.width * 1
			if chosenCheckbox?
				#console.log 'Checkbox candidate found close'
				fieldData.value = chosenCheckbox.checked
				fieldData.confidence = chosenCheckbox.confidence
				fieldData.box = chosenCheckbox.box
			else
				#console.log 'No checkbox candidate'
				fieldData.value = false
				fieldData.confidence = 99
				fieldData.box = pos
	#require('fs').writeFileSync('checkboxes.png', logImage.toBuffer('png'))

findClosestShortWord = (words, pos, maxDistance) ->
	minDistance = maxDistance
	closest = null
	centerX = pos.x + pos.width / 2
	centerY = pos.y + pos.height / 2
	for word in words when word.text.length < 3
		dist = Math.abs(word.box.x - centerX) + Math.abs(word.box.y - centerY)
		if dist < minDistance
			minDistance = dist
			closest = word
	return closest

findClosestCheckbox = (checkboxes, pos, maxDistance) ->
	minDistance = maxDistance
	closest = null
	centerX = pos.x + pos.width / 2
	centerY = pos.y + pos.height / 2
	for checkbox in checkboxes
		dist = Math.abs(checkbox.box.x - centerX) + Math.abs(checkbox.box.y - centerY)
		if dist < minDistance
			minDistance = dist
			closest = checkbox
	return closest
