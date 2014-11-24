module.exports.FormReader = require './form_reader' 
module.exports.estimateTransform = require('./estimate_transform').estimateTransform
module.exports.filters = {}
module.exports.filters.binarize = require './filters/binarize' 
module.exports.filters.darkenInk = require './filters/darken_ink' 
module.exports.filters.deskew = require './filters/deskew' 
module.exports.filters.filterBackground = require './filters/filter_background' 
module.exports.filters.removeRed = require './filters/remove_red' 
