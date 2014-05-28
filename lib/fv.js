require('coffee-script/register');
module.exports.FormReader = require('../src/form_reader');
module.exports.FormSchema = require('../src/form_schema');
module.exports.estimateTransform = require('../src/estimate_transform');
module.exports.filters = {}
module.exports.filters.binarize = require('../src/filters/binarize');
module.exports.filters.darkenInk = require('../src/filters/darken_ink');
module.exports.filters.deskew = require('../src/filters/deskew');
module.exports.filters.filterBackground = require('../src/filters/filter_background');
module.exports.filters.removeRed = require('../src/filters/remove_red');
