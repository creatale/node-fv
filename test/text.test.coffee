global.should = require('chai').should()
dv = require 'dv'
fs = require 'fs'

{boundingBox} = require '../src/math'
{findText} = require '../src/find_text'
{matchText} = require '../src/match_text'

createFormSchema = (a, b, c) ->
	page: {width: 200, height: 100}
	words: []
	fields: [
		path: 'one'
		type: 'text'
		box:
			x: 0
			y: 0
			width: 200
			height: 50
		fieldValidator: (value) -> if not a? then true else value is a
		fieldSelector: (choices) -> choices[0]
	,
		path: 'two'
		type: 'text'
		box:
			x: 0
			y: 50
			width: 100
			height: 50
		fieldValidator: if not b? then null else (value) -> value is b
		fieldSelector: null
	,
		path: 'three'
		type: 'text'
		box:
			x: 0
			y: 50
			width: 100
			height: 50
		fieldValidator: if not c? then null else (value) -> value is c
		fieldSelector: null
	]

createWords = (text) ->
	words = []
	image = new dv.Image 200, 100, 32
	image.fillBox 0, 0, image.width, image.height, 255, 255, 255
	for line, lineIndex in text.split('\n')
		offset = 0
		for fragment, fragmentIndex in line.split(' ')
			if fragment isnt ''
				offset += fragment.length * 10
			else
				words.push word =
					box:
						x: offset
						y: lineIndex * 25 + ((fragmentIndex * 3) % 7)
						width: fragment.length * 10
						height: 20
					text: fragment
					confidence: Number(fragment.match(/\d+$/)?[0] ? 50)
				grayLevel = ((1.0 - word.confidence / 100) * 255 | 0)
				try image.fillBox word.box, grayLevel, grayLevel, grayLevel
				offset += fragment.length * 10 + (lineIndex % 3)
	return [image, words]

schemaToPage = ({x, y, width, height}) -> {x, y, width, height}

describe 'Text recognizer', ->
	contentImage = null

	before ->
		contentImage = new dv.Image('png', fs.readFileSync(__dirname + '/data/m10-content.png'))

	describe 'find', ->
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

	describe 'match by position', ->
		it 'should match 1 word to "one" and drop others', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords 'a100\n\n\nx100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.equal words[0].box
			should.not.exist(formData.two)
			should.not.exist(formData.three)

		it 'should match 2 words to "one" with mean confidence', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords 'a75 b51\n\n\nx100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 63
			formData.one.value.should.equal words[0].text + ' ' + words[1].text
			formData.one.box.should.equal boundingBox([words[0].box, words[1].box])
			should.not.exist(formData.two)
			should.not.exist(formData.three)
			
		it 'should match 1 word to "one", 1 word to "two" and one word to "three"', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords 'a100\nb100      c100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.equal words[0].box
			formData.two.confidence.should.equal 100
			formData.two.value.should.equal words[1].text
			formData.two.box.should.equal words[1].box
			formData.three.confidence.should.equal 100
			formData.three.value.should.equal words[2].text
			formData.three.box.should.equal words[2].box

	describe 'match by validator', ->
		it 'should match 1 word to "one" and drop others', ->
			formData = {}
			formSchema = createFormSchema 'a100', undefined, undefined
			[image, words] = createWords 'z100\na100\n\n\nx100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.equal words[0].box
			should.not.exist(formData.two)
			should.not.exist(formData.three)

		it 'should match 2 words to "one" with mean confidence', ->
			formData = {}
			formSchema = createFormSchema 'a75 b51', undefined, undefined
			[image, words] = createWords 'z100\na75 b51\n\n\nx100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 63
			formData.one.value.should.equal words[0].text + ' ' + words[1].text
			formData.one.box.should.equal boundingBox([words[0].box, words[1].box])
			should.not.exist(formData.two)
			should.not.exist(formData.three)

		it 'should match 1 word to "one" and "two" with low confidence', ->
			#XXX: define this, once fieldSelection semantics are ready.
			should.exist(null)

		it 'should match 2 words to "one" and "two" with low confidence', ->
			# e.g. 'a100 a100' isnt valid, but ['a100', 'a100'] is.
			#XXX: define this, once fieldSelection semantics are ready.
			should.exist(null)

		it 'should match 2 words to "one" and "two" and with low confidence', ->
			#XXX: define this, once fieldSelection semantics are ready.
			should.exist(null)

		it 'should match 1 word to "one", 1 word to "two" and one word to "three"', ->
			formData = {}
			formSchema = createFormSchema 'a100', 'b100', 'c100'
			[image, words] = createWords 'z100\na100\nb100 c100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.equal words[0].box
			formData.two.confidence.should.equal 100
			formData.two.value.should.equal words[1].text
			formData.two.box.should.equal words[1].box
			formData.three.confidence.should.equal 100
			formData.three.value.should.equal words[2].text
			formData.three.box.should.equal words[2].box

	describe 'match by position and validator', ->
		it 'should match 1 word to "one", 1 word to "two" and one word to "three" (1)', ->
			formData = {}
			formSchema = createFormSchema undefined, 'b100', undefined
			[image, words] = createWords 'z100\na100\nb100      c100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.equal words[0].box
			formData.two.confidence.should.equal 100
			formData.two.value.should.equal words[1].text
			formData.two.box.should.equal words[1].box
			formData.three.confidence.should.equal 100
			formData.three.value.should.equal words[2].text
			formData.three.box.should.equal words[2].box

		it 'should match 1 word to "one", 1 word to "two" and one word to "three" (2)', ->
			formData = {}
			formSchema = createFormSchema undefined, 'b100', 'c100'
			[image, words] = createWords 'z100\na100\nb100 c100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.equal words[0].box
			formData.two.confidence.should.equal 100
			formData.two.value.should.equal words[1].text
			formData.two.box.should.equal words[1].box
			formData.three.confidence.should.equal 100
			formData.three.value.should.equal words[2].text
			formData.three.box.should.equal words[2].box

		it 'should match 1 word to "one", 1 word to "two" and one word to "three" (3)', ->
			formData = {}
			formSchema = createFormSchema undefined, 'b100', undefined
			[image, words] = createWords 'a100\nx100 c100'
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal words[0].text
			formData.one.box.should.equal words[0].box
			formData.two.confidence.should.equal 100
			formData.two.value.should.equal words[1].text
			formData.two.box.should.equal words[1].box
			formData.three.confidence.should.equal 100
			formData.three.value.should.equal words[2].text
			formData.three.box.should.equal words[2].box

	describe 'verify emptiness', ->
		it 'should match cluttered empty to "one" with low confidence', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords 'abcdefghikjlmnopqrst\nabcdefghikjlmnopqrst'
			matchText(formData, formSchema, [], schemaToPage, image)
			formData.one.confidence.should.equal 0
			formData.one.value.should.equal ''
			formData.two.confidence.should.equal 0
			formData.two.value.should.equal ''
			formData.three.confidence.should.equal 0
			formData.three.value.should.equal ''

		it 'should match clean empty to "one" with high confidence', ->
			formData = {}
			formSchema = createFormSchema undefined, undefined, undefined
			[image, words] = createWords ''
			matchText(formData, formSchema, words, schemaToPage, image)
			formData.one.confidence.should.equal 100
			formData.one.value.should.equal ''
			formData.one.confidence.should.equal 100
			formData.two.value.should.equal ''
			formData.one.confidence.should.equal 100
			formData.three.value.should.equal ''
