const {app, BrowserWindow, Menu, MenuItem, ipcMain, session, dialog} = require('electron')
const {spawn} = require('child_process')
const path = require('path')
const process = require('process')
const fs = require('fs')
const dialog = require('dialog')
const console = require('console')
const fontList = require('./node-font-list/index.js')

// Keep a global reference of the window objects, to ensure they won't
// be closed automatically when the JavaScript object is garbage collected.
let windows = []

// Same for server, keep it globally to ensure it isn't garbage collected.
let server

let dioSettings = {}
let lockFile

let startupDone = false

let currentLinkURL = null

//const webprefs = {contextIsolation: true, nodeIntegration: false, preload: path.join(app.getAppPath(), 'preload.js')}
const webprefs = {contextIsolation: true, nodeIntegration: false, preload: path.resolve(__dirname, 'preload.js')}
const winopts = {icon: path.join(app.getAppPath(), 'assets', 'icon.png')}

const settingsPath = app.getPath('userData')
const winStatePath = path.join(settingsPath, 'windowstate.json')
const prefsFile = path.join(settingsPath, 'diogenes.prefs')

const versionFile = path.resolve(__dirname, 'version.js')
var currentVersion = "0.0"
if (fs.existsSync(versionFile)) {
    currentVersion = settingsFromFile(versionFile).version
}

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
	let newwin = createWindow(win, 20, 20)
	newwin.loadURL(currentLinkURL)
	currentLinkURL = null
    }
}}))

// Create a new window (either the first or an additional one)
function createWindow (oldWin, offset_x, offset_y, defaultPos) {
    var winstate = getWindowState(winStatePath)

    if (defaultPos) {
        // These values can get messed up when swapping displays so
        // that all windows are put off-screen, so we need to provide
        // an emergency way for the user to reset them.
        x = 0
        y = 0
        w = 800
        h = 600
    }
    else if (oldWin == null) {
        // Use saved window state if available
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
    }
    else {
        const pos = oldWin.getPosition()
        x = pos[0]
        y = pos[1]
        // Add desired offset from existing window.
        x = x + offset_x
        y = y + offset_y
        if(winstate && winstate.bounds) {
	    w = winstate.bounds.width
	    h = winstate.bounds.height
        } else {
	    w = 800
	    h = 600
        }
    }

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

function checkVersion (win) {
    // Retrieve previous version and compare with current.  If this is
    // a new version of Diogenes, we have to clear the HTTP cache, or
    // we may continue to use the js, css, etc. files from the
    // obsolete version.
    win.webContents.executeJavaScript('localStorage.getItem("diogenesVersion")')
        .then( (oldVersion) => {
            if (oldVersion != currentVersion) {
                console.log('Old version: '+oldVersion+'; Current version: '+currentVersion)
                // Not promisified yet in the Electron we are using, but will be soon
                // win.webContents.session.clearCache()
                //     .then( () => {
                //         console.log('Deleted stale cache')
                //         win.webContents.reload()
                //     } )
                //     .catch( (e) => {console.log('Failed to delete stale cache: '+e)} )
                win.webContents.session.clearCache( () => {
                    console.log('Deleted stale cache')
                    win.webContents.reload()
                } )
                win.webContents.executeJavaScript('localStorage.setItem("diogenesVersion", '+'"'+currentVersion+'")')
                    .then( () => {console.log('New version number saved')} )
                    .catch( (e) => {console.log('Failed to save new version number: '+e)} )
            }
        })
        // Errors from non-promisified clearCache fall through
        // .catch( (e) => {console.log('Failed to get old version number: '+e)} )
        .catch( (e) => {console.log('checkVersion failed: '+e)} )
}

// Create the initial window and start the diogenes server
function createFirstWindow () {
    lockFile = path.join(settingsPath, 'diogenes-lock.json')
    process.env.Diogenes_Config_Dir = settingsPath

    // Set the Content Security Policy headers
    session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
	callback({ responseHeaders: Object.assign({
	    "Content-Security-Policy": [ "default-src 'self' logeion.uchicago.edu *.logeion.org 'unsafe-inline'" ]
	}, details.responseHeaders)})
    })

    win = createWindow(null, 0, 0);

    win.webContents.on("dom-ready", () => {
        checkVersion(win)
    })

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
    })

    // Intercept and handle new-window requests (e.g. from shift-click), to
    // prevent child windows being created which would die if the parent was
    // killed. This was something to do with the new window being a "guest"
    // window, which I am intentionally setting here, to fix the issue. The
    // Electron documentation states that it should be set for "failing to
    // do so may result in unexpected behavior" but I haven't seen any yet.
    win.webContents.on('new-window', (event, url) => {
	event.preventDefault()
	let newWin = createWindow(win, 20, 20)
	newWin.once('ready-to-show', () => newWin.show())
	newWin.loadURL(url)
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

    // Clear "find" highlighting when we navigate to a new page
    win.webContents.on('did-start-loading', (event, result) => {
        win.webContents.stopFindInPage('clearSelection')
    })

})

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', createFirstWindow)

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

	// server/ can be either at ../server or ../../server depending on whether
	// we're running a packaged or development version, so try both
	let serverPath = path.join(app.getAppPath(), '..', 'server', 'diogenes-server.pl')
	if (!fs.existsSync(serverPath)) {
		serverPath = path.join(app.getAppPath(), '..', '..', 'server', 'diogenes-server.pl')
	}

        let server = spawn(perlName, [serverPath], {'windowsHide': true})
	server.stdout.on('data', (data) => {
		console.log('server stdout: ' + data)
	})
	server.stderr.on('data', (data) => {
		console.log('server stderr: ' + data)
	})
	server.on('close', (code) => {
		console.log('Diogenes server exited (or failed to start)')
	})
	return server
}

// Load settings in lockfile into an object
function settingsFromFile(fn) {
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

		dioSettings = settingsFromFile(lockFile)

		if(dioSettings.port === undefined || dioSettings.pid === undefined) {
			console.error("Error, no port or pid settings found in lockFile")
			app.quit()
		}

		loadFirstPage(prefsFile, win)

		startupDone = true
	})
}

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
    let ret
    try {
	s = fs.readFileSync(path, {'encoding': 'utf8'})
    } catch(e) {
	return false
    }
    try {
	ret = JSON.parse(s)
    } catch(e) {
	return false
    }
    return ret
}

// Load either the Diogenes homepage or the firstrun page
function loadFirstPage(prefsFile, win) {
	if(!fs.existsSync(prefsFile) || !checkDbSet(prefsFile)) {
		win.loadFile("pages/firstrun.html")
	} else {
		win.loadURL('http://localhost:' + dioSettings.port)
	}
}

function makeFontWin (win) {
    return new BrowserWindow({
        parent: win,
        show: true,
        modal: true,
        width: 600,
        height: 400,
        resizable: false,
        movable: false,
        frame: true,
        transparent: false,
        fullscreen: false,
        webPreferences: webprefs
    })
}

function makeNewWin (win, defaultPos) {
    if (typeof win === 'undefined') {
        // No existing application window (for Mac only)
        return createWindow(null, 0, 0, defaultPos)
    } else {
        // Additional window
        return createWindow(win, 20, 20, defaultPos)
    }
}

// Menus
function initializeMenuTemplate () {
    const template = [
        {
            label: 'File',
            submenu: [
                {
                    label: 'New Window',
                    accelerator: 'CmdOrCtrl+N',
                    click: (menu, win) => {
                        let newWin = makeNewWin(win, false)
                        newWin.loadURL('http://localhost:' + dioSettings.port)
                    }
                },
                {
                    label: 'New Win (reset position)',
                    accelerator: 'CmdOrCtrl+!',
                    click: (menu, win) => {
                        let newWin = makeNewWin(win, true)
                        newWin.loadURL('http://localhost:' + dioSettings.port)
                    }
                },
                {
                    label: 'Save File',
                    accelerator: 'CmdOrCtrl+S',
                    click: (menu, win) => {
                        win.webContents.send('saveFileRequest', win);
                        ipcMain.on('saveFileResponse', (event, path) => {
                            win.webContents.savePage(path, 'HTMLOnly', function(error) {
                                if (!error)
                                    console.log("Saved page successfully");
                            });
                        })
                    }
                },
                {
                    label: 'Print to PDF',
                    accelerator: 'CmdOrCtrl+P',
                    click: (menu, win) => {
                        win.webContents.send('printPDFRequest', win);
                        ipcMain.on('printPDFResponse', (event, path) => {
                            win.webContents.printToPDF({}, (error, data) => {
                                if (error) throw error
                                fs.writeFile(path, data, (error) => {
                                    if (error) throw error
                                    console.log('Wrote PDF successfully.')
                                })
                            })
                        })
                    }
                },
                {
                    label: 'Database Locations',
                    accelerator: 'CmdOrCtrl+B',
                    click: (menu, win) => {
                        let newWin = createWindow(win, 20, 20)
                        newWin.loadFile("pages/firstrun.html")
                    }
                },
                {
                    label: 'Change Font',
                    accelerator: 'CmdOrCtrl+U',
                    click: (menu, win) => {
                        let newWin = makeFontWin()
                        newWin.loadFile("pages/font.html")
                    }
                },
                {
                    label: 'Download TLL PDFs',
                    click: (menu, win) => {
                        win.webContents.send('TLLPathRequest', win);
                        ipcMain.on('TLLPathResponse', (event, path) => {
                            let newWin = createWindow(win, 20, 20)
                            newWin.loadURL('http://localhost:' + dioSettings.port + '/tll-pdf-download.cgi')
                        })
                    }
                },
                {
                    label: 'Other Settings',
                    accelerator: 'CmdOrCtrl+T',
                    click: (menu, win) => {
                        let newWin = createWindow(win, 20, 20)
		        newWin.loadURL('http://localhost:' + dioSettings.port + '/Settings.cgi')
                    }
                },
                {
                    label: 'Close Window',
                    accelerator: 'CmdOrCtrl+W',
                    click: (menu, win) => {
                        win.close()
                    }
                }
            ]
        },

        {
            label: 'Edit',
            role: 'editMenu'
        },
        {
            label: 'Navigate',
            submenu: [
                {label: 'Stop/Kill',
                 accelerator: 'CmdOrCtrl+K',
                 click: (menu, win) => {
                     let contents = win.webContents
                     contents.stop()
                     win.webContents.executeJavaScript('stopSpinningCursor()')
                 }},
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
                     findTargetWin.webContents.findInPage( mySearchText )
                 }},
                {label: 'Find Previous',
                 accelerator: 'CmdOrCtrl+Shift+G',
                 click: (menu, win) => {
                     findTargetWin.webContents.findInPage( mySearchText, {'forward': false} )
                 }},

            ]
        },
        {
            label: 'View',
            submenu: [
                {role: 'resetZoom',
                 label: 'Original Zoom'},
                {role: 'zoomIn'},
                {role: 'zoomOut'},
                {type: 'separator'},
                {role: 'togglefullscreen'},
                {type: 'separator'},
                {role: 'toggleDevTools'}
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
                    click () { require('electron').shell.openExternal('https://d.iogen.es/d') }
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
            {role: 'quit', accelerator: 'CmdOrCtrl+Q'}
        )
    }

    return template
}

// Find-in-page mini-window

let findWin
let findTargetWin;
let mySearchText;

function findText (win) {

    if (win === findWin) {
        // Wrongly called find from active find window
        return
    }
    if (findWin && findWin.isVisible()) {
        // Find window present by unfocused
        findWin.focus()
        return
    }

    findTargetWin = win;
    let findWidth = 340
    let find_x = findTargetWin.getBounds().x + win.getContentBounds().width - findWidth
    let find_y = findTargetWin.getBounds().y

    findWin = new BrowserWindow({
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
        fullscreen: false,
        webPreferences: webprefs
    })
    findWin.once('ready-to-show', () => {
        findWin.show()
        findWin.focus()
    })
    findWin.on('closed', () => {
        win.webContents.stopFindInPage('clearSelection')
        ipcMain.removeAllListeners('findText')
        findWin = null
    })

    ipcMain.on("findText", (event, text, dir) => {
        if (text === "") {
            findTargetWin.webContents.stopFindInPage('clearSelection')
        }
        else {
            if (dir === "next") {
                console.log("next!")
                findTargetWin.webContents.findInPage(text)
            } else {
                findTargetWin.webContents.findInPage(text, {'forward': false})
            }
            mySearchText = text
        }
    })

    findWin.loadFile("pages/find.html")
}

//////////// Moved from preload for new security model

// app.whenReady().then(() => {
//   ipcMain.handle('open-dialog', (event, method, params) => {       
//     dialog[method](params);
//   });
// });


// Support for firstrun (db settings) page

var dioSettingsFile = path.join(settingsPath, 'diogenes.prefs')
var cssConfigFile = path.join(settingsPath, 'config.css')

const dbs = ['PHI', 'TLG', 'DDP', 'TLL_PDF', 'OLD_PDF']

app.whenReady().then(() => {
  ipcMain.on('getport', (event, arg) => {
    event.returnValue = dioSettings.port
  })
  ipcMain.on('firstrunSetupMain', (event, arg) => {
    event.returnValue = firstrunSetupMain()
  })
  ipcMain.on('dbOpenDialog', (event, prop, dbName) => {
    event.returnValue = dbOpenDialog(prop, dbName)
  })
  ipcMain.on('authtabExists', (event, folderPath) => {
    event.returnValue = dioSettings.authtabExists(folderPath)
  })
});

function firstrunSetupMain() {
  // Create settings dir, if necessary
  if (!fs.existsSync(dioSettingsDir)) {
    fs.mkdirSync(dioSettingsDir)
  }
  // Read existing db settings
  try {
    data = fs.readFileSync(dioSettingsFile, 'utf8')
  } catch(e) {
    data = null
  }
  return data
}

function dbOpenDialog (prop, dbName) {
  folderPath = dialog.showOpenDialogSync(null, {
    title: `Set ${dbName} location`,
    properties: [prop] }
  )
  writeToSettings(dbName, folderPath)
  console.log(dbName + 'location set to: ' + folderPath)
  return folderPath
}

function writeToSettings (dbName, folderPath) {
  if( typeof folderPath === "undefined" ) {
    return
  }
  try {
    data = fs.readFileSync(dioSettingsFile, 'utf8')
  } catch(e) {
    data = '# Created by Diogenes'
  }
  let db_l = dbName.toLowerCase()
  let newLine = `${db_l}_dir "${folderPath}"`
  let re = new RegExp(`^${db_l}_dir.*$`, 'm')
  let newData
  if(re.test(data)) {
    newData = data.replace(re, newLine)
  } else {
    newData = `${data}\n${newLine}`
  }
  fs.writeFileSync(dioSettingsFile, newData)
}

function authtabExists (folderPath)  {
  if (fs.existsSync(`${folderPath}/authtab.dir`) || fs.existsSync(`${folderPath}/AUTHTAB.DIR`) ) {
    return True
  } else {
    return False
  }
}

