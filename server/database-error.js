// File picker when database not found

window.onload = function() {

    function chooseFile(name) {
        var chooser = document.querySelector(name);
        chooser.addEventListener("change", function(evt) {
            console.log(this.value);
        }, false);
    
        chooser.click();  
    }
    chooseFile('#fileDialog');
};
