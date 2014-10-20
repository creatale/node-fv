unpack = require './unpack'
{estimateTransform} = require './estimate_transform'
{distance} = require './math'

findClosestShortWord = (words, box, maxDistance) ->
	minDistance = maxDistance
	closestIndex = -1
	for word, index in words when word.text.length < 3
		dist = distance(word.box, box)
		if dist < minDistance
			minDistance = dist
			closestIndex = index
	return closestIndex

matchByWords = (formData, fields, words, schemaToPage, schemaToData) ->
	matchedFields = []
	matches = []
	wordUsage = []
	for field in fields
		# Find short words close to estimated locations (data and page transform).
		dataBox = schemaToData field.box
		closeIndex = findClosestShortWord words, dataBox, dataBox.width
		closeIndex = findClosestShortWord words, schemaToPage(field.box), dataBox.width if closeIndex is -1
		continue if closeIndex is -1
		# Validate short words.
		if not field.fieldValidator? or field.fieldValidator(words[closeIndex].text)
			wordUsage[closeIndex] ?= []
			wordUsage[closeIndex].push field.path
			matchedFields.push field
			matches.push closeIndex
	# Assign matching fields.
	for field, index in matchedFields
		index = matches[index]
		fieldData = unpack formData, field.path
		fieldData.value = words[index].text
		fieldData.confidence = words[index].confidence
		fieldData.box = words[index].box
		fieldData.conflicts = if wordUsage[index].length > 1 then wordUsage[index] else []
	return matchedFields

findClosestMark = (marks, box, maxDistance) ->
	minDistance = maxDistance
	closestIndex = -1
	for mark, index in marks
		dist = distance(mark.box, box)
		if dist < minDistance
			minDistance = dist
			closestIndex = index
	return closestIndex

matchByMark = (formData, fields, marks, schemaToPage) ->
	matches = {}
	markUsage = []
	for field in fields
		# Find close marks using estimated locations (only page transform).
		pageBox = schemaToPage field.box
		nearDistance = pageBox.width
		farDistance = pageBox.width * 3
		closeIndex = findClosestMark marks, pageBox, farDistance
		if closeIndex is -1
			# No marks with less than far distance found, thus false.
			matches[field.path] = 
				index: -1
				value: false
				confidence: 100
				box: pageBox
		else if distance(marks[closeIndex].box, pageBox) > nearDistance
			# Mark between near and far distance found, thus false with reduced confidence.
			matches[field.path] =
				index: -1
				value: false
				confidence: Math.round((distance(marks[closeIndex].box, pageBox) / farDistance) * 100)
				box: pageBox
		else
			# Near mark found, thus use it.
			matches[field.path] = 
				index: closeIndex
				value: marks[closeIndex].checked
				confidence: marks[closeIndex].confidence
				box: marks[closeIndex].box
			markUsage[closeIndex] ?= []
			markUsage[closeIndex].push field.path
	# Assign matching fields.
	for field in fields
		match = matches[field.path]
		fieldData = unpack formData, field.path
		fieldData.value = match.value
		fieldData.confidence = match.confidence
		fieldData.box = match.box
		if match.index is -1
			fieldData.conflicts = []
		else
			fieldData.conflicts = if markUsage[match.index].length > 1 then markUsage[match.index] else []
	return
	
# Match checkboxes to form schema.
#
# This process is content- and location-sensitive. Short words are preferred over marks.
# XXX: false negatives are to be expected when words are invalidated!
# XXX: do not use word confidence as checkbox confidence!
module.exports.matchCheckboxes = (formData, formSchema, marks, words, schemaToPage, schemaToData) ->
	checkboxFields = formSchema.fields.filter((field) -> field.type is 'checkbox')
	assignedFields = matchByWords formData, checkboxFields, words, schemaToPage, schemaToData
	remainingFields = (field for field in checkboxFields when field not in assignedFields)
	matchByMark formData, remainingFields, marks, schemaToPage
	return
