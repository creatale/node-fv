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

module.exports = class FormReader
	constructor: (language, @image = null) ->
		# Initialize DocumentVision instances.
		@tesseract = new dv.Tesseract language
		@tesseract.classify_enable_learning = 0
		@tesseract.classify_enable_adaptive_matcher = 0
		#@tesseract.tessedit_char_whitelist = 'ÄÖÜABCDEFGHIJKLMNOPQRSTUVWXYZäöüabcdefghijklmnopqrstuvwxyz+-.,;:§[]'
		#@tesseract.tessedit_consistent_reps = false
		@zxing = new dv.ZXing()
		@images = [@image, null, null, null]
		@words = []
		@barcodes = []
		@checkboxes = []
		@schemaToPage = null
		@schemaToData = null

	find: (formSchema, cb) =>
		# Reset data.
		@images = [@image, null, null, null]
		@words = []
		@barcodes = []
		@checkboxes = []
		@schemaToPage = null
		@schemaToData = null
		formData = {}

		# Extract data.
		[@barcodes, @images[1]] = findBarcodes @images[0], @zxing
		[@words, @images[2]] = findText @images[1], @tesseract
		[@checkboxes, @images[3]] = findCheckboxes @images[2]

		# Match barcodes invariant to transformation changes.
		matchBarcodes formData, formSchema, @barcodes

		if typeof formSchema.schemaToPage is 'function'
			@schemaToPage = formSchema.schemaToPage
		else if formSchema.page?
			# Estimate transform between image and schema.
			fallbackScale = @image.width / formSchema.page.width
			@schemaToPage = estimateTransform formSchema.words, @words, fallbackScale
		matchText formData, formSchema, @words, @schemaToPage, @image

		# Estimate schema to data transform and match checkboxes.
		@schemaToFields = estimateTransform formSchema, formData, 1, 1, matchByPath
		matchCheckboxes formData, formSchema, @checkboxes, @words, @schemaToPage, @schemaToFields, @image
		
		# Call form validators.
		async.forEach formSchema, (field, nextField) ->
			if field.formValidator?
				field.formValidator formData, nextField
			else
				nextField()
		, (err) ->
			return cb err if err?
			cb null, formData

	logImage: =>
		if @images.some((image) -> not image?)
			throw new "FormReader#find() did not run"

		imageBox = {x: 0, y: 0, width: @image.width, height: @image.height}
		imageOffset = (box, index) =>
			return {
				x: box.x + @image.width * index
				y: box.y
				width: box.width
				height: box.height
			}

		logImage = new dv.Image @image.width * 4, @image.height, 32
		for image, index in @images
			logImage.drawImage(image.toColor(), imageOffset(imageBox, index))

		for barcode in @barcodes
			logImage.drawBox(imageOffset(barcode.box, 0), 2, 255, 0, 0, 0.5)

		for word in @words
			logImage.drawBox(imageOffset(word.box, 1), 2, 255, 0, 0, 0.5)

		for checkbox in @checkboxes
			logImage.drawBox(imageOffset(checkbox.box, 2), 2, 255, 0, 0, 0.5)

		return logImage
