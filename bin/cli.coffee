#!/usr/bin/env coffee
#
# FormVision Command-Line Interface
#
args = require('minimist')(process.argv[2..], boolean: true)
fs = require 'fs'
dv = require 'dv'
fv = require __dirname + '/../lib/fv'

# Help text.
if args.help
	text = ['Usage: cli [OPTION]... FILES'
		'Process FILES using FormVision.'
		''
		'  --lang=             language to use for Tesseract'
		'  --schema=           FormVision Schema (module.exports)'
		'  --deskew            apply deskew filter'
		'  --darken-ink        apply darken-ink filter'
		'  --filter-background apply filter-background filter'
		'  --remove-red        apply remove-red filter'
		'  --help              display help text'
		''
		'Supported image formats are PNG and JPEG.'
	]
	console.log text.join('\n')
	process.exit(0)

# Initialize schema.
schemaFilename = args['schema']
if schemaFilename?
	formSchema = require schemaFilename

# Initialize reader.
formReader = new fv.FormReader args['lang']

# Process images.
imageFilenames = args._
if imageFilenames.length is 0
	console.log 'Missing file arguments'
	process.exit(0)
for filename in imageFilenames
	fs.readFile filename, (err, data) ->
		if /\.png$/i.test filename
			image = new dv.Image 'png', data
		else if /\.(jpg|jpeg)$/i.test filename
			image = new dv.Image 'jpg', data
		else
			console.warn 'Skipping: ' + filename
			return
		console.log 'Processing: ' + filename
		# Apply filters.
		if args['deskew']
			console.log 'deskew'
			image = fv.filters.deskew image
		if args['remove-red']
			console.log 'removeRed'
			image = fv.filters.removeRed image
		if args['filter-background']
			console.log 'filterBackground'
			image = fv.filters.filterBackground image, 25, 35
		if args['darken-ink']
			console.log 'darkenInk'
			image = fv.filters.darkenInk image
		# Read form.
		formReader.image = image
		result = formReader.find()
		if formSchema?
			result.match formSchema, (err, formData) =>
				if err?
					console.error err.message
					return
				console.log formData
		else
			logFilename = filename.replace(/\.([^\.]+)$/, '.log.$1')
			fs.writeFile logFilename, result.toImage().toBuffer('png')
			object = result.toObject()
			console.log 'Barcodes: ' + object.barcodes.map((data) -> data.type + ': ' + data.data)
			console.log 'Checkboxes: ' + object.checkboxes.length + ' in total'
			console.log 'Text: ', object.text.map((data) -> data.text)
			console.log 'Log Image: ' + logFilename
