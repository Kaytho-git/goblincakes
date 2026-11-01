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
        anchors.fill: parent
        backgroundColor: "#0B1018"
        // The web view ignores QT_SCALE_FACTOR (0.8): without this the right fifth was cut off (provat offscreen)
        zoomFactor: uiScale
        webChannel: channel
        settings.focusOnNavigationEnabled: true
        // Set once: a reload would lose the tabs' screens (the shells live on in ptyterm.py)
        Component.onCompleted: url = Qt.resolvedUrl("terminal/index.html") + "?accent=" + encodeURIComponent(accent.color)
                                     + "&size=" + Math.round(13 / uiScale)  // 13 px on the screen
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
