// GOBLINCAKES panel layout (applied on first login)

// ---- Wallpaper on every desktop ----
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/goblincakes/goblincakes.svg");
}

// ---- Top bar: logo + open programs left, now playing + system icons + clock + power right ----
var topBar = new Panel;
topBar.location = "top";
topBar.height = Math.round(gridUnit * 2);
try { topBar.floating = false; } catch (e) {}
// Always opaque: draws solid/widgets/panel-background (with the white bottom line)
try { topBar.opacity = "opaque"; } catch (e) {}

// The logo opens AppGrid: an app grid in the middle of the screen, like GNOME
// (settings in /etc/xdg/appgridrc)
var apps = topBar.addWidget("dev.xarbit.appgrid");
apps.currentConfigGroup = ["General"];
apps.writeConfig("icon", "goblincakes");
// About half AppGrid's default size (16 Oct, the user's wish): small icons, 4 × 3 per page
apps.writeConfig("iconSize", 0);
apps.writeConfig("gridColumns", 4);
apps.writeConfig("gridRows", 3);

// Open programs (icons only), left-aligned after the logo. It fills the free
// space, so it grows to the right while "now playing" grows to the left.
// No pinned launchers: pinning is the dock's job.
var running = topBar.addWidget("org.kde.plasma.icontasks");
running.currentConfigGroup = ["General"];
running.writeConfig("launchers", []);
running.writeConfig("fill", true);
running.writeConfig("maxStripes", 1);
// Windows on every screen (23 Oct, the user's choice; was only this screen – systray.js too).
// From Plasma 6.8 Meta+1–9 may go to the top bar instead of the dock.
running.writeConfig("showOnlyCurrentScreen", false);
// Hover = live preview of the window(s); hovering a preview highlights that window
running.writeConfig("showToolTips", true);
running.writeConfig("highlightWindows", true);

// What Spotify/the music player is playing and the Discord server/channel
// (/usr/share/plasma/plasmoids/org.goblincakes.nowplaying), just left of the tray
topBar.addWidget("org.goblincakes.nowplaying");
// A green arrow when there are updates (click = Config → Uppdatera); otherwise takes no space
topBar.addWidget("org.goblincakes.updates");
// Two small bars: how much of Claude's and ChatGPT/Codex's 5-hour limits is used (click = 5 h + week)
topBar.addWidget("org.goblincakes.quota");
// System tray: trimmed to network, volume and notifications by
// /usr/share/goblincakes/systray.js, which goblincakes-firstlogin runs once the
// tray has started (its settings don't exist yet while this layout runs)
topBar.addWidget("org.kde.plasma.systemtray");

// The week number ("v41") just left of the clock – the clock itself can't show it
topBar.addWidget("org.goblincakes.week");
var clock = topBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
// "tis 6 okt" + a gap before the time, like the design. The invisible word
// joiner at the end keeps Plasma from trimming the two spaces.
clock.writeConfig("customDateFormat", "ddd d MMM  \u2060");

// Fixed size: Plasma otherwise makes the clock as tall as the bar allows (looked huge).
// Font and weight too: with a fixed size Plasma drops to a thin default font that looked grey.
clock.writeConfig("autoFontAndSize", false);
clock.writeConfig("fontFamily", "IBM Plex Sans");
clock.writeConfig("fontWeight", 600);  // semi-bold (the user's choice, 9 Oct)
clock.writeConfig("fontSize", 11);
// The calendar (click the clock): Swedish public holidays (region in
// /etc/xdg/plasma_calendar_holiday_regions) and week numbers
clock.currentConfigGroup = ["General"];
clock.writeConfig("enabledCalendarPlugins", ["holidaysevents"]);
clock.writeConfig("showWeekNumbers", true);
clock.currentConfigGroup = ["Appearance"];  // the clock reads both keys from here (main.xml)
clock.writeConfig("enabledCalendarPlugins", ["holidaysevents"]);
clock.writeConfig("showWeekNumbers", true);

// Power button: opens the GOBLINCAKES logout screen
var power = topBar.addWidget("org.kde.plasma.lock_logout");
power.currentConfigGroup = ["General"];
power.writeConfig("show_lockScreen", false);
power.writeConfig("show_requestLogoutScreen", true);

// ---- Bottom dock: hidden, comes up at the bottom edge or with Meta+Z (23 Oct, the user's
// wish; Meta+Z = the goblincakes-windows KWin script, also over games) ----
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 3.2);
dock.alignment = "center";
dock.hiding = "autohide";
// Translucent mode = always widgets/panel-background (thin frame all round);
// our theme draws it 60 % opaque (translucent/widgets/panel-background, 24 Oct)
try { dock.opacity = "translucent"; } catch (e) {}
try { dock.lengthMode = "fit"; } catch (e) {}
try { dock.floating = true; } catch (e) {}

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
// Only these two, in this order: the terminal (Ghostty), Firefox. Users pin the rest themselves.
tasks.writeConfig("launchers", ["applications:com.mitchellh.ghostty.desktop", "applications:org.mozilla.firefox.desktop"]);
tasks.writeConfig("showToolTips", true);
tasks.writeConfig("highlightWindows", true);
