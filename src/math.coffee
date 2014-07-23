# Compute length of a vector.
module.exports.length = (vector) ->
	return Math.sqrt(vector.x * vector.x + vector.y * vector.y)

# Computes the euclidean distance vector between two vectors.
module.exports.distanceVector = (vectorA, vectorB) ->
	return {
		x: vectorA.x - vectorB.x
		y: vectorA.y - vectorB.y
	}

# Compute manhattan vector between two boxes.
module.exports.manhattanVector = (boxA, boxB) ->
	return {
		x: Math.max(boxA.x, boxB.x) - Math.min(boxA.x + boxA.width, boxB.x + boxB.width)
		y: Math.max(boxA.y, boxB.y) - Math.min(boxA.y + boxA.height, boxB.y + boxB.height)
	}

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
