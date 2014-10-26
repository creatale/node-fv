global.should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

FormReader = require '../src/form_reader'

describe 'FormReader', ->
	contentImage = null

	it 'should read M10', (done) ->
		imagePath = '/data/m10-content.png'
		schemaPath = '/data/m10-schema.json'
		formReader = new FormReader 'deu'
		formReader.image = new dv.Image 'png', fs.readFileSync(__dirname + imagePath)
		form = formReader.find()
		form.match JSON.parse(fs.readFileSync(__dirname + schemaPath)), (err, data) ->
			should.not.exist err
			data.patientVorname.value.should.equal 'Maria'
			data.patientName.value.should.equal 'Musterfrau'
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
		formReader.image = new dv.Image 'png', fs.readFileSync(__dirname + imagePath)
		form = formReader.find()
		form.match schema, (err, data) ->
			should.not.exist err
			data.checkbox_YAY.confidence.should.be.within(30, 70)
			data.checkbox_NAY.confidence.should.be.within(30, 70)
			done()
