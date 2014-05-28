dv = require 'dv'
binarize = require './filters/binarize'

# Width of the quiet zone around a checkbox.
QUIETZONE_WIDTH = 10

# Spline points for mapping score to confidence.
LOWER_UNCERTAIN_SCORE = 0.02 # confidence 0
LOWER_CERTAIN_SCORE = 0.10   # confidence 1
UPPER_CERTAIN_SCORE = 1.5    # confidence 1
UPPER_UNCERTAIN_SCORE = 4    # confidence 0

# Detect potentially checked checkboxes.
detectCandidates = (binarizedImage) ->
	candidates = []
	for candidate in binarizedImage.dilate(3, 3).connectedComponents(8)
		if 0.5 < candidate.width / candidate.height < 2 and candidate.width > 10
			candidates.push candidate
	return candidates

# Classify potentially checked checkboxes by computing a weighted score for filling.
scoreCandidate = (binarizedImage, candidate) ->
	# Crop candidate from image with quite zone.
	overscannedCandidate =
		x: candidate.x - QUIETZONE_WIDTH
		y: candidate.y - QUIETZONE_WIDTH
		width: candidate.width + QUIETZONE_WIDTH * 2
		height: candidate.height + QUIETZONE_WIDTH * 2
	candidateImage = binarizedImage.crop overscannedCandidate
	# Aggressively close image, then apply weighting which favors the center of the checkbox
	imageWithGapsClosed = candidateImage.dilate(31, 31).erode(31, 31)
	distanceImage = imageWithGapsClosed.distanceFunction(8)
	imageWithWeightedPixels = distanceImage.and(candidateImage.invert().toGray())
	score = 0
	for value, index of imageWithWeightedPixels.histogram()
		score += index * value
	return score

# Interpret score as result. This is heuristically measured.
scoreToCheckState = (score) =>
	lerp = (x, zeroAt, oneAt) -> (x - zeroAt) / (oneAt - zeroAt)
	checked = LOWER_UNCERTAIN_SCORE < score < UPPER_UNCERTAIN_SCORE
	confidence = switch
		when score < LOWER_UNCERTAIN_SCORE 
			lerp(score, LOWER_UNCERTAIN_SCORE, 0)
		when LOWER_UNCERTAIN_SCORE <= score < LOWER_CERTAIN_SCORE 
			lerp(score, LOWER_UNCERTAIN_SCORE, LOWER_CERTAIN_SCORE)
		when LOWER_CERTAIN_SCORE <= score < UPPER_CERTAIN_SCORE 
			1.0
		when UPPER_CERTAIN_SCORE <= score < UPPER_UNCERTAIN_SCORE 
			lerp(score, UPPER_UNCERTAIN_SCORE, UPPER_CERTAIN_SCORE)
		else
			0.0
	confidence = Math.round(confidence * 92 + 5)
	return [checked, confidence]

# Find filled checkboxes in image. This process is pretty prone to words, thus it assumes all
# words have been removed from the image.
module.exports.findCheckboxes = (image) ->
	checkboxes = []
	clearedImage = new dv.Image image
	binarizedImage = binarize image
	candidates = detectCandidates binarizedImage
	for candidate in candidates
		score = scoreCandidate binarizedImage, candidate
		[checked, confidence] = scoreToCheckState score
		if confidence > 0
			checkboxes.push
				box: candidate
				checked: checked
				confidence: confidence
			clearedImage.clearBox candidate
	return [checkboxes, clearedImage]
