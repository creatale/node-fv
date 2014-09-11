require('coffee-coverage').register({
	path: 'relative',
	basePath: __dirname + '/..',
	exclude: ['test', 'node_modules', '.git', 'bin'],
	initAll: true
});
