// Make splash-page choices sticky.  Should work both in nw.js and in other html5 browsers
var corpus, action, query;

// Is localStorage available?
var lsTest = function(){
    var test = 'test';
    try {
        localStorage.setItem(test, test);
        localStorage.removeItem(test);
        return true;
    } catch(e) {
        return false;
    }
}();

window.onload = function() {
    if(lsTest === true){
        corpus = document.getElementById("corpus_menu");
        action = document.getElementById("action_menu");
        query = document.getElementById("query_text");

        var val = localStorage.getItem("corpus");
        if (val) {
            corpus.value = val;
        }
        val = localStorage.getItem("action");
        if (val) {
            action.value = val;
        }
        val = localStorage.getItem("query");
        if (val) {
            query.value = val;
        }
    }
};

window.onsubmit = function() {
    if(lsTest === true){
        localStorage.setItem("corpus", corpus.value);
        localStorage.setItem("action", action.value);
        localStorage.setItem("query", query.value);
    }
};
