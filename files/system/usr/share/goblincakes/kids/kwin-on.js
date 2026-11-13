// GOBLINCAKES Barnläge (13 Nov): loaded by goblin-kids while Barnläge is on (kids.py lock), unloaded when it ends.
// Only Barnläge's own windows (goblin-kids), the games (steam_app_<id>, Proton .exe, gamescope) and the
// programs chosen in Config → BARNLÄGE may be seen: every other window is minimized (and told to goblin-kids,
// which puts them back afterwards with kwin-off.js). Barnläge's main window ("GOBLINCAKES barnläge") and the
// games are on the main screen (screenOrder[0], as the games always are); "GOBLINCAKES barnläge 2", "… 3"
// cover the other screens.
// Every action first asks goblin-kids whether Barnläge is still on (D-Bus "active"): if goblin-kids is gone
// (a crash) nothing is done any more – the parent's windows are never hidden by a script left behind.
const data = __DATA__;
const OWN = "goblin-kids";
const IFACE = "org.goblincakes.kids";

function low(v) { return String(v || "").toLowerCase(); }
function ours(w) { return low(w.resourceClass) === OWN || low(w.desktopFileName) === OWN; }
function game(w) {
    const c = low(w.resourceClass);
    return c.indexOf("steam_app_") === 0 || /\.exe$/.test(c) || c === "gamescope";
}
function allowed(w) {
    if (!w)
        return false;
    if (ours(w) || game(w))
        return true;
    const names = [w.desktopFileName, w.resourceClass, w.resourceName].map(function (n) {
        return low(n).replace(/\.desktop$/, "");
    });
    for (let i = 0; i < data.allowed.length; i++)
        if (names.indexOf(data.allowed[i]) >= 0)
            return true;
    return !!(w.transient && w.transientFor && w.transientFor !== w && allowed(w.transientFor));
}
// Windows a child could use: ordinary windows and dialogs (not panels, the desktop, notifications, OSDs)
function managed(w) {
    return !!w && (w.normalWindow || w.dialog) && !w.desktopWindow && !w.dock;
}
function screenFor(w) {
    const order = workspace.screenOrder;
    if (!order.length)
        return w.output;
    const m = /^GOBLINCAKES barnläge (\d+)$/.exec(String(w.caption));
    const n = m ? parseInt(m[1], 10) - 1 : 0;
    return order[Math.min(n, order.length - 1)];
}
function mainWindow() {
    const list = workspace.windowList();
    for (let i = 0; i < list.length; i++)
        if (ours(list[i]) && String(list[i].caption) === "GOBLINCAKES barnläge")
            return list[i];
    return null;
}

function whenOn(fn) {
    callDBus(data.service, "/kids", IFACE, "active", function (on) {
        if (on === true)
            fn();
    });
}

function hide(w) {
    if (!managed(w) || allowed(w) || w.minimized)
        return;
    w.minimized = true;
    callDBus(data.service, "/kids", IFACE, "hidden", String(w.internalId));
}

function place(w) {
    if (!managed(w))
        return;
    const target = screenFor(w);
    if (ours(w)) {
        if (target && w.output !== target)
            workspace.sendClientToScreen(w, target);
        if (!w.fullScreen)
            w.fullScreen = true;
        w.keepAbove = String(w.caption) !== "GOBLINCAKES barnläge";   // the covers over everything on their screens
        w.skipTaskbar = true;
        w.skipSwitcher = true;
        return;
    }
    if (w.minimized)
        w.minimized = false;
    // Over the panels (DockLayer) even when a game is in a window
    w.keepAbove = true;
    if (target && w.output !== target && !w.transient)
        workspace.sendClientToScreen(w, target);
    // A chosen program (not a game – they choose their own size) fills the screen
    if (!game(w) && w.normalWindow && !w.transient && w.fullScreenable && !w.fullScreen)
        w.fullScreen = true;
}

let lastPlay = null;   // the game or program last in front

whenOn(function () {
    const list = workspace.windowList();
    for (let i = 0; i < list.length; i++) {
        if (allowed(list[i]))
            place(list[i]);
        else
            hide(list[i]);
    }
});

workspace.windowAdded.connect(function (w) {
    whenOn(function () {
        if (allowed(w)) {
            place(w);
            if (!ours(w) && w.normalWindow)
                workspace.activeWindow = w;
        } else {
            hide(w);
        }
    });
    // Captions and classes can come a moment after the window
    if (w && ours(w))
        w.captionChanged.connect(function () { whenOn(function () { place(w); }); });
});

workspace.windowActivated.connect(function (w) {
    if (!w)
        return;
    whenOn(function () {
        if (!allowed(w)) {
            hide(w);
            const back = lastPlay || mainWindow();
            if (back)
                workspace.activeWindow = back;
            return;
        }
        if (ours(w) && String(w.caption) !== "GOBLINCAKES barnläge") {
            // A click on a cover screen: back to what he was doing
            const back = lastPlay || mainWindow();
            if (back && back !== w)
                workspace.activeWindow = back;
            return;
        }
        if (!ours(w) && w.normalWindow)
            lastPlay = w;
    });
});

workspace.windowRemoved.connect(function (w) {
    if (w !== lastPlay)
        return;
    lastPlay = null;
    whenOn(function () {
        const main = mainWindow();
        if (main)
            workspace.activeWindow = main;
    });
});
