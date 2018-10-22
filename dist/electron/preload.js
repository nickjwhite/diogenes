const {ipcRenderer} = require('electron')
const {dialog} = require('electron').remote
const path = require('path');
const fs = require('fs');


// Export these for the dbsettings page
window.dioPort = ipcRenderer.sendSync('getport')
window.dioSettingsDir = ipcRenderer.sendSync('getsettingsdir')
window.dioSettingsFile = path.join(window.dioSettingsDir, 'diogenes.prefs')
window.dioOpenDialog = dialog.showOpenDialog
window.dioWriteSettings = function(s) {
	fs.writeFileSync(window.dioSettingsFile, s)
}
window.dioReadSettings = function() {
	try {
		return fs.readFileSync(window.dioSettingsFile, 'utf8')
	} catch(e) {
		return null
	}
}
window.dioMkSettingsDir = function() {
	return fs.mkdirSync(window.dioSettingsDir)
}
window.dioExistsSync = fs.existsSync
