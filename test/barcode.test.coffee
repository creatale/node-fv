should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{findBarcodes} = require '../src/find_barcodes'
{matchBarcodes} = require '../src/match_barcodes'

createFormSchema = (a, b) ->
	that =
		called: []
		fields: [
			path: 'one'
			type: 'barcode'
			box:
				x: 0
				y: 0
				width: 100
				height: 50
			fieldValidator: if not a? then null else (value) ->
				shouldHaveBarcode value
				return value.type is a
			fieldSelector: (choices) -> 
				that.called.push 'one'
				return 0
		,
			path: 'two'
			type: 'barcode'
			box:
				x: 0
				y: 50
				width: 100
				height: 50
			fieldValidator: if not b? then null else (value) ->
				shouldHaveBarcode value
				return value.type is b
		]
	return that

createBarcodes = (a, b) -> [
	type: a
	data: '1234567890'
	buffer: '1234567890'
	box:
		x: 0
		y: 0
		width: 100
		height: 1
,
	type: b
	data: '1234567891'
	buffer: '1234567890'
	box:
		x: 0
		y: 50
		width: 100
		height: 1
]

shouldHaveBarcode = (barcode, withBox = false) ->
	should.exist barcode.type
	should.exist barcode.buffer
	should.exist barcode.data
	if withBox
		should.exist barcode.box
	else
		should.not.exist barcode.box
	should.not.exist barcode.points
	return

schemaToPage = ({x, y, width, height}) -> {x, y, width, height}

describe 'Barcode', ->
	describe 'recognizer', ->
		zxing = null
	
		before ->
			zxing = new dv.ZXing()

		it 'should find barcodes in synthetic image', ->
			barcodesImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/barcodes.png'))
			[barcodes, imageOut] = findBarcodes barcodesImage, zxing
			barcodes.should.have.length 4
			for barcode in barcodes
				shouldHaveBarcode barcode, true
				barcode.buffer.toString('ascii').should.equal ''
				barcode.data.should.equal '3000001060'
				barcode.type.should.equal 'ITF'
			imageOut.should.not.equal barcodesImage

		it 'should find barcodes in printed image', ->
			printedImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-printed.png'))
			[barcodes, imageOut] = findBarcodes printedImage, zxing
			barcodes.should.have.length 3
			for barcode in barcodes
				shouldHaveBarcode barcode, true
			imageOut.should.not.equal printedImage

	describe 'by position', ->
		it 'should not care', ->
			formSchema = createFormSchema 'ITF', 'ITF'
			formData1 = {}
			formData2 = {}
			barcodes1 = createBarcodes 'ITF', 'ITF'
			barcodes2 = createBarcodes 'ITF', 'ITF'
			barcodes2[0].box.x += 1042
			barcodes2[1].box.x += 1042
			matchBarcodes(formData1, formSchema, barcodes1, schemaToPage)
			matchBarcodes(formData2, formSchema, barcodes2, schemaToPage)
			formData1.one.box.x = 1042
			formData1.two.box.x = 1042
			formData1.should.deep.equal formData2

	describe 'by validator', ->
		it 'should match 1 barcode to "one" and drop others', ->
			formData = {}
			barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
			matchBarcodes(formData, createFormSchema('ITF', 'PDF_417'), barcodes, schemaToPage)
			formData.one.confidence.should.equal 100
			formData.one.value.data.should.equal barcodes[0].data
			formData.one.box.should.deep.equal barcodes[0].box
			formData.one.conflicts.should.have.length 0
			should.exist(formData.two)

		it 'should match 1 barcode to "one" and "two" with conflicts', ->
			formData = {}
			barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
			matchBarcodes(formData, createFormSchema('ITF', 'ITF'), barcodes, schemaToPage)
			formData.one.confidence.should.equal 100
			formData.one.value.data.should.equal(barcodes[0].data)
			formData.one.box.should.deep.equal(barcodes[0].box)
			formData.one.conflicts.should.have.length 1
			formData.two.confidence.should.equal 100
			formData.two.value.data.should.equal(barcodes[0].data)
			formData.two.box.should.deep.equal(barcodes[0].box)
			formData.two.conflicts.should.have.length 1
			
		it 'should match 2 barcodes to "one" using field selector', ->
			formData = {}
			barcodes = createBarcodes 'ITF', 'ITF'
			formSchema = createFormSchema 'ITF', 'PDF_417'
			matchBarcodes(formData, formSchema, barcodes, schemaToPage)
			formData.one.confidence.should.equal 100
			(formData.one.value.data in [barcodes[0].data, barcodes[1].data]).should.be.true
			(formData.one.box in [barcodes[0].box, barcodes[1].box]).should.be.true
			formData.one.conflicts.should.have.length 0
			formSchema.called.should.contain 'one'
			should.exist(formData.two)

		it 'should match 2 barcodes to "one" and "two" using field selector with conflicts', ->
			formData = {}
			barcodes = createBarcodes 'ITF', 'ITF'
			formSchema = createFormSchema 'ITF', 'ITF'
			matchBarcodes(formData, formSchema, barcodes, schemaToPage)
			formData.one.confidence.should.equal 100
			formData.one.conflicts.should.have.length 1
			(formData.one.value.data in [barcodes[0].data, barcodes[1].data]).should.be.true
			(formData.one.box in [barcodes[0].box, barcodes[1].box]).should.be.true
			formSchema.called.should.contain 'one'
			formData.two.confidence.should.equal 50
			formData.two.conflicts.should.have.length 1
			(formData.two.value.data in [barcodes[0].data, barcodes[1].data]).should.be.true
			(formData.two.box in [barcodes[0].box, barcodes[1].box]).should.be.true
			
		it 'should match 1 barcode to "one" and 1 barcode to "two"', ->
			formData = {}
			barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
			matchBarcodes(formData, createFormSchema('ITF', 'DATA_MATRIX'), barcodes, schemaToPage)
			formData.one.confidence.should.equal 100
			formData.one.value.data.should.equal(barcodes[0].data)
			formData.one.box.should.deep.equal(barcodes[0].box)
			formData.one.conflicts.should.have.length 0
			formData.two.confidence.should.equal 100
			formData.two.value.data.should.equal(barcodes[1].data)
			formData.two.box.should.deep.equal(barcodes[1].box)
			formData.two.conflicts.should.have.length 0
			