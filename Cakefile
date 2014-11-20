{spawn} = require 'child_process'
os = require 'os'

cmd = (name) ->
	if os.platform() is 'win32' then name + '.cmd' else name

npm = cmd 'npm'
mocha = cmd 'mocha'

task 'build', 'Compile CoffeeScript', ->
	coffee = cmd __dirname + '/node_modules/coffee-script/bin/coffee'
	spawn coffee, '-b -o lib -c src'.split(' '), {cwd: __dirname, stdio: 'inherit'}

task 'install', 'Install node.js packages', ->
	spawn npm, ['install'], {cwd: '.', stdio: 'inherit'}

task 'update', 'Update node.js packages', ->
	spawn npm, ['update'], {cwd: '.', stdio: 'inherit'}

task 'test', 'Run tests.', ->
	mocha = spawn mocha, ['--reporter', 'spec'], {cwd: '.', stdio: 'inherit'}
	mocha.on 'exit', (status) ->
		return process.exit(status)

task 'test-cov', 'Run tests, generating a coverage report', ->
	fs = require 'fs'
	path = require 'path'
	timestamp = (new Date()).toISOString().replace(/[:.]/g, '-')
	filename = path.join 'test', 'log', 'cov-' + timestamp + '.log.html'
	console.log 'Generating ' + filename
	stream = fs.openSync filename, 'w'
	mocha = spawn mocha, ['--require', './test/mocha.coverage.js', '--reporter', 'html-cov'],
		{cwd: '.', stdio: ['ignore', stream, process.stderr]}
	mocha.on 'exit', (status) ->
		return process.exit(status)
