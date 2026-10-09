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
// Start menu, the desktop takes the focus while the dock is shown – then the next click
// on any window is an activation. (Panels can't take the focus: trying stopped the script.)
var windows = workspace.windowList();
var desktop = null;  // the desktop on the active screen, otherwise any
for (var i = 0; i < windows.length; i++) {
    if (windows[i].desktopWindow && (!desktop || windows[i].output === workspace.activeScreen))
        desktop = windows[i];
}
if (desktop)
    workspace.activeWindow = desktop;

workspace.windowActivated.connect(hide);
