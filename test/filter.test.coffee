should = require('chai').should()
dv = require 'dv'
fs = require 'fs'
path = require 'path'

binarize = require '../src/filters/binarize'
darkenInk = require '../src/filters/darken_ink'
deskew = require '../src/filters/deskew'
filterBackground = require '../src/filters/filter_background'
removeRed = require '../src/filters/remove_red'

writeImage = (filename, image) ->
	fs.writeFileSync(path.join(__dirname, 'log', filename), image.toBuffer('png'))

describe 'Filters', ->
	printedImage = null
	lowInkImage = null
	skewedImage = null
	
	before (done) ->
		printedImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-printed.png'))
		lowInkImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/low-ink.png'))
		skewedImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/skewed.png'))
		done()

	it 'should binarize', (done) ->
		writeImage 'M10-binarize.png', binarize printedImage
		done()

	it 'should darkenInk', (done) ->
		writeImage 'M10-darkenInk.png', darkenInk printedImage
		writeImage 'low-toner-darkenInk.png', darkenInk lowInkImage
		done()

	it 'should deskew', (done) ->
		writeImage 'skewed-deskew.png', deskew skewedImage
		writeImage 'low-toner-deskew.png', deskew lowInkImage
		done()

	it 'should filterBackground', (done) ->
		writeImage 'M10-filterBackground.png', filterBackground printedImage, 13, 19
		done()

	it 'should removeRed', (done) ->
		writeImage 'M10-removeRed.png', removeRed printedImage
		done()
