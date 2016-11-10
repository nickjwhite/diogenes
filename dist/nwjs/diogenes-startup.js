// Kill any stale server process, then start the new server, then wait
// for server to have started, then open a new window and load the
// splash page from the cgi script.  This window stays open and
// hidden, because node-webkit gets upset if it disappears.

///// attic
// window.alert('Current directory: ' + process.cwd());
// window.alert(path.dirname(process.execPath));

var gui = require('nw.gui');
var fs = require('fs');
var path = require('path');
var mainWin = gui.Window.get();
var console = require('console');


//////////////////////// Set up environment and launch server

var osName = process.platform.toLowerCase();

// For Mac and Unix, we assume perl is in the path
var perlName = 'perl';
if (osName == 'win32') { 
    // This is a version that runs without opening up a console
    // window.  For debugging, change to wperl perl.exe.
    perlName = path.join('strawberry', 'perl', 'bin', 'wperl.exe');
}

var settingsPath = gui.App.dataPath;
// window.alert(settingsPath);
process.env.Diogenes_Config_Dir = settingsPath;
var lockFile = path.join(settingsPath, ".diogenes.run");

function readLockFile () {
    // Test for existence before calling this function
    var contents = fs.readFileSync(lockFile, {encoding: 'ascii'});
    var rePid  = /^pid (.*)$/m;
    var rePort = /^port (.*)$/m;
    var ar = rePid.exec(contents);
    var pid = ar[1];
    var ar = rePort.exec(contents);
    var port = ar[1];
    return [port, pid];
}

// First we delete any existing lock file and kill the associated
// process.  No need to wait, as the new server will choose a different
// port if the current one is still in use.
if (fs.existsSync(lockFile)) {
    var ar = readLockFile();
    var pid = ar[1];
    console.log("Lockfile exists. Killing pid: " + pid);
    try {
        process.kill(pid);
    } catch (e) {
        console.log("Failed to kill old server process (perhaps it no longer exists): " + e);
    }
    fs.unlinkSync(lockFile);
}

var curDir = process.cwd();
var serverPath = path.join(curDir, '../../diogenes-browser/perl/', 'diogenes-server.pl');
var spawn = require('child_process').spawn;
var server = spawn(perlName, [serverPath]);

// Clean up children on exit
process.on('exit', function () {
    server.kill();
    fs.unlinkSync(lockFile);
});

// Capture server output
server.stdout.on('data', function (data) {
  console.log('server stdout: ' + data);
});
server.stderr.on('data', function (data) {
  console.log('server stderr: ' + data);
});
server.on('close', function (code) {
  console.log('Diogenes server exited with code ' + code);
});

//////////////// Wait for server to start and then load splash page

// Config for new windows
var winConfig = {
    "title": "Diogenes",
    "frame": true,
    "icon": "diogenes.ico"
};

function initMenu(mywin){
    var menu = new gui.Menu({type:"menubar"});
    menu.append(new gui.MenuItem({ label: 'Item A', click: function() {} }));
    mywin.menu = menu;
}

var newWin;

fs.watch(settingsPath, function (event, filename) {
    console.log('event is: ' + event);
    if (filename) {
        // Other actions happen in this directory around this time:
        // e.g. cache clearance
        console.log('filename provided: ' + filename);
        if (filename == '.diogenes.run' && event == 'change') {
            if (fs.existsSync(lockFile)) {
                var ar = readLockFile();
                var dio_port = ar[0];
                if (!dio_port) {
                    window.alert ("ERROR: port unknown! " + dio_port);
                    gui.App.quit();     
                }
                var localURL = 'http://127.0.0.1:' + dio_port;
                // Load splash page
                //         newWin.location.href = localURL;
                gui.Window.open(localURL, winConfig, function(newWin) {
                    newWin.on('load', initMenu(newWin));
                });
                mainWin.hide();
            } 
            else {
                alert ("ERROR: disappearing lockfile!");
                gui.App.quit();     
            }
        }
    } 
    else {
        console.log('filename not provided');
    }
});

////////////////////////// Menus

// Mac standard menus with modifications

var mb = new gui.Menu({type:"menubar"});
if (osName == 'darwin') {
    mb.createMacBuiltin("Diogenes");
    mb.items[0].submenu.append(
        new gui.MenuItem({
            label: 'Do Something',
            click: function () { alert('Doing something'); }
        })
    );    
    gui.Window.get().menu = mb;
}

// Create an menu

// var dioMenubar = new gui.Menu({ type: 'menubar' });
// dioMenubar.append(new gui.MenuItem({ label: 'Diogenes'}));
// mainWin.menu = dioMenubar;

// var menu = new gui.Menu();
// Add some items
// menu.append(new gui.MenuItem({ label: 'Item A' }));
// menu.append(new gui.MenuItem({ label: 'Item B' }));
// menu.append(new gui.MenuItem({ type: 'separator' }));
// menu.append(new gui.MenuItem({ label: 'Item C' }));


// empty var DiogenesMenu = new gui.Menu();
// DiogenesMenu.append(new gui.MenuItem({ label: 'Item 1' }));
// DiogenesMenu.append(new gui.MenuItem({ label: 'Item 2' }));
// DiogenesMenu.append(new gui.MenuItem({ label: 'Item 3' }));


// Add some items
// gui.Window.get().menu = dioMenubar;


//                                      submenu: DiogenesMenu}));
// dioMenubar.append(new gui.MenuItem({ label: 'File' }));
// dioMenubar.append(new gui.MenuItem({ type: 'Edit' }));
// dioMenubar.append(new gui.MenuItem({ label: 'Window' }));

// You can have submenu!
// item.submenu = submenu;
