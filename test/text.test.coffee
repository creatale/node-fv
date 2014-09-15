global.should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{findText} = require '../src/find_text'
{matchText} = require '../src/match_text'

formSchema =
	page: {width: 200, height: 200}
	words: []
	fields: [
		path: 'lineOne.wordOne'
		type: 'text'
		box:
			x: 50
			y: 23
			width: 20
			height: 15
	,
		path: 'lineOne.wordTwo'
		type: 'text'
		box:
			x: 60
			y: 0
			width: 20
			height: 15
		validValue: '1234' 
		fieldValidator: (fieldData) -> /^\d+$/.test fieldData
	,
		path: 'lineTwo.wordOne'
		type: 'text'
		box:
			x: 0
			y: 18
			width: 40
			height: 15
		shouldValue: 'Hello' 
	,
		path: 'lineTwoNHalf.wordOne'
		type: 'text'
		box:
			x: 50
			y: 23
			width: 20
			height: 15
	,
		path: 'lineThree.wordOne'
		type: 'text'
		box:
			x: 0
			y: 36
			width: 30
			height: 15
	,
		path: 'lineFour.wordOne'
		type: 'text'
		box:
			x: 0
			y: 49
			width: 60
			height: 15
	]

fuzzyWords = (valid, offset) ->
	fuzzyString = 'TZV8IdsZiCd?wYd0QxOwT.nwt8phbQs!InZ6unGrkXP'
	words = []
	for field, index in formSchema.fields
		if valid and field.validValue?
			value = field.validValue
		else
			value = fuzzyString.substr(index, 2 + index * 2)
		direction = 2 * Math.PI * (index / formSchema.fields.length)
		words.push
			text: value
			confidence: if valid then 0.9 else 0.5
			box:
				x: field.box.x + offset * Math.sin(direction)
				y: field.box.y + offset * Math.cos(direction)
				width: field.box.width
				height: field.box.height
	return words

describe 'Text recognizer', ->
	mockSchemaToPage = ({x, y, width, height}) -> {x, y, width, height}
	contentImage = null

	before ->
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))

	describe 'should find text in', ->
		tesseract = null
		shouldFindText = (language, image, expectedText) ->
			image = 
			[words, image] = findText(image, tesseract)
			words.should.not.be.empty
			wordsMissing = expectedText.split(' ').filter((word) -> word in words)
			if wordsMissing.length > 0
				throw new Error('Content word(s) missing: ' + wordsMissing)

		before ->
			tesseract = new dv.Tesseract 'deu'
			tesseract.pageSegMode = 'single_block'
			tesseract.classify_enable_learning = 0
			tesseract.classify_enable_adaptive_matcher = 0

		it 'synthetic image at 45% black', ->
			shouldFindText 'eng', new dv.Image('png', fs.readFileSync(__dirname + '/data/text-045.png')),
				'I am 3 LOW contrast text I am a high I am a low contrast text '
				'I am a low contrast text contrast text I am a low contrast text'

		it 'synthetic image at 30% black', ->
			shouldFindText 'eng', new dv.Image('png', fs.readFileSync(__dirname + '/data/text-030.png')),
				'I am 3 LOW contrast text I am a high I am a low contrast text '
				'I am a low contrast text contrast text I am a low contrast text'

		it 'synthetic image at 5% black', ->
			shouldFindText 'eng', new dv.Image('png', fs.readFileSync(__dirname + '/data/text-005.png')),
				'I am 3 LOW contrast text I am a high I am a low contrast text '
				'I am a low contrast text contrast text I am a low contrast text'

		it 'real image', ->
			shouldFindText 'deu', contentImage,
				'LeeTK 00047 Musterfrau Maria 11.05.42 Teststr. 1 D 99210 Prüfdorf 12/13 8001337 X123456789 ' +
				'5000 1 123456700 101234567 02.09.13 Hypertonie(primäre) Struma nodosa BZ, HbA1, Krea, K+, ' +
				'TSH, Chol, HDL, LDL, HS'

	it 'should match valid text', ->
		formData = {}
		matchText formData, formSchema, fuzzyWords(true, 0), mockSchemaToPage, contentImage
		formData.should.not.be.empty
		
	it 'should match valid and fuzzed (5) text', ->
		formData = {}
		matchText formData, formSchema, fuzzyWords(true, 5), mockSchemaToPage, contentImage
		formData.should.not.be.empty
		
	it 'should match valid and fuzzed (15) text', ->
		formData = {}
		matchText formData, formSchema, fuzzyWords(true, 15), mockSchemaToPage, contentImage
		formData.should.not.be.empty
		
	it 'should match valid and fuzzed (20) text', ->
		formData = {}
		matchText formData, formSchema, fuzzyWords(true, 20), mockSchemaToPage, contentImage
		formData.should.not.be.empty
		should.exist formData.lineOne.wordTwo.value
		formData.lineOne.wordTwo.value.should.equal '1234'
		
	it 'should partially match invalid and fuzzed text', ->
		formData = {}
		matchText formData, formSchema, fuzzyWords(true, 5), mockSchemaToPage, contentImage
		formData.should.not.be.empty
		