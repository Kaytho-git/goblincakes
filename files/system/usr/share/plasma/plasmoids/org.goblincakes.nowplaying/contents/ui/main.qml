/*
    GOBLINCAKES Now Playing – the middle of the top bar.

    Music: what Spotify or the music player (Quod Libet …) is playing, read over
    MPRIS with the same model as Plasma's media controller. Browsers are left out
    so a YouTube tab doesn't take over the bar.
    Discord: the server whose voice channel you are in (only while you are in voice –
    10 Oct, the user's choice). /usr/libexec/goblincakes-discord-voice reads Discord's log
    (voice connect/disconnect + which server you look at, by id); the server's name is
    learnt from the Discord window's title ("#channel | Server - Discord") while you look
    at it and kept in the widget's config. The voice channel's own name isn't on the
    computer (not in the title or the log) – you name it once with `goblin discord namn …`
    while you are in it (~/.config/goblincakes/discord-channels), else "Röstkanal".
    Also with Discord's window closed to the system tray (11 Oct): the helper says whether
    Discord runs, and a click brings the window back like its tray icon does.
    Steam (16 Oct, the user's wish – the fans were loud and it wasn't clear why): while Steam
    downloads a game or processes its Vulkan shaders, the game and how far (shaders in %,
    downloads in Mbit/s); click = Steam's downloads. /usr/libexec/goblincakes-steam-activity
    reads Steam's logs every 5 s, only while Steam runs.
    Goblin AI (17 Oct, the user's wish – after Meta+§ the quick box closes and nothing showed that
    the AI was still working): "Kakan tänker · din dator" / "ritar en bild · din dator 40 %" while a
    question or a picture is under way, with the seconds so far; click = the Goblin AI window.
    /usr/libexec/goblincakes-ai-activity reads the files goblinai.py writes, every second.
    Battery (24 Oct, the user's wish – the Logitech mouse's charge was nowhere to be seen): each
    wireless mouse/keyboard/headset with its name and %, green/orange/red by charge; click = name on/off (saved).
    /usr/libexec/goblincakes-device-battery reads UPower every 30 s.
    Nothing to show = the widget takes no space.
    The dashboard's desktop row (10 Nov, goblincakes-desktop-layout; config "part"): two copies of this widget
    either side of the clock box (org.goblincakes.deskclock), each part in its own box (DeskBox.qml, after the
    mockup): "left" = Steam (only while it works) + Discord, "right" = what is playing + Kakan (only while
    she works). Discord and Spelas nu always show, so the row stays even on both sides; the batteries are in
    the clock box there.
*/
import QtQuick
import QtQuick.Layouts
import QtQml.Models
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import QtCore
import Qt.labs.folderlistmodel
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Palette (same as the rest of GOBLINCAKES)
    readonly property color frost: "#E6ECF5"
    readonly property color muted: "#8B98AD"
    readonly property color accent: Kirigami.Theme.focusColor // the accent chosen in Config → Utseende
    readonly property color line: "#2A3852"

    readonly property bool editMode: Plasmoid.containment.corona?.editMode ?? false
    // "" = the top bar; "left"/"right" = the dashboard's desktop row
    readonly property string part: Plasmoid.configuration.part || ""
    readonly property bool desk: part !== ""
    // Stil (Config → Utseende): Levande = tinted glass on the desktop row (Levande utseende step 6) and, in the top
    // bar, text that fades in when it changes (step 7) – the file ~/.config/goblincakes/utseende (platt/levande, no
    // file = platt) and the game guard's file (no fades during a game), read again when it changes
    readonly property string lookCommand: "cat \"$HOME/.config/goblincakes/utseende\" 2>/dev/null; "
        + "[ -e \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/goblincakes-gaming\" ] && echo spel; true"
    property bool living: false
    property bool gaming: false
    readonly property bool moving: living && !gaming && Kirigami.Units.longDuration > 1
    // A line of text that fades in when it changes (Stil Levande, step 7)
    component FadeLabel: Text {
        id: fadeLabel
        onTextChanged: if (root.moving && visible) fadeIn.restart()
        NumberAnimation { id: fadeIn; target: fadeLabel; property: "opacity"; from: 0.15; to: 1; duration: 260; easing.type: Easing.OutQuad }
    }

    // ---- Music ----
    // Music players only (desktop entry or name contains one of these)
    readonly property var musicPlayers: ["spotify", "quodlibet", "quod libet", "elisa", "strawberry",
        "audacious", "rhythmbox", "lollypop", "amberol", "clementine", "deadbeef", "tauon",
        "cmus", "g4music", "gapless", "harmonoid", "cider", "tidal", "deezer", "youtube-music",
        "youtubemusic", "nuclear", "museeks", "sayonara", "juk", "qmmp", "mpd", "mpv", "goblinamp", "goblin-amp"]

    property int playerRevision: 0

    function isMusicPlayer(entry, identity) {
        const name = (entry + " " + identity).toLowerCase();
        return musicPlayers.some(p => name.indexOf(p) !== -1);
    }

    // Playing beats paused; stopped players are not shown
    readonly property var player: {
        playerRevision;
        let paused = null;
        for (let i = 0; i < players.count; i++) {
            const p = players.objectAt(i);
            if (!p || p.multiplexer || !p.container || !isMusicPlayer(p.entry, p.identity)) {
                continue;
            }
            if (p.status === Mpris.PlaybackStatus.Playing) {
                return p.container;
            }
            if (p.status === Mpris.PlaybackStatus.Paused && !paused) {
                paused = p.container;
            }
        }
        return paused;
    }
    readonly property bool playing: player?.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string songText: {
        if (!player || !player.track) {
            return "";
        }
        return player.artist ? player.artist + "  —  " + player.track : player.track;
    }

    Mpris.Mpris2Model {
        id: mpris2Model
    }

    Instantiator {
        id: players
        model: mpris2Model
        delegate: QtObject {
            required property var model
            readonly property var container: model.container
            readonly property bool multiplexer: model.isMultiplexer ?? false
            readonly property string entry: model.desktopEntry ?? ""
            readonly property string identity: model.identity ?? ""
            readonly property int status: model.playbackStatus ?? 0
            onStatusChanged: root.playerRevision++
            onEntryChanged: root.playerRevision++
            onIdentityChanged: root.playerRevision++
        }
        onObjectAdded: root.playerRevision++
        onObjectRemoved: root.playerRevision++
    }

    // ---- Discord ----
    property int windowRevision: 0
    property bool inVoice: false
    property string voiceServer: ""   // server id of the voice channel ("" = DM call)
    property string viewingServer: "" // server id you are looking at
    property string voiceChannel: ""  // the voice channel's name from goblin discord namn
    property var serverNames: ({})    // server id → name, saved in the widget's config
    property bool discordRunning: false // also with the window closed to the system tray
    property string discordIcon: "discord" // the window's icon, kept for when it is hidden
    property string pendingName: ""   // "<id>|<name>" seen once – saved when seen twice in a row

    // "(2) #general | Raid Night - Discord", "Discord | #general | Raid Night" → "Raid Night".
    // Empty outside a server channel (DMs, friends list).
    function discordServer(title) {
        let t = title.replace(/^\(\d+\)\s*/, "").replace(/^[•●]\s*/, "");
        t = t.replace(/\s+[-–—]\s+(Discord|Vesktop)$/i, "");
        const parts = t.split(" | ").map(p => p.trim())
            .filter(p => p.length > 0 && !/^(discord|vesktop)$/i.test(p));
        const channel = parts.find(p => p.startsWith("#"));
        return channel ? parts.filter(p => p !== channel).join(" · ") : "";
    }

    readonly property var discordWindow: {
        windowRevision;
        for (let i = 0; i < windows.count; i++) {
            const w = windows.objectAt(i);
            if (w && /discord|vesktop|vencord|webcord|armcord|legcord/i.test(w.appId)) {
                return { row: w.row, icon: w.appId, title: w.title };
            }
        }
        return null;
    }

    onDiscordWindowChanged: if (discordWindow) discordIcon = discordWindow.icon

    readonly property string voiceServerName: serverNames[voiceServer] || ""

    readonly property var discord: {
        if (!inVoice || (!discordWindow && !discordRunning)) {
            return null;
        }
        const server = serverNames[voiceServer] || "";
        const channel = "🔊 " + (voiceChannel || "Röstkanal");
        return { place: server ? server + "  ›  " + channel : channel,
                 row: discordWindow ? discordWindow.row : -1,
                 icon: discordWindow ? discordWindow.icon : discordIcon };
    }

    // The title and the log are read at slightly different moments, so a name is only
    // saved when the same server id and title name are seen in two reads in a row.
    function learnServerName() {
        if (!discordWindow || !viewingServer) {
            pendingName = "";
            return;
        }
        const name = discordServer(discordWindow.title);
        const pair = viewingServer + "|" + name;
        if (!name || pair !== pendingName) {
            pendingName = name ? pair : "";
            return;
        }
        if (serverNames[viewingServer] !== name) {
            const names = Object.assign({}, serverNames);
            names[viewingServer] = name;
            serverNames = names;
            Plasmoid.configuration.discordServers = JSON.stringify(names);
        }
    }

    // ---- Steam ----
    property var steam: ({})          // {kind: "download"|"shader"|"", name, phase, percent, rate}
    readonly property string steamText: !steam.kind ? ""
        : steam.name + "  ·  " + (steam.kind === "shader" ? "shaders" : steam.phase)
          + (steam.percent !== null && steam.percent !== undefined ? " " + steam.percent + " %" : "")
          + (steam.rate ? "  ·  " + steam.rate + " Mbit/s" : "")
    // Steam's own pid file first (P1, 11 Nov: pgrep reads all of /proc, 25 ms); pgrep only without one (Flatpak)
    readonly property string steamCommand: "p=$(cat \"$HOME/.steam/steam.pid\" 2>/dev/null); "
        + "if [ -n \"$p\" ]; then [ \"$(cat /proc/$p/comm 2>/dev/null)\" = steam ]; else pgrep -x steam >/dev/null; fi "
        + "&& exec /usr/libexec/goblincakes-steam-activity; echo '{}'"

    // ---- Goblin AI ----
    property var ai: ({})             // {kind: "ask"|"image"|"", name, text, local, progress, seconds, steps}
    readonly property string aiText: !ai.kind ? ""
        : ai.name + " " + ai.text
          + (ai.progress !== null && ai.progress !== undefined ? " " + ai.progress + " %" : "")
          + (ai.seconds >= 3 ? "  ·  " + ai.seconds + " s" : "")
    // Optimization P1 (11 Nov): no Python while nothing is under way – goblinai.py writes a file in the folder
    // for each question/picture, the helper only runs when there is one (it also removes files left by a crash)
    readonly property string aiCommand: "set -- \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}\"/goblincakes-ai/*.json; "
        + "[ -e \"$1\" ] && exec /usr/libexec/goblincakes-ai-activity; echo '{}'"
    // The work loop's steps (25 Oct, the user's wish – it only said "tänker"): one line each in the tooltip
    readonly property string aiSteps: (ai.steps || []).map(function (s, i) {
        return (s.state === "run" ? "▸ " : s.state === "ok" ? "✓ " : "✗ ") + s.text
    }).join("\n")

    // ---- Battery of wireless devices ----
    property var devices: []          // [{kind, name, percent, charging}]
    readonly property string batteryCommand: "/usr/libexec/goblincakes-device-battery"

    function deviceIcon(kind) {
        return { mouse: "input-mouse", keyboard: "input-keyboard", headset: "audio-headset",
                 headphones: "audio-headphones", "gaming-input": "input-gaming",
                 touchpad: "input-touchpad", pen: "input-tablet", tablet: "input-tablet",
                 speakers: "audio-speakers", "remote control": "input-gaming" }[kind] || "battery";
    }

    readonly property string voiceCommand: "/usr/libexec/goblincakes-discord-voice"

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.lookCommand) {
                const lines = String(data["stdout"] || "").split("\n").map(l => l.trim());
                root.living = lines[0] === "levande";
                root.gaming = lines.indexOf("spel") >= 0;
                disconnectSource(source);
                return;
            }
            if (source === root.voiceCommand) {
                try {
                    const state = JSON.parse(data["stdout"]);
                    root.inVoice = state.voice === true;
                    root.voiceServer = state.guild || "";
                    root.viewingServer = state.viewing || "";
                    root.voiceChannel = state.channelName || "";
                    root.discordRunning = state.running === true;
                } catch (e) {
                    root.inVoice = false;
                    root.discordRunning = false;
                }
                root.learnServerName();
            } else if (source === root.aiCommand) {
                try {
                    root.ai = JSON.parse(data["stdout"] || "{}");
                } catch (e) {
                    root.ai = {};
                }
            } else if (source === root.steamCommand) {
                try {
                    root.steam = JSON.parse(data["stdout"] || "{}");
                } catch (e) {
                    root.steam = {};
                }
            } else if (source === root.batteryCommand) {
                try {
                    root.devices = JSON.parse(data["stdout"] || "[]");
                } catch (e) {
                    root.devices = [];
                }
            }
            disconnectSource(source);
        }
    }

    // Optimization P1 (11 Nov): each part of the desktop row only reads what it shows ("left" = Steam + Discord,
    // "right" = music + Kakan; the top bar = all), the batteries are in the clock box there, and while a game
    // runs (the look file's "spel") the reads are three times sparser – the game covers the bar anyway.
    readonly property int slow: gaming ? 3 : 1
    readonly property bool readsLeft: part !== "right"
    readonly property bool readsRight: part !== "left"

    // Every second while Discord's window is open (the helper takes ~0.02 s and reads only
    // the new lines of the log), so the channel shows up right after you join; every third
    // second while it runs in the system tray without a window; every tenth when it isn't
    // running (P1, 11 Nov – a window that opens shortens the interval at once)
    Timer {
        interval: (root.discordWindow !== null ? 1000 : root.discordRunning ? 3000 : 10000) * root.slow
        running: root.readsLeft
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource(root.voiceCommand)
    }

    // Steam's progress changes by the second; without Steam only a pid check
    Timer {
        interval: 5000 * root.slow
        running: root.readsLeft
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource(root.steamCommand)
    }

    // A glob in the shell (Python only while something is under way); every second so the indicator
    // comes and goes with the answer – every other while a game runs (Meta+§ in a game still shows it soon)
    Timer {
        interval: root.gaming ? 2000 : 1000
        running: root.readsRight
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource(root.aiCommand)
    }

    // A battery changes slowly; a mouse switched on shows up within half a minute.
    // Not in the desktop row – the clock box reads the batteries there
    Timer {
        interval: 30000 * root.slow
        running: !root.desk
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource(root.batteryCommand)
    }

    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        filterMinimized: false
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    Instantiator {
        id: windows
        model: tasksModel
        delegate: QtObject {
            required property var model
            required property int index
            readonly property int row: index
            readonly property string appId: model.AppId ?? ""
            readonly property string title: model.display ?? ""
            onAppIdChanged: root.windowRevision++
            onTitleChanged: root.windowRevision++
            onRowChanged: root.windowRevision++
        }
        onObjectAdded: root.windowRevision++
        onObjectRemoved: root.windowRevision++
    }

    // ---- Look ----
    // Read when the style file or the game guard's file changes (the folders are watched – no process), and every
    // 60 s in case a change was missed (12 Nov – was a process every 5 s in each widget)
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource(root.lookCommand)
    }
    FolderListModel {
        folder: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/goblincakes"
        nameFilters: ["utseende"]
        showDirs: false
        onCountChanged: exec.connectSource(root.lookCommand)
        onDataChanged: exec.connectSource(root.lookCommand)
    }
    FolderListModel {
        folder: StandardPaths.writableLocation(StandardPaths.RuntimeLocation)
        nameFilters: ["goblincakes-gaming"]
        showDirs: false
        onCountChanged: exec.connectSource(root.lookCommand)
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    fullRepresentation: Item {
        id: full
        readonly property bool empty: !music.visible && !chat.visible && !steamPart.visible && !aiPart.visible
                                      && !batteryPart.visible
        // The desktop row keeps room for both its boxes (Steam/Kakan come and go): the panel is centred and as
        // wide as its widgets, so a box that appeared pushed the clock sideways (13 Nov, the user: "grow outwards").
        // The two sides are equally wide – the clock stays in the middle; the empty room is see-through.
        readonly property real deskWidth: Math.round(240 * 0.6) + Math.round(300 * 0.6) + 2 * deskRow.spacing
        readonly property real wanted: root.desk ? deskWidth : row.implicitWidth

        Layout.minimumWidth: wanted
        Layout.preferredWidth: wanted
        Layout.maximumWidth: wanted
        Layout.fillHeight: true

        // ---- The desktop row: one box per part ----
        Row {
            id: deskRow
            visible: root.desk
            anchors.verticalCenter: parent.verticalCenter
            // Against the clock box: the left part grows to the left, the right part to the right
            anchors.right: root.part === "left" ? parent.right : undefined
            anchors.left: root.part === "left" ? undefined : parent.left
            spacing: 7
            // In the order they stand on the screen; 7 px towards the clock box, like the gaps between the boxes
            // (12 in the mockup, times DeskBox's s = 0.6)
            rightPadding: root.part === "left" ? 7 : 0
            leftPadding: root.part === "left" ? 0 : 7

            // Left: Steam (only while it downloads or makes shaders), farthest from the clock
            DeskBox {
                glass: root.living
                visible: root.part === "left" && root.steamText !== ""
                implicitWidth: Math.round(240 * s)
                alignRight: true
                mark: "#66C0F4"
                label: "STEAM · " + (root.steam.kind === "shader" ? "SHADERS" : String(root.steam.phase || "").toUpperCase())
                text: (root.steam.name || "")
                      + (root.steam.percent !== null && root.steam.percent !== undefined ? "  " + root.steam.percent + " %" : "")
                      + (root.steam.rate ? "  ·  " + root.steam.rate + " Mbit/s" : "")
                onClicked: exec.connectSource("setsid -f xdg-open steam://open/downloads >/dev/null 2>&1 < /dev/null")
                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    mainText: root.steam.kind === "shader" ? "Steam bearbetar shaders" : "Steam " + (root.steam.phase || "")
                    subText: (root.steam.kind === "shader"
                        ? "Gör " + root.steam.name + " redo så att spelet inte hackar. Det tar mycket processorkraft – fläktarna kan låta en stund.\n"
                        : root.steam.name + "\n") + "Klicka för att visa Steams nedladdningar"
                }
            }

            // Left, next to the clock: Discord – the voice channel, or that you aren't in one
            DeskBox {
                glass: root.living
                visible: root.part === "left"
                alignRight: true
                mark: "#7C8CF8"
                dim: root.discord === null
                label: "DISCORD" + (root.discord && root.voiceServerName ? " · " + root.voiceServerName.toUpperCase() : "")
                text: root.discord ? "🔊 " + (root.voiceChannel || "Röstkanal")
                    : root.discordWindow || root.discordRunning ? "Inte i en röstkanal" : "Inte igång"
                onClicked: {
                    if (root.discordWindow) {
                        tasksModel.requestActivate(tasksModel.index(root.discordWindow.row, 0));
                    } else if (root.discordRunning) {
                        exec.connectSource(root.voiceCommand + " show");
                    } else {
                        exec.connectSource("setsid -f gtk-launch discord >/dev/null 2>&1 < /dev/null");
                    }
                }
                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    mainText: "Discord"
                    subText: root.discordWindow || root.discordRunning ? "Klicka för att visa Discord" : "Klicka för att starta Discord"
                }
            }

            // Right, next to the clock: what is playing – click = play/pause, wheel = next/previous
            DeskBox {
                glass: root.living
                visible: root.part === "right"
                mark: "#3BD16F"
                dim: !root.playing
                label: root.player && !root.playing ? "SPELAS NU · PAUSAD" : "SPELAS NU"
                text: root.player && root.player.track
                    ? root.player.track + (root.player.artist ? " – " + root.player.artist : "")
                    : "Inget spelas"
                onClicked: button => {
                    if (!root.player) {
                        exec.connectSource("setsid -f gtk-launch goblin-amp >/dev/null 2>&1 < /dev/null");
                    } else if (button === Qt.MiddleButton) {
                        root.player.Raise();
                    } else {
                        root.player.PlayPause();
                    }
                }
                onWheeled: delta => {
                    if (root.player && delta < 0) {
                        root.player.Next();
                    } else if (root.player && delta > 0) {
                        root.player.Previous();
                    }
                }
                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    mainText: root.player ? (root.player.track || "Spelas nu") : "Inget spelas"
                    subText: root.player
                        ? (root.player.artist ? root.player.artist + (root.player.album ? " · " + root.player.album : "") + "\n" : "")
                          + "Klicka = spela/pausa, hjulet = nästa/föregående, mittenklick = visa spelaren"
                        : "Klicka för att starta GoblinAmp"
                }
            }

            // Right, farthest out: Kakan (Goblin AI) while she answers or draws
            DeskBox {
                glass: root.living
                visible: root.part === "right" && root.aiText !== ""
                implicitWidth: Math.round(240 * s)
                mark: Kirigami.Theme.focusColor
                breathe: true
                label: String(root.ai.name || "Kakan").toUpperCase() + (root.ai.kind === "image" ? " RITAR" : " ARBETAR")
                text: {
                    const steps = root.ai.steps || [];
                    const now = steps.filter(s => s.state === "run").pop();
                    return (now ? now.text : root.ai.text || "")
                        + (root.ai.progress !== null && root.ai.progress !== undefined ? " " + root.ai.progress + " %" : "")
                        + (root.ai.seconds >= 3 ? "  ·  " + root.ai.seconds + " s" : "");
                }
                onClicked: exec.connectSource("setsid -f goblin-ai >/dev/null 2>&1 < /dev/null")
                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    mainText: root.ai.kind === "image" ? root.ai.name + " ritar en bild" : root.ai.name + " arbetar på ett svar"
                    subText: (root.aiSteps ? root.aiSteps + "\n\n" : "") + (root.ai.local
                        ? "På din dator – grafikkortet arbetar, fläktarna kan låta en stund.\n"
                        : "I molnet – din dator väntar bara på svaret.\n")
                        + "Klicka för att visa Goblin AI"
                }
            }
        }

        RowLayout {
            id: row
            visible: !root.desk
            anchors.verticalCenter: parent.verticalCenter
            spacing: Kirigami.Units.gridUnit

            // In edit mode the widget would otherwise be invisible and impossible to find
            Text {
                visible: root.editMode && full.empty
                text: "Spelas nu"
                color: root.muted
                font: Kirigami.Theme.defaultFont
            }

            // Music: click = play/pause, wheel = next/previous
            Item {
                id: music
                visible: root.songText !== ""
                implicitWidth: musicRow.implicitWidth
                implicitHeight: musicRow.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: musicRow
                    anchors.fill: parent
                    spacing: Math.round(Kirigami.Units.smallSpacing * 1.5)

                    Text {
                        text: root.playing ? "♪" : "❚❚"
                        color: root.playing ? root.accent : root.muted
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pixelSize: root.playing ? Kirigami.Theme.defaultFont.pixelSize * 1.15 : Kirigami.Theme.defaultFont.pixelSize * 0.7
                        Layout.alignment: Qt.AlignVCenter
                    }
                    FadeLabel {
                        text: root.songText
                        color: root.playing ? root.frost : root.muted
                        font: Kirigami.Theme.defaultFont
                        elide: Text.ElideRight
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Kirigami.Units.smallSpacing
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (!root.player) {
                            return;
                        }
                        if (mouse.button === Qt.MiddleButton) {
                            root.player.Raise();
                        } else {
                            root.player.PlayPause();
                        }
                    }
                    onWheel: wheel => {
                        if (!root.player) {
                            return;
                        }
                        if (wheel.angleDelta.y < 0) {
                            root.player.Next();
                        } else if (wheel.angleDelta.y > 0) {
                            root.player.Previous();
                        }
                    }
                }
            }

            Rectangle {
                visible: music.visible && chat.visible
                color: root.line
                implicitWidth: 1
                implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.1)
                Layout.alignment: Qt.AlignVCenter
            }

            // Discord: click = show the Discord window (also when it is closed to the tray)
            Item {
                id: chat
                visible: root.discord !== null
                implicitWidth: chatRow.implicitWidth
                implicitHeight: chatRow.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: chatRow
                    anchors.fill: parent
                    spacing: Math.round(Kirigami.Units.smallSpacing * 1.5)

                    Kirigami.Icon {
                        source: root.discord ? root.discord.icon : ""
                        fallback: "discord"
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                    }
                    FadeLabel {
                        text: root.discord ? root.discord.place : ""
                        color: root.frost
                        font: Kirigami.Theme.defaultFont
                        elide: Text.ElideRight
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Kirigami.Units.smallSpacing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.discord && root.discord.row >= 0) {
                            tasksModel.requestActivate(tasksModel.index(root.discord.row, 0));
                        } else if (root.discord) {
                            exec.connectSource(root.voiceCommand + " show");
                        }
                    }
                }
            }

            Rectangle {
                visible: (music.visible || chat.visible) && steamPart.visible
                color: root.line
                implicitWidth: 1
                implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.1)
                Layout.alignment: Qt.AlignVCenter
            }

            // Steam downloading or processing shaders: click = Steam's downloads
            Item {
                id: steamPart
                visible: root.steamText !== ""
                implicitWidth: steamRow.implicitWidth
                implicitHeight: steamRow.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: steamRow
                    anchors.fill: parent
                    spacing: Math.round(Kirigami.Units.smallSpacing * 1.5)

                    Kirigami.Icon {
                        source: "steam"
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                    }
                    FadeLabel {
                        text: root.steamText
                        color: root.muted
                        font: Kirigami.Theme.defaultFont
                        elide: Text.ElideRight
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    mainText: root.steam.kind === "shader" ? "Steam bearbetar shaders" : "Steam " + (root.steam.phase || "")
                    subText: (root.steam.kind === "shader"
                        ? "Gör " + root.steam.name + " redo så att spelet inte hackar. Det tar mycket processorkraft – fläktarna kan låta en stund.\n"
                        : root.steam.name + "\n") + "Klicka för att visa Steams nedladdningar"
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Kirigami.Units.smallSpacing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: exec.connectSource("setsid -f xdg-open steam://open/downloads >/dev/null 2>&1 < /dev/null")
                }
            }

            Rectangle {
                visible: (music.visible || chat.visible || steamPart.visible) && aiPart.visible
                color: root.line
                implicitWidth: 1
                implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.1)
                Layout.alignment: Qt.AlignVCenter
            }

            // Goblin AI answering or drawing: click = the Goblin AI window
            Item {
                id: aiPart
                visible: root.aiText !== ""
                implicitWidth: aiRow.implicitWidth
                implicitHeight: aiRow.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: aiRow
                    anchors.fill: parent
                    spacing: Math.round(Kirigami.Units.smallSpacing * 1.5)

                    Kirigami.Icon {
                        source: "goblincakes-ai"
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                        // Breathes while it works, so it reads as busy and not as a leftover
                        SequentialAnimation on opacity {
                            running: aiPart.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }
                    FadeLabel {
                        text: root.aiText
                        color: root.ai.local ? root.frost : root.muted
                        font: Kirigami.Theme.defaultFont
                        elide: Text.ElideRight
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    mainText: root.ai.kind === "image" ? root.ai.name + " ritar en bild" : root.ai.name + " arbetar på ett svar"
                    subText: (root.aiSteps ? root.aiSteps + "\n\n" : "") + (root.ai.local
                        ? "På din dator – grafikkortet arbetar, fläktarna kan låta en stund.\n"
                        : "I molnet – din dator väntar bara på svaret.\n")
                        + "Goblin AI-fönstret visas när svaret är klart. Klicka för att visa det nu."
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Kirigami.Units.smallSpacing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: exec.connectSource("setsid -f goblin-ai >/dev/null 2>&1 < /dev/null")
                }
            }

            Rectangle {
                visible: (music.visible || chat.visible || steamPart.visible || aiPart.visible) && batteryPart.visible
                color: root.line
                implicitWidth: 1
                implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.1)
                Layout.alignment: Qt.AlignVCenter
            }

            // Wireless mouse/keyboard/headset battery: click = show or hide the names
            Item {
                id: batteryPart
                visible: root.devices.length > 0
                implicitWidth: batteryRow.implicitWidth
                implicitHeight: batteryRow.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: batteryRow
                    anchors.fill: parent
                    spacing: Kirigami.Units.gridUnit

                    Repeater {
                        model: root.devices
                        delegate: RowLayout {
                            required property var modelData
                            // 24 Oct, the user's choice: green 50–100 %, orange 11–49 %, red at 10 % and below
                            readonly property color level: modelData.percent <= 10 ? Kirigami.Theme.negativeTextColor
                                : modelData.percent < 50 ? Kirigami.Theme.neutralTextColor
                                : Kirigami.Theme.positiveTextColor
                            spacing: Math.round(Kirigami.Units.smallSpacing * 1.5)
                            Layout.alignment: Qt.AlignVCenter

                            Kirigami.Icon {
                                source: root.deviceIcon(modelData.kind)
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: (Plasmoid.configuration.deviceNames ? modelData.name + "  " : "")
                                      + (modelData.charging ? "⚡" : "") + modelData.percent + " %"
                                color: level
                                font.family: Kirigami.Theme.defaultFont.family
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                font.weight: Font.DemiBold // 600, like the clock (24 Oct, the user's choice)
                                elide: Text.ElideRight
                                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }

                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    mainText: "Batteri"
                    subText: root.devices.map(d => d.name + ": " + d.percent + " %"
                                              + (d.charging ? " (laddar)" : "")).join("\n")
                             + "\nKlicka för att " + (Plasmoid.configuration.deviceNames ? "dölja" : "visa") + " namnet"
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Kirigami.Units.smallSpacing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Plasmoid.configuration.deviceNames = !Plasmoid.configuration.deviceNames
                }
            }
        }
    }

    Component.onCompleted: {
        Plasmoid.removeInternalAction("configure");
        try {
            serverNames = JSON.parse(Plasmoid.configuration.discordServers || "{}");
        } catch (e) {
            serverNames = {};
        }
    }
}

