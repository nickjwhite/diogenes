//const console = require('console');
const {ipcRenderer} = require('electron')
const path = require('path');
const fs = require('fs');

function setPath(dbName, folderPath) {
    // check if folderPath is defined.
    fs.readFile(window.dioSettingsFile, 'utf8', (err, data) => {
        if (err) {
            console.log('No prefs file found at ' + window.dioSettingsFile);
            data = '# Created by electron';
        }
        var dir = dbName.toLowerCase() + '_dir';
        var newLine = dir + ' "' + folderPath + '"';
        var re = new RegExp('^'+dir+'.*$', 'm');
        var newData;
        if (re.test(data)) {
            newData = data.replace(re, newLine);
        }
        else {
            newData = data + "\n" + newLine;
        }
        fs.writeFile(window.dioSettingsFile, newData, (err) => {
            if (err) {
                alert ("Writing settings failed!");
                throw err;
            }
            console.log("Written " + window.dioSettingsFile);
        });
    });
    showPath(dbName, folderPath);
}

function showPath (dbName, folderPath) {
    document.getElementById(`${dbName}path`).innerHTML = folderPath;
}

function bindClickEvent (dbName) {
    let button = document.getElementById(`${dbName}button`);
    let input = document.getElementById(`${dbName}`);
    button.addEventListener('click', () => {
        input.click();
    });
    input.addEventListener('change', function () {
        setPath(dbName, this.value);
    });
}

function setup() {
    var dioport = ipcRenderer.sendSync('getport')
    document.getElementById('diolink').href = `http://localhost:${dioport}`

    const settingsDir = ipcRenderer.sendSync('getsettingsdir')
    window.dioSettingsFile = path.join(settingsDir, 'diogenes.prefs');

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
    fs.readFile(window.dioSettingsFile, (err, data) => {
        if (!err) {
            console.log("Reading " + window.dioSettingsFile);
            var reTLG = /^tlg_dir\s+"?(.*?)"?$/m;
            var rePHI = /^phi_dir\s+"?(.*?)"?$/m;
            var reDDP = /^ddp_dir\s+"?(.*?)"?$/m;
            var ar;
            ar = reTLG.exec(data);
            if (ar) {
                showPath('TLG', ar[1]);
            }
            ar = rePHI.exec(data);
            if (ar) {
                showPath('PHI', ar[1]);
            }
            ar = reDDP.exec(data);
            if (ar) {
                showPath('DDP', ar[1]);
            }
        }
    });

};

window.addEventListener('load', setup, false);
