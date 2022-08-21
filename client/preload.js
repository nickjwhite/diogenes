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
  exportPathPick: () => {
    return ipcRenderer.sendSync('exportPathPick')
  },
  findText: (string, direction) => {
    return ipcRenderer.sendSync('findText', string, direction)
  },
  cssWriteFont: (font) => {
    return ipcRenderer.sendSync('cssWriteFont', font)
  },
  cssReadFont: () => {
    return ipcRenderer.sendSync('cssReadFont')
  },
  cssRevertFont: () => {
    return ipcRenderer.sendSync('cssRevertFont')
  },
  getFonts: () => ipcRenderer.invoke('getFonts'),

  // Not used yet, but might be useful 
  saveFile: () => {
    return ipcRenderer.sendSync('saveFile')
  },
  printToPDF: () => {
    return ipcRenderer.sendSync('printToPDF')
  },

})
