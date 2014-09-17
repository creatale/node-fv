matchText = (word, words) ->
	matches = (item for item in words when item.text is word.text)
	return matches[0] if matches.length is 1

# Return the average out of the median and its two neighbours.
# I.e. for `values = [1, 2, 2, 2.3, 4]`, returns (2 + 2 + 2.3) / 3 = 2.1.
#
# For one to three elements, all values will be averaged.
# If *values* is empty, returns undefined.
avgMedian3 = (values) ->
	if values.length > 3
		values.sort()
		median = Math.floor values.length / 2
		averagingValues = values[median-1..median+1]
	else
		averagingValues = values

	sum = 0
	count = averagingValues.length
	sum += value for value in averagingValues
	return sum / count if count > 0

# Estimates an affine transformation from `itemsA` to `itemsB`. The function assumes that both sets
# have (almost) the same orientation and skew.
#
# `itemsA` and `itemsB` must be of the form [{box: {x, y}}].
# `fallbackScale` will be used if `requiredMatchCount` isn't met.
# `findMatch` is a function of the form (itemFromSetA, itemsB) -> itemFromSetB. May return undefined if no match exists.
module.exports.estimateTransform = (itemsA, itemsB, fallbackScale, requiredMatchCount = 7, findMatch = matchText) ->
	# For every element of itemsA, run findMatch and cache the result
	matches = new Array itemsA.length
	for item, index in itemsA
		matches[index] = findMatch item, itemsB

	transforms = []
	# Iterate over all pairs of items in itemsA iff they have a correspondence in itemsB
	for itemA1, i in itemsA
		if itemB1 = matches[i]
			for j in [i + 1...itemsA.length] by 1
				itemA2 = itemsA[j]
				if itemB2 = matches[j]
					# Compute affine transformation for this pair
					distX = Math.abs(itemB1.box.x - itemB2.box.x)
					distY = Math.abs(itemB1.box.y - itemB2.box.y)
					angle = Math.atan2(itemB1.box.x - itemB2.box.x, itemB1.box.y - itemB2.box.y)
					expectedAngle = Math.atan2(itemA1.box.x - itemA2.box.x, itemA1.box.y - itemA2.box.y)
					# Assume that A and B are not too close to each other and
					# have roughly the same rotation. This means we can detect
					# false positives quite safely by comparing the angle between them.
					if distX + distY > 1000 and Math.abs(angle - expectedAngle) < 0.02
						scaleX = distX / Math.abs(itemA1.box.x - itemA2.box.x)
						scaleY = distY / Math.abs(itemA1.box.y - itemA2.box.y)
						transforms.push
							distance: [distX, distY]
							scale: [scaleX, scaleY]
							offset: [itemB1.box.x - itemA1.box.x * scaleX, itemB1.box.y - itemA1.box.y * scaleY]

	if transforms.length > requiredMatchCount
		# Aggregate matches to find a stable solution.
		byDistX = transforms.filter((i) -> i.distance[0] > 20).sort (a, b) -> a.distance[0] - b.distance[0]
		scaleX = avgMedian3 (i.scale[0] for i in byDistX[-7..])
		offsetX = avgMedian3 (i.offset[0] for i in byDistX[-7..])
		byDistY = transforms.filter((i) -> i.distance[1] > 20).sort (a, b) -> a.distance[1] - b.distance[1]
		scaleY = avgMedian3 (i.scale[1] for i in byDistY[-7..])
		offsetY = avgMedian3 (i.offset[1] for i in byDistY[-7..])
	else
		# Use fallback.
		scaleX = fallbackScale
		scaleY = fallbackScale
		offsetX = 0
		offsetY = 0

	return (box) ->
		x: box.x * scaleX + offsetX
		y: box.y * scaleY + offsetY
		width: box.width * scaleX
		height: box.height * scaleY
