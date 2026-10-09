// GOBLINCAKES (KWin script, loaded by `goblincakes-dock toggle` = the Meta key): bring up the dock.
// Uses Plasma's own "move keyboard focus between panels": the hidden dock comes up with the focus
// and Plasma hides it again by itself when anything else is clicked – like the Start menu.
// That shortcut steps through the panels one at a time (top bar, dock, back to the window), so
// when the top bar gets the focus, step once more. Pressed while the dock is up, the focus moves
// on and the dock hides.
var steps = 0;

function step() {
    callDBus("org.kde.kglobalaccel", "/component/plasmashell", "org.kde.kglobalaccel.Component",
             "invokeShortcut", "cycle-panels");
}

function isDock(w) {
    if (!w || !w.dock)
        return false;
    var area = workspace.clientArea(KWin.FullScreenArea, w.output, workspace.currentDesktop);
    return w.frameGeometry.y + w.frameGeometry.height / 2 > area.y + area.height / 2;
}

function activated(w) {
    if (w && w.dock && !isDock(w) && ++steps < 3) {
        step();  // the top bar: on to the dock
        return;
    }
    workspace.windowActivated.disconnect(activated);  // the dock, or back to a window
}

workspace.windowActivated.connect(activated);
step();
