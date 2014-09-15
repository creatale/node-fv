should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{findCheckboxes} = require '../src/find_checkboxes'

describe 'Checkbox recognizer', ->
	femaleBox = { x: 1480, y: 300, width: 24, height: 23 }
	
	describe 'should find checkboxes in', ->
		it 'synthetic image', ->
			checkboxesImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/checkboxes.png'))
			[checkboxes, imageOut] = findCheckboxes checkboxesImage
			checkboxes.should.have.length 12
			imageOut.should.not.equal checkboxesImage

		it 'content image', ->
			contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))
			[checkboxes, imageOut] = findCheckboxes contentImage
			checkboxes.should.not.be.empty
			imageOut.should.not.equal contentImage
			checkboxes.some((checkbox) -> Math.abs(checkbox.box.x - femaleBox.x) < 10).should.be.ok

	it 'should match checkboxes (mark)', ->
		#TODO: NYI.
		should.exist(null)

	it 'should match checkboxes (word)', ->
		#TODO: NYI.
		should.exist(null)

	it 'should match checkboxes (empty)', ->
		#TODO: NYI.
		should.exist(null)

	it 'should match checkboxes (white)', ->
		#TODO: NYI.
		should.exist(null)
