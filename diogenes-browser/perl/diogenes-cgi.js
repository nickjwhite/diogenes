
// Select All for the checkboxes
function setAll() {
    with (document.form) {
        for (i = 0; i < elements.length; i++) {
            if (elements[i].name == "word_list" || 
                elements[i].name == "author_list" ||
                elements[i].name == "works_list" ||
                elements[i].name == "lemma_list") {
                elements[i].checked = true;
                elements[i].selected = true;
            }
        }
    }
}

// For the splash page
function onActionChange() {
  if (document.form.action.selectedIndex == 7) {
    document.form.submit();
  }
}

// AJAX stuff
var req = null;

function new_page (action, lang, query){
    window.location.href = "Perseus.cgi?do="+action+"&lang="+lang+"&q="+query+"&popup=1"+"&font="+getFont();
}

function sendRequest(action, lang, query) {
    /* If we just want a popup, skip the AJAX fancy stuff*/
    var sidebar = document.getElementById("sidebar");
    var sidebarClass = sidebar.getAttribute("class");
    if (sidebarClass == "sidebar-popup") {
        try {
            var perseusWin = window.open("Perseus.cgi?do="+action+"&lang="+lang+"&q="+query+"&popup=1", 
                'Perseus Data');
        } catch(e) {
            alert('You have requested that Perseus data be displayed in a pop-up window, ' +
                  'but you appear to have disallowed pop-ups from this web site. ' + e );
        }
    }
    else if (sidebarClass == "sidebar-newpage") {
        new_page(action, lang, query);
    }    
    else {
        /* Check for running connections */
        if (req != null && req.readyState != 0 && req.readyState != 4) {
            req.abort();
        }
        if (window.XMLHttpRequest) { 
            req = new XMLHttpRequest();     // Firefox, Safari, ...
        } else if (window.ActiveXObject) {
            req = new ActiveXObject("Microsoft.XMLHTTP");  // Internet Explorer 
        }
        req.onreadystatechange = stateHandler;
        req.open("POST", "Perseus.cgi");
        req.send("do="+action+"&lang="+lang+"&q="+query);
        return true;
    }
    return true;
}

function stateHandler() {
    if (req.readyState == 4) {
        if (req.status && req.status == 200) {
            showPerseus();
        }
        /* IE returns a status code of 0 on some occasions, so ignore this case */
        else if (req.status != 0)
        {
            failedConnect();
        }
    }
    return true;
}

function failedConnect () {
    alert("Could not get Perseus data!");
}

function showPerseus () {
    var sidebar = document.getElementById("sidebar");
    if (sidebar == null) {
        alert("Error: no sidebar");
    }
    else {
        sidebar.innerHTML = req.responseText;
    }
    var sidebarClass = sidebar.getAttribute("class");
    if (sidebarClass == "sidebar-full") {
        var mainWindow = document.getElementById("main_window");
        mainWindow.setAttribute("class", "main-hidden");
    }
    sidebarControl();
}


function sidebarControl () {
    var sidebar = document.getElementById("sidebar");
    var sidebarClass = sidebar.getAttribute("class");
    var sidebarControl = document.getElementById("sidebar-control");

    if (sidebarClass == 'sidebar-split') {
        sidebarControl.innerHTML = '<a onClick="sidebarDismiss();">Dismiss</a><br/>'+
            '<a onClick="sidebarFullscreen();">Full Screen</a>';
    } else if (sidebarClass == 'sidebar-full') {
        sidebarControl.innerHTML = '<a onClick="sidebarDismiss();">Dismiss</a><br/>'+
            '<a onClick="sidebarSplitscreen();">Split Screen</a>';
    } else {
        alert("Error: sidebar state -- "+sidebarClass);
    }
}

function sidebarDismiss () {
    var sidebar = document.getElementById("sidebar");
    var mainWindow = document.getElementById("main_window");
    sidebar.innerHTML = "";
    mainWindow.setAttribute("class", "main-full");
}

function sidebarFullscreen () {
    var sidebar = document.getElementById("sidebar");
    var mainWindow = document.getElementById("main_window");
    sidebar.setAttribute("class", "sidebar-full");
    mainWindow.setAttribute("class", "main-hidden");
    sidebarControl();
}

function sidebarSplitscreen () {
    var sidebar = document.getElementById("sidebar");
    var mainWindow = document.getElementById("main_window");
    sidebar.setAttribute("class", "sidebar-split");
    mainWindow.setAttribute("class", "main-full");
    sidebarControl();
}


function parse_grk (word) {
    sendRequest("parse", "grk", word);
}
function parse_lat (word) {
    sendRequest("parse", "lat", word);
}
function parse_eng (word) {
    sendRequest("parse", "eng", word);
}

// These put the results in a new page
function parse_grk_page (word) {
    new_page("parse", "grk", word);
}
function parse_lat_page (word) {
    new_page("parse", "lat", word);
}
function parse_eng_page (word) {
    new_page("parse", "eng", word);
}

function getEntrygrk (loc) {
    sendRequest("get_entry", "grk", loc);
    window.scrollTo(0,0);
}
function getEntrylat (loc) {
    sendRequest("get_entry", "lat", loc);
    window.scrollTo(0,0);
}
function getEntryeng (loc) {
    sendRequest("get_entry", "eng", loc);
    window.scrollTo(0,0);
}

function prevEntrygrk (loc) {
    sendRequest("prev_entry", "grk", loc);
    window.scrollTo(0,0);
}
function prevEntrylat (loc) {
    sendRequest("prev_entry", "lat", loc);
    window.scrollTo(0,0);
}
function prevEntryeng (loc) {
    sendRequest("prev_entry", "eng", loc);
    window.scrollTo(0,0);
}

function nextEntrygrk (loc) {
    sendRequest("next_entry", "grk", loc);
    window.scrollTo(0,0);
}
function nextEntrylat (loc) {
    sendRequest("next_entry", "lat", loc);
    window.scrollTo(0,0);
}
function nextEntryeng (loc) {
    sendRequest("next_entry", "eng", loc);
    window.scrollTo(0,0);
}

function jumpTo (loc) {
    var dio_form = document.getElementById("form");
    dio_form.JumpTo.value = loc;
    document.form.submit();
}

function getFont () {
    var dio_form = document.getElementById("form");
    return dio_form.FontName.value;
}

function toggleLemma (num) {
    var img = document.getElementById("lemma_"+num);
    if (img.getAttribute("src") == "images/opened.gif") {
        img.setAttribute("src","images/closed.gif");
        var span = document.getElementById("lemma_span_"+num);
        span.setAttribute("class", "lemma_span_invisible");

    }
    else if (img.getAttribute("src") == "images/closed.gif") {
        img.setAttribute("src","images/opened.gif");
        var span = document.getElementById("lemma_span_"+num);
        span.setAttribute("class", "lemma_span_visible");
    }
}

function selectVisible (bool) {
    var elements = document.form.getElementsByTagName("span");
    for (i = 0; i < elements.length; i++) {
        if (elements[i].className == "lemma_span_visible") {
            var subspan = elements[i].getElementsByTagName("span");
            for (j = 0; j < subspan.length; j++) {
                if (subspan[j].className == "form_span_visible") {
//                     alert(boxes[j].className);
                    var boxes = subspan[j].getElementsByTagName("input");
                    boxes[0].checked = bool;
                    boxes[0].selected = bool;
                }
            }
        }
    }
}

function formFilter () {
    var text = document.getElementById('form_filter').value;
    var re = /[\s,]/;
    var textList = text.split(re);
    var elements = document.form.getElementsByTagName("span");
    for (i = 0; i < elements.length; i++) {
        var myClass = elements[i].className;
        if (myClass == "form_span_visible" || myClass == "form_span_invisible") {
            var infl = elements[i].getAttribute("infl");
//              alert(infl);
            for (var j = 0; j < textList.length; j++) {
//                 if (textList[j] != "" && infl.indexOf(textList[j]) != -1) {
                if (infl.indexOf(textList[j]) != -1) {
//                     alert(infl);
                    elements[i].className = "form_span_visible";
                }
                else {
                    elements[i].className = "form_span_invisible";
                }
            }
        }
    }
}

 
