const {app, BrowserWindow} = require('electron')
const {execFile} = require('child_process')
const path = require('path')
const process = require('process')
const fs = require('fs')

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let win

let server

let dioSettings = {}
let lockFile

let startupDone = false

function createWindow () {
	// Create the browser window.
	win = new BrowserWindow({width: 800, height: 600})

	// Emitted when the window is closed.
	win.on('closed', () => {
		// Dereference the window object, usually you would store windows
		// in an array if your app supports multi windows, this is the time
		// when you should delete the corresponding element.
		win = null
	})

	win.loadFile('index.html')

	const settingsPath = app.getPath('userData')
	lockFile = path.join(settingsPath, 'diogenes-lock.json')
	process.env.Diogenes_Config_Dir = settingsPath

	// Remove any stale lockfile
	if (fs.existsSync(lockFile)) {
		fs.unlinkSync(lockFile)
	}

	watchForLockFile(lockFile)
	server = startServer()
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', createWindow)

// Quit when all windows are closed.
app.on('window-all-closed', () => {
	// On macOS it is common for applications and their menu bar
	// to stay active until the user quits explicitly with Cmd + Q
	if (process.platform !== 'darwin') {
		app.quit()
	}
})

app.on('will-quit', () => {
	if(server) {
		try {
			server.kill()
		} catch(e) {
			console.log("Couldn't kill server")
		}
	}
	fs.unlinkSync(lockFile)
})

app.on('activate', () => {
	// On macOS it's common to re-create a window in the app when the
	// dock icon is clicked and there are no other windows open.
	if (win === null) {
		createWindow()
	}
})


function startServer () {
	// For Mac and Unix, we assume perl is in the path
	let perlName = 'perl'
	if (process.platform == 'win32') {
		perlName = path.join('strawberry', 'perl', 'bin', 'perl.exe')
	}

	const serverPath = path.join(process.cwd(), '..', '..', 'diogenes-browser', 'perl', 'diogenes-server.pl')

	let server = execFile(perlName, [serverPath], {'windowsHide': true})
	server.stdout.on('data', (data) => {
		console.log('server stdout: ' + data)
	})
	server.stderr.on('data', (data) => {
		console.log('server stderr: ' + data)
	})
	server.on('close', (code) => {
		console.log('Diogenes server exited')
	})
	return server
}

function settingsFromLockFile(fn) {
	let s = fs.readFileSync(fn, {'encoding': 'utf8'})
	return JSON.parse(s)
}

function watchForLockFile(lockFile) {
	fs.watch(path.dirname(lockFile), function(event, filename) {
		if(startupDone) {
			return
		}

		if(filename != path.basename(lockFile)) {
			return
		}

		if(!fs.existsSync(lockFile)) {
			return
		}

		dioSettings = settingsFromLockFile(lockFile)

		if(dioSettings.port === undefined || dioSettings.pid === undefined) {
			console.error("Error, no port or pid settings found in lockFile")
			app.quit()
		}

		loadDioIndex()

		startupDone = true
	})
}

function loadDioIndex() {
	win.loadURL('http://localhost:' + dioSettings.port)
}
