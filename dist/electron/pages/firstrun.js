// This relies on nodejs functionality exposed by preload.js

let dbs = ['PHI', 'TLG', 'DDP']

function setPath(dbName, folderPath) {
	if(typeof folderPath === "undefined") {
		return
	}

	// check if folderPath is defined.
	let data = window.dioReadSettings()
	if(data === null) {
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
	window.dioWriteSettings(newData)
	showPath(dbName, folderPath)
	readyDoneButton()
}

function showPath(dbName, folderPath) {
	document.getElementById(`${dbName}path`).innerHTML = folderPath

	checkmark = document.getElementById(`${dbName}ok`)
	if(window.dioExistsSync(`${folderPath}/authtab.dir`) || window.dioExistsSync(`${folderPath}/AUTHTAB.DIR`)) {
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
		setPath(dbName, window.dioOpenDialog({
			title: `Set ${dbName} location`,
			properties: ['openDirectory']
		}))
	})
}

function firstrunSetup() {
	// Create settings dir, if necessary
	if(!window.dioExistsSync(window.dioSettingsDir)) {
		window.dioMkSettingsDir()
	}

	readyDoneButton()

	document.getElementById('done').addEventListener('click', () => {
		window.location.href = `http://localhost:${window.dioPort}`
	})

	// Read existing db settings
	let data = window.dioReadSettings()

	for(let i = 0; i < dbs.length; i++) {
		let db = dbs[i]

		bindClickEvent(db)

		if(data === null) {
			continue
		}

		let db_l = db.toLowerCase()
		let re = `/^${db_l}_dir\s+"?(.*?)"?$/m;/`
		let ar = re.exec(data)
		if(ar) {
			showPath(db, ar[1])
		}
	}
}

window.addEventListener('load', firstrunSetup, false)
