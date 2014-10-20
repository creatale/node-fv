unpack = require './unpack'
{distanceVector, length, center} = require './math'

barcodeToValue = (barcode) ->
	type: barcode.type
	data: barcode.data
	buffer: barcode.buffer

# Match barcode data to form schema.
module.exports.matchBarcodes = (formData, formSchema, barcodes, schemaToPage) ->
	barcodeFields = formSchema.fields.filter (field) -> field.type is 'barcode'
	# Map barcodes and fields to matches.
	matchMap = {}
	for barcode in barcodes
		value = barcodeToValue barcode
		validFields = barcodeFields.filter (field) -> not field.fieldValidator? or field.fieldValidator(value)
		for field in validFields
			# If searchRadius is set, additionally filter matches by distance
			if field.searchRadius > 0
				projection = schemaToPage(field.box)
				distance = length distanceVector(center(projection), center(barcode.box))
				radius = Math.max(projection.width, projection.height) / 2
				continue if distance > radius * field.searchRadius

			matchMap[field.path] ?= []
			matchMap[field.path].push 
				barcode: barcode
				paths: validFields.map (field) -> field.path
	# Reduce matches to fields.
	for field in barcodeFields
		if matchMap[field.path]?
			matches = matchMap[field.path]
			# Many barcodes to one field resolution.
			if matches.length > 1 and field.fieldSelector?
				values = matches.map (match) -> barcodeToValue match.barcode
				choice = field.fieldSelector values
				if choice not of values
					throw new Error('Returned choice index out of bounds')
			else
				choice = 0
			# Assign to field.
			fieldData = unpack formData, field.path
			fieldData.value = barcodeToValue matches[choice].barcode
			fieldData.confidence = 100
			fieldData.box = matches[choice].barcode.box
			fieldData.conflicts = matches[choice].paths.filter (path) -> path isnt field.path
		else
			fieldData = unpack formData, field.path
			fieldData.confidence = 100
			fieldData.box = schemaToPage field.box
			fieldData.conflicts = []
	return
