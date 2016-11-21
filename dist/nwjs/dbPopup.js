function setPath (dbName, folderPath) {
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

function saveSettings() {

}

window.onload = function () {
    bindClickEvent('PHI');
    bindClickEvent('TLG');
    bindClickEvent('DDP');
    var button = document.querySelector('#save');
    button.addEventListener('click', function () {
        saveSettings();
        window.close()
    });
    button = document.querySelector('#cancel');
    button.addEventListener('click', function () {
        window.close()
    });
};


// var fileinput = document.querySelector('#PHI');
// var path;
// function foo () {
//     path = fileinput.value;
//     alert(path);
// }
// fileinput.onchange = function(e) { 
//     console.log("foo"+path);
// };
// fileinput.addEventListener("change", function(evt) {
//     console.log("Bar"+path);
// }, false);
// function bindEvent () {
//     var button = document.querySelector('#TLG');
//     button.addEventListener('click', function () {
//         alert(button.value);
//     });
// }
// window.onload = function () {
//     bindEvent();
// };
