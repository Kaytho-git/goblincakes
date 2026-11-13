// GOBLINCAKES: trims every system tray to network, volume and notifications,
// like the design (battery appears on laptops only).
// Run by goblincakes-firstlogin through plasmashell's evaluateScript, after
// the panels exist – the tray's own settings aren't there while layout.js runs.
var shown = [
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.notifications",
    "org.kde.plasma.battery"
];
// Everything listed here but not above stays switched off
var known = shown.concat([
    "org.kde.plasma.brightness",
    "org.kde.plasma.dwellclicker",
    "org.kde.kscreen",
    "org.kde.plasma.devicenotifier",
    "org.kde.plasma.clipboard",
    "org.kde.plasma.bluetooth",
    "org.kde.plasma.mediacontroller",
    "org.kde.plasma.keyboardindicator",
    "org.kde.plasma.keyboardlayout",
    "org.kde.plasma.manage-inputmethod",
    "org.kde.plasma.printmanager",
    "org.kde.plasma.cameraindicator",
    "org.kde.plasma.vault",
    "org.kde.plasma.weather",
    "org.kde.kdeconnect",
    "org.kde.plasma.nightcolorcontrol",
    "org.kde.plasma.nightlight",
    "org.kde.plasma.diskquota",
    "org.kde.discovernotifier",
    "org.kde.merkuro.contact.applet" // Merkuro's contact list (calendar accounts, 9 Oct)
]);

// The dashboard layout (goblincakes-desktop-layout, 10 Nov): network and sound are in the row's clock box,
// so its tray (in its own hidden panel top right) shows only notifications (and the battery on laptops). The tray has to be there: without
// one Plasma shows no notifications and Discord/Steam have nowhere to put their tray icon.
var rowShown = ["org.kde.plasma.notifications", "org.kde.plasma.battery"];

var trimmed = 0;
function trim(target, row) {
    target.currentConfigGroup = ["General"];
    target.writeConfig("extraItems", row ? rowShown : shown);
    target.writeConfig("knownItems", known);
    // Electron programs' own icons go behind the arrow: goblincakes-archon-tray shows its own in their place
    // (Archon purple 24 Oct; Raider.IO and WowUp 13 Nov – a left click on theirs did nothing). Plasma names
    // Chromium's generic ids "chrome_status_icon_N@<process>"; ids of their own (Raider.IO, WowUp) as they are.
    // (readConfig gives the list back as one comma-separated string; a first try on 24 Oct glued "obs" to a wrong
    // name.) Follows APPS in goblincakes-archon-tray.
    var ours = ["chrome_status_icon_1@archon", "RaiderIO_status_icon_1", "WowUpCf_status_icon_1"];
    var hidden = String(target.readConfig("hiddenItems") || "").split(",").map(function (item) {
        return item === "obschrome_status_icon_1" ? "obs" : item;
    }).filter(function (item) {
        // a wrong first try (13 Nov) and a plain Chromium id
        return item && item !== "chrome_status_icon_1" && item.indexOf("_status_icon_1@raiderio") < 0
            && item.indexOf("_status_icon_1@wowup") < 0;
    });
    ours.forEach(function (item) {
        if (hidden.indexOf(item) < 0)
            hidden.push(item);
    });
    target.writeConfig("hiddenItems", hidden);
    target.reloadConfig();
    trimmed++;
}
panels().forEach(function (panel) {
    // the dashboard layout: the row (first version) or the tray's own hidden panel top right (10 Nov)
    var row = panel.widgets("org.goblincakes.deskclock").length > 0
        || (panel.location === "top" && panel.widgets().length === 1 && panel.widgets("org.kde.plasma.systemtray").length === 1);
    panel.widgets("org.kde.plasma.systemtray").forEach(function (tray) {
        // Plasma before 6.7: the items live in a separate inner containment.
        // Plasma 6.7: on the tray itself ([General] extraItems/knownItems) – the inner id is
        // empty and nothing was trimmed (10 Oct)
        var id = tray.readConfig("SystrayContainmentId");
        var items = id ? desktopById(id) : null;
        trim(items || tray, row);
    });
});

// The top bar's open programs: windows on every screen (23 Oct, the user's choice; 14 Oct it
// was only its own screen). From Plasma 6.8 Meta+1–9 goes to the first task manager showing
// all screens, which may now be the top bar instead of the dock. Here too for existing panels.
panels().forEach(function (panel) {
    if (panel.location !== "top")
        return;
    panel.widgets("org.kde.plasma.icontasks").forEach(function (tasks) {
        tasks.currentConfigGroup = ["General"];
        tasks.writeConfig("showOnlyCurrentScreen", false);
        tasks.reloadConfig();
    });
});

// The dock auto-hides (23 Oct, the user's wish): up at the bottom edge or with Meta+Z
panels().forEach(function (panel) {
    if (panel.location === "bottom")
        panel.hiding = "autohide";
});

// Not ready yet: fail, so goblincakes-firstlogin tries again in a moment
if (trimmed === 0) {
    throw new Error("system tray not ready");
}
