// GOBLINCAKES (KWin script, loaded by `goblincakes-dock toggle` = the Meta key): show or hide the dock.
// The dock "dodges windows": in Plasma 6 it hides only behind the *active* window. So the Meta
// key makes the desktop active – nothing active covers the dock, it comes up – and clicking a
// window makes that one active and the dock hides again, like the Start menu. Pressed again
// while the desktop is active, the focus goes back to the topmost window.
// (Window outputs are compared by name: comparing the objects found nothing, 9 Oct.)
function onScreen(w) {
    return !workspace.activeScreen || !w.output || w.output.name === workspace.activeScreen.name;
}

var active = workspace.activeWindow;
var windows = workspace.stackingOrder;  // bottom to top
var target = null;

if (active && active.desktopWindow) {
    for (var i = windows.length - 1; i >= 0 && !target; i--) {
        var w = windows[i];
        if (w.normalWindow && !w.minimized && !w.skipTaskbar && onScreen(w))
            target = w;
    }
} else {
    for (var j = 0; j < windows.length; j++) {
        if (windows[j].desktopWindow && (!target || onScreen(windows[j])))
            target = windows[j];
    }
}

if (target)
    workspace.activeWindow = target;
