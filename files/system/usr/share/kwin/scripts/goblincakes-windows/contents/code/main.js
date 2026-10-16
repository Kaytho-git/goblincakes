// GOBLINCAKES Config opens in the middle of the main screen (the first in Display settings'
// priority order), not on the screen you happen to be on or down by the dock while the panels
// and screens are still being set up at login (10 Oct).
const CENTERED = ["goblincakes-config"];

// Games always start on the main screen too (10 Oct): KWin otherwise places new windows on the
// screen under the mouse, and gamescope's --display-index only works without a desktop.
// Steam games (Proton/XWayland) are steam_app_<id>, Wine games <name>.exe, gamescope's window
// is gamescope; native games have their own class – add them to GAMES.
const GAMES = ["gamescope", "cs2", "dota2"];

// The user's own rules (goblin screen add discord screen 2, 11 Oct): kwinrc
// [Script-goblincakes-windows] screenRules = "discord=2;org.mozilla.firefox|firefox=1".
// Screen 1 = the main screen, then the order in Display settings (screenOrder). Read at every
// new window, so a new rule works at once (goblin screen asks KWin to reread kwinrc).
function ruleScreen(window) {
    const names = [window.desktopFileName, window.resourceClass, window.resourceName]
        .map(function (n) { return String(n || "").toLowerCase(); });
    const rules = String(readConfig("screenRules", "")).split(";");
    for (let i = 0; i < rules.length; i++) {
        const parts = rules[i].split("=");
        const number = parseInt(parts[1], 10);
        const matches = parts[0].split("|").some(function (n) { return n && names.indexOf(n) >= 0; });
        if (matches && number >= 1 && number <= workspace.screenOrder.length)
            return workspace.screenOrder[number - 1];
    }
    return null;
}

// Tiles (goblin tile add discord 2 1, 12 Oct): kwinrc [Script-goblincakes-windows] tileRules =
// "discord=DP-1:1;org.mozilla.firefox|firefox=HDMI-A-1:2" – the screen by connector (so a
// new main screen doesn't move the layout) and the tile's number among KDE's own tiles
// (Meta+T), in KDE's order: left to right, a split tile's parts top to bottom. Goes before a
// screen rule; games, dialogs and windows without a rule are left alone.
function leafTiles(tile) {
    const children = tile.tiles || [];
    if (!children.length)
        return [tile];
    let out = [];
    for (let i = 0; i < children.length; i++)
        out = out.concat(leafTiles(children[i]));
    return out;
}

// A third part "…:3:2" = the layout's own virtual desktop (15 Oct, Config → Fönster → Eget
// skrivbord): the window goes to that desktop and its tile there.
function ruleTile(window) {
    if (!tilesOn())
        return null;
    const names = [window.desktopFileName, window.resourceClass, window.resourceName]
        .map(function (n) { return String(n || "").toLowerCase(); });
    const rules = String(readConfig("tileRules", "")).split(";");
    for (let i = 0; i < rules.length; i++) {
        const parts = rules[i].split("=");
        const matches = parts[0].split("|").some(function (n) { return n && names.indexOf(n) >= 0; });
        if (!matches || !parts[1])
            continue;
        const place = parts[1].split(":");
        const screen = workspace.screens.find(function (s) { return s.name === place[0]; });
        const number = parseInt(place[1], 10);
        const desk = parseInt(place[2], 10);
        if (!screen || !(number >= 1))
            return null;
        return { screen: screen, number: number,
                 desktop: desk >= 1 && desk <= workspace.desktops.length ? workspace.desktops[desk - 1] : null };
    }
    return null;
}

// The root tile of a screen on a desktop: KWin 6.8 has workspace.rootTile(screen, desktop);
// 6.7 only the desktop shown (another desktop = null, the window waits until it is shown)
function rootOf(screen, desktop) {
    if (!screen)
        return null;
    if (desktop && desktop !== workspace.currentDesktop)
        return typeof workspace.rootTile === "function" ? workspace.rootTile(screen, desktop) : null;
    const manager = workspace.tilingForScreen(screen);
    return manager ? manager.rootTile : null;
}

function tileFor(rule) {
    const root = rootOf(rule.screen, rule.desktop);
    const tiles = root ? leafTiles(root) : [];
    return rule.number <= tiles.length ? tiles[rule.number - 1] : null;
}

const waiting = [];  // [{window, rule}] – to be tiled when their desktop is shown (KWin 6.7)
workspace.currentDesktopChanged.connect(function () {
    for (let i = waiting.length - 1; i >= 0; i--) {
        const w = waiting[i];
        if (w.rule.desktop !== workspace.currentDesktop)
            continue;
        waiting.splice(i, 1);
        const tile = tileFor(w.rule);
        if (tile && w.window.desktops && w.window.desktops.indexOf(w.rule.desktop) >= 0)
            toTile(w.window, tile);
    }
});

// Into the tile – and back again during the first seconds, while programs like Chromium,
// Discord and Steam restore the size they had last time (not while you drag it yourself).
// KWin keeps such a window marked as tiled, so the size is compared with the tile's.
// tile.manage() since KWin 6.7 (writing window.tile is deprecated); the old way as a fallback
// Programs have a smallest size (Spotify 800×600, Discord 800×500). In a smaller tile KWin can't
// shrink the window, so it spilled over the next tile – or onto the next screen at a screen's
// edge (15 Oct, the user's bug). The tile grows toward its neighbour instead, never past the
// screen's edge (KWin keeps every tile ≥ 15 % of its layout, so a far too big window can still
// stick out). Same code in goblincakes/tile/apply.js – change both.
const EDGE = { top: 1, left: 2, right: 4, bottom: 8 };  // Qt::Edge
function growTile(tile, horizontal, need) {
    // the nearest tile (itself or a parent) that sits in a row (horizontal) or column (vertical)
    for (let node = tile; node && node.parent; node = node.parent) {
        const parent = node.parent;
        const kids = parent.tiles || [];
        if (parent.layoutDirection !== (horizontal ? 1 : 2) || kids.length < 2)
            continue;
        let i = 0;
        while (i < kids.length && kids[i] !== node)
            i++;
        if (i >= kids.length)
            return;
        const size = function (t) { return horizontal ? t.absoluteGeometry.width : t.absoluteGeometry.height; };
        // into the neighbour: the only one at the screen's edge, otherwise the bigger one
        const towardStart = i === kids.length - 1 || (i > 0 && size(kids[i - 1]) > size(kids[i + 1]));
        if (towardStart)
            node.resizeByPixels(-need, horizontal ? EDGE.left : EDGE.top);
        else
            node.resizeByPixels(need, horizontal ? EDGE.right : EDGE.bottom);
        return;
    }
}

function fitTileToWindow(window, tile) {
    const min = window.minSize;
    if (!min || typeof tile.resizeByPixels !== "function")
        return;
    // the smallest size is the program's own area; the title bar and border come on top (8×42 px)
    const frame = window.frameGeometry, client = window.clientGeometry || frame;
    const pad = tile.padding || 0;
    const geo = tile.absoluteGeometry;
    const needWidth = Math.ceil(min.width + frame.width - client.width + 2 * pad - geo.width);
    const needHeight = Math.ceil(min.height + frame.height - client.height + 2 * pad - geo.height);
    if (needWidth > 0)
        growTile(tile, true, needWidth);
    if (needHeight > 0)
        growTile(tile, false, needHeight);
}

function putInTile(window, tile) {
    fitTileToWindow(window, tile);
    const old = window.tile;
    if (old && old !== tile && typeof old.unmanage === "function")
        old.unmanage(window);
    if (typeof tile.manage === "function")
        tile.manage(window);
    else
        window.tile = tile;
}

function toTile(window, tile) {
    putInTile(window, tile);
    const start = Date.now();
    window.frameGeometryChanged.connect(function () {
        if (Date.now() - start > 8000 || window.move || window.resize || window.fullScreen)
            return;
        if ((window.tile && window.tile !== tile) || floating[idOf(window)])
            return;  // moved to another tile (dragged, swapped) or taken out – leave it
        // the tile's own size; the window sits inside it by the padding (half at inner edges)
        const want = tile.absoluteGeometry;
        const geo = window.frameGeometry;
        const slack = 2 * (tile.padding || 0) + 2;
        if (Math.abs(geo.x - want.x) > slack || Math.abs(geo.y - want.y) > slack
                || Math.abs(geo.width - want.width) > slack || Math.abs(geo.height - want.height) > slack) {
            if (typeof tile.unmanage === "function")
                tile.unmanage(window);
            else
                window.tile = null;
            putInTile(window, tile);
        }
    });
}

function mainScreen(window) {
    return workspace.screenOrder.length ? workspace.screenOrder[0] : window.output;
}

function isGame(window) {
    const cls = String(window.resourceClass || "").toLowerCase();
    return window.normalWindow && (GAMES.indexOf(cls) >= 0 || cls.indexOf("steam_app_") === 0
        || /\.exe$/.test(cls));
}

function toMainScreen(window) {
    const screen = mainScreen(window);
    if (window.output !== screen)
        workspace.sendClientToScreen(window, screen);
}

function center(window) {
    const screen = mainScreen(window);
    const area = workspace.clientArea(KWin.PlacementArea, screen, workspace.currentDesktop);
    const geo = window.frameGeometry;
    window.frameGeometry = {
        x: Math.round(area.x + Math.max(0, (area.width - geo.width) / 2)),
        y: Math.round(area.y + Math.max(0, (area.height - geo.height) / 2)),
        width: geo.width,
        height: geo.height
    };
}

// Web apps (Config's streaming services and own web apps, 11 Oct): Chromium's app windows
// open taller than the screen (the user's 1080p screen). They are kept within the screen's
// free area (without the panels): when they open, and while Chromium restores its saved size
// during the first seconds. chrome-<address>__-Default, also Chromium's and Brave's.
function isWebapp(window) {
    return window.normalWindow && /^(chrome|chromium|brave)-.+__/i.test(String(window.resourceClass || ""));
}

// "Helskärm" on a web app in GOBLINCAKES Config (11 Oct): kwinrc [Script-goblincakes-windows]
// fullscreenApps = "chrome-claude.ai__-default;…" (window classes, lower case), read at every
// new window. Chromium's own --start-fullscreen counts for the whole browser, not one web app.
function wantsFullscreen(window) {
    const cls = String(window.resourceClass || "").toLowerCase();
    return String(readConfig("fullscreenApps", "")).split(";").indexOf(cls) >= 0;
}

function fit(window) {
    if (window.fullScreen || window.maximizeMode)
        return;
    const area = workspace.clientArea(KWin.PlacementArea, window.output, workspace.currentDesktop);
    const geo = window.frameGeometry;
    const width = Math.min(geo.width, area.width);
    const height = Math.min(geo.height, area.height);
    const x = Math.max(area.x, Math.min(geo.x, area.x + area.width - width));
    const y = Math.max(area.y, Math.min(geo.y, area.y + area.height - height));
    if (x !== geo.x || y !== geo.y || width !== geo.width || height !== geo.height)
        window.frameGeometry = { x: x, y: y, width: width, height: height };
}

// goblin graph (12 Oct): on Wayland a window can't know or choose where it is, so KWin keeps
// its place. After a move the script tells goblin-graph (D-Bus org.goblincakes.graph), which
// stores it in kwinrc [Script-goblincakes-windows] graphPlace = "wide=x,y;round=x,y" (bars
// and oscilloscope / circle and explosion, the window's two shapes) and asks KWin to reread.
const GRAPH = "goblin-graph";

function graphShape(window) {
    const geo = window.frameGeometry;
    return Math.abs(geo.width - geo.height) <= 2 ? "round" : "wide";
}

function graphPlace(window) {
    const shape = graphShape(window);
    const places = String(readConfig("graphPlace", "")).split(";");
    for (let i = 0; i < places.length; i++) {
        const parts = places[i].split("=");
        if (parts[0] !== shape || !parts[1])
            continue;
        const xy = parts[1].split(",").map(Number);
        const geo = window.frameGeometry;
        // only on a screen that is still there
        const onScreen = workspace.screens.some(function (s) {
            const g = s.geometry;
            return xy[0] + geo.width / 2 >= g.x && xy[0] + geo.width / 2 < g.x + g.width
                && xy[1] + geo.height / 2 >= g.y && xy[1] + geo.height / 2 < g.y + g.height;
        });
        if (onScreen && (xy[0] !== geo.x || xy[1] !== geo.y))
            window.frameGeometry = { x: xy[0], y: xy[1], width: geo.width, height: geo.height };
        return;
    }
}

function graphAdded(window) {
    // In the system tray, not among the programs (12 Oct, the user's wish)
    window.skipTaskbar = true;
    window.skipSwitcher = true;
    window.skipPager = true;
    graphPlace(window);
    let shape = graphShape(window);
    window.interactiveMoveResizeFinished.connect(function () {
        const geo = window.frameGeometry;
        callDBus("org.goblincakes.graph", "/graph", "org.goblincakes.graph", "placed",
                 graphShape(window) + "=" + Math.round(geo.x) + "," + Math.round(geo.y));
    });
    // A new view with the other shape (double-click): to that shape's place
    window.frameGeometryChanged.connect(function () {
        if (window.move || window.resize || graphShape(window) === shape)
            return;
        shape = graphShape(window);
        graphPlace(window);
    });
}

// AppGrid (12 Oct, the user: with AppGrid open, the system tray and the dock couldn't be
// clicked – the click went back to the game): AppGrid opens a see-through window over the
// whole screen with the grid in the middle, above the panels, and a click on it closes
// AppGrid. Its window is made to end below the top bar and above the dock instead, so the
// panels stay clickable while it is open. (plasmashell, no title, a whole screen.)
function isAppGrid(window) {
    if (window.resourceClass !== "plasmashell" || !window.normalWindow || window.caption)
        return false;
    const g = window.frameGeometry, s = window.output.geometry;
    return g.x === s.x && g.y === s.y && g.width === s.width && g.height === s.height;
}

function besidePanels(window) {
    const s = window.output.geometry;
    let top = s.y, bottom = s.y + s.height;
    const list = workspace.windowList();
    for (let i = 0; i < list.length; i++) {
        const p = list[i];
        if (!p.dock || p.output !== window.output)
            continue;
        const g = p.frameGeometry;
        if (g.y <= s.y + 2)
            top = Math.max(top, g.y + g.height); // the top bar
        else if (g.y + g.height >= s.y + s.height - 2)
            bottom = Math.min(bottom, g.y);      // the dock (also while it is hidden)
    }
    return { x: s.x, y: top, width: s.width, height: bottom - top };
}

function appGridAdded(window) {
    const fit = function () {
        const want = besidePanels(window);
        const geo = window.frameGeometry;
        if (geo.y !== want.y || geo.height !== want.height || geo.x !== want.x || geo.width !== want.width)
            window.frameGeometry = want;
    };
    fit();
    window.frameGeometryChanged.connect(fit);
}

// Goblin AI's quick question (Meta+§, 16 Oct): like KDE's search box – at the top third of the
// screen with the pointer, not in the taskbar or Alt+Tab, never in a tile
const QUICK = "Goblin AI – snabbfråga";
function quickAdded(window) {
    window.skipTaskbar = true;
    window.skipSwitcher = true;
    window.skipPager = true;
    const area = workspace.clientArea(KWin.PlacementArea, workspace.activeScreen, workspace.currentDesktop);
    const geo = window.frameGeometry;
    window.frameGeometry = {
        x: Math.round(area.x + Math.max(0, (area.width - geo.width) / 2)),
        y: Math.round(area.y + area.height * 0.22),
        width: geo.width,
        height: geo.height
    };
}

function added(window) {
    if (!window)
        return;
    if (String(window.caption) === QUICK) {
        quickAdded(window);
        return;
    }
    if (ordinaryWindow(window))
        watchDrag(window);
    if (isAppGrid(window)) {
        appGridAdded(window);
        return;
    }
    if (window.resourceClass === GRAPH) {
        graphAdded(window);
        return;
    }
    const tiled = window.normalWindow && !window.transient && !isGame(window) ? ruleTile(window) : null;
    const ruled = window.normalWindow ? ruleScreen(window) : null;
    if (CENTERED.indexOf(window.resourceClass) >= 0) {
        center(window);
    } else if (tiled) {
        if (tiled.desktop && !window.onAllDesktops)
            window.desktops = [tiled.desktop];
        const tile = tileFor(tiled);
        if (tile)
            toTile(window, tile);
        else if (tiled.desktop)
            waiting.push({ window: window, rule: tiled });
    } else if (ruled) {
        if (window.output !== ruled)
            workspace.sendClientToScreen(window, ruled);
        if (isWebapp(window) && wantsFullscreen(window))
            window.fullScreen = true;
        else if (autoFillable(window) && autoFill(window))
            ;
        else if (isWebapp(window))
            fit(window);
    } else if (isWebapp(window) && wantsFullscreen(window)) {
        window.fullScreen = true;
    } else if (autoFillable(window) && autoFill(window)) {
        // in the next free tile (automatic tiles)
    } else if (isWebapp(window)) {
        fit(window);
        const start = Date.now();
        window.frameGeometryChanged.connect(function () {
            if (Date.now() - start < 5000)
                fit(window);
        });
    } else if (isGame(window)) {
        toMainScreen(window);
        // Games often switch to fullscreen a moment later, on the screen the window is on –
        // the first switch during the first half minute is kept on the main screen as well.
        const start = Date.now();
        window.fullScreenChanged.connect(function () {
            if (window.fullScreen && Date.now() - start < 30000)
                toMainScreen(window);
        });
    }
}

// ── Automatic tiles (15 Oct, the user's wish: goblin tile auto på / Config → Fönster) ──
// When a screen has tiles: a new window without a rule goes into the first free tile, and a
// tiled window dragged onto another tile swaps places with the window there (dropped on a
// free tile = just moves). Meta+Shift+T takes the active window out of the tiles (it then
// floats and is left alone) or back in. Games, dialogs, fixed-size and special windows are
// left alone. kwinrc [Script-goblincakes-windows] autoTile=true.
// goblin tile av / Config → Fönster → Rutor: av (15 Oct): no rules, no automatic tiles
function tilesOn() {
    return String(readConfig("tilesOff", "false")) !== "true";
}

function autoOn() {
    return tilesOn() && String(readConfig("autoTile", "false")) === "true";
}

function ordinaryWindow(window) {
    return !!window && window.normalWindow && !window.transient && !isGame(window)
        && window.resizeable !== false && !window.skipTaskbar && !isAppGrid(window)
        && CENTERED.indexOf(window.resourceClass) < 0 && window.resourceClass !== GRAPH;
}

const floating = {};  // windows taken out with Meta+Shift+T (by internalId)
function idOf(window) {
    return String(window.internalId);
}

function autoFillable(window) {
    return autoOn() && ordinaryWindow(window) && !window.fullScreen && !floating[idOf(window)];
}

function freeTile(root, except) {
    const tiles = root ? leafTiles(root) : [];
    if (tiles.length < 2)
        return null;  // no tiles on this screen: nothing to fill
    for (let i = 0; i < tiles.length; i++) {
        const taken = (tiles[i].windows || []).some(function (w) {
            return w !== except && ordinaryWindow(w) && !w.minimized;
        });
        if (!taken)
            return tiles[i];
    }
    return null;
}

function autoFill(window) {
    const tile = freeTile(rootOf(window.output, null), window);
    if (!tile)
        return false;  // all tiles taken: the window opens as usual
    toTile(window, tile);
    return true;
}

const watched = {};
function watchDrag(window) {
    const id = idOf(window);
    if (watched[id])
        return;
    watched[id] = true;
    let from = null, moving = false;
    window.interactiveMoveResizeStarted.connect(function () {
        moving = window.move;
        from = window.tile;
    });
    window.interactiveMoveResizeFinished.connect(function () {
        if (!moving || !autoOn() || floating[id] || window.fullScreen || !ordinaryWindow(window))
            return;
        const area = workspace.clientArea(KWin.MaximizeArea, window.output, workspace.currentDesktop);
        const geo = window.frameGeometry;
        if (geo.width >= area.width - 2 && geo.height >= area.height - 2)
            return;  // dragged to the top edge: maximized, as KDE does
        let target = window.tile;
        if (!target || target === from) {
            const pos = workspace.cursorPos;
            const screen = workspace.screenAt(pos);
            const manager = screen ? workspace.tilingForScreen(screen) : null;
            if (!manager || !manager.rootTile || leafTiles(manager.rootTile).length < 2)
                return;  // dropped where there are no tiles: it floats
            target = manager.bestTileForPosition(pos.x, pos.y);
        }
        if (!target)
            return;
        const others = (target.windows || []).filter(function (w) {
            return w !== window && ordinaryWindow(w) && !w.minimized;
        });
        putInTile(window, target);
        if (target === from)
            return;
        for (let i = 0; i < others.length; i++) {
            const place = from || freeTile(rootOf(others[i].output, null), others[i]);
            if (place && place !== target)
                putInTile(others[i], place);  // the two swap places
        }
    });
    window.closed.connect(function () {
        delete watched[id];
        delete floating[id];
    });
}

registerShortcut("GOBLINCAKES Tile Float", "GOBLINCAKES: fönstret ut ur rutorna / tillbaka in", "Meta+Shift+T",
    function () {
        const window = workspace.activeWindow;
        if (!ordinaryWindow(window))
            return;
        const id = idOf(window);
        if (window.tile) {
            floating[id] = true;
            if (typeof window.tile.unmanage === "function")
                window.tile.unmanage(window);
            else
                window.tile = null;
        } else {
            delete floating[id];
            const geo = window.frameGeometry;
            const manager = workspace.tilingForScreen(window.output);
            const tile = manager && manager.rootTile && leafTiles(manager.rootTile).length > 1
                ? manager.bestTileForPosition(geo.x + geo.width / 2, geo.y + geo.height / 2) : null;
            if (tile)
                putInTile(window, tile);
        }
    });

const existing = workspace.windowList();
for (let i = 0; i < existing.length; i++)
    if (ordinaryWindow(existing[i]))
        watchDrag(existing[i]);

// 2 px between tiled windows (12 Oct, the user's wish): KDE's tiles have 4 px padding by default
// (between two windows = the padding, half from each). Set on every screen whose tiles still
// have KDE's 4 – another value chosen in the tile editor (Meta+T) is kept. KWin saves it.
const TILE_PADDING = 2;
function tilePadding() {
    for (let i = 0; i < workspace.screens.length; i++) {
        const manager = workspace.tilingForScreen(workspace.screens[i]);
        if (manager && manager.rootTile && manager.rootTile.padding === 4)
            manager.rootTile.padding = TILE_PADDING;
    }
}
tilePadding();
workspace.screensChanged.connect(tilePadding);

workspace.windowAdded.connect(added);
