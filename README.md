# FormVision

FormVision is a [node.js](http://nodejs.org) library for extracting data from scanned forms.

## Features

- Extract text, barcodes and checkboxes from images
- Specify expected region, type and validation for each field
- Supports incorporation of domain specific knowledge (wrong place, right data)
- Supports multiple transformations (half printed, half written, different offsets)
- Meant to cut red tape!

## Installation

    $ npm install fv

## Quick Start

Install `fv` and `dv` and download [that image](https://github.com/creatale/node-fv/blob/master/test/data/m10-printed.png). Now run the following code snippet:

```coffee
dv = require 'dv'
fv = require 'fv'

# TODO: simple, but meaningful example
```

## License

Licensed under the incredibly [permissive](http://en.wikipedia.org/wiki/Permissive_free_software_licence) [MIT License](http://creativecommons.org/licenses/MIT/). Copyright &copy; 2013-2014 Christoph Schulz.
