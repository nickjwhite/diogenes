// Adapted from Benjamin Smedberg's mybrowser XULrunner example


// nsIWebProgressListener implementation to monitor activity in the browser.
function WebProgressListener() {
}
WebProgressListener.prototype = {
_requestsStarted: 0,
_requestsFinished: 0,

// We need to advertize that we support weak references.  This is done simply
// by saying that we QI to nsISupportsWeakReference.  XPConnect will take
// care of actually implementing that interface on our behalf.
QueryInterface: function(iid) {
        if (iid.equals(Components.interfaces.nsIWebProgressListener) ||
            iid.equals(Components.interfaces.nsISupportsWeakReference) ||
            iid.equals(Components.interfaces.nsISupports))
            return this;
        
        throw Components.results.NS_ERROR_NO_INTERFACE;
    },

// This method is called to indicate state changes.
onStateChange: function(webProgress, request, stateFlags, status) {
        const WPL = Components.interfaces.nsIWebProgressListener;
        
//         var progress = document.getElementById("progress");
        
        if (stateFlags & WPL.STATE_IS_REQUEST) {
            if (stateFlags & WPL.STATE_START) {
                this._requestsStarted++;
            } else if (stateFlags & WPL.STATE_STOP) {
                this._requestsFinished++;
            }
            if (this._requestsStarted > 1) {
                var value = (100 * this._requestsFinished) / this._requestsStarted;
//                 progress.setAttribute("mode", "determined");
//                 progress.setAttribute("value", value + "%");
            }
        }
        
        if (stateFlags & WPL.STATE_IS_NETWORK) {
            var stop = document.getElementById("stop-button");
            var stopMenu = document.getElementById("stop-menuitem");
            if (stateFlags & WPL.STATE_START) {
                stop.setAttribute("disabled", false);
                stopMenu.setAttribute("disabled", false);
//                 progress.setAttribute("style", "");
            } else if (stateFlags & WPL.STATE_STOP) {
                stop.setAttribute("disabled", true);
                stopMenu.setAttribute("disabled", true);
//                 progress.setAttribute("style", "display: none");
                this.onStatusChange(webProgress, request, 0, "Done");
                this._requestsStarted = this._requestsFinished = 0;
            }
        }
    },

// This method is called to indicate progress changes for the currently
// loading page.
onProgressChange: function(webProgress, request, curSelf, maxSelf,
                           curTotal, maxTotal) {
        if (this._requestsStarted == 1) {
//             var progress = document.getElementById("progress");
//             if (maxSelf == -1) {
//                 progress.setAttribute("mode", "undetermined");
//             } else {
//                 progress.setAttribute("mode", "determined");
//                 progress.setAttribute("value", ((100 * curSelf) / maxSelf) + "%");
//             }
        }
    },

// This method is called to indicate a change to the current location.
onLocationChange: function(webProgress, request, location) {
        
        var browser = document.getElementById("browser");
        var back = document.getElementById("back-button");
        var backMenu = document.getElementById("back-menuitem");
        var forward = document.getElementById("forward-button");
        var forwardMenu = document.getElementById("forward-menuitem");

        back.setAttribute("disabled", !browser.canGoBack);
        backMenu.setAttribute("disabled", !browser.canGoBack);
        forward.setAttribute("disabled", !browser.canGoForward);
        forwardMenu.setAttribute("disabled", !browser.canGoForward);
    },

// This method is called to indicate a status changes for the currently
// loading page.  The message is already formatted for display.
onStatusChange: function(webProgress, request, status, message) {
//         var statusX = document.getElementById("status");
//         statusX.setAttribute("label", message);
    },
// This method is called when the security state of the browser changes.
onSecurityChange: function(webProgress, request, state) {
    }
};

var listener;

var dio_port;

function get_port () {
    if (!dio_port) {
        var ar = readLockFile();
        dio_port = ar[0];
    }
    return dio_port;
}

function go() {
    var browser = document.getElementById("browser");
    var port = get_port();
    if (!port)
    {
        dump("ERROR: port unknown!\n");
    } else {
        browser.loadURI("http:127.0.0.1:" + port + "/", null, null); 
    }
}

var wentBack = false;
function back() {
    var browser = document.getElementById("browser");
    browser.stop();
    wentBack = true;
    browser.goBack();
}

function forward() {
    var browser = document.getElementById("browser");
    browser.stop();
    browser.goForward();
}

function reload() {
    var browser = document.getElementById("browser");
    browser.reload();
}

function stop() {
  var browser = document.getElementById("browser");
  browser.stop();
}

function showConsole() {
  window.open("chrome://global/content/console.xul", "_blank",
    "chrome,extrachrome,menubar,resizable,scrollbars,status,toolbar");
}

function windowClose() {
    // Why doesn't this happen automatically?
    onClose();
    window.close();
}

function onLoad() {

    // Only fires when a new chrome window opens
    listener = new WebProgressListener();

    var browser = document.getElementById("browser");

    browser.addProgressListener(listener,
                                Components.interfaces.nsIWebProgress.NOTIFY_ALL);

    browser.addEventListener("load", browserOnLoad, true);
    browser.addEventListener("submit", browserOnSubmit, true);

    // When the first window is loading, we clean up any server
    // processes that are hanging around from a previous run that ended
    // uncleanly.  We then start the server and wait for a lock file to
    // indicate that the server is running.  Only then do we go()
    // and load the URL -- otherwise we get connection errors.
    // Subsequent windows can just connect.
    if (isFirstOrLastWindow()) {
        setupEnv();
        waitToLoad();
    }
    else {
        go();
    }
}

// addEventListener("load", onload, false);

// --------- end of browser -------------

// The waiting functions call each other in a chain that ends in go()

function waitToLoad () {
    var lock = new FileFactory(getLockFile());
    if (lock.exists()) {
        dump("Lockfile exists.\n");
        killServer();
        waitForNoLockAndStartServer();
    }
    else {
        dump("No lockfile.\n");
        runPerlServer();
        waitForLock();
    }
}


function warnUser(message) {
    alert(message);
}

function getOS() { 
    var platform;
    var OS;
    if (typeof(window.navigator.platform) != 'undefined')
    {
        platform = window.navigator.platform.toLowerCase();
        if (platform.indexOf('win') != -1) {
            OS = 'win'; 
        } else if (platform.indexOf('mac') != -1) {
            OS = 'mac';
        } else if (platform.indexOf('unix') != -1 || platform.indexOf('linux') != -1 || platform.indexOf('sun') != -1) {
            OS = 'unix';
        } else {
            warnUser("Unidentified Operating System");
        }
    }
    return OS;
}

function getEnv (envVar) {
    var environment = Components.classes["@mozilla.org/process/environment;1"].
        getService(Components.interfaces.nsIEnvironment);
    return environment.get(envVar);
}

function getPathSep() {
    var sep;
    var OS = getOS();
    if (OS == 'unix' || OS == 'mac') {
        sep = ':';
    } else if (OS == 'win') {
        sep = ';';
    } else {
        warnUser("Could not get path separator");
    }
    return sep;
}

function getDirSep() {
    var sep;
    var OS = getOS();
    if (OS == 'unix' || OS == 'mac') {
        sep = '/';
    } else if (OS == 'win') {
        sep = '\\';
    } else {
        warnUser("Could not get directory separator");
    }
    return sep;
}

// Windows note: to enable debugging, change wperl.exe to perl.exe, so
// that it gets a console window, and give xulrunner the -console
// argument.

function getPerl() {
    var OS = getOS();
    if (OS == 'win') {
        // This is provided with ActivePerl and runs without a console window
        return 'wperl.exe';
//         return 'perl.exe';
    } else {
        return 'perl';
    }
}

function myAppendPath(path, leaf) {
    var sep = getDirSep();
    return ((path.charAt(path.length - 1) == sep) ? path : path + sep) + leaf;
}

function ensureDirectory (dir) {
    if (!dir) {return ''}
    var sep = getDirSep();
    return (dir.charAt(dir.length - 1) == sep) ? dir : dir + sep;
}

const FileFactory = new Components.Constructor("@mozilla.org/file/local;1","nsILocalFile","initWithPath"); 

function getPerlExecutable() {
    var perlpath;
    var path = getEnv('PATH');
    var dirs = path.split(getPathSep());
    for (var i in dirs) {
        // nsIFile.append method doesn't seem to work here
        var dir = dirs[i];
        var file = new FileFactory(myAppendPath(dir, getPerl()));
        // strangely, isExecutable fails for the Mac perl in /usr/bin.
        if (file.exists() && file.isFile()) {
            perlpath = file.path;
            break;
        }
    }
    if (! perlpath) {
        warnUser('Perl executable not found in path.');
    }
    return perlpath;
}

function runPerlServer() {
    dump("Starting up server.\n");
    runPerlScript("diogenes-server.pl", false);
}

function killServer () {
    var lock = new FileFactory(getLockFile());
    if (lock.exists()) {
        dump("Lockfile present\n");
        runServerKiller();
    }
    else if (complain) {
        dump("No lockfile present when trying to kill server");
    }
}

function runServerKiller() {
    dump("Shutting down server.\n");
    // We might end up killing the process we start next.
    // Asynchronicity is a funny thing.

    // Tried to block here, worked on Linux, but blocks forever on OS
    // X.  So we wait for the lock file to disappear instead using
    // waitForNoLockAndStartServer.

    runPerlScript("diogenes-server-kill.pl", false);
}

function runPerlScript (filename, blocking) {
    var perlfile = getPerlExecutable();
    try { 
        var perl = new FileFactory(perlfile);
    } catch (e) { alert(e) }
    //try to create process 
    try { 
        var perlProcess = Components.classes["@mozilla.org/process/util;1"].
            createInstance(Components.interfaces.nsIProcess); 
    } catch (e) { alert(e); }
    perlProcess.init(perl); 
    perlProcess.run(blocking, [getScriptPath(filename)], 1);
}

function getScriptPath (filename) {
    var self_dir = Components.classes["@mozilla.org/file/directory_service;1"]
        .getService(Components.interfaces.nsIProperties)
        .get("resource:app", Components.interfaces.nsIFile);
    return myAppendPath(myAppendPath(self_dir.path, "perl"), filename);
}

function getSettingsDir () {
    var  prof_dir= Components.classes["@mozilla.org/file/directory_service;1"]
        .getService(Components.interfaces.nsIProperties)
        .get("ProfD", Components.interfaces.nsIFile);
    return prof_dir.parent.parent.path;
}

function getLockFile () {
    return myAppendPath(getSettingsDir(), ".diogenes.run");
}

// The lock file goes into the base dir, but individual user settings
// go into a subdir, which for us, since we are not using cookies, is
// "default".
function getSettingsFile () {
    var userDir = ensureDirectory(myAppendPath(getSettingsDir(), 'default'));
    var dir = new FileFactory(userDir);
    if (!dir.exists()) {
        try {
            dir.create(Components.interfaces.nsIFile.DIRECTORY_TYPE, 0777);
        } catch (e) { 
            warnUser("Unable to create preferences dir: aborting ("+userDir+"). "+e);
            quitDiogenes();
        }
    }
    return myAppendPath(userDir, "diogenes.prefs");
}

var startIntervalID;
var stopIntervalID;
var serverStartTries;
var serverStopTries;

function waitForLock () {
    dump("Looking for " + getLockFile() + "\n");
    serverStartTries = 0;
    startIntervalID = setInterval(waitForLockHelper, 100); 
}

function waitForNoLockAndStartServer () {
    dump("Waiting for " + getLockFile() + " to disappear.");
    serverStopTries = 0;
    stopIntervalID = setInterval(waitForNoLockHelper, 100); 
}

function waitForLockHelper () {
    dump("Diogenes: attempting to contact server\n");
    serverStartTries++;
    var file = new FileFactory(getLockFile());
    if (file.exists() && file.isFile() && file.isReadable())
    {
        clearInterval(startIntervalID);
        go();
    }
    // 30 sec timeout
    if (serverStartTries > 300) {
        clearInterval(startIntervalID);
        var prompts = Components.classes["@mozilla.org/embedcomp/prompt-service;1"]
            .getService(Components.interfaces.nsIPromptService);
        var ok = prompts.alert(window, "Diogenes Error", 
                               "Unable to start perl server. Aborting.");
        quitDiogenes();
    }
}

function waitForNoLockHelper () {
    dump("Diogenes: waiting for server to exit\n");
    serverStopTries++;
    var file = new FileFactory(getLockFile());
    if (!file.exists())
    {
        startServerAndWait();
    }
    // 30 sec timeout
    if (serverStartTries > 300) {
        dump("Lockfile never disappeared!  Starting another server.");
        startServerAndWait();
    }
}

function startServerAndWait () {
    clearInterval(stopIntervalID);
    runPerlServer();
    waitForLock();
}

function readLockFile() {
    var file = new FileFactory(getLockFile());
    var istream = Components.classes["@mozilla.org/network/file-input-stream;1"]
        .createInstance(Components.interfaces.nsIFileInputStream);
    istream.init(file, 0x01, 0444, 0);
    istream.QueryInterface(Components.interfaces.nsILineInputStream);

    var line = {}, hasmore = true, port, pid;
    while (hasmore) {
        hasmore = istream.readLine(line);
        if (line.value == '') {
        }
        else if (line.value.substring(0,4) == 'port') {
            port = line.value.substring(5);
        }
        else if (line.value.substring(0,3) == 'pid') {
            pid = line.value.substring(4);
        }
        else { 
            warnUser ("Bad diogenes.run file!"); 
        }
    }
    istream.close();
    return [port, pid];
}


function newWindow () {
    var win = window.open("chrome://diogenes/content/diogenes.xul", "_blank",
              "chrome,extrachrome,menubar,resizable,scrollbars,status,toolbar");
    win.setAttribute("title", "Diogenes");
}

// Sigh.  There has to be a better way than this to detect when the
// app. is quitting.

// When we use an observer to listen for a quit-application event or
// similar, we can do a dump(), but nothing more elaborate than that.
// Seems to be a xulrunner bug.  So instead, we manually keep track of
// the windows we have opened and kill the server when the last one is
// gone.

// When the app is killed externally, the perl server will keep
// running, but there seems to be nothing that we can do about that.
// It will be shut down next time we run.

// TODO: on Macs, keep running even when last window is closed.

function onClose () {
    if (isFirstOrLastWindow()) {
        // This is the last main window closing down
//         runServerKiller();
        killServer();
    }
}

function isFirstOrLastWindow () {
    var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
        .getService(Components.interfaces.nsIWindowMediator);
    var enumerator = wm.getEnumerator("diogenes:main");
    var window_count = 0;
    while(enumerator.hasMoreElements()) {
        var win = enumerator.getNext();
        window_count++;
    }
    if (window_count == 1) {
        return true;
    }
    else {
        return false;
    }
}

function closeAllWindows () {
    var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
        .getService(Components.interfaces.nsIWindowMediator);
    var enumerator = wm.getEnumerator("diogenes:main");
    var window_count = 0;
    while(enumerator.hasMoreElements()) {
        var win = enumerator.getNext();
        win.close();
    }
    killServer();
}

// Couln't get findbar to work
function dioFind () {
    window.find("", false, false, false,
                false, true, true);
}

// for Venkman
function toOpenWindowByType(inType, uri) {
  var winopts = "chrome,extrachrome,menubar,resizable,scrollbars,status,toolbar";
  window.open(uri, "_blank", winopts);
}

var defaultSaveDir = null;
function saveAs () {

    var nsIFilePicker = Components.interfaces.nsIFilePicker;
    var fp = Components.classes["@mozilla.org/filepicker;1"]
        .createInstance(nsIFilePicker);
    fp.init(window, "Select a Location", nsIFilePicker.modeSave);
    fp.defaultString = "diogenes.html";
    if (defaultSaveDir) {fp.displayDirectory = defaultSaveDir}
    var rv = fp.show();
    if (rv != Components.interfaces.nsIFilePicker.returnCancel) {
        saveDoc(fp.file);
        defaultSaveDir = fp.file.parent;
    }
}

function saveDoc (file) {
    
    var persist = Components.classes["@mozilla.org/embedding/browser/nsWebBrowserPersist;1"]
        .createInstance(Components.interfaces.nsIWebBrowserPersist);
  
    persist.persistFlags = Components.interfaces.nsIWebBrowserPersist.PERSIST_FLAGS_REPLACE_EXISTING_FILES;
    persist.persistFlags |= Components.interfaces.nsIWebBrowserPersist.PERSIST_FLAGS_AUTODETECT_APPLY_CONVERSION;
    
    var browser = document.getElementById("browser");
    try {
        var rv= persist.saveDocument(browser.contentWindow.document, file, null, null, null, null);
    } catch (e) {alert(e);}
}

function printDoc () {
    
    var browser = document.getElementById("browser");
    browser.contentWindow.print();
}

var zoomFactor = 1.0;

function enlargeText () {
    zoomFactor = zoomFactor + 0.25;
    var browser = document.getElementById("browser");
    browser.markupDocumentViewer.textZoom = zoomFactor;
}

function reduceText () {
    zoomFactor = zoomFactor - 0.25;
    var browser = document.getElementById("browser");
    browser.markupDocumentViewer.textZoom = zoomFactor;
}

function browserOnLoad () {
    var browser = document.getElementById("browser");
    var err = browser.contentWindow.document.getElementById("database-error");
    if (err && !wentBack) {
        getDatabaseDirectory(err.getAttribute("type"), err.getAttribute("long-type"), true);
    }
    wentBack = false;
    
    var corpus = browser.contentWindow.document.getElementById("corpus_menu");
    var pref = getPrefCorpus();
    if (corpus) {
        for (var i=0; i<corpus.length; i++) {
            if (corpus.options[i].value == pref) {
                corpus.selectedIndex = i;
                break;
            }
        }
    }
    var action = browser.contentWindow.document.getElementById("action_menu");
    var pref = getPrefAction();
    if (action) {
        for (var i=0; i<action.length; i++) {
            if (action.options[i].value == pref) {
                action.selectedIndex = i;
                break;
            }
        }
    }
    var query = browser.contentWindow.document.getElementById("query_text");
    if (query) {
        query.focus();
    }
}

function getPrefCorpus () {
    // Will fail on first run
    try {
        var prefs = Components.classes["@mozilla.org/preferences-service;1"].
            getService(Components.interfaces.nsIPrefBranch);
        return prefs.getCharPref("diogenes.preferred.corpus");
    }
    catch (e) { return false; }
}
function getPrefAction () {
    // Will fail on first run
    try {
        var prefs = Components.classes["@mozilla.org/preferences-service;1"].
            getService(Components.interfaces.nsIPrefBranch);
        return prefs.getCharPref("diogenes.preferred.action");
    }
    catch (e) { return false; }
}

function setPrefCorpus (corpus) {
    var prefs = Components.classes["@mozilla.org/preferences-service;1"].
        getService(Components.interfaces.nsIPrefBranch);
    prefs.setCharPref("diogenes.preferred.corpus", corpus);
}
function setPrefAction (action) {
    var prefs = Components.classes["@mozilla.org/preferences-service;1"].
        getService(Components.interfaces.nsIPrefBranch);
    prefs.setCharPref("diogenes.preferred.action", action);
}

function maybeSetPrefCorpus () {
    var browser = document.getElementById("browser");
    var corpus = browser.contentWindow.document.getElementById("corpus_menu");
    if (corpus) {
        setPrefCorpus(corpus.options[corpus.selectedIndex].value);
    }
}
function maybeSetPrefAction () {
    var browser = document.getElementById("browser");
    var action = browser.contentWindow.document.getElementById("action_menu");
    if (action) {
        setPrefAction(action.options[action.selectedIndex].value);
    }
}
 
// wentBack is to avoid the situation where the user has entered a
// correct db location, and then uses the back key to come across the
// error page and so is prompted again.  The submit listener ensures
// that even after backtracking to the splash page when we go forward
// again we get propmted if it is a genuinely new database error.

function browserOnSubmit () {
    wentBack = false;
    maybeSetPrefCorpus();
    maybeSetPrefAction();
}

function setupEnv() {
    var environment = Components.classes["@mozilla.org/process/environment;1"].
        getService(Components.interfaces.nsIEnvironment);
    environment.set('Diogenes-Browser', 'yes');
    
    var appInfo = Components.classes["@mozilla.org/xre/app-info;1"]
        .getService(Components.interfaces.nsIXULAppInfo);
    environment.set('Xulrunner-version', appInfo.platformVersion);

    environment.set('Diogenes_Config_Dir', getSettingsDir());
}

function getDatabaseDirectory (type, longType, prompt) {
    if (prompt) {
        var prompts = Components.classes["@mozilla.org/embedcomp/prompt-service;1"]
            .getService(Components.interfaces.nsIPromptService);
        var ok = prompts.alert(window, "Database Error", 
"Database not found. You must give the location of the "+longType+" database."); 
    }
    var nsIFilePicker = Components.interfaces.nsIFilePicker;
    var fp = Components.classes["@mozilla.org/filepicker;1"]
        .createInstance(nsIFilePicker);
    fp.init(window, "Where is the " + type + " database?", nsIFilePicker.modeGetFolder);
    fp.appendFilter("authtab files", "authtab.dir");
    var rv = fp.show();
    if (rv != Components.interfaces.nsIFilePicker.returnCancel) {
        var authtab = new FileFactory(myAppendPath(fp.file.path, "authtab.dir"));
        if (authtab.exists() && authtab.isFile() && authtab.isReadable()) {
            saveDatabasePath(type, fp.file.path);
        } else {
            var prompts = Components.classes["@mozilla.org/embedcomp/prompt-service;1"]
                .getService(Components.interfaces.nsIPromptService);
            var ok = prompts.confirm(window, "Database Not Found", 
 "Error: No TLG/PHI/DDP database was found in the location you specified.  Click OK to try a new location.");
            if (ok) {
                getDatabaseDirectory (type, longType, false);
            }
        }
    }
}


function saveDatabasePath (type, path) {
    var type_key = type + '_dir';
    var file = new FileFactory(getSettingsFile());
    var oldLine = false, output = '';
    if (file.exists() && file.isFile() && file.isReadable) {
        var istream = Components.classes["@mozilla.org/network/file-input-stream;1"]
            .createInstance(Components.interfaces.nsIFileInputStream);
        istream.init(file, -1, 0664, 0);
        istream.QueryInterface(Components.interfaces.nsILineInputStream);
        
        var line = {}, hasmore = true;
        while (hasmore) {
            hasmore = istream.readLine(line);
            var re = new RegExp('^' + type_key);
            if (re.test(line.value)) {
                output += type_key + ' "' + path + '"' + "\n"; 
                hasline = true;
            }
            else {
                output += line.value + "\n"; 
            }
        }
        istream.close();
    }
    if (!oldLine) {
        output += type_key + ' "' + path + '"' + "\n";
    }
    try {
        var foStream = Components.classes["@mozilla.org/network/file-output-stream;1"]
            .createInstance(Components.interfaces.nsIFileOutputStream);
        foStream.init(file, 0x02 | 0x08 | 0x20, 0664, 0); // write, create, truncate
        foStream.write(output, output.length);
        foStream.close();
    }
    catch (e) {alert("Error: could not write to settings file ("+file.path+").  "+e)}

    
    // Resubmit (error page helpfully pretends to be the splash page)
    var browser = document.getElementById("browser");
    var form = browser.contentWindow.document.getElementById("form");
    form.submit();

}

function selectFont () {
    var enumerator = Components.classes["@mozilla.org/gfx/fontenumerator;1"]
        .createInstance(Components.interfaces.nsIFontEnumerator);
    var allFonts = enumerator.EnumerateAllFonts({});

    var prompts = Components.classes["@mozilla.org/embedcomp/prompt-service;1"]
        .getService(Components.interfaces.nsIPromptService);
    var selected = {};
    var ok = prompts.select(window, "Font Chooser", "Choose the font to use for Diogenes:", 
                        allFonts.length, allFonts, selected);
    if (ok) {
        var prefs = Components.classes["@mozilla.org/preferences-service;1"].
            getService(Components.interfaces.nsIPrefBranch);
        try {
            prefs.setCharPref("font.name.serif.x-western",allFonts[selected.value]);
        } catch (e) { alert (e); }
    }
}

function gotoSettings () {
    var browser = document.getElementById("browser");
    var port = get_port();
    browser.loadURI("http:127.0.0.1:" + port + "/Settings.cgi", null, null); 
}

function showAbout () {
        var prompts = Components.classes["@mozilla.org/embedcomp/prompt-service;1"]
            .getService(Components.interfaces.nsIPromptService);
        var ok = prompts.alert(window, "About Diogenes", 
                               "Diogenes is an application for searching and browsing databases in the fomat used by the Packard Humanities Institute and the Thesaurus Linguae Gracae. Diogenes is free software by P. J.Heslin.");

}

function quit (aForceQuit) {
  var appStartup = Components.classes['@mozilla.org/toolkit/app-startup;1'].
    getService(Components.interfaces.nsIAppStartup);

  // eAttemptQuit will try to close each XUL window, but the XUL window can cancel the quit
  // process if there is unsaved data. eForceQuit will quit no matter what.
  var quitSeverity = aForceQuit ? Components.interfaces.nsIAppStartup.eForceQuit :
                                  Components.interfaces.nsIAppStartup.eAttemptQuit;
  appStartup.quit(quitSeverity);
}

function quitDiogenes () {
    closeAllWindows();
    quit(true);
}

function quitHiddenDiogenes () {
    quit(true);
}

var shortcuts = new Object;
shortcuts['l'] = 'PHI Latin'; 
shortcuts['g'] = 'TLG Texts'; 
shortcuts['w'] = 'word_list'; 
shortcuts['d'] = 'Duke'; 
shortcuts['o'] = 'Coptic'; 
shortcuts['.'] = 'search'; 
shortcuts['u'] = 'multiple'; 
shortcuts['m'] = 'morphological'; 
shortcuts['b'] = 'browse'; 
shortcuts['c'] = 'filters'; 

function doShortcut(key) {
    var browser = document.getElementById("browser");
    var action = browser.contentWindow.document.getElementById("action_menu");
    var corpus = browser.contentWindow.document.getElementById("corpus_menu");
    if (action) {
        for (var i=0; i<action.length; i++) {
            if (action.options[i].value.indexOf(shortcuts[key]) != -1) {
                action.selectedIndex = i;
                break;
            }
        }
    }
    if (corpus) {
        for (var i=0; i<corpus.length; i++) {
            if (corpus.options[i].value.indexOf(shortcuts[key]) != -1) {
                corpus.selectedIndex = i;
                break;
            }
        }
    }
}

function showShortcuts () {
    var browser = document.getElementById("browser");
    var port = get_port();
    browser.loadURI("http:127.0.0.1:" + port + "/Shortcuts.html", null, null); 
}


function foo () {
}

