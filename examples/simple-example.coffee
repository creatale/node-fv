fs = require 'fs'
dv = require 'dv'
fv = require __dirname + '/../lib/fv'

image = new dv.Image 'png', fs.readFileSync __dirname + '/form1-clean.png'
formSchema =
	page:
		width: 2360
		height: 1800
	words: []
	fields: [
		path: 'last-name'
		type: 'text'
		box:
			x: 150
			y: 660
			width: 1200
			height: 50
	,
		path: 'first-name'
		type: 'text'
		box:
			x: 1500
			y: 660
			width: 750
			height: 50
	,
		path: 'birthdate'
		type: 'text'
		box:
			x: 680
			y: 920
			width: 530
			height: 42

	,
		path: 'anchors.gender'
		type: 'text'
		box:
			x: 1525
			y: 900
			width: 110
			height: 32
		fieldValidator: (value) -> value is 'gender'
	]


formReader = new fv.FormReader 'eng'
formReader.image = image
form = formReader.find()
form.match formSchema, (err, formData) =>
	console.log formData
	fs.writeFile 'example.log.png', form.toImage().toBuffer('png')
