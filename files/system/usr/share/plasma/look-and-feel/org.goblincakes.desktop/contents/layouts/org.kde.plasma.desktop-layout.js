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
// Always opaque: draws solid/widgets/panel-background (with the white bottom line)
try { topBar.opacity = "opaque"; } catch (e) {}

// The logo opens AppGrid: an app grid in the middle of the screen, like GNOME
// (settings in /etc/xdg/appgridrc)
var apps = topBar.addWidget("dev.xarbit.appgrid");
apps.currentConfigGroup = ["General"];
apps.writeConfig("icon", "goblincakes");

topBar.addWidget("org.kde.plasma.panelspacer");
// System tray: trimmed to network, volume and notifications by
// /usr/share/goblincakes/systray.js, which goblincakes-firstlogin runs once the
// tray has started (its settings don't exist yet while this layout runs)
topBar.addWidget("org.kde.plasma.systemtray");

var clock = topBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
// "tis 6 okt" + a gap before the time, like the design. The invisible word
// joiner at the end keeps Plasma from trimming the two spaces.
clock.writeConfig("customDateFormat", "ddd d MMM  \u2060");

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
// Translucent mode = always widgets/panel-background (thin frame all round);
// our theme makes it solid #05070A anyway
try { dock.opacity = "translucent"; } catch (e) {}
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
