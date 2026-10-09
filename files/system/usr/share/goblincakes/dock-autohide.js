// GOBLINCAKES (KWin script): the dock was shown with the Meta key – hide it again as
// soon as something else is clicked (a window, the desktop) or an app is started from
// the dock, like the Start menu in Windows. Loaded by `goblincakes-dock toggle`.
var hideDock = 'panels().forEach(function (p) { if (p.location === "bottom") p.hiding = "dodgewindows"; });';

function hide() {
    workspace.windowActivated.disconnect(hide);
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", hideDock);
}

// Clicking the window that is already active changes nothing for KWin (no signal), so
// the dock stayed up when Firefox was active and Firefox was clicked (9 Oct). Like the
// Start menu, the dock takes the focus while it is shown: the dock itself if KWin lets
// it, otherwise the desktop – then the next click on any window is an activation.
var before = workspace.activeWindow;
var windows = workspace.windowList();
var screen = before ? before.output : workspace.activeScreen;
var dock = null;  // the lowest panel on this screen (the top bar is a dock window too)
for (var i = 0; i < windows.length; i++) {
    var w = windows[i];
    if (w.dock && w.output === screen && (!dock || w.frameGeometry.y > dock.frameGeometry.y))
        dock = w;
}
if (dock)
    workspace.activeWindow = dock;
for (var j = 0; j < windows.length && workspace.activeWindow === before; j++) {
    if (windows[j].desktopWindow && windows[j].output === screen)
        workspace.activeWindow = windows[j];
}

workspace.windowActivated.connect(hide);
