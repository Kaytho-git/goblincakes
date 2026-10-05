// GOBLINCAKES panel layout (applied on first login)

// ---- Wallpaper on every desktop ----
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/goblincakes/goblincakes.svg");
}

// ---- Top bar: app menu left, clock centre, system icons right ----
var topBar = new Panel;
topBar.location = "top";
topBar.height = Math.round(gridUnit * 1.8);
try { topBar.floating = false; } catch (e) {}

topBar.addWidget("org.kde.plasma.kickoff");
topBar.addWidget("org.kde.plasma.panelspacer");
topBar.addWidget("org.kde.plasma.digitalclock");
topBar.addWidget("org.kde.plasma.panelspacer");
topBar.addWidget("org.kde.plasma.systemtray");

// ---- Bottom dock: hides when a window covers it ----
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 3);
dock.alignment = "center";
dock.hiding = "dodgewindows";
try { dock.lengthMode = "fit"; } catch (e) {}
try { dock.floating = true; } catch (e) {}

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "preferred://browser",
    "preferred://filemanager",
    "applications:com.mitchellh.ghostty.desktop",
    "applications:code.desktop",
    "applications:com.valvesoftware.Steam.desktop",
    "applications:net.lutris.Lutris.desktop",
    "applications:com.discordapp.Discord.desktop"
]);
