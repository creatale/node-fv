#!/usr/bin/env coffee
#
# FormVision Command-Line Interface
#
args = require('minimist')(process.argv[2..], boolean: true)
glob = require 'glob'
fs = require 'fs'
dv = require 'dv'
fv = require __dirname + '/../lib/fv'

printHelp = ->
	console.log ['Usage: cli [OPTION]... FILES'
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
	].join('\n')

processImage = (formReader, filename, data) ->
	console.log 'Processing: ' + filename
	if /\.log\..*$/i.test filename
		console.log '  Skipping log image'
		return
	if /\.png$/i.test filename
		image = new dv.Image 'png', data
	else if /\.(jpg|jpeg)$/i.test filename
		image = new dv.Image 'jpg', data
	else
		console.warn '  Invalid format'
		return
	# Apply filters.
	if args['deskew']
		console.log '  Deskewing'
		image = fv.filters.deskew image
	if args['remove-red']
		console.log '  Removing Red'
		image = fv.filters.removeRed image
	if args['filter-background']
		console.log '  Filtering Background'
		image = fv.filters.filterBackground image, 25, 35
	if args['darken-ink']
		console.log '  Darkening Ink'
		image = fv.filters.darkenInk image
	# Require schema.
	if args['schema'] and typeof(args['schema']) is 'string'
		if /\.json$/.test args['schema']
			formSchema = JSON.parse(fs.readFileSync(args['schema']).toString())
		else
			formSchema = require args['schema']
	# Read form.
	formReader.image = image
	result = formReader.find()
	if formSchema?
		result.match formSchema, (err, formData) =>
			if err?
				console.error err.message
				return				
			console.log JSON.stringify(formData, null, 2)
	else
		logFilename = filename.replace(/\.([^\.]+)$/, '.log.$1')
		fs.writeFile logFilename, result.toImage().toBuffer('png')
		object = result.toObject()
		console.log '  Barcodes: ' + object.barcodes.map((data) -> data.type + ': ' + data.data)
		console.log '  Checkboxes: ' + object.checkboxes.length + ' in total'
		console.log '  Text: ', object.text.map((data) -> data.text).join(' ')
		console.log '  Log Image: ' + logFilename

# Help text.
if args.help
	printHelp()
	process.exit(0)

# Initialize reader.
lang = args['lang']
if lang?
	console.log 'Language: ' + lang
formReader = new fv.FormReader lang

# Process images.
filenames = args._
if filenames.length is 0
	console.warn 'Missing file arguments'
	printHelp()
	process.exit(-1)
for filename in filenames
	do (filename) ->
		fs.readFile filename, (err, data) ->	
			if err? and err.code is 'ENOENT'
				glob filename, null, (err, filenames) ->
					if err?
						console.warn 'Cannot glob pattern: ' + filename + ' ' + err
						process.exit(-2)
					for filename in filenames
						do (filename) ->
							fs.readFile filename, (err, data) ->
								processImage formReader, filename, data
			else if err?
				console.error 'Cannot read file: ' + filename
				process.exit(-3)
			else
				processImage formReader, filename, data
