unpack = require './unpack'

# Match barcode data to form schema.
#
# This process is not location-senstive.
module.exports.matchBarcodes = (formData, formSchema, barcodes) ->
	barcodeFields = formSchema.fields.filter((field) -> field.type is 'barcode')
	for barcode in barcodes
		matches = []
		filteredBarcode =
			type: barcode.type
			data: barcode.data
			buffer: barcode.buffer
		for barcodeField in barcodeFields
			if barcodeField.fieldValidator(filteredBarcode)
				matches.push barcodeField 
		for match in matches
			fieldData = unpack(formData, match.path)
			confidence = Math.round(100 / matches.length)
			if not (confidence < fieldData.confidence)
				fieldData.value = 
					data: barcode.data
					buffer: barcode.buffer
				fieldData.confidence = confidence
				fieldData.box = barcode.box
