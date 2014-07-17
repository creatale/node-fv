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
	contentImage = null
	tesseract = null
	tesseractSparse = null
	mockSchemaToPage = ({x, y, width, height}) -> {x, y, width, height}
	contentWords = 'LeeTK 00047 Musterfrau Maria 11.05.42 Teststr. 1 D 99210 Prüfdorf 12/13 8001337 X123456789 '
	contentWords += '5000 1 123456700 101234567 02.09.13 Hypertonie(primäre) Struma nodosa BZ, HbA1, Krea, K+, '
	contentWords += 'TSH, Chol, HDL, LDL, HS'
	
	before (done) ->
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))
		tesseract = new dv.Tesseract 'deu'
		tesseract.pageSegMode = 'auto_osd'
		tesseract.classify_enable_learning = 0
		tesseract.classify_enable_adaptive_matcher = 0
		done()

	it 'should find text (clean)', (done) ->
		[words, image] = findText(contentImage, tesseract)
		wordsToBeFound = contentWords.split(' ')
		words.should.not.be.empty
		# We expect our contentWords in order (but allow gaps)
		for word in words
			# Tolerate the instances where Tesseract emits a SINGLE LOW-9 QUOTATION MARK instead of a comma...
			if word.text.replace('‚', ',') is wordsToBeFound[0]
				wordsToBeFound.shift()

		if wordsToBeFound.length > 0
			done new Error('Content word(s) missing, starting at: ' + wordsToBeFound[0])
		else
			done()

	it 'should match valid text', (done) ->
		formData = {}
		matchText formData, formSchema, fuzzyWords(true, 0), mockSchemaToPage, contentImage
		formData.should.not.be.empty
		done()

	it 'should match valid and fuzzed (5) text', (done) ->
		formData = {}
		matchText formData, formSchema, fuzzyWords(true, 5), mockSchemaToPage, contentImage
		formData.should.not.be.empty
		done()
		
	it 'should match valid and fuzzed (15) text', (done) ->
		formData = {}
		matchText formData, formSchema, fuzzyWords(true, 15), mockSchemaToPage, contentImage
		formData.should.not.be.empty
		done()
	
	it 'should match valid and fuzzed (20) text', (done) ->
		formData = {}
		matchText formData, formSchema, fuzzyWords(true, 20), mockSchemaToPage, contentImage
		formData.should.not.be.empty
		should.exist formData.lineOne.wordTwo.value
		formData.lineOne.wordTwo.value.should.equal '1234'
		done()

	it 'should partially match invalid and fuzzed text', (done) ->
		formData = {}
		matchText formData, formSchema, fuzzyWords(true, 5), mockSchemaToPage, contentImage
		formData.should.not.be.empty
		done()
