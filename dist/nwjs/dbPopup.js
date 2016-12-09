var gui = require('nw.gui');
var fs = require('fs');
var path = require('path');

// The config files usually go into a directory like "foobar/Default/default/" The first level (Default) is the default user of the nw.js app.  The second level (default) is the default user of the diogenes-server.  Other users of the server have other setting dirs, set by cookie.  It is possible (though unlikely) that both use cases might be mixed at the same time, so we need both levels.

var settingsPath = gui.App.dataPath;
var settingsDir = path.join(settingsPath, 'default');
var settingsFile = path.join(settingsDir, 'diogenes.prefs');

function setPath(dbName, folderPath) {
    fs.readFile(settingsFile, (err, data) => {
        if (err) throw err;
        var dir = dbName.toLowerCase() + '_dir';
        var newLine = dir + ' "' + folderPath + '"';
        var re = new RegExp('^'+dir+'\s+"?(.*)"?$', 'm');
        var newData;
        if (re.test(data)) {
            newData = data.replace(re, newLine);
        }
        else {
            newData = data + "\n" + newLine;
        }
        fs.writeFile(settingsFile, newData, (err) => {
            if (err) throw err;
        });
    });
    showPath(dbName, folderPath);
}

function showPath (dbName, folderPath) {
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

window.onload = function () {
    // Set up click events
    bindClickEvent('PHI');
    bindClickEvent('TLG');
    bindClickEvent('DDP');
    button = document.querySelector('#close');
    button.addEventListener('click', function () {
        window.close()
    });

    // Create settings dir, if necessary
    if (! fs.existsSync(settingsDir)) {
        fs.mkdir(path, function (e) {
            if (e) throw e;
            console.log("Created directory " + path);
        });
    }
    // Read existing db settings
    fs.readFile(settingsFile, (err, data) => {
        if (!err) {
            console.log("Reading " + settingsFile);
            console.log(data);
            var reTLG = /^tlg_dir\s+"?(.*)"?$/m;
            var rePHI = /^phi_dir\s+"?(.*)"?$/m;
            var reDDP = /^ddp_dir\s+"?(.*)"?$/m;
            var ar;
            ar = reTLG.exec(data);
            showPath('TLG', ar[1]);
            ar = rePHI.exec(data);
            showPath('PHI', ar[1]);
            ar = reDDP.exec(data);
            showPath('DDP', ar[1]);
        }
});



    
};

