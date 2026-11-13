// GOBLINCAKES Barnläge ends (kids.py restore): the windows kwin-on.js minimized come back, and games or
// programs still open lose "keep above". Loaded for a moment and unloaded again.
const data = __DATA__;

function low(v) { return String(v || "").toLowerCase(); }
function played(w) {
    const c = low(w.resourceClass);
    if (c.indexOf("steam_app_") === 0 || /\.exe$/.test(c) || c === "gamescope")
        return true;
    const names = [w.desktopFileName, w.resourceClass, w.resourceName].map(function (n) {
        return low(n).replace(/\.desktop$/, "");
    });
    return data.allowed.some(function (a) { return names.indexOf(a) >= 0; });
}

const list = workspace.windowList();
let last = null;
for (let i = 0; i < list.length; i++) {
    const w = list[i];
    if (data.hidden.indexOf(String(w.internalId)) >= 0 && w.minimized) {
        w.minimized = false;
        last = w;
    }
    if (played(w) && w.keepAbove)
        w.keepAbove = false;
}
if (last)
    workspace.activeWindow = last;
