// Goblin AI's windows (point 5 of Kakan's plan, 28 Oct): loaded for a moment by desktop.py (fönster …).
// __DATA__ is replaced with:
//   {"mode": "list", "service"}
//   {"mode": "do", "service", "match": words, "screen": connector or "", "actions": ["fram", "maximera", …]}
//   {"mode": "find", "service", "match": words} – only which window it would be
//   {"mode": "close", "service", "id": internalId} – after the user's Tillåt
//   {"mode": "restore", "service", "id": internalId, "before": {screen, x, y, w, h, max, full, min}}
// It answers with report(JSON) on the service's /win.
const DATA = __DATA__;

function norm(text) {
    return String(text || "").toLowerCase().replace(/[^a-z0-9åäö]+/g, "");
}

function windows() {
    // topmost first (stackingOrder is bottom → top)
    const order = workspace.stackingOrder;
    const out = [];
    for (let i = order.length - 1; i >= 0; i--) {
        const w = order[i];
        if (w.normalWindow && !w.skipTaskbar)
            out.push(w);
    }
    return out;
}

function screenNamed(name) {
    for (let i = 0; i < workspace.screens.length; i++)
        if (workspace.screens[i].name === name)
            return workspace.screens[i];
    return null;
}

function state(w) {
    const g = w.frameGeometry;
    const area = workspace.clientArea(KWin.MaximizeArea, w);
    return {"screen": w.output ? w.output.name : "", "x": g.x, "y": g.y, "w": g.width, "h": g.height,
            "max": g.width >= area.width - 2 && g.height >= area.height - 2 && !w.fullScreen,
            "full": w.fullScreen, "min": w.minimized};
}

function describe(w) {
    return {"id": String(w.internalId), "caption": w.caption, "app": w.resourceClass, "desktop": w.desktopFileName,
            "pid": w.pid,
            "state": state(w), "active": workspace.activeWindow === w};
}

// The window the words mean: its program's own name (desktop file/class) before a word in the title
function find(words) {
    const want = norm(words);
    let best = null, bestScore = 0;
    const all = windows();
    for (let i = 0; i < all.length; i++) {
        const w = all[i];
        const ids = [norm(w.desktopFileName), norm(w.resourceClass), norm(w.resourceName)];
        const title = norm(w.caption);
        let score = 0;
        if (ids.indexOf(want) >= 0)
            score = 4;
        else if (ids.some(function (n) { return n && (n.indexOf(want) >= 0 || want.indexOf(n) >= 0 && n.length > 3); }))
            score = 3;
        else if (title.indexOf(want) >= 0)
            score = 2;
        if (score > bestScore) {   // ties: the topmost (first) one stays
            best = w;
            bestScore = score;
        }
    }
    return best;
}

function byId(id) {
    const all = windows();
    for (let i = 0; i < all.length; i++)
        if (String(all[i].internalId) === id)
            return all[i];
    return null;
}

function apply(w, actions, screen) {
    for (let i = 0; i < actions.length; i++) {
        const a = actions[i];
        if (a === "normal") {
            w.fullScreen = false;
            w.setMaximize(false, false);
            w.minimized = false;
        } else if (a === "minimera") {
            w.minimized = true;
        } else if (a === "maximera") {
            w.fullScreen = false;
            w.minimized = false;
            w.setMaximize(true, true);
        } else if (a === "fullskärm") {
            w.minimized = false;
            w.fullScreen = true;
        } else if (a === "fram") {
            w.minimized = false;
            workspace.activeWindow = w;
        }
    }
    if (screen) {
        const was = state(w);
        const out = screenNamed(screen);
        if (out && w.output !== out) {   // full screen/maximized: out of it for the move, then back
            if (was.full)
                w.fullScreen = false;
            if (was.max)
                w.setMaximize(false, false);
            workspace.sendClientToScreen(w, out);
            if (was.max)
                w.setMaximize(true, true);
            if (was.full)
                w.fullScreen = true;
        }
    }
    if (actions.indexOf("minimera") < 0) {
        w.minimized = false;
        workspace.activeWindow = w;
    }
}

let report = {};
if (DATA.mode === "list") {
    report.windows = windows().map(describe);
} else if (DATA.mode === "do") {
    const w = find(DATA.match);
    if (w) {
        report.before = describe(w);
        apply(w, DATA.actions || [], DATA.screen || "");
        report.after = describe(w);
    }
    report.windows = windows().map(function (x) { return x.caption + " (" + (x.desktopFileName || x.resourceClass) + ")"; });
} else if (DATA.mode === "find") {
    const w = find(DATA.match);
    if (w)
        report.before = describe(w);
    report.windows = windows().map(function (x) { return x.caption + " (" + (x.desktopFileName || x.resourceClass) + ")"; });
} else if (DATA.mode === "close") {
    const w = byId(DATA.id);
    if (w)
        w.closeWindow();
} else if (DATA.mode === "restore") {
    const w = byId(DATA.id);
    if (w) {
        const b = DATA.before;
        w.fullScreen = false;
        w.setMaximize(false, false);
        const out = screenNamed(b.screen);
        if (out && w.output !== out)
            workspace.sendClientToScreen(w, out);
        w.frameGeometry = {"x": b.x, "y": b.y, "width": b.w, "height": b.h};
        if (b.max)
            w.setMaximize(true, true);
        if (b.full)
            w.fullScreen = true;
        w.minimized = b.min;
        report.after = describe(w);
    }
}
callDBus(DATA.service, "/win", "org.goblincakes.win", "report", JSON.stringify(report));
