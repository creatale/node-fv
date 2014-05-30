should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{findBarcodes} = require '../src/find_barcodes'
{matchBarcodes} = require '../src/match_barcodes'

describe 'Barcode recognizer', ->
	contentImage = null
	zxing = null
	
	before (done) ->
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))
		zxing = new dv.ZXing()
		done()

	it 'should find barcodes', (done) ->
		[barcodes, imageOut] = findBarcodes contentImage, zxing
		barcodes.should.not.be.empty
		imageOut.should.not.equal contentImage
		done()
