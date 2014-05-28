module.exports = (object, path) ->
	tail = object
	for item in path.split('.')
		tail[item] ?= {}
		tail = tail[item]
	return tail
