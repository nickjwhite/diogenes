const {app, BrowserWindow, ipcMain} = require('electron')
const {execFile} = require('child_process')
const path = require('path')
const process = require('process')
const fs = require('fs')
const console = require('console')

// Keep a global reference of the window objects, to ensure they won't
// be closed automatically when the JavaScript object is garbage collected.
let windows = []

// Same for server, keep it globally to ensure it isn't garbage collected.
let server

let dioSettings = {}
let lockFile

let startupDone = false

function createWindow () {
	let win = new BrowserWindow({width: 800, height: 600, show: false})

	// Hide window until everything has loaded
	win.on('ready-to-show', function() {
		win.show()
		win.focus()
	})

	const settingsPath = app.getPath('userData')
	lockFile = path.join(settingsPath, 'diogenes-lock.json')
	const prefsFile = path.join(settingsPath, 'diogenes.prefs')
	process.env.Diogenes_Config_Dir = settingsPath

	// Remove any stale lockfile
	if (fs.existsSync(lockFile)) {
		fs.unlinkSync(lockFile)
	}

	loadWhenLocked(lockFile, prefsFile, win)
	server = startServer()
}

app.on('browser-window-created', (event, win) => {
	// Track window in global windows object
	windows.push(win)

	win.on('closed', () => {
		// Delete window id from list of windows
		windows.splice(windows.indexOf(win), 1)

		// Dereference the windows object if there are no more windows
		if(windows.length == 0) {
			windows = null
		}
	})

})

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
	if (Object.keys(windows).length == 0) {
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

function loadWhenLocked(lockFile, prefsFile, win) {
	// TODO: consider setting a timeout for this, in case the server
	//       doesn't start correctly for some reason.
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

		loadFirstPage(prefsFile, win)

		startupDone = true
	})
}

ipcMain.on('getport', (event, arg) => {
	event.returnValue = dioSettings.port
})

ipcMain.on('getsettingsdir', (event, arg) => {
	event.returnValue = app.getPath('userData')
})

// Check if a database folder has been set
function checkDbSet(prefsFile) {
	let s
	try {
		s = fs.readFileSync(prefsFile, 'utf8')
	} catch(e) {
		return false
	}
	let re = new RegExp('_dir .*')
	if(re.test(s)) {
		return true
	}
	return false
}

function loadFirstPage(prefsFile, win) {
	if(!fs.existsSync(prefsFile) || !checkDbSet(prefsFile)) {
		win.loadFile("pages/dbsettings.html")
	} else {
		win.loadURL('http://localhost:' + dioSettings.port)
	}
}
