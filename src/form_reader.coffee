dv = require 'dv'
async = require 'async'

{findBarcodes} = require './find_barcodes'
{findCheckboxes} = require './find_checkboxes'
{findText} = require './find_text'
{estimateTransform} = require './estimate_transform'
{matchBarcodes} = require './match_barcodes'
{matchText} = require './match_text'
{matchCheckboxes} = require './match_checkboxes'
{unpack} = require './schema'

matchByPath = (field, formData) ->
	return unless field?.box? and field?.path?
	tail = formData
	for item in field.path.split('.')
		tail = tail[item]
		return unless tail?
	return tail if tail?.box?

distinctColor = (index) ->
	colors = [
		"#000000", "#FFFF00", "#1CE6FF", "#FF34FF", "#FF4A46", "#008941", "#006FA6", "#A30059",
		"#FFDBE5", "#7A4900", "#0000A6", "#63FFAC", "#B79762", "#004D43", "#8FB0FF", "#997D87",
		"#5A0007", "#809693", "#FEFFE6", "#1B4400", "#4FC601", "#3B5DFF", "#4A3B53", "#FF2F80",
		"#61615A", "#BA0900", "#6B7900", "#00C2A0", "#FFAA92", "#FF90C9", "#B903AA", "#D16100",
		"#DDEFFF", "#000035", "#7B4F4B", "#A1C299", "#300018", "#0AA6D8", "#013349", "#00846F",
		"#372101", "#FFB500", "#C2FFED", "#A079BF", "#CC0744", "#C0B9B2", "#C2FF99", "#001E09",
		"#00489C", "#6F0062", "#0CBD66", "#EEC3FF", "#456D75", "#B77B68", "#7A87A1", "#788D66",
		"#885578", "#FAD09F", "#FF8A9A", "#D157A0", "#BEC459", "#456648", "#0086ED", "#886F4C",
		"#34362D", "#B4A8BD", "#00A6AA", "#452C2C", "#636375", "#A3C8C9", "#FF913F", "#938A81",
		"#575329", "#00FECF", "#B05B6F", "#8CD0FF", "#3B9700", "#04F757", "#C8A1A1", "#1E6E00",
		"#7900D7", "#A77500", "#6367A9", "#A05837", "#6B002C", "#772600", "#D790FF", "#9B9700",
		"#549E79", "#FFF69F", "#201625", "#72418F", "#BC23FF", "#99ADC0", "#3A2465", "#922329",
		"#5B4534", "#FDE8DC", "#404E55", "#0089A3", "#CB7E98", "#A4E804", "#324E72", "#6A3A4C",
		"#83AB58", "#001C1E", "#D1F7CE", "#004B28", "#C8D0F6", "#A3A489", "#806C66", "#222800",
		"#BF5650", "#E83000", "#66796D", "#DA007C", "#FF1A59", "#8ADBB4", "#1E0200", "#5B4E51",
		"#C895C5", "#320033", "#FF6832", "#66E1D3", "#CFCDAC", "#D0AC94", "#7ED379", "#012C58";
	]
	color = colors[index % colors.length]
	return [parseInt(color[1..2], 16), parseInt(color[3..4], 16), parseInt(color[5..6], 16)]

class Form
	constructor: (@data, @images) ->

	match: (formSchema, cb) =>
		formData = {}

		# Test if schema to page mapping was provided, estimate otherwise.
		if typeof formSchema.schemaToPage is 'function'
			schemaToPage = formSchema.schemaToPage
		else if formSchema.page?
			fallbackScale = @images[0].width / formSchema.page.width
			schemaToPage = estimateTransform formSchema.words, @data[2], fallbackScale

		# Match barcodes invariant to transformation changes.
		matchBarcodes formData, formSchema, @data[1], schemaToPage

		# Match text and verify cleanliness of empty text fields.
		{anchors} = matchText formData, formSchema, @data[2], schemaToPage, @images[0]
		@anchors = anchors
		# Estimate schema to fields transform and match checkboxes.
		schemaToFields = estimateTransform formSchema.fields, formData, 1, 1, matchByPath
		matchCheckboxes formData, formSchema, @data[3], @data[2], schemaToPage, schemaToFields
		
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
			for boxed, boxedIndex in data
					try for candidateBox in boxed.candidate
						color = distinctColor boxedIndex
						resultImage.drawBox(imageOffset(candidateBox, index), 6, color[0], color[1], color[2], 0.5)
					try resultImage.drawBox(imageOffset(boxed.box, index), 2, 0, 0, 255, 0.5)

		for anchor, index in @anchors ? []
			box =
				x: anchor.word.box.x + anchor.offset.x
				y: anchor.word.box.y + anchor.offset.y
				width: anchor.word.box.width
				height: anchor.word.box.height
			resultImage.drawBox(imageOffset(box, 1), 4, 0, 255, 50, 0.5)
			resultImage.drawLine(imageOffset(box, 1), imageOffset(anchor.word.box, 1), 4, 0, 255, 255, 0.5)

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
		
