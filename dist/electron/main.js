const {app, BrowserWindow, Menu, MenuItem, ipcMain} = require('electron')
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

let currentLinkURL = null

// Ensure the app is single-instance (see 'second-instance' event
// handler below)
function initialise() {
	const gotTheLock = app.requestSingleInstanceLock()

	if (!gotTheLock) {
		return app.quit()
	}
}

initialise()

// Set up Open Link context menu
// TODO: there is probably a better way to open links than using the
//       currentLinkURL global variable
const linkContextMenu = new Menu()
linkContextMenu.append(new MenuItem({label: 'Open', click: (item, win) => {
	if(currentLinkURL) {
		win.loadURL(currentLinkURL)
		currentLinkURL = null
	}
}}))
linkContextMenu.append(new MenuItem({label: 'Open in New Window', click: (item, win) => {
	if(currentLinkURL) {
		let newwin = new BrowserWindow({width: 800, height: 600, show: true})
		newwin.loadURL(currentLinkURL)
		currentLinkURL = null
	}
}}))

// Create the initial window and start the diogenes server
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

// Track each window in a global 'windows' array, and set up the
// context menu
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

	// Intercept and handle new-window requests (e.g. from shift-click), to
	// prevent child windows being created which would die if the parent was
	// killed. This was something to do with the new window being a "guest"
	// window, which I am intentionally setting here, to fix the issue. The
	// Electron documentation states that it should be set for "failing to
	// do so may result in unexpected behavior" but I haven't seen any yet.
	win.webContents.on('new-window', (event, url) => {
		event.preventDefault()
		const win = new BrowserWindow({show: false})
		win.once('ready-to-show', () => win.show())
		win.loadURL(url)
		//event.newGuest = win
	})

	// Load context menu
	win.webContents.on('context-menu', (e, params) => {
		// Only load on links, which aren't javascript links
		if(params.linkURL != "" && params.linkURL.indexOf("javascript:") != 0) {
			currentLinkURL = params.linkURL
			linkContextMenu.popup(win, params.x, params.y)
		} else {
			currentLinkURL = null
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

// Try to kill the server when the app being closed
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

// If a user tries to open a second instance of diogenes, catch that
// and focus an existing window instead
app.on('second-instance', () => {
	if(windows.length == 0) {
		return false
	}
	if(windows[0].isMinimized()) {
		windows[0].restore()
	}
	windows[0].focus()
})

// Only allow loading content from localhost
app.on('web-contents-created', (event, contents) => {
	contents.on('will-navigate', (event, navigationUrl) => {
		const url = new URL(navigationUrl)
		if (url.hostname !== 'localhost') {
			event.preventDefault()
		}
	})
})

// Start diogenes-server.pl
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

// Load settings in lockfile into an object
function settingsFromLockFile(fn) {
	let s = fs.readFileSync(fn, {'encoding': 'utf8'})
	return JSON.parse(s)
}

// Watch for the lockfile diogenes-server sets, and once it's there
// load the first page.
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

// IPC used by dbsettings page
ipcMain.on('getport', (event, arg) => {
	event.returnValue = dioSettings.port
})

// IPC used by dbsettings page
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

// Load either the Diogenes homepage or the dbsettings page
function loadFirstPage(prefsFile, win) {
	if(!fs.existsSync(prefsFile) || !checkDbSet(prefsFile)) {
		win.loadFile("pages/dbsettings.html")
	} else {
		win.loadURL('http://localhost:' + dioSettings.port)
	}
}
