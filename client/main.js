const {app, BrowserWindow, Menu, MenuItem, ipcMain, session} = require('electron')
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

const webprefs = {contextIsolation: true, nodeIntegration: false, preload: path.join(app.getAppPath(), 'preload.js')}
const winopts = {icon: path.join(app.getAppPath(), 'assets', 'icon.png')}

const settingsPath = app.getPath('userData')
const winStatePath = path.join(settingsPath, 'windowstate.json')
const prefsFile = path.join(settingsPath, 'diogenes.prefs')


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
	let newwin = createWindow(20, 20)
	newwin.loadURL(currentLinkURL)
	currentLinkURL = null
    }
}}))

// Create a new window (either the first or an additional one)
function createWindow (offset_x, offset_y) {

    // Use saved window state if available
    let winstate = getWindowState(winStatePath)
    if(winstate && winstate.bounds) {
	x = winstate.bounds.x
	y = winstate.bounds.y
	w = winstate.bounds.width
	h = winstate.bounds.height
    } else {
	x = undefined
	y = undefined
	w = 800
	h = 600
    }

    // Add any desired offset from previously saved window location (useful for showing additional windows)
    x = x + offset_x
    y = y + offset_y

    let win = new BrowserWindow({x: x, y: y, width: w, height: h,
	                         show: false, webPreferences: webprefs, winopts})

    if(winstate && winstate.maximzed) {
	win.maximize()
    }

    // Hide window until everything has loaded
    win.on('ready-to-show', function() {
	win.show()
	win.focus()
        saveWindowState(win, winStatePath)
    })

    // Save window state whenever it changes
    let changestates = ['resize', 'move', 'close']
    changestates.forEach(function(e) {
	win.on(e, function() {
	    saveWindowState(win, winStatePath)
	})
    })

    return win
}

// Create the initial window and start the diogenes server
function createFirstWindow () {
    lockFile = path.join(settingsPath, 'diogenes-lock.json')
    process.env.Diogenes_Config_Dir = settingsPath

    // Set the Content Security Policy headers
    session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
	callback({ responseHeaders: Object.assign({
	    "Content-Security-Policy": [ "default-src 'self' 'unsafe-inline'" ]
	}, details.responseHeaders)})
    })

    win = createWindow(0, 0);

    // Remove any stale lockfile
    if (fs.existsSync(lockFile)) {
	fs.unlinkSync(lockFile)
    }

    loadWhenLocked(lockFile, prefsFile, win)
    server = startServer()

    const menu = Menu.buildFromTemplate(initializeMenuTemplate())
    Menu.setApplicationMenu(menu)

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
//		if(windows.length == 0) {
//			windows = null
//		}
	})

	// Intercept and handle new-window requests (e.g. from shift-click), to
	// prevent child windows being created which would die if the parent was
	// killed. This was something to do with the new window being a "guest"
	// window, which I am intentionally setting here, to fix the issue. The
	// Electron documentation states that it should be set for "failing to
	// do so may result in unexpected behavior" but I haven't seen any yet.
	win.webContents.on('new-window', (event, url) => {
	    event.preventDefault()
	    const win = createWindow(20, 20)
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

app.on('ready', createFirstWindow)

// app.on('ready', () => {
//     const menu = Menu.buildFromTemplate(initializeMenuTemplate())
//     Menu.setApplicationMenu(menu)
//     createFirstWindow
// })

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
		perlName = path.join(app.getAppPath(), '..', '..', 'strawberry', 'perl', 'bin', 'perl.exe')
	}

	const serverPath = path.join(app.getAppPath(), '..', '..', 'server', 'diogenes-server.pl')

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

// IPC used by firstrun page
ipcMain.on('getport', (event, arg) => {
	event.returnValue = dioSettings.port
})

// IPC used by firstrun page
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

// Save window dimensions and state to a file
function saveWindowState(win, path) {
	let s = {}
	s.maximized = win.isMaximized()
	if(!s.maximized) {
		s.bounds = win.getBounds()
	}
	try {
		fs.writeFileSync(path, JSON.stringify(s))
	} catch(e) {
		return false
	}
	return true
}

// Load window dimensions and state from a file
function getWindowState(path) {
	let s
	try {
		s = fs.readFileSync(path, {'encoding': 'utf8'})
	} catch(e) {
		return false
	}
	return JSON.parse(s)
}

// Load either the Diogenes homepage or the firstrun page
function loadFirstPage(prefsFile, win) {
	if(!fs.existsSync(prefsFile) || !checkDbSet(prefsFile)) {
		win.loadFile("pages/firstrun.html")
	} else {
		win.loadURL('http://localhost:' + dioSettings.port)
	}
}

function initializeMenuTemplate () {
    const template = [
        {
            label: 'File',
            submenu: [
                {
                    label: 'New Window',
                    accelerator: 'CmdOrCtrl+N',
                    click: (menu, win) => {
                        let newWin
                        if (typeof win === 'undefined') {
                            // No existing application window (for Mac only)
                            newWin = createWindow(0, 0)
                        } else {
                            // Additional window
                            newWin = createWindow(20, 20)
                        }
                        newWin.loadURL('http://localhost:' + dioSettings.port)
                    }
                },
                {
                    label: 'Diogenes Settings',
                    accelerator: 'CmdOrCtrl+S',
                    click: (menu, win) => {
                        let newWin = createWindow(20, 20)
		        newWin.loadURL('http://localhost:' + dioSettings.port + '/Settings.cgi')
                    }
                }
            ]
        },

        {
            label: 'Edit',
            role: 'editMenu'
        },
        {
            label: 'Go',
            submenu: [
                {label: 'Back',
                 accelerator: 'CmdOrCtrl+[',
                 click: (menu, win) => {
                     let contents = win.webContents
                     contents.goBack()
                 }},
                {label: 'Forward',
                 accelerator: 'CmdOrCtrl+]',
                 click: (menu, win) => {
                     let contents = win.webContents
                     contents.goForward()
                 }},
                {label: 'Home',
                 accelerator: 'CmdOrCtrl+D',
                 click: (menu, win) => {
                     win.loadURL('http://localhost:' + dioSettings.port)
                 }},

                {type: 'separator'},

                {label: 'Find',
                 accelerator: 'CmdOrCtrl+F',
                 click: (menu, win) => {
                     findText(win)
                 }},
                {label: 'Find Next',
                 accelerator: 'CmdOrCtrl+G',
                 click: (menu, win) => {
                     win.webContents.findInPage(win.mySearchText, {'findNext': true})
                 }},
                {label: 'Find Previous',
                 accelerator: 'CmdOrCtrl+Shift+G',
                 click: (menu, win) => {
                     win.webContents.findInPage(win.mySearchText,
                                                {'findNext': true, 'forward': false})
                 }},

            ]
        },
        {
            label: 'View',
            submenu: [
                {role: 'resetzoom',
                 label: 'Original Zoom'},
                {role: 'zoomin'},
                {role: 'zoomout'},
                {type: 'separator'},
                {role: 'togglefullscreen'},
                {type: 'separator'},
                {role: 'toggledevtools'}
            ]
        },
        {
            label: 'Window',
            role: 'windowMenu',
        },
        {
            role: 'help',
            submenu: [
                {
                    label: 'Learn More',
                    click () { require('electron').shell.openExternal('http://community.dur.ac.uk/p.j.heslin/Software/Diogenes/diogenes-help.html') }
                }
            ]
        }
    ]

    if (process.platform === 'darwin') {
        template.unshift({
            label: "Diogenes",
            submenu: [
                {role: 'about'},
                {type: 'separator'},
                {role: 'services', submenu: []},
                {type: 'separator'},
                {role: 'hide'},
                {role: 'hideothers'},
                {role: 'unhide'},
                {type: 'separator'},
                {role: 'quit'}
            ]
        })
        // File menu
        template[1].submenu.push(
            {type: 'separator'},
            {
                label: 'Speak',
                submenu: [
                    {role: 'startspeaking'},
                    {role: 'stopspeaking'}
                ]
            }
        )
    }

    if (process.platform !== 'darwin') {
        template[0].submenu.push(
                {role: 'quit'}
        )
    }

    return template
}

function findText (win) {
    let findWidth = 300
    let find_x = win.getBounds().x + win.getBounds().width - findWidth
    let find_y = win.getBounds().y

    let findWin = new BrowserWindow({
        parent: win,
        show: false,
        modal: false,
        width: findWidth,
        height: 40,
        x: find_x,
        y: find_y,
        resizable: false,
        movable: true,
        frame: false,
        transparent: false,
    })
    findWin.once('ready-to-show', () => {
        findWin.show()
        findWin.focus()
    })

    ipcMain.on("findText", (event, text, dir) => {
        if (text === "") {
            win.webContents.stopFindInPage('clearSelection')
        }
        else {
            if (dir === "next") {
                win.webContents.findInPage(text)
            } else {
                win.webContents.findInPage(text, {'forward': false})
            }
            win.mySearchText = text
        }
    })
    findWin.on('closed', () => {
        win.webContents.stopFindInPage('clearSelection')
        ipcMain.removeAllListeners('findText')
    })
    // Clear highlighting when we navigate to a new page
    win.webContents.on('did-start-loading', (event, result) => {
         win.webContents.stopFindInPage('clearSelection')
     })

    findWin.loadFile("pages/find.html")
}
