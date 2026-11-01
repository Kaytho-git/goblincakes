// Goblin AI's TERMINAL tab (1 Nov): xterm.js (terminal/index.html) in a web view, the shells in ptyterm.py.
// Its own file, loaded by Main.qml's Loader the first time the tab opens – without QtWebEngine the rest
// of the window still works.
import QtQuick
import QtWebEngine
import QtWebChannel

Item {
    id: root
    function show(sid) { web.runJavaScript("show(" + sid + ")"); web.forceActiveFocus(); }
    function focusWeb() { web.forceActiveFocus(); }
    function focusTerminal() { web.forceActiveFocus(); web.runJavaScript("focusCurrent()"); }

    WebChannel {
        id: channel
        Component.onCompleted: registerObject("terms", terminals)
    }
    WebEngineView {
        id: web
        // Main.qml's zoomRoot enlarges everything 1–1.3× as a picture: the web view would be stretched (blurry,
        // half-redrawn rows on the real screen 1 Nov). Undone here – one pixel per pixel, the text bigger instead.
        width: root.width * zoomRoot.zoom
        height: root.height * zoomRoot.zoom
        scale: 1 / zoomRoot.zoom
        transformOrigin: Item.TopLeft
        backgroundColor: "#0B1018"
        webChannel: channel
        settings.focusOnNavigationEnabled: true
        // Set once: a reload would lose the tabs' screens (the shells live on in ptyterm.py)
        Component.onCompleted: url = Qt.resolvedUrl("terminal/index.html") + "?accent=" + encodeURIComponent(accent.color)
                                     + "&size=" + Math.round(13 * zoomRoot.zoom)
        onContextMenuRequested: request => request.accepted = true  // the page's own right click (copy/paste)
        onNewWindowRequested: request => Qt.openUrlExternally(request.requestedUrl)
        onNavigationRequested: request => {
            if (request.url.toString().indexOf("terminal/index.html") < 0) {  // never leave the page
                request.reject();
                Qt.openUrlExternally(request.url);
            }
        }
        onLoadingChanged: info => { if (info.status === WebEngineLoadingInfo.LoadSucceededStatus) root.focusTerminal(); }
    }
}
