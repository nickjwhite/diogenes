// This relies on nodejs functionality exposed by preload.js

function setPath(dbName, folderPath) {
    if(typeof folderPath === "undefined") {
        return
    }

    // check if folderPath is defined.
	data = window.dioReadSettings()
	if(data === null) {
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
	window.dioWriteSettings(newData)
    showPath(dbName, folderPath);
}

function showPath (dbName, folderPath) {
    document.getElementById(`${dbName}path`).innerHTML = folderPath;

    checkmark = document.getElementById(`${dbName}ok`)
    if(window.dioExistsSync(`${folderPath}/authtab.dir`) || window.dioExistsSync(`${folderPath}/AUTHTAB.DIR`)) {
        checkmark.innerHTML = '✓'
    } else {
        checkmark.innerHTML = '✕ No authtab.dir found; this may not be a valid database location'
    }
}

function bindClickEvent (dbName) {
    document.getElementById(`${dbName}button`).addEventListener('click', () => {
        setPath(dbName, window.dioOpenDialog({
            title: `Set ${dbName} location`,
            properties: ['openDirectory']
            }))
    });
}

window.dbSettingsSetup = function() {
    // Set up click events
    bindClickEvent('PHI');
    bindClickEvent('TLG');
    bindClickEvent('DDP');

    document.getElementById('done').addEventListener('click', () => {
        window.location.href = `http://localhost:${window.dioPort}`
    });

    // Create settings dir, if necessary
    if (! window.dioExistsSync(window.dioSettingsDir)) {
        window.dioMkSettingsDir
    }
    // Read existing db settings
	data = window.dioReadSettings()
	if(data === null) {
		return
	}
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
};

window.addEventListener('load', dbSettingsSetup, false);
