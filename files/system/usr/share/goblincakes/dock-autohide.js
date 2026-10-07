// GOBLINCAKES (KWin script): the dock was shown with the Meta key – hide it again as
// soon as something else is clicked (a window, the desktop) or an app is started from
// the dock, like the Start menu in Windows. Loaded by `goblincakes-dock toggle`.
var hideDock = 'panels().forEach(function (p) { if (p.location === "bottom") p.hiding = "dodgewindows"; });';

function hide() {
    workspace.windowActivated.disconnect(hide);
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", hideDock);
}

workspace.windowActivated.connect(hide);
