const {app, BrowserWindow} = require('electron')
const {execFile} = require('child-process')
const path = require('path')
const process = require('process')
const fs = require('fs')

// TODO: consider using win.webContents.executeJavascript('alert("blabla"')
//       to print errors, rather than console

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let win

let server

let dioSettings = {}

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

	// and load the index.html of the app.
	win.loadFile('index.html')

	const settingsPath = app.getPath('userData')
	const lockFile = path.join(settingsPath, '.diogenes.run')
	process.env.Diogenes_Config_Dir = settingsPath

	// TODO: also check if process is running, if not delete the lockfile and spawn, if so assign server var to it
	if (!fs.existsSync(lockFile)) {
		watchForLockFile(lockFile)
		server = startServer()
	} else {
		dioSettings = settingsFromLockFile(lockFile)
		loadDioIndex()
	}
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

app.on('activate', () => {
	// On macOS it's common to re-create a window in the app when the
	// dock icon is clicked and there are no other windows open.
	if (win === null) {
		createWindow()
	}
})


function startServer () {
	// For Mac and Unix, we assume perl is in the path
	var perlName = 'perl'
	if (process.platform == 'win32') {
		perlName = path.join('strawberry', 'perl', 'bin', 'perl.exe')
	}

	var serverPath = path.join(process.cwd(), '..', '..', 'diogenes-browser', 'perl', 'diogenes-server.pl')

	// TODO: write lock file appropriately

	return execFile(perlName, serverPath, {'windowsHide': true}, (error, stdout, stderr) => {
		if (error) {
			throw error;
		}
		console.log(stdout);
	});
}

function settingsFromLockFile(fn) {
	var s = fs.readFileSync(fn, {'encoding': 'utf8'})
	var rePid  = /^pid (.*)$/m;
	var rePort = /^port (.*)$/m;
	var ar = rePid.exec(s);
	var pid = ar[1];
	var ar = rePort.exec(s);
	var port = ar[1];

	if(!port || !pid) {
		console.error("Error, no port or pid settings found in lockFile")
		return {}
	}

	return {"port": port, "pid": pid};
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
		loadDioIndex()

		startupDone = true
	})
}

function loadDioIndex() {
	if(!dioSettings.port) {
		console.error("Error, no port known")
		// TODO: kill server if possible and exit
		return false
	}

	win.loadURL('localhost:' + dioSettings.port)
}
