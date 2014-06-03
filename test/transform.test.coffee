global.should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{estimateTransform} = require '../src/estimate_transform'

describe 'Estimate transform', ->
	contentImage = null

	before (done) ->
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))
		done()

	it 'should map between A and B', (done) ->
		#TODO: NYI.
		should.exist(null)
		done()

	it 'should map between A and B (fallback)', (done) ->
		#TODO: NYI.
		should.exist(null)
		done()
