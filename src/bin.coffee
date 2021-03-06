timer = new Date

###
Dependencies
###

BootstrapPackageManager = require '../lib/main'
ProgressBar = require 'progress'
_ = require "underscore"
program = require 'commander'
fs = require 'fs'
utils = require '../lib/utils'
path = require 'path'

###
Program Stuff
###

program
	.version('1.1.7')
	.usage('[options] <dir>')
	
	.option('-j, --js', 'Add Javascript')
	.option('-c, --css', 'Add CSS')
	.option('-l, --less', 'Add Less')
	.option('-i, --img', 'Add Images')
	.option('-a, --font-awesome', "Add Font Awesome")
	
	.option('-t, --theme <name>', "Mixin in a free Bootswatch theme. See http://bootswatch.com/ for full list.")
	.option('-v, --variables <path>', "Path to a custom `variables.less` file to replace the included version.")
	.option('-f, --font-path <path>', "Set a custom value for the less variable `@FontAwesomePath` for a custom css font path when using Font Awesome.")
	.option('-s, --script <paths>', "Include javascript files (seperated by commas) with custom runtime instructions.")
	
	.option('-x, --compress', "Compress JS and CSS and include as  an extra \"*.min.*\" file.")
	.option('--compress-js', "Compress JS with UglifyJs and include as an extra \"*.min.js\" file.")
	.option('--compress-css', "Compress CSS with lessc (YUI) and include as an extra \"*.min.css\" file.")
	.option('--no-concat', "Don't concat Javascript files together.")
	
	.option('--bootstrap-version <version>', "Specific Bootstrap version to use. See http://github.com/twitter/bootstrap/tags for full list.")
	#.option('--font-awesome-version <version>', "Specific Font Awesome version to use. See http://github.com/FortAwesome/Font-Awesome/tags for full list.")
	
program.on '--help', () ->
	console.log('  Note: The default is to include all javascript, css, images and less unless you include at least one of the options `-j`, `-c`, `-l`, or `-i`, in which case only those specified are included.')
	console.log('')

program.parse(process.argv);

###
Options Set Up
###

o = {}

# Bootstrap Version
o.version = "master"
if program.bootstrapVersion then o.version = program.bootstrapVersion
if o.version isnt "master" and o.version.substr(0, 1) isnt "v" then o.version = "v" + o.version

# Parts to Include
parts = [ "img", "css", "less", "js" ]
o.parts = _.filter parts, (part) -> return program[part]
if _.isEmpty(o.parts) then o.parts = parts

# Compression
o.compress = []
if program.compress or program.compressCss then o.compress.push "css"
if program.compress or program.compressJs then o.compress.push "js"

# Concatenation
o.concat = []
if program.concat then o.concat.push "js"

# Font Awesome
if program.fontAwesome
	fa = o["font-awesome"] = {}
	if program.fontPath then fa.path = program.fontPath
	#if program.fontAwesomeVersion then fa.version = program.fontAwesomeVersion
	#if fa.version and fa.version.substr(0, 1) isnt "v" then fa.version = "v" + fa.version

# Bootswatch
o.theme = program.theme or null

# Variables.less
o["variables.less"] = program.variables or null

###
Destination Set Up
###

dest = _.first(program.args)
unless dest then dest = "bootstrap"

###
The Manager
###

BPM = new BootstrapPackageManager dest, o

###
The Extras
###

scripts = _.map [ "font-awesome", "bootswatch", "variables" ], (f) -> return path.join __dirname, "../lib/", f
if program.script then scripts = scripts.concat utils.split program.script, ","

_.each scripts, (f) ->
	fp = path.resolve process.cwd(), f
	require(fp)(BPM)

###
Display
###

bar = null
events =
	# Main
	"folder-setup": "\nInitiating...\n"
	"download-start": () ->
		console.log "Downloading Bootstrap..."
		bar = new ProgressBar '[:bar] :percent :etas',
			width: 50,
			total: 1,
			incomplete: " "
	"download": (amt) ->
		bar.tick amt
	"download-end": ""
	"unarchive": "Unpacking Bootstrap...\n"
	"copy-parts": "Moving Files...\n"
	"compile-js": "Compiling Javascript..."
	"compile-css": "Compiling CSS..."
	"cleanup": "\nCleaning Up..."

	# Font Awesome
	"fa-download-start": () ->
		console.log "Downloading Font-Awesome..."
		bar = new ProgressBar '[:bar] :percent :etas',
			width: 50,
			total: 1,
			incomplete: " "
	"fa-download": (amt) ->
		bar.tick amt
	"fa-download-end": ""
	"fa-unarchive": "Unpacking Font Awesome...\n"
	"fa-copy-less": "Configuring Bootstrap for Font Awesome..."
	"fa-copy-fonts": "Installing fonts..."

	# Bootswatch theme
	"theme-install": "Installing Bootswatch Theme '#{o.theme}'..."

	# Variables.less
	"variables-copy": "Copying custom variables.less..."

_.each events, (e, name) ->
	if _.isString(e)
		log = e
		e = () -> console.log log
	BPM.progress.on name, e

###
Error Catch
###

process.on 'uncaughtException', (err) ->
	console.log "\n\nBPM crashed with the following error:\n"
	console.error(err.stack)
	process.exit(1)

###
Run
###

run = () ->
	BPM.run (err) ->
		if err then throw err
		else
			time = Math.round (new Date - timer) / 1000
			console.log "\nDone in #{time}s."
			process.exit(0)

# First check if the folder exists and confirm
fs.exists dest, (exists) ->							# exists
	unless exists then run()
	else fs.stat dest, (err, stat) ->				# is directory
		if err then throw err
		else unless stat.isDirectory() then run()
		else fs.rmdir dest, (err) ->				# isn't empty
			if err and err.code is "ENOTEMPTY"
				program.confirm "Destination folder already exists and isn't empty. Continue? ", (ok) ->
					if ok then run()
					else process.exit(0)
			else if err then throw err
			else run()