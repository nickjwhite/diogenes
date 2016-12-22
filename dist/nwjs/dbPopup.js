var gui = require('nw.gui');
var fs = require('fs');
var path = require('path');
var console = require('console');

var settingsDir = gui.App.dataPath;
var settingsFile = path.join(settingsDir, 'diogenes.prefs');

function setPath(dbName, folderPath) {
    // check if folderPath is defined.
    fs.readFile(settingsFile, 'utf8', (err, data) => {
        if (err) {
            console.log('No prefs file found at ' + settingsFile);
            data = '';
        }
        var dir = dbName.toLowerCase() + '_dir';
        var newLine = dir + ' "' + folderPath + '"';
        var re = new RegExp('^'+dir+'.*$', 'm');
        var newData;
        if (re.test(data)) {
            newData = data.replace(re, newLine);
        }
        else {
            newData = data + "\n" + newLine + "\n";
        }
        fs.writeFile(settingsFile, newData, (err) => {
            if (err) {
                alert ("Writing settings failed!");
                throw err;
            }
            console.log("Written " + settingsFile);
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
            var reTLG = /^tlg_dir\s+"?(.*?)"?$/m;
            var rePHI = /^phi_dir\s+"?(.*?)"?$/m;
            var reDDP = /^ddp_dir\s+"?(.*?)"?$/m;
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

