// GOBLINCAKES (KWin script, loaded by `goblincakes-dock toggle` = the Meta key): show or hide the dock.
// The dock "dodges windows": in Plasma 6 it hides only behind the *active* window. So the Meta
// key makes the desktop active – nothing active covers the dock, it comes up – and clicking a
// window makes that one active and the dock hides again, like the Start menu. Pressed again
// while the desktop is active, the focus goes back to the topmost window on the screen.
var screen = workspace.activeScreen;
var active = workspace.activeWindow;
var windows = workspace.stackingOrder;  // bottom to top

if (active && active.desktopWindow) {
    for (var i = windows.length - 1; i >= 0; i--) {
        var w = windows[i];
        if (w.normalWindow && !w.minimized && !w.skipTaskbar && w.output === screen) {
            workspace.activeWindow = w;
            break;
        }
    }
} else {
    for (var j = 0; j < windows.length; j++) {
        if (windows[j].desktopWindow && windows[j].output === screen) {
            workspace.activeWindow = windows[j];
            break;
        }
    }
}
