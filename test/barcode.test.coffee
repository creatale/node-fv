should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{findBarcodes} = require '../src/find_barcodes'
{matchBarcodes} = require '../src/match_barcodes'

createFormSchema = (a, b) ->
	fields: [
		path: 'one'
		type: 'barcode'
		box:
			x: 0
			y: 0
			width: 100
			height: 50
		fieldValidator: (value) ->
			shouldHaveBarcode value
			return value.type is a
		fieldSelector: (choices) ->
			choice = choices[0]
			choice.foobar = true
			return choices
	,
		path: 'two'
		type: 'barcode'
		box:
			x: 0
			y: 50
			width: 100
			height: 50
		fieldValidator: (value) ->
			shouldHaveBarcode value
			return value.type is b
		fieldSelector: (choices) ->
			choice = choices[0]
			choice.foobar = true
			return choices
	]

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

describe 'Barcode recognizer', ->
	describe 'find', ->
		zxing = null
	
		before ->
			zxing = new dv.ZXing()

		it 'should find barcodes in synthetic image', ->
			barcodesImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/barcodes.png'))
			[barcodes, imageOut] = findBarcodes barcodesImage, zxing
			barcodes.should.have.length 4
			for barcode in barcodes
				shouldHaveBarcode barcode, true
				barcode.buffer.toString('ascii').should.equal '3000001060'
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

	describe 'match by position', ->
		it 'should not care', ->
			formSchema = createFormSchema 'ITF', 'ITF'
			formData1 = {}
			formData2 = {}
			barcodes1 = createBarcodes 'ITF', 'ITF'
			barcodes2 = createBarcodes 'ITF', 'ITF'
			barcodes2[0].box.x += 1000
			barcodes2[1].box.x += 1042
			matchBarcodes(formData1, formSchema, barcodes1)
			matchBarcodes(formData2, formSchema, barcodes2)
			formData1.one.box.x = 1042
			formData1.two.box.x = 1042
			formData1.should.deep.equal formData2

	describe 'match by validator', ->
		it 'should match 1 barcode to "one" and drop others', ->
			formData = {}
			barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
			matchBarcodes(formData, createFormSchema('ITF', 'PDF_417'), barcodes)
			formData.one.confidence.should.equal 100
			formData.one.value.data.should.equal barcodes[0].data
			formData.one.box.should.equal barcodes[0].box
			should.not.exist(formData.one.foobar)
			should.not.exist(formData.two)

		it 'should match 1 barcode to "one" and "two" with low confidence', ->
			formData = {}
			barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
			matchBarcodes(formData, createFormSchema('ITF', 'ITF'), barcodes)
			formData.one.confidence.should.equal 50
			formData.one.value.data.should.equal(barcodes[0].data)
			formData.one.box.should.equal(barcodes[0].box)
			formData.two.confidence.should.equal 50
			formData.two.value.data.should.equal(barcodes[0].data)
			formData.two.box.should.equal(barcodes[0].box)
			(formData.one.foobar? isnt formData.two.foobar?).should.be.true

		it 'should match 2 barcodes to "one" with low confidence', ->
			formData = {}
			barcodes = createBarcodes 'ITF', 'ITF'
			matchBarcodes(formData, createFormSchema('ITF', 'PDF_417'), barcodes)
			formData.one.confidence.should.equal 50
			formData.one.value.data.should.equal(barcodes[0].data).or.equal(barcodes[1].data)
			formData.one.box.should.equal(barcodes[0].box).or.equal(barcodes[1].box)
			formData.one.foobar.should.be.true
			should.not.exist(formData.two)

		it 'should match 2 barcodes to "one" and "two" and with low confidence', ->
			formData = {}
			barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
			matchBarcodes(formData, createFormSchema('ITF', 'ITF'), barcodes)
			formData.one.confidence.should.equal 50
			formData.one.foobar.should.be.true
			formData.two.confidence.should.equal 50
			formData.two.foobar.should.be.true
			a = formData.one.value.data is barcodes[0].data and formData.two.value.data is barcodes[1].data and
				formData.one.box is barcodes[0].box and formData.two.box is barcodes[1].box
			b = formData.one.value.data is barcodes[1].data and formData.two.value.data is barcodes[0].data and
				formData.one.box is barcodes[1].box and formData.two.box is barcodes[0].box
			(a or b).should.be.true
			
		it 'should match 1 barcode to "one" and 1 barcode to "two"', ->
			formData = {}
			barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
			matchBarcodes(formData, createFormSchema('ITF', 'DATA_MATRIX'), barcodes)
			formData.one.confidence.should.equal 100
			formData.one.value.data.should.equal(barcodes[0].data)
			formData.one.box.should.equal(barcodes[0].box)
			should.not.exist formData.one.foobar
			formData.two.confidence.should.equal 100
			formData.two.value.data.should.equal(barcodes[1].data)
			formData.two.box.should.equal(barcodes[1].box)
			should.not.exist formData.two.foobar
