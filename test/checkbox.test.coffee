should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{findCheckboxes} = require '../src/find_checkboxes'

describe 'Checkbox recognizer', ->
	contentImage = null
	femaleBox = { x: 1480, y: 300, width: 24, height: 23 }
	
	before (done) ->
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))
		done()

	it 'should find checkboxes', (done) ->
		[checkboxes, imageOut] = findCheckboxes contentImage
		checkboxes.should.not.be.empty
		imageOut.should.not.equal contentImage
		checkboxes.some((checkbox) -> Math.abs(checkbox.box.x - femaleBox.x) < 10).should.be.ok
		done()
