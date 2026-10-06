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
    "org.kde.discovernotifier"
]);

var trimmed = 0;
panels().forEach(function (panel) {
    panel.widgets("org.kde.plasma.systemtray").forEach(function (tray) {
        var items = desktopById(tray.readConfig("SystrayContainmentId"));
        if (!items) {
            return;
        }
        items.currentConfigGroup = ["General"];
        items.writeConfig("extraItems", shown);
        items.writeConfig("knownItems", known);
        items.reloadConfig();
        trimmed++;
    });
});

// Not ready yet: fail, so goblincakes-firstlogin tries again in a moment
if (trimmed === 0) {
    throw new Error("system tray not ready");
}
