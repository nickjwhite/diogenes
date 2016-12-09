var fs = require('fs');
var path = require('path');

// The config files usually go into a directory like "foobar/Default/default/" The first level (Default) is the default user of the nw.js app.  The second level (default) is the default user of the diogenes-server.  Other users of the server have other setting dirs, set by cookie.  It is possible (though unlikely) that both use cases might be mixed at the same time, so we need both levels.

var settingsPath = gui.App.dataPath;
var settingsDir = path.join(settingsPath, 'default');
var settingsFile = path.join(settingsDir, 'diogenes.prefs');

if (! fs.existsSync(settingsDir)) {
    fs.mkdir(path, function (e) {
        if (e) throw e;
        console.log("Created directory " + path);
    });
}

fs.readFile(SettingsFile, (err, data) => {
    if (!err) {
        console.log(data);
    }
});

var contents = fs.readFileSync(lockFile, {encoding: 'ascii'});
    var rePid  = /^pid (.*)$/m;
    var rePort = /^port (.*)$/m;
    var ar = rePid.exec(contents);
    var pid = ar[1];


function setPath (dbName, folderPath) {
    var showPath = document.querySelector('#'+dbName+'path');
    showPath.innerHTML = folderPath;
}

function bindChangeEvent (dbName) {
    var inputField = document.querySelector('#'+dbName);
    inputField.addEventListener('change', function () {
        var folderPath = this.value;
        setPath(dbName, folderPath);
    }, false);
    inputField.click();
}

function bindClickEvent (dbName) {
    var button = document.querySelector('#'+dbName+'button');
    button.addEventListener('click', function () {
        bindChangeEvent(dbName);
    });
}

function saveSettings() {

}

window.onload = function () {
    bindClickEvent('PHI');
    bindClickEvent('TLG');
    bindClickEvent('DDP');
    var button = document.querySelector('#save');
    button.addEventListener('click', function () {
        saveSettings();
        window.close()
    });
    button = document.querySelector('#cancel');
    button.addEventListener('click', function () {
        window.close()
    });
};

