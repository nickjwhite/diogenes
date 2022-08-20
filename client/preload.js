const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electron', {
  firstrunSetupMain: () => {
    return ipcRenderer.sendSync('firstrunSetupMain')
  },
  getport: () => {
    return ipcRenderer.sendSync('getport')
  },
  dbOpenDialog: (prop, dbName) => {
    return ipcRenderer.sendSync('dbOpenDialog', prop, dbName)
  },
  authtabExists: (folderPath) => {
    return authtabExists = ipcRenderer.sendSync('authtabExists', folderPath)
  },
  
})
