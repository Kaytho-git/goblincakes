// GOBLINCAKES fönsterlayouter: loaded for a moment by /usr/libexec/goblincakes-tile (Config →
// Fönster, Meta+Ctrl+1–9, goblin tile layout). __DATA__ is replaced with:
//   {"mode": "apply", "screens": {connector: tree}, "rules": [{names, screen, tile}], "games", "service",
//    "desktop": the layout's own virtual desktop (number, 0 = the one shown now)}
//   {"mode": "capture", "games", "service"}
// A tree is {"dir": "h"|"v", "children": [{size, …}]} (h = side by side, size = part of the
// parent) or a tile {}. KWin can't reload its tiles from kwinrc, so they are rebuilt here with
// KDE's own tile API (split, resizeByPixels – the same as the tile editor, Meta+T); KWin saves them.
// Tiles are numbered as KDE keeps them: depth first, left to right, top to bottom.
const DATA = __DATA__;
const HORIZONTAL = 1, VERTICAL = 2;    // KWin::Tile::LayoutDirection
const RIGHT_EDGE = 4, BOTTOM_EDGE = 8;  // Qt::Edge

function leafTiles(tile) {
    const children = tile.tiles || [];
    if (!children.length)
        return [tile];
    let out = [];
    for (let i = 0; i < children.length; i++)
        out = out.concat(leafTiles(children[i]));
    return out;
}

function screenNamed(name) {
    for (let i = 0; i < workspace.screens.length; i++)
        if (workspace.screens[i].name === name)
            return workspace.screens[i];
    return null;
}

function rootOf(screen) {
    const manager = screen ? workspace.tilingForScreen(screen) : null;
    return manager ? manager.rootTile : null;
}

function names(window) {
    return [window.desktopFileName, window.resourceClass, window.resourceName]
        .map(function (n) { return String(n || "").toLowerCase(); });
}

function isGame(window) {
    const cls = String(window.resourceClass || "").toLowerCase();
    return (DATA.games || []).indexOf(cls) >= 0 || cls.indexOf("steam_app_") === 0 || /\.exe$/.test(cls);
}

function ordinary(window) {
    return window.normalWindow && !window.transient && !isGame(window);
}

// ── Building ────────────────────────────────────────────────────

function clear(root) {
    for (let guard = 0; guard < 64 && root.tiles.length; guard++)
        root.tiles[root.tiles.length - 1].remove();
}

// The children's sizes: each border moved to its place, left to right (top to bottom)
function sizeChildren(tile, node, horizontal) {
    const g = tile.absoluteGeometry;
    const total = horizontal ? g.width : g.height;
    let edge = horizontal ? g.x : g.y;
    const kids = tile.tiles;
    for (let i = 0; i < kids.length - 1 && i < node.children.length - 1; i++) {
        edge += total * node.children[i].size;
        const cg = kids[i].absoluteGeometry;
        const now = horizontal ? cg.x + cg.width : cg.y + cg.height;
        const delta = edge - now;
        if (Math.abs(delta) >= 1)
            kids[i].resizeByPixels(delta, horizontal ? RIGHT_EDGE : BOTTOM_EDGE);
    }
}

function build(tile, node) {
    const kids = node.children || [];
    if (kids.length < 2)
        return;
    const dir = node.dir === "v" ? VERTICAL : HORIZONTAL;
    // The root, or a tile in a layout of the other direction: split = two tiles inside it
    tile.split(dir);
    // Splitting the last one in the same direction adds one more beside it
    for (let guard = 0; tile.tiles.length < kids.length && guard < 16; guard++)
        tile.tiles[tile.tiles.length - 1].split(dir);
    sizeChildren(tile, node, dir === HORIZONTAL);
    for (let i = 0; i < kids.length && i < tile.tiles.length; i++)
        build(tile.tiles[i], kids[i]);
}

function putInTile(window, tile) {
    const old = window.tile;
    if (old && old !== tile && typeof old.unmanage === "function")
        old.unmanage(window);
    if (typeof tile.manage === "function")
        tile.manage(window);
    else
        window.tile = tile;
}

function apply() {
    // A layout with its own desktop: go there first – KWin keeps tiles per desktop, and a
    // script builds them on the desktop shown (goblincakes-tile has made the desktop)
    const desk = DATA.desktop > 0 ? workspace.desktops[DATA.desktop - 1] : null;
    if (desk && workspace.currentDesktop !== desk)
        workspace.currentDesktop = desk;
    const screens = DATA.screens || {};
    for (const name in screens) {
        const root = rootOf(screenNamed(name));
        if (!root)
            continue;  // that screen isn't connected now
        clear(root);
        build(root, screens[name]);
    }
    // Open windows into their tiles
    const rules = DATA.rules || [];
    const list = workspace.windowList();
    for (let i = 0; i < list.length; i++) {
        const w = list[i];
        if (!ordinary(w))
            continue;
        const n = names(w);
        for (let r = 0; r < rules.length; r++) {
            if (!rules[r].names.some(function (x) { return x && n.indexOf(x) >= 0; }))
                continue;
            const root = rootOf(screenNamed(rules[r].screen));
            const tiles = root ? leafTiles(root) : [];
            if (rules[r].tile >= 1 && rules[r].tile <= tiles.length) {
                if (desk && !w.onAllDesktops)
                    w.desktops = [desk];
                putInTile(w, tiles[rules[r].tile - 1]);
            }
            break;
        }
    }
}

// ── Reading (Config: "Spara som det ser ut nu") ─────────────────

function treeOf(tile) {
    const kids = tile.tiles || [];
    if (!kids.length) {
        const wins = tile.windows || [];
        const out = [];
        for (let i = 0; i < wins.length; i++)
            if (ordinary(wins[i]))
                out.push(names(wins[i]));
        return { windows: out };
    }
    const horizontal = tile.layoutDirection !== VERTICAL;
    const g = tile.absoluteGeometry;
    const total = (horizontal ? g.width : g.height) || 1;
    const children = [];
    for (let i = 0; i < kids.length; i++) {
        const cg = kids[i].absoluteGeometry;
        const child = treeOf(kids[i]);
        child.size = (horizontal ? cg.width : cg.height) / total;
        children.push(child);
    }
    return { dir: horizontal ? "h" : "v", children: children };
}

function running() {
    const out = [];
    const list = workspace.windowList();
    for (let i = 0; i < list.length; i++)
        if (ordinary(list[i]))
            out.push(names(list[i]));
    return out;
}

let report = { running: [] };
try {
    if (DATA.mode === "apply")
        apply();
    if (DATA.mode === "capture") {
        report.screens = {};
        for (let i = 0; i < workspace.screens.length; i++) {
            const root = rootOf(workspace.screens[i]);
            if (root)
                report.screens[workspace.screens[i].name] = treeOf(root);
        }
    }
    report.running = running();
} catch (e) {
    report.error = String(e);
}
callDBus(DATA.service, "/tile", "org.goblincakes.tile", "report", JSON.stringify(report));
