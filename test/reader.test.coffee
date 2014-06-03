global.should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

fv = require '../lib/fv'

describe 'FormReader', ->
	contentImage = null

	before (done) ->
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))
		formSchema = new fv.FormSchema()
		done()

	it 'should read', (done) ->
		#TODO: NYI.
		should.exist(null)
		done()
