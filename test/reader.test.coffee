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
