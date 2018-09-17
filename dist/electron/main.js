const {app, BrowserWindow} = require('electron')
const {execFile} = require('child_process')
const path = require('path')
const process = require('process')
const fs = require('fs')

// TODO: consider using win.webContents.executeJavascript('alert("blabla"')
//       to print errors, rather than console

// TODO: probably can trigger diogenes start earlier, before electron's app.ready

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
	lockFile = path.join(settingsPath, '.diogenes.run')
	process.env.Diogenes_Config_Dir = settingsPath

	// Kill any stale server process
	if (fs.existsSync(lockFile)) {
		let {pid} = settingsFromLockFile(lockFile)
		try {
			process.kill(pid)
		} catch(e) {
			console.log("Warning: failed to kill stale server process")
		}
		console.log("Removing stale lockfile")
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

	return execFile(perlName, [serverPath], {'windowsHide': true}, (error, stdout, stderr) => {
		console.log(stdout);
		console.log(stderr);
	});
	// TODO: probably hook into stderr and stdout of the server to print them on the main console
}

function settingsFromLockFile(fn) {
	var s = fs.readFileSync(fn, {'encoding': 'utf8'})
	var rePid  = /^pid (.*)$/m;
	var rePort = /^port (.*)$/m;
	var ar
	ar = rePid.exec(s)
	var pid
	if(ar === null || !(1 in ar)) {
		console.log("No pid settings found in lockFile")
		pid = null
	} else {
		pid = ar[1];
	}

	var port
	ar = rePort.exec(s)
	if(ar === null || !(1 in ar)) {
		console.log("No port settings found in lockFile")
		port = null
	} else {
		port = ar[1];
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

		if(dioSettings.port === null || dioSettings.pid === null) {
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
