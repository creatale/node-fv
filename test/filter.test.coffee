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
	inkImage = null
	skewedImage = null
	
	before ->
		printedImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-printed.png'))
		inkImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/filter-ink.png'))
		skewedImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/filter-skewed.png'))
		
	it 'should binarize', ->
		writeImage('M10-binarize.png', binarize(printedImage))
		
	it 'should darkenInk', ->
		writeImage('M10-darkenInk.png', darkenInk(printedImage))
		writeImage('ink-darkenInk.png', darkenInk(inkImage))
		
	it 'should deskew', ->
		writeImage('skewed-deskew.png', deskew(skewedImage))
		writeImage('ink-deskew.png', deskew(inkImage))
		
	it 'should filterBackground', ->
		writeImage('M10-filterBackground.png', filterBackground(printedImage, 13, 19))

	it 'should removeRed', ->
		writeImage('M10-removeRed.png', removeRed(printedImage))
		