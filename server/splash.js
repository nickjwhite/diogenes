// Dynamic splash-page with sticky choices.  Requires html5
var corpus, query, author;

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

function save_values () {
    if(lsTest === true){
        if (document.getElementById("corpus_menu")) {
            corpus = document.getElementById("corpus_menu").value;
            localStorage.setItem("corpus", corpus);
        }
        if (document.getElementById("query_text")) {
            query = document.getElementById("query_text").value;
            localStorage.setItem("query", query);
        }
        if (document.getElementById("author_text")) {
            author = document.getElementById("author_text").value;
            localStorage.setItem("author", author);
        }
    }
}

window.onsubmit = function () {
    console.log('saving values');
    save_values();
}
function dropdown (menu) {
    document.getElementById(menu).style.display = "block";
}
function dropup (menu) {
    document.getElementById(menu).style.display = "none";
}
function droptoggle (menu) {
    var state = document.getElementById(menu).style.display;
    if (state === "none") {
        dropdown(menu)
    } else {
        dropup(menu)
    }
}

const infoText ={};
function info (choice) {

    if (document.getElementById("corpus_menu")) {
        corpus = document.getElementById("corpus_menu").value;
    }
    if (document.getElementById("query_text")) {
        query = document.getElementById("query_text").value;
    }
    if (document.getElementById("author_text")) {
        author = document.getElementById("author_text").value;
    }

    // Hide all submenus
    dropup('submenu1');
    dropup('submenu2');
    document.getElementById("info").innerHTML = infoText[choice];
    if (corpus && document.getElementById("corpus_menu")) {
        document.getElementById("corpus_menu").value = corpus;
    }
    if (query && document.getElementById("query_text")) {
        document.getElementById("query_text").value = query;
    }
    if (author && document.getElementById("author_text")) {
        document.getElementById("author_text").value = author;
    }

    if (document.getElementById("query_text")) {
        document.getElementById("query_text").focus();
    }

    document.getElementById("action").value = choice;
}

// Set up content for user choices.
window.onload = function () {
    if(lsTest === true){
        corpus = localStorage.getItem("corpus");
        query = localStorage.getItem("query");
        author = localStorage.getItem("author");
    }
    var corpora1 = document.getElementById("corpora-list1").innerHTML;
    var corpora2 = document.getElementById("corpora-list2").innerHTML;
    var corporaAll = '<select name="corpus" id="corpus_menu" class="info-field">' +
        '<optgroup label="Databases">' + corpora1 +
        '</optgroup><optgroup label="User-defined corpora">' +
        corpora2 + '</optgroup></select>';
    var corporaCore = '<select name="corpus" id="corpus_menu" class="info-field">' +
        corpora1 +
        '</select>';

    infoText['browse'] = '<h2 class="info-h2">Read a Text</h2>' +
        '<p class="info-field">Corpus: ' + corporaCore +
        '<p class="info-field">Author:&nbsp;<input type="text" name="author" size="30" id="author_text" class="info-field">&nbsp;<input type="submit" name="go" value="Go" class="info-field"></p>' +
        '<p class="info-text">Choose the relevant corpus, and then enter the name of an author (or part of the name, or the author\'s number or nickname).  Leave the space blank to choose from a list of all authors in the corpus.</p>';

    infoText['search'] = '<h2 class="info-h2">Simple Search</h2>' +
        '<p class="info-field">Corpus: ' + corporaAll + '</p>' +
        '<p class="info-field">Pattern:&nbsp;<input type="text" name="query" size="40" id="query_text" class="info-field">&nbsp;<input type="submit" name="go" value="Go" class="info-field"></p>' +
        '<p class="info-text">Choose the relevant corpus, and then enter a pattern (word or sequence of words) to search for.  Enter Greek without diacritics. <b>NB.</b> To restrict a search to the beginning or end of a word, enter a space before or after the letters in your pattern.</p>';

    infoText['author'] = '<h2 class="info-h2">Search in an Author</h2>' +
        '<p class="info-field">Corpus: ' + corporaCore + '</p>' +
        '<p class="info-field">Author: <input type="text" name="author" size="20" id="author_text" class="info-field"></p>' +
        '<p class="info-field">Pattern:&nbsp;<input type="text" name="query" size="40" id="query_text" class="info-field">&nbsp;<input type="submit" name="go" value="Go" class="info-field"></p>' +
        '<p class="info-text">This is a simple search within the texts of selected author(s). Choose the relevant corpus, and enter part of an author\'s name (all matching authors will be searched).  Then enter a pattern to search for. For finer-grained control over which authors and texts to search in and many more ways to select them, choose the <b>Filter</b> option above.</p> <h1>Not implemented yet!</h1>';

    infoText['multiple'] = '<h2 class="info-h2">Multiple Pattern Search</h2>' +
        '<p class="info-field">Corpus: ' + corporaAll + '</p>' +
        '<p class="info-field">Pattern:&nbsp;<input type="text" name="query" size="40" id="query_text" class="info-field">&nbsp;<input type="submit" name="go" value="Go" class="info-field"></p>' +
        '<p class="info-text">Search for multiple terms in arbitrary order within a certain scope.  Enter the corpus to search in and the first of your search terms.  You will be able to add further terms in subsequent pages.</p>';

    infoText['lemma'] = '<h2 class="info-h2">Morphological Search</h2>' +
        '<p class="info-field">Corpus: ' + corporaAll + '</p>' +
        '<p class="info-field">Pattern:&nbsp;<input type="text" name="query" size="40" id="query_text" class="info-field">&nbsp;<input type="submit" name="go" value="Go" class="info-field"></p>' +
        '<p class="info-text">Search for particular inflected forms of a given word.  Enter the corpus and (part of) a word in its dictionary form.</p>';

    infoText['word_list'] = '<h2 class="info-h2">TLG Word List Search</h2>' +
        '<p class="info-field">Pattern:&nbsp;<input type="text" name="query" size="40" id="query_text" class="info-field">&nbsp;<input type="submit" name="go" value="Go" class="info-field"></p>' +
        '<p class="info-text">The <i>TLG</i> has a word-list that serves as an index, indicating which texts each word appears in.  In some cases, searching via the word list can be faster.  Enter a word to see matches from the word-list.  Put a space in front to match only at the beginning of words.</p>';

    infoText['lookup'] = '<h2 class="info-h2">Dictionary Lookup</h2>' +
        '<p class="info-field">Word:&nbsp;<input type="text" name="query" size="40" id="query_text" class="info-field">&nbsp;<input type="submit" name="go" value="Go" class="info-field"></p>' +
        '<p class="info-text">Look up a word in the Greek lexicon of Liddel, Scott and Jones or in the Latin lexicon of Lewis and Short.</p>';

    infoText['parse'] = '<h2 class="info-h2">Parse an Inflected Form</h2>' +
        '<p class="info-field">Word:&nbsp;<input type="text" name="query" size="40" id="query_text" class="info-field">&nbsp;<input type="submit" name="go" value="Go" class="info-field"></p>' +
        '<p class="info-text">Parse the morphology of an inflected word in Latin or Greek.</p>';

    infoText['filters'] = '<h2 class="info-h2">Select subsets of texts</h2>' +
        '<p class="info-text">In order to perform delimited, targeted searches, you can create lists of particular authors and/or texts and save them for later reuse.  These personalized subsets of texts can be created for any database.  Furthermore, the <i>TLG</i> database categorizes texts by genre, date and so on, and these can be used as the basis for user-defined subsets.</p>' +
        '<p class="info-field"><center><input class="info-button" type="submit" name="go" value="Create and Manage Subsets" class="info-field"></center></p>';

    infoText['export'] = '<h2 class="info-h2">Export texts as XML</h2>' +
        '<p class="info-text">You can export texts as XML (compliant with the Text Encoding Initiative) for feeding into other text-analysis tools.  If you want to export particular texts or authors, first go to <b>Filter</b> and create a subset with the texts you want to export.</p>' +
        '<p class="info-field"><center><input class="info-button" type="submit" name="go" value="Go to XML Export Page" class="info-field"></center></p><h1>Not implemented yet!</h1>';

    infoText['help'] = '<h2 class="info-h2">Help and Support</h2>' +
        '<p class="info-text">For information about using Diogenes, see the <a href="http://community.dur.ac.uk/p.j.heslin/Software/Diogenes/diogenes-help.html">website</a>.</p>' +
        '<p class="info-text">If are a student, a schoolteacher or a member of the general public who uses Diogenes, or if you are a university teacher who uses it in your undergraduate teaching, you can help to support its continuing development by sending a quick message describing the benefits it has brought to you to this address:  <a href="mailto:p.j.heslin@durham.ac.uk?subject=Diogenes Impact">p.j.heslin@durham.ac.uk</a>.</p>';

}
