const {ipcRenderer} = require('electron')
const {dialog} = require('electron').remote
const path = require('path');
const fs = require('fs');

function setPath(dbName, folderPath) {
    if(typeof folderPath === "undefined") {
        return
    }

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

    checkmark = document.getElementById(`${dbName}ok`)
    if(fs.existsSync(`${folderPath}/authtab.dir`) || fs.existsSync(`${folderPath}/AUTHTAB.DIR`)) {
        checkmark.innerHTML = '✓'
    } else {
        checkmark.innerHTML = '✕ No authtab.dir found; this may not be a valid database location'
    }
}

function bindClickEvent (dbName) {
    document.getElementById(`${dbName}button`).addEventListener('click', () => {
        setPath(dbName, dialog.showOpenDialog({
            title: `Set ${dbName} location`,
            properties: ['openDirectory']
            }))
    });
}

function setup() {
    var dioport = ipcRenderer.sendSync('getport')

    const settingsDir = ipcRenderer.sendSync('getsettingsdir')
    window.dioSettingsFile = path.join(settingsDir, 'diogenes.prefs');

    // Set up click events
    bindClickEvent('PHI');
    bindClickEvent('TLG');
    bindClickEvent('DDP');

    document.getElementById('done').addEventListener('click', () => {
        window.location.href = `http://localhost:${dioport}`
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
