// All used by the pages/firstrun.html page

const {ipcRenderer} = require('electron')
const {dialog} = require('electron').remote
const path = require('path');
const fs = require('fs');

dioSettingsDir = ipcRenderer.sendSync('getsettingsdir')
dioSettingsFile = path.join(dioSettingsDir, 'diogenes.prefs')

let dbs = ['PHI', 'TLG', 'DDP']

function setPath(dbName, folderPath) {
    if(typeof folderPath === "undefined") {
        return
    }

    // check if folderPath is defined.
    try {
        data = fs.readFileSync(dioSettingsFile, 'utf8')
    } catch(e) {
        data = '# Created by electron'
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
    showPath(dbName, folderPath)
    readyDoneButton()
}

function showPath(dbName, folderPath) {
    document.getElementById(`${dbName}path`).innerHTML = folderPath

    checkmark = document.getElementById(`${dbName}ok`)
    if(fs.existsSync(`${folderPath}/authtab.dir`) || fs.existsSync(`${folderPath}/AUTHTAB.DIR`)) {
        checkmark.innerHTML = '✓'
        checkmark.classList.remove('warn')
        checkmark.classList.add('valid')
    } else {
        checkmark.innerHTML = '✕ No authtab.dir found; this doesn\'t look like a correct database location'
        checkmark.classList.remove('valid')
        checkmark.classList.add('warn')
    }
}

function readyDoneButton() {
    let anyset = 0
    for(let i = 0; i < dbs.length; i++) {
        let d = `${dbs[i]}path`
        if(document.getElementById(d).innerHTML.length > 0) {
            anyset = 1
        }
    }

    if(anyset) {
        document.getElementById('donesection').style.display = 'block'
    }
}

function bindClickEvent(dbName) {
    document.getElementById(`${dbName}button`).addEventListener('click', () => {
        setPath(dbName, dialog.showOpenDialog({
            title: `Set ${dbName} location`,
            properties: ['openDirectory']
        }))
    })
}

function firstrunSetup() {
    // Create settings dir, if necessary
    if(!fs.existsSync(dioSettingsDir)) {
        fs.mkdirSync(dioSettingsDir)
    }

    readyDoneButton()

    document.getElementById('done').addEventListener('click', () => {
        window.location.href = `http://localhost:` + ipcRenderer.sendSync('getport')
    })

    // Read existing db settings
    try {
        data = fs.readFileSync(dioSettingsFile, 'utf8')
    } catch(e) {
        data = null
    }

    for(let i = 0; i < dbs.length; i++) {
        let db = dbs[i]

        bindClickEvent(db)

        if(data === null) {
            continue
        }

        let db_l = db.toLowerCase()
        let re = new RegExp(`^${db_l}_dir\\s+"?(.*?)"?$`, 'm')
        let ar = re.exec(data)
        if(ar) {
            showPath(db, ar[1])
        }
    }
}

function isFirstRunPage() {
    // Only load on the first run page
    if(document.getElementById('firstrunpage') !== null) {
        firstrunSetup()
    }
}

window.addEventListener('load', isFirstRunPage, false)

// Select folder for XML export

function setXMLPath (path) {
    if (path) {
        var event = new CustomEvent('XMLPathResponse', { detail: path });
        document.dispatchEvent(event)
    }
}

function exportPathPick () {
    setXMLPath(dialog.showOpenDialog({
        title: 'Set location for XML directory',
        properties: ['openDirectory']
    }))
}

document.addEventListener('XMLPathRequest', exportPathPick, false)

// Select file for File Save

function saveFile () {
    var path = dialog.showSaveDialog({title: 'Save File Location', defaultPath: 'diogenes-output.html'});
    if (path) {
        ipcRenderer.send('saveFileResponse', path)
    }
}

ipcRenderer.on('saveFileRequest', (event, message) => {
    console.log('Saving file ...');
    saveFile();
});

// Select file for Print to PDF

function printPDF (win) {
    var path = dialog.showSaveDialog({title: 'PDF File Location', defaultPath: 'diogenes-print.pdf'});
    if (path) {
        ipcRenderer.send('printPDFResponse', path)
    }
}

ipcRenderer.on('printPDFRequest', (event, message) => {
    console.log('Printing to PDF ...');
    printPDF();
});

// Open selected links using system default app (e.g. PDFs).

const shell = require('electron').shell;
document.addEventListener('openWithExternal', openWithExternal, false)

function openWithExternal (e) {
    var link = e.detail;
    console.log('Opening ' + link);
    shell.openExternal(link);
}

//console.log('preload done');
