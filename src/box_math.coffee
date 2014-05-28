# Return rectangle enclosing both parameters. One parameter may be undefined.
module.exports.enclosingRectangle = (rectA, rectB) ->
	return rectA unless rectB?.x and rectB?.y
	return rectB unless rectA?.x and rectA?.y
	left = Math.min(rectA.x, rectB.x)
	top = Math.min(rectA.y, rectB.y)
	return {
		x: left
		y: top
		width: Math.max(rectA.x + rectA.width, rectB.x + rectB.width) - left
		height: Math.max(rectA.y + rectA.height, rectB.y + rectB.height) - top
	}

# Compute manhattan distance between boxes.
module.exports.boxDistance = (boxA, boxB) ->
	delta =
		x: Math.max(boxA.x, boxB.x) - Math.min(boxA.x + boxA.width, boxB.x + boxB.width)
		y: Math.max(boxA.y, boxB.y) - Math.min(boxA.y + boxA.height, boxB.y + boxB.height)
	return Math.sqrt(delta.x * delta.x + delta.y * delta.y)

# Compute bounding box of a set of boxes.
module.exports.boundingBox = (boxes) ->
	minX = Number.MAX_VALUE
	minY = Number.MAX_VALUE
	maxX = Number.MIN_VALUE
	maxY = Number.MIN_VALUE
	for box in boxes
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
