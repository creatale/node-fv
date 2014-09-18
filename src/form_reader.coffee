dv = require 'dv'
async = require 'async'

{findBarcodes} = require './find_barcodes'
{findCheckboxes} = require './find_checkboxes'
{findText} = require './find_text'
{estimateTransform} = require './estimate_transform'
{matchBarcodes} = require './match_barcodes'
{matchText} = require './match_text'
{matchCheckboxes} = require './match_checkboxes'
unpack = require './unpack'

matchByPath = (field, formData) ->
	return unless field?.box? and field?.path?
	tail = formData
	for item in field.path.split('.')
		tail = tail[item]
		return unless tail?
	return tail if tail?.box?

class Form
	constructor: (@data, @images) ->

	match: (formSchema, cb) =>
		formData = {}

		# Match barcodes invariant to transformation changes.
		matchBarcodes formData, formSchema, @data[1]

		# Test if schema to page mapping was provided, estimate otherwise.
		if typeof formSchema.schemaToPage is 'function'
			schemaToPage = formSchema.schemaToPage
		else if formSchema.page?
			fallbackScale = @images[0].width / formSchema.page.width
			schemaToPage = estimateTransform formSchema.words, @data[2], fallbackScale

		# Match text and verify cleanliness of empty text fields.
		matchText formData, formSchema, @data[2], schemaToPage, @images[0]

		# Estimate schema to fields transform and match checkboxes.
		schemaToFields = estimateTransform formSchema.fields, formData, 1, 1, matchByPath
		matchCheckboxes formData, formSchema, @data[3], @data[2], schemaToPage, schemaToFields
		
		# Ensure that all paths exist.
		for field in formSchema.fields
			unpack formData, field.path
		
		# Call form validators.
		async.forEach formSchema.fields, (field, nextField) ->
			if field.formValidator?
				field.formValidator formData, nextField
			else
				nextField()
		, (err) ->
			return cb err if err?
			cb null, formData

		return

	toImage: =>
		resultImage = new dv.Image @images[0].width * @images.length, @images[0].height, 32
		imageOffset = (box, index) =>
			return {
				x: box.x + @images[0].width * index
				y: box.y
				width: box.width
				height: box.height
			}

		imageBox = {x: 0, y: 0, width: @images[0].width, height: @images[0].height}
		for image, index in @images when image?
			resultImage.drawImage(image.toColor(), imageOffset(imageBox, index))
		for data, index in @data[1..] when data?
			for boxed in data
				try 
					resultImage.drawBox(imageOffset(boxed.box, index), 2, 0, 0, 255, 0.5)
					resultImage.drawBox(imageOffset(boxed.candidate, index), 2, 255, 0, 0)

		#for anchor, index in @anchors
		#	box =
		#		x: anchor.word.box.x + anchor.offset.x
		#		y: anchor.word.box.y + anchor.offset.y
		#		width: anchor.word.box.width
		#		height: anchor.word.box.height
		#	resultImage.drawBox(imageOffset(box, 1), 4, 0, 255, 50, 0.5)
		#	resultImage.drawLine(imageOffset(box, 1), imageOffset(anchor.word.box, 1), 4, 0, 255, 255, 0.5)

		return resultImage

	toObject: =>
		return {
			barcodes: @data[1]
			text: @data[2]
			checkboxes: @data[3]
		}

module.exports = class FormReader
	constructor: (language = 'eng', @image = null) ->
		@tesseract = new dv.Tesseract language
		@tesseract.pageSegMode = 'single_block'
		@tesseract.classify_enable_learning = 0
		@tesseract.classify_enable_adaptive_matcher = 0
		@zxing = new dv.ZXing()

	find: =>
		data = [null, null, null, null]
		images = [@image, null, null, null]
		[data[1], images[1]] = findBarcodes images[0], @zxing
		[data[2], images[2]] = findText images[1], @tesseract
		[data[3], images[3]] = findCheckboxes images[2]
		return new Form data, images
		
