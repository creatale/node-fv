# Compute length of a vector.
module.exports.length = (vector) ->
	return Math.sqrt(vector.x * vector.x + vector.y * vector.y)

# Computes the distance between two vectors or boxes.
module.exports.distance = (boxA, boxB) ->
	center1X = boxA.x + (boxA.width ? 0) / 2
	center1Y = boxA.y + (boxA.height ? 0) / 2
	center2X = boxB.x + (boxB.width ? 0) / 2
	center2Y = boxB.y + (boxB.height ? 0) / 2
	return Math.abs(center1X - center2X) + Math.abs(center1Y - center2Y)

# Returns the center point/vector of a box.
module.exports.center = (box) ->
	return {
		x: box.x + box.width / 2
		y: box.y + box.height / 2
	}

# Computes the euclidean distance vector between two vectors.
module.exports.distanceVector = (vectorA, vectorB) ->
	return {
		x: vectorA.x - vectorB.x
		y: vectorA.y - vectorB.y
	}

# Compute the distance between two boxes.
module.exports.boxDistanceVector = (boxA, boxB) ->
	return {
		x: Math.max(boxA.x, boxB.x) - Math.min(boxA.x + boxA.width, boxB.x + boxB.width)
		y: Math.max(boxA.y, boxB.y) - Math.min(boxA.y + boxA.height, boxB.y + boxB.height)
	}

# Test if boxes A and B intersect each other.
module.exports.intersectBox = (boxA, boxB) ->
	return boxA.x < (boxB.x + boxB.width) and (boxA.x + boxA.width) > boxB.x and
		boxA.y < (boxB.y + boxB.height) and (boxA.y + boxA.height) > boxB.y

# Compute bounding box of a set of boxes. Boxes may be undefined, but at least one must be defined.
module.exports.boundingBox = (boxes) ->
	minX = Number.MAX_VALUE
	minY = Number.MAX_VALUE
	maxX = Number.MIN_VALUE
	maxY = Number.MIN_VALUE
	for box in boxes when box?
		minX = Math.min(box.x, minX)
		minY = Math.min(box.y, minY)
		maxX = Math.max(box.x, maxX)
		maxY = Math.max(box.y, maxY)
		minX = Math.min(box.x + box.width, minX)
		minY = Math.min(box.y + box.height, minY)
		maxX = Math.max(box.x + box.width, maxX)
		maxY = Math.max(box.y + box.height, maxY)
	return {
		x: minX
		y: minY
		width: maxX - minX
		height: maxY - minY
	}
