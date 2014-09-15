global.should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

FormReader = require '../src/form_reader'

describe 'FormReader', ->
	contentImage = null

	before (done) ->
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))
		done()

	it 'should read', (done) ->
		#TODO: NYI.
		should.exist(null)
		done()

	it 'should find checkbox between boxes with low confidence', (done) ->
		imagePath = '/data/lonely-checkboxes.png'
		schema =
			page:
				width: 1024
				height: 500
			words: []
			fields: [
				path: 'checkbox_YAY'
				type: 'checkbox'
				box:
					x: 660
					y: 135
					width: 60
					height: 60
			,
				path: 'checkbox_NAY'
				type: 'checkbox'
				box:
					x: 775
					y: 135
					width: 60
					height: 60
			]
		formReader = new FormReader 'eng'
		image = new dv.Image 'png', fs.readFileSync __dirname + imagePath
		formReader.image = image
		form = formReader.find()
		form.match schema, (err, data) ->
			data.checkbox_YAY.confidence.should.be.within(30,70)
			data.checkbox_NAY.confidence.should.be.within(30,70)
			done()

