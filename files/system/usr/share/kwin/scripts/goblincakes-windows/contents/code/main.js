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

function ruleTile(window) {
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
        if (!screen || !(number >= 1))
            return null;
        const manager = workspace.tilingForScreen(screen);
        const tiles = manager && manager.rootTile ? leafTiles(manager.rootTile) : [];
        return number <= tiles.length ? tiles[number - 1] : null;
    }
    return null;
}

// Into the tile – and back again during the first seconds, while programs like Chromium,
// Discord and Steam restore the size they had last time (not while you drag it yourself).
// KWin keeps such a window marked as tiled, so the size is compared with the tile's.
function toTile(window, tile) {
    window.tile = tile;
    const start = Date.now();
    window.frameGeometryChanged.connect(function () {
        if (Date.now() - start > 8000 || window.move || window.resize || window.fullScreen)
            return;
        // the tile's own size; the window sits inside it by the padding (half at inner edges)
        const want = tile.absoluteGeometry;
        const geo = window.frameGeometry;
        const slack = 2 * (tile.padding || 0) + 2;
        if (Math.abs(geo.x - want.x) > slack || Math.abs(geo.y - want.y) > slack
                || Math.abs(geo.width - want.width) > slack || Math.abs(geo.height - want.height) > slack) {
            window.tile = null;
            window.tile = tile;
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

function added(window) {
    if (!window)
        return;
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
        toTile(window, tiled);
    } else if (ruled) {
        if (window.output !== ruled)
            workspace.sendClientToScreen(window, ruled);
        if (isWebapp(window) && wantsFullscreen(window))
            window.fullScreen = true;
        else if (isWebapp(window))
            fit(window);
    } else if (isWebapp(window) && wantsFullscreen(window)) {
        window.fullScreen = true;
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
