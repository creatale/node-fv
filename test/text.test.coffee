global.should = require('chai').should()
dv = require 'dv'
fs = require 'fs'
path = require 'path'

{boundingBox} = require '../src/math'
{findText} = require '../src/find_text'
{matchText} = require '../src/match_text'

createFormSchema = (a, b, c) ->
	that =
		called: []
		page: {width: 500, height: 100}
		words: ['foobar']
		fields: [
			path: 'one'
			type: 'text'
			box:
				x: 0
				y: 0
				width: 500
				height: 50
			fieldValidator: (value) -> if not a? then true else value is a
			fieldSelector: (choices) ->
				that.called.push 'one'
				return 0
		,
			path: 'two'
			type: 'text'
			box:
				x: 0
				y: 50
				width: 250
				height: 50
			fieldValidator: if not b? then null else (value) -> value is b
		,
			path: 'three'
			type: 'text'
			box:
				x: 250
				y: 50
				width: 250
				height: 50
			fieldValidator: if not c? then null else (value) -> value is c
		]
	return that

createWords = (text) ->
	# Create words from text.
	words = []
	yOffset = 0
	for line, lineIndex in text.split('\n')
		xOffset = 0
		for fragment, fragmentIndex in line.split(' ')
			if fragment.length isnt 0
				wordWidth = fragment.length * 10
				words.push
					box:
						x: xOffset
						y: yOffset
						width: wordWidth
						height: 25
					text: fragment
					confidence: Number(fragment.match(/\d+$/)?[0] ? 100)
				xOffset += 20 + wordWidth
			else
				xOffset += 15
		yOffset += 30
	# Create image words.
	wordBoxes = (word.box for word in words)
	if wordBoxes.length isnt 0
		imageBox = boundingBox wordBoxes
	else
		imageBox = 
			x: 0
			y: 0
			width: xOffset
			height: yOffset
	image = new dv.Image imageBox.width, imageBox.height, 32
	image.fillBox 0, 0, image.width, image.height, 255, 255, 255
	for word in words
		grayLevel = ((1.0 - word.confidence / 100) * 255 | 0)
		image.fillBox word.box, grayLevel, grayLevel, grayLevel
	# Log image.
	wordImageFilename = path.join(__dirname, 'log', "words-#{text.replace(/\n/g, '_')}.png")
	fs.writeFileSync wordImageFilename, image.toBuffer('png')
	return [image, words]

schemaToPage = ({x, y, width, height}) -> {x, y, width, height}

describe 'Text', ->
	contentImage = null

	before ->
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))

	describe 'recognizer', ->
		shouldFindText = (language, image, expectedText) ->
			tesseract = new dv.Tesseract language
			tesseract.pageSegMode = 'single_block'
			tesseract.classify_enable_learning = 0
			tesseract.classify_enable_adaptive_matcher = 0
			[words, image] = findText(image, tesseract)
			words.should.not.be.empty
			wordsMissing = expectedText.split(' ').filter((word) -> word in words)
			if wordsMissing.length > 0
				throw new Error('Content word(s) missing: ' + wordsMissing)

		it 'should find text in synthetic image at 45% black', ->
			shouldFindText 'eng', new dv.Image('png', fs.readFileSync(__dirname + '/data/text-045.png')),
				'I am 3 LOW contrast text I am a high I am a low contrast text '
				'I am a low contrast text contrast text I am a low contrast text'

		it 'should find text in synthetic image at 30% black', ->
			shouldFindText 'eng', new dv.Image('png', fs.readFileSync(__dirname + '/data/text-030.png')),
				'I am 3 LOW contrast text I am a high I am a low contrast text '
				'I am a low contrast text contrast text I am a low contrast text'

		it 'should find text in synthetic image at 5% black', ->
			shouldFindText 'eng', new dv.Image('png', fs.readFileSync(__dirname + '/data/text-005.png')),
				'I am 3 LOW contrast text I am a high I am a low contrast text '
				'I am a low contrast text contrast text I am a low contrast text'

		it 'should find text in real image', ->
			shouldFindText 'deu', contentImage,
				'LeeTK 00047 Musterfrau Maria 11.05.42 Teststr. 1 D 99210 Prüfdorf 12/13 8001337 X123456789 ' +
				'5000 1 123456700 101234567 02.09.13 Hypertonie(primäre) Struma nodosa BZ, HbA1, Krea, K+, ' +
				'TSH, Chol, HDL, LDL, HS'

	describe 'recognizer verification', ->
		it 'should verify clean pixels with high confidence for "one"', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords '      \n      '
			matchText(formData, formSchema, [], schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal ''
			formData.one.conflicts.should.have.length 0
			should.exist formData.two
			should.exist formData.three

		it 'should verify cluttered pixels with low confidence for "one"', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords 'abcdefghikjlmnopqrst\nabcdefghikjlmnopqrst'
			matchText(formData, formSchema, [], schemaToPage, image)
			formData.one.confidence.should.equal 0
			formData.one.value.should.equal ''
			formData.one.conflicts.should.have.length 0
			should.exist formData.two
			should.exist formData.three

	describe 'by position', ->
		it 'should match 1 word to "one" and drop others', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords 'a100\n\n\nx100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal words[0].confidence
			formData.one.value.should.equal words[0].text
			formData.one.box.should.deep.equal words[0].box
			formData.one.conflicts.should.have.length 0
			should.exist(formData.two)
			should.exist(formData.three)
			formSchema.called.should.contain 'one'

		it 'should match 2 words to "one" with mean confidence', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords 'a75 b51\n\n\nx100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 63
			formData.one.value.should.equal words[0].text + ' ' + words[1].text
			formData.one.box.should.deep.equal boundingBox([words[0].box, words[1].box])
			formData.one.conflicts.should.have.length 0
			should.exist(formData.two)
			should.exist(formData.three)

		it 'should match 1 word to "two" and "three" with conflicts', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords '\n    x100    '
			matchText(formData, formSchema, words, schemaToPage, image)
			should.exist(formData.one)
			formData.two.confidence.should.equal 100
			formData.two.value.should.equal words[0].text
			formData.two.box.should.deep.equal words[0].box
			formData.two.conflicts.should.have.length 1
			formData.three.confidence.should.equal 100
			formData.three.value.should.equal words[0].text
			formData.three.box.should.deep.equal words[0].box
			formData.three.conflicts.should.have.length 1
			
	describe 'by validator', ->
		it 'should match 1 word to "one" and drop others', ->
			formData = {}
			formSchema = createFormSchema 'a100', undefined, undefined
			[image, words] = createWords 'z100\na100\n\n\nx100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.deep.equal words[0].box
			formData.one.conflicts.should.have.length 0
			should.exist(formData.two)
			should.exist(formData.three)
			formSchema.called.should.contain 'one'

		it 'should match 2 words to "one" with mean confidence', ->
			formData = {}
			formSchema = createFormSchema 'a75 b51', undefined, undefined
			[image, words] = createWords 'z100\na75 b51\n\n\nx100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 63
			formData.one.value.should.equal words[0].text + ' ' + words[1].text
			formData.one.box.should.deep.equal boundingBox([words[0].box, words[1].box])
			formData.one.conflicts.should.have.length 0
			should.exist(formData.two)
			should.exist(formData.three)

		it 'should match 1 word to "one" and "two" with conflicts', ->
			formData = {}
			formSchema = createFormSchema 'x100', 'x100', undefined
			[image, words] = createWords '\n    x100    '
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.deep.equal words[0].box
			formData.one.conflicts.should.have.length 1
			formData.two.confidence.should.equal 100
			formData.two.value.should.equal words[0].text
			formData.two.box.should.deep.equal words[0].box
			formData.two.conflicts.should.have.length 1
			should.exist(formData.three)

	describe 'by position and validator', ->
		it 'should ignore schema words', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords 'foobar\n a\nb'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[1].text
			formData.one.box.should.deep.equal words[0].box
			formData.one.conflicts.should.have.length 0
			should.exist(formData.two)
			should.exist(formData.three)

		it 'should match words to fields, no anchors', ->
			formData = {}
			formSchema = createFormSchema undefined, 'b100', undefined
			[image, words] = createWords 'a100\nx100 c100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.deep.equal words[0].box
			formData.one.conflicts.should.have.length 0
			formData.two.confidence.should.equal 100
			formData.two.value.should.equal words[1].text
			formData.two.box.should.deep.equal words[1].box
			formData.two.conflicts.should.have.length 0
			formData.three.confidence.should.equal 100
			formData.three.value.should.equal words[2].text
			formData.three.box.should.deep.equal words[2].box
			formData.three.conflicts.should.have.length 0

		it 'should match words to fields using one anchor', ->
			formData = {}
			formSchema = createFormSchema undefined, 'b100', undefined
			[image, words] = createWords 'z100\na100\nb100      c100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.deep.equal words[0].box
			formData.one.conflicts.should.have.length 0
			formData.two.confidence.should.equal 100
			formData.two.value.should.equal words[1].text
			formData.two.box.should.deep.equal words[1].box
			formData.two.conflicts.should.have.length 0
			formData.three.confidence.should.equal 100
			formData.three.value.should.equal words[2].text
			formData.three.box.should.deep.equal words[2].box
			formData.three.conflicts.should.have.length 0

		it 'should match words to fields using two anchors', ->
			formData = {}
			formSchema = createFormSchema undefined, 'b100', 'c100'
			[image, words] = createWords 'z100\na100\nb100 c100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.deep.equal words[0].box
			formData.one.conflicts.should.have.length 0
			formData.two.confidence.should.equal 100
			formData.two.value.should.equal words[1].text
			formData.two.box.should.deep.equal words[1].box
			formData.two.conflicts.should.have.length 0
			formData.three.confidence.should.equal 100
			formData.three.value.should.equal words[2].text
			formData.three.box.should.deep.equal words[2].box
			formData.three.conflicts.should.have.length 0
