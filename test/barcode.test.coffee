should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{findBarcodes} = require '../src/find_barcodes'
{matchBarcodes} = require '../src/match_barcodes'

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

	it 'should match barcodes', (done) ->
		#TODO: NYI.
		should.exist(null)
		done()
