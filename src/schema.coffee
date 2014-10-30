module.exports.unpack = (object, path) ->
	tail = object
	for item in path.split('.')
		tail[item] ?= {}
		tail = tail[item]
	return tail

module.exports.validate = (field, value, defaultResult) ->
	if field.fieldValidator?
		return Boolean(field.fieldValidator(value))
	else
		return defaultResult
