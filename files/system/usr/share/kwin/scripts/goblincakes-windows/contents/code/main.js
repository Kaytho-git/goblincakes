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

function added(window) {
    if (!window)
        return;
    const ruled = window.normalWindow ? ruleScreen(window) : null;
    if (CENTERED.indexOf(window.resourceClass) >= 0) {
        center(window);
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

workspace.windowAdded.connect(added);
