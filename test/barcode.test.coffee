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
		fieldValidator: (barcode) -> barcode.type is a
	,
		path: 'two'
		type: 'barcode'
		box:
			x: 0
			y: 50
			width: 100
			height: 50
		fieldValidator: (barcode) -> barcode.type is b
	]

createBarcodes = (a, b) -> [
	type: a
	data: '1234567890'
	box:
		x: 0
		y: 0
,
	type: b
	data: '1234567891'
	box:
		x: 0
		y: 50
]

describe 'Barcode recognizer', ->
	barcodesImage = null
	printedImage = null
	zxing = null
	
	before (done) ->
		barcodesImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/barcodes.png'))
		printedImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-printed.png'))
		zxing = new dv.ZXing()
		done()

	it 'should find barcodes in synthetic image', (done) ->
		[barcodes, imageOut] = findBarcodes barcodesImage, zxing
		barcodes.should.have.length 4
		imageOut.should.not.equal barcodesImage
		done()

	it 'should find barcodes in real image', (done) ->
		[barcodes, imageOut] = findBarcodes printedImage, zxing
		barcodes.should.have.length 3
		imageOut.should.not.equal printedImage
		done()

	it 'should match 1 barcode to "one" and drop others', (done) ->
		formData = {}
		barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
		matchBarcodes(formData, createFormSchema('ITF', 'PDF_417'), barcodes)
		formData.one.confidence.should.equal 100
		formData.one.value.data.should.equal barcodes[0].data
		formData.one.box.should.equal barcodes[0].box
		done()

	it 'should match 2 barcodes to "one" with low confidence', (done) ->
		formData = {}
		barcodes = createBarcodes 'ITF', 'ITF'
		matchBarcodes(formData, createFormSchema('ITF', 'PDF_417'), barcodes)
		formData.one.confidence.should.equal 50
		formData.one.value.data.should.equal(barcodes[0].data).or.equal(barcodes[1].data)
		formData.one.box.should.equal(barcodes[0].box).or.equal(barcodes[1].box)
		done()

	it 'should match 1 barcode to "one" and "two" with low confidence', (done) ->
		formData = {}
		barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
		matchBarcodes(formData, createFormSchema('ITF', 'ITF'), barcodes)
		formData.one.confidence.should.equal 50
		formData.one.value.data.should.equal(barcodes[0].data)
		formData.one.box.should.equal(barcodes[0].box)
		formData.two.confidence.should.equal 50
		formData.two.value.data.should.equal(barcodes[0].data)
		formData.two.box.should.equal(barcodes[0].box)
		done()

	it 'should match 2 barcodes to "one" and "two" and with low confidence', (done) ->
		formData = {}
		barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
		matchBarcodes(formData, createFormSchema('ITF', 'ITF'), barcodes)
		formData.one.confidence.should.equal 50
		formData.two.confidence.should.equal 50
		a = formData.one.value.data is barcodes[0].data and formData.two.value.data is barcodes[1].data and
			formData.one.box is barcodes[0].box and formData.two.box is barcodes[1].box
		b = formData.one.value.data is barcodes[1].data and formData.two.value.data is barcodes[0].data and
			formData.one.box is barcodes[1].box and formData.two.box is barcodes[0].box
		(a or b).should.be.true
		done()

	it 'should match 1 barcode to "one" and 1 barcode to "two"', (done) ->
		formData = {}
		barcodes = createBarcodes 'ITF', 'DATA_MATRIX'
		matchBarcodes(formData, createFormSchema('ITF', 'DATA_MATRIX'), barcodes)
		formData.one.confidence.should.equal 100
		formData.one.value.data.should.equal(barcodes[0].data)
		formData.one.box.should.equal(barcodes[0].box)
		formData.two.confidence.should.equal 100
		formData.two.value.data.should.equal(barcodes[1].data)
		formData.two.box.should.equal(barcodes[1].box)
		done()
