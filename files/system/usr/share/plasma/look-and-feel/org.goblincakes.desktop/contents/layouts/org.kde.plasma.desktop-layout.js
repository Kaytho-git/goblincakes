// GOBLINCAKES panel layout (applied on first login)

// ---- Wallpaper on every desktop ----
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/goblincakes/goblincakes.svg");
}

// ---- Top bar: "Apps" with logo left, system icons + clock + power right ----
var topBar = new Panel;
topBar.location = "top";
topBar.height = Math.round(gridUnit * 2.4);
try { topBar.floating = false; } catch (e) {}

var apps = topBar.addWidget("org.kde.plasma.kickoff");
apps.currentConfigGroup = ["General"];
apps.writeConfig("icon", "goblincakes");
apps.writeConfig("menuLabel", "Apps");

topBar.addWidget("org.kde.plasma.panelspacer");
topBar.addWidget("org.kde.plasma.systemtray");

var clock = topBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BesideTime");

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
    "applications:code.desktop",
    "applications:org.videolan.VLC.desktop"
]);

dock.addWidget("org.kde.plasma.marginsseparator");

// "Show all apps" grid, like GNOME
var allApps = dock.addWidget("org.kde.plasma.kickerdash");
allApps.currentConfigGroup = ["General"];
allApps.writeConfig("icon", "view-app-grid-symbolic");
