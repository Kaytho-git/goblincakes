// GOBLINCAKES panel layout (applied on first login)

// ---- Wallpaper on every desktop ----
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/goblincakes/goblincakes.svg");
}

// ---- Top bar: logo left, system icons + clock + power right ----
var topBar = new Panel;
topBar.location = "top";
topBar.height = Math.round(gridUnit * 2.4);
try { topBar.floating = false; } catch (e) {}

// The logo opens the Application Dashboard (full-screen app grid)
var apps = topBar.addWidget("org.kde.plasma.kickerdash");
apps.currentConfigGroup = ["General"];
apps.writeConfig("icon", "goblincakes");

topBar.addWidget("org.kde.plasma.panelspacer");
// System tray: only network, volume and notifications, like the design
// (battery appears on laptops only)
var tray = topBar.addWidget("org.kde.plasma.systemtray");
try {
    var trayItems = desktopById(tray.readConfig("SystrayContainmentId"));
    trayItems.currentConfigGroup = ["General"];
    trayItems.writeConfig("extraItems", [
        "org.kde.plasma.networkmanagement",
        "org.kde.plasma.volume",
        "org.kde.plasma.notifications",
        "org.kde.plasma.battery"
    ]);
    // Everything listed here but not above stays switched off
    trayItems.writeConfig("knownItems", [
        "org.kde.plasma.networkmanagement",
        "org.kde.plasma.volume",
        "org.kde.plasma.notifications",
        "org.kde.plasma.battery",
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
} catch (e) {}

var clock = topBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");   // "tis 6 okt", like the design

// Power button: opens the GOBLINCAKES logout screen
var power = topBar.addWidget("org.kde.plasma.lock_logout");
power.currentConfigGroup = ["General"];
power.writeConfig("show_lockScreen", false);
power.writeConfig("show_requestLogoutScreen", true);

// ---- Bottom dock: hides when a window covers it ----
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 4);
dock.alignment = "center";
dock.hiding = "dodgewindows";
try { dock.lengthMode = "fit"; } catch (e) {}
try { dock.floating = true; } catch (e) {}

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.mozilla.firefox.desktop",
    "applications:com.valvesoftware.Steam.desktop",
    "applications:com.discordapp.Discord.desktop",
    "applications:com.microsoft.VSCode.desktop",
    "applications:org.videolan.VLC.desktop"
]);
