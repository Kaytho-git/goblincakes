// GOBLINCAKES Dashboard: the open windows (ÖPPNA PROGRAM). Loaded for a moment by goblin-dashboard.
// __DATA__ is replaced with {"mode": "list", "service"} or {"mode": "activate", "service", "id": internalId};
// it answers with report(JSON) on the service's /win.
const DATA = __DATA__;

function windows() {
    // topmost first (stackingOrder is bottom → top); the dashboard itself is not a program to switch to
    const order = workspace.stackingOrder;
    const out = [];
    for (let i = order.length - 1; i >= 0; i--) {
        const w = order[i];
        if (w.normalWindow && !w.skipTaskbar && w.desktopFileName !== "goblin-dashboard"
                && w.resourceClass !== "goblin-dashboard")
            out.push(w);
    }
    return out;
}

let answer = {};
if (DATA.mode === "list") {
    answer.windows = windows().map(function (w) {
        return {"id": String(w.internalId), "caption": w.caption, "app": w.resourceClass,
                "desktop": w.desktopFileName, "min": w.minimized};
    });
} else if (DATA.mode === "activate") {
    const all = windows();
    for (let i = 0; i < all.length; i++) {
        if (String(all[i].internalId) === DATA.id) {
            all[i].minimized = false;
            workspace.activeWindow = all[i];
            answer.ok = true;
        }
    }
}
callDBus(DATA.service, "/win", "org.goblincakes.win", "report", JSON.stringify(answer));
