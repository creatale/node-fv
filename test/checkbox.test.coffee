should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{findCheckboxes} = require '../src/find_checkboxes'

describe 'Checkbox recognizer', ->
	checkboxesImage = null
	contentImage = null
	femaleBox = { x: 1480, y: 300, width: 24, height: 23 }
	
	before (done) ->
		checkboxesImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/checkboxes.png'))
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))
		done()

	it 'should find checkboxes in synthetic image', (done) ->
		[checkboxes, imageOut] = findCheckboxes checkboxesImage
		checkboxes.should.have.length 12
		imageOut.should.not.equal checkboxesImage
		done()

	it 'should find checkboxes in real image', (done) ->
		[checkboxes, imageOut] = findCheckboxes contentImage
		checkboxes.should.not.be.empty
		imageOut.should.not.equal contentImage
		checkboxes.some((checkbox) -> Math.abs(checkbox.box.x - femaleBox.x) < 10).should.be.ok
		done()

	it 'should match checkboxes (mark)', (done) ->
		#TODO: NYI.
		should.exist(null)
		done()

	it 'should match checkboxes (word)', (done) ->
		#TODO: NYI.
		should.exist(null)
		done()

	it 'should match checkboxes (empty)', (done) ->
		#TODO: NYI.
		should.exist(null)
		done()

	it 'should match checkboxes (white)', (done) ->
		#TODO: NYI.
		should.exist(null)
		done()
