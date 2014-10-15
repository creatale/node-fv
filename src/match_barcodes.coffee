unpack = require './unpack'

barcodeToValue = (barcode) ->
	type: barcode.type
	data: barcode.data
	buffer: barcode.buffer

# Match barcode data to form schema.
#
# This process is content-sensitive, but not location-senstive.
module.exports.matchBarcodes = (formData, formSchema, barcodes, schemaToPage) ->
	barcodeFields = formSchema.fields.filter (field) -> field.type is 'barcode'
	# Map barcodes and fields to matches.
	matchMap = {}
	for barcode in barcodes
		value = barcodeToValue barcode
		validFields = barcodeFields.filter (field) -> not field.fieldValidator? or field.fieldValidator(value)
		for field in validFields
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
			fieldData.conflicts = if matches[choice].paths.length > 1 then matches[choice].paths else []
		else
			fieldData = unpack formData, field.path
			fieldData.confidence = 100
			fieldData.box = schemaToPage field.box
			fieldData.conflicts = []
	return
