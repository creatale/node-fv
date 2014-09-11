global.should = require('chai').should()
dv = require 'dv'
fs = require 'fs'
fv = require __dirname + '/../lib/fv'


testImageForText = (imagePath, text) ->
	formReader = new fv.FormReader 'eng'
	image = new dv.Image 'png', fs.readFileSync __dirname + imagePath
	formReader.image = image
	result = formReader.find()
	object = result.toObject()
	imageText = []
	imageText.push data.text for data in object.text
	imageText = imageText.join ' '
	imageText.should.equal text

describe 'fv low contrast', ->
	it 'should find text in 45% black', (done) ->
		testImageForText '/data/low-contrast-045.png', 'I am 3 LOW contrast text I am a high I am a low contrast text I am a low contrast text contrast text I am a low contrast text'
		done()
	
	it 'should not find text in 40% black', (done) ->
		testImageForText '/data/low-contrast-040.png', 'I am a high contrast text'
		done()

	it 'should not find text in 30% black', (done) ->
		testImageForText '/data/low-contrast-030.png', 'I am a high contrast text'
		done()

	it 'should not find text in 20% black', (done) ->
		testImageForText '/data/low-contrast-020.png', 'I am a high contrast text'
		done()

	it 'should not find text in 10% black', (done) ->
		testImageForText '/data/low-contrast-010.png', 'I am a high contrast text'
		done()

	it 'should not find text in 5% black', (done) ->
		testImageForText '/data/low-contrast-005.png', 'I am a high contrast text'
		done()
