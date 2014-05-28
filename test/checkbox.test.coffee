should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{findCheckboxes} = require '../src/find_checkboxes'

describe 'Checkbox recognizer', ->
	contentImage = null
	femaleBox = { x: 902, y: 143, width: 24, height: 23 }
	maleBox = { x: 1027, y: 143, width: 23, height: 23 }
	
	before ->
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))

	it 'should find checkboxes', ->
		[checkboxes, imageOut] = findCheckboxes contentImage
		checkboxes.should.not.be.empty
		imageOut.should.not.equal contentImage
		checkboxes.some((entry) -> entry.placement.x is maleBox.x).should.be.ok
		checkboxes.some((entry) -> entry.placement.x is femaleBox.x).should.be.ok
