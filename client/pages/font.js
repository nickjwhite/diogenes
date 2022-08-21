// Get and show list of installed fonts
async function showFonts () {
  document.getElementById('fontSelectButton').addEventListener('click', setNewFont)
  document.getElementById('fontRevertButton').addEventListener('click', revertFont)
  document.getElementById('fontAbortButton').addEventListener('click', cancelFont)

  var list = document.getElementById('fontList')
  var loading = document.getElementById('fontLoading')
  var select = document.createElement('select')
  select.setAttribute('id', 'fontSelect')
  var current = await window.electron.cssReadFont()
  console.log('current:', current)

  fonts = await window.electron.getFonts()
  console.log('Fonts', fonts)
  fonts.forEach(font => {
    var option = document.createElement('option')
    option.setAttribute('value', font)
    var text = font.replace(/^"|"$/g, '')
    option.append(document.createTextNode(text));
    if (current && text == current) {
      option.setAttribute('selected', 'selected')
    }
    select.append(option)
  })

  list.removeChild(loading)
  list.append(select)
}

async function setNewFont () {
  var list = document.getElementById("fontSelect");
  var font = list.options[list.selectedIndex].value;
  font = font.replace(/^"|"$/g, '')
  ret = await window.electron.cssWriteFont(font)
  if (ret == 'done') {
    window.close()
  } else {
    document.getElementById('errormsg').innerHTML = "Error writing CSS file: " + ret
  }
}

async function revertFont () {
  ret = await window.electron.cssRevertFont()
  if (ret == 'done') {
    window.close()
  } else {
    document.getElementById('errormsg').innerHTML = "Error deleting CSS file: " + ret
  }
}
function cancelFont () {
    window.close()
}

showFonts()

