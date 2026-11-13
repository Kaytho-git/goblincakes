/*
    GOBLINCAKES Clock Box – the middle of the dashboard's desktop row (10 Nov, goblincakes-desktop-layout; the
    user's decisions 9 Nov, mockup "Skrivbordet utan docka"): the mouse's/keyboard's/controller's battery –
    ethernet – the clock with the date and week under it – sound – the headset's battery, in one box. Steam,
    Discord, Spelas nu and Kakan are two org.goblincakes.nowplaying widgets either side (config "part").
    The look is ClockBox.qml/DeskIcon.qml (plain Qt Quick); this file reads the values and does the clicks:
      clock    click = the calendar (Plasma's month view, week numbers, Swedish holidays)
      network  nmcli every 10 s; click = System Settings → Wi-Fi & Internet
      sound    wpctl every 6 s and when the pointer comes over it; wheel = ±5 %, middle click = mute, click = System Settings → Sound
      battery  /usr/libexec/goblincakes-device-battery every 30 s (like the top bar's Spelas nu), the names in
               the tooltip; headset/headphones/speakers right of the sound, everything else left of the network
      Kakan    (13 Nov) Ollama's /api/ps every 10 s straight over HTTP (no process), not at all while a game has
               stopped her (goblincakes-ollama-paused, watched); hidden without local AI (no ollama.json);
               click = goblincakes-ollama wake: Goblin AI opens, the everyday model is loaded, she greets aloud
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import QtCore
import Qt.labs.folderlistmodel

PlasmoidItem {
    id: root

    // ISO 8601 week (as org.goblincakes.week): the week with the year's first Thursday is week 1
    function isoWeek(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        const day = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
    }

    property date now: new Date()
    property var net: ({ kind: "ethernet", name: "" })
    property int volume: -1
    property bool muted: false
    property bool volumeShown: false
    property var devices: []
    readonly property var rightKinds: ["headset", "headphones", "speakers"]
    readonly property var leftDevices: devices.filter(d => rightKinds.indexOf(d.kind) < 0)
    readonly property var rightDevices: devices.filter(d => rightKinds.indexOf(d.kind) >= 0)

    readonly property string netCommand: "nmcli -t -f TYPE,STATE,CONNECTION device status"
    readonly property string volumeCommand: "wpctl get-volume @DEFAULT_AUDIO_SINK@"
    readonly property string batteryCommand: "/usr/libexec/goblincakes-device-battery"
    // Stil (Config → Utseende): Levande = tinted glass on the desktop row (Levande utseende step 6) – the file
    // ~/.config/goblincakes/utseende (platt/levande, no file = platt), read again when it changes
    readonly property string lookCommand: "cat \"$HOME/.config/goblincakes/utseende\" 2>/dev/null; "
        + "[ -e \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/goblincakes-gaming\" ] && echo spel; "
        + "echo \"namn=$(head -c 40 \"$HOME/.config/goblincakes/ai-name\" 2>/dev/null)\"; true"
    property bool living: false
    property string aiName: "Kakan"       // Goblin AI → name (ai-name)
    // Optimization P1 (11 Nov): while a game runs the reads are three times sparser – the game covers the row
    property bool gaming: false
    readonly property int slow: gaming ? 3 : 1

    // Kakan (local AI): installed = ~/.config/goblincakes/ollama.json, paused = the service stopped her for a game
    property bool kakanInstalled: false
    property bool kakanPaused: false
    property bool kakanAnswers: false
    property var kakanModels: []          // [{name, expires_at, size_vram}] from /api/ps
    property bool kakanWaking: false      // clicked: "Laddar" until she is in memory (at most 5 min)
    // Goblin AI answers right now ($XDG_RUNTIME_DIR/goblincakes-ai/*.json, goblinai.activity) – while the local AI
    // rests for a game that goes to a cloud service: "Molnet" instead of "Vilar" (13 Nov, the user's wish)
    property bool kakanBusy: false
    // The folder is made by the first question after login – made here first, then watched (a missing folder isn't)
    readonly property string aiFolderCommand: "mkdir -p \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/goblincakes-ai\"; echo ok"
    property string aiFolder: ""
    readonly property string kakan: !kakanInstalled ? ""
        : kakanPaused ? (kakanBusy ? "cloud" : "resting")
        : kakanModels.length > 0 ? "ready"
        : kakanWaking ? "loading"
        : kakanAnswers ? "idle" : "off"
    function readKakan() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            let models = [];
            try {
                models = xhr.status === 200 ? (JSON.parse(xhr.responseText).models || []) : [];
            } catch (e) {
                models = [];
            }
            root.kakanAnswers = xhr.status === 200;
            root.kakanModels = models;
            if (models.length > 0) {
                root.kakanWaking = false;
            }
        };
        xhr.open("GET", "http://127.0.0.1:11434/api/ps");
        xhr.timeout = 3000;
        xhr.send();
    }
    function kakanTip() {
        if (kakan === "cloud") {
            return "Den lokala AI:n vilar medan spelet kör – " + aiName + " svarar via en molntjänst just nu\nKlicka för Goblin AI";
        }
        if (kakan === "resting") {
            return "Vilar medan spelet kör – laddas in igen när spelet är stängt\nKlicka för Goblin AI";
        }
        if (kakan === "ready") {
            return kakanModels.map(m => m.name + " i minnet till "
                + Qt.formatTime(new Date(m.expires_at), "HH:mm")).join("\n") + "\nKlicka för Goblin AI";
        }
        if (kakan === "loading") {
            return "Laddas in i grafikminnet …";
        }
        if (kakan === "idle") {
            return "Inte i minnet – första svaret tar en stund\nKlicka för att ladda henne och öppna Goblin AI";
        }
        return "Den lokala AI:n svarar inte\nKlicka för Goblin AI";
    }

    // nmcli -t: fields split by ":", a ":" inside a name written as "\:"
    function fields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (line[i] === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += line[i];
            }
        }
        out.push(cur);
        return out;
    }

    // Ethernet first, then wifi; "connected (externally)" (bridges, the loopback) doesn't count
    function readNet(text) {
        let wifi = null;
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const f = fields(lines[i]);
            if (f.length < 3 || f[1] !== "connected") {
                continue;
            }
            if (f[0] === "ethernet") {
                return { kind: "ethernet", name: f[2] };
            }
            if (f[0] === "wifi" && !wifi) {
                wifi = { kind: "wifi", name: f[2] };
            }
        }
        return wifi || { kind: "offline", name: "" };
    }

    function run(command) {
        exec.connectSource(command);
    }

    function changeVolume(delta) {
        if (delta === 0) {
            return;
        }
        run("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + (delta > 0 ? "5%+" : "5%-") + " && " + volumeCommand);
        volumeShown = true;
        shownTimer.restart();
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const out = data["stdout"] || "";
            if (source === root.netCommand) {
                root.net = root.readNet(out);
            } else if (source.indexOf(root.volumeCommand) >= 0) {
                const m = /Volume:\s*([0-9.]+)/.exec(out);
                root.volume = m ? Math.round(parseFloat(m[1]) * 100) : -1;
                root.muted = out.indexOf("[MUTED]") >= 0;
            } else if (source === root.lookCommand) {
                const lines = out.split("\n").map(l => l.trim());
                root.living = lines[0] === "levande";
                root.gaming = lines.indexOf("spel") >= 0;
                const named = lines.find(l => l.indexOf("namn=") === 0);
                root.aiName = named && named.length > 5 ? named.slice(5) : "Kakan";
            } else if (source === root.aiFolderCommand) {
                root.aiFolder = StandardPaths.writableLocation(StandardPaths.RuntimeLocation) + "/goblincakes-ai";
            } else if (source === root.batteryCommand) {
                try {
                    root.devices = JSON.parse(out || "[]");
                } catch (e) {
                    root.devices = [];
                }
            }
            disconnectSource(source);
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
    Timer {
        interval: 10000 * root.slow
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run(root.netCommand)
    }
    // Every 6 s (P7.4, 12 Nov – was 2 s): the icon shows the level, so it is read without a click too;
    // after a change here and on hover at once
    Timer {
        interval: 6000 * root.slow
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run(root.volumeCommand)
    }
    Timer {
        interval: 30000 * root.slow
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run(root.batteryCommand)
    }
    Timer {
        interval: (root.kakanWaking ? 2000 : 10000) * root.slow
        running: root.kakanInstalled && !root.kakanPaused
        repeat: true
        triggeredOnStart: true
        onTriggered: root.readKakan()
    }
    Timer {
        id: wakingTimer
        interval: 300000
        onTriggered: root.kakanWaking = false
    }
    Timer {
        id: shownTimer
        interval: 1500
        onTriggered: root.volumeShown = false
    }

    // Read when the style file or the game guard's file changes (the folders are watched – no process), and every
    // 60 s in case a change was missed (12 Nov – was a process every 5 s in each widget)
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run(root.lookCommand)
    }
    FolderListModel {
        folder: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/goblincakes"
        nameFilters: ["utseende"]
        showDirs: false
        onCountChanged: root.run(root.lookCommand)
        onDataChanged: root.run(root.lookCommand)
    }
    FolderListModel {
        folder: StandardPaths.writableLocation(StandardPaths.RuntimeLocation)
        nameFilters: ["goblincakes-gaming"]
        showDirs: false
        onCountChanged: root.run(root.lookCommand)
    }
    FolderListModel {
        folder: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/goblincakes"
        nameFilters: ["ollama.json"]
        showDirs: false
        onCountChanged: root.kakanInstalled = count > 0
    }
    FolderListModel {
        folder: StandardPaths.writableLocation(StandardPaths.RuntimeLocation)
        nameFilters: ["goblincakes-ollama-paused"]
        showDirs: false
        onCountChanged: {
            root.kakanPaused = count > 0;
            if (count === 0) {
                root.readKakan();
            }
        }
    }
    FolderListModel {
        folder: root.aiFolder
        nameFilters: ["*.json"]
        showDirs: false
        onCountChanged: {
            root.kakanBusy = count > 0;
            // A file left by a Goblin AI that crashed: the helper removes it (and nothing else)
            if (count > 0 && root.kakanPaused) {
                root.run("/usr/libexec/goblincakes-ai-activity >/dev/null; true");
            }
        }
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    compactRepresentation: Item {
        Layout.minimumWidth: box.implicitWidth
        Layout.preferredWidth: box.implicitWidth
        Layout.maximumWidth: box.implicitWidth
        Layout.fillHeight: true

        ClockBox {
            id: box
            anchors.centerIn: parent
            glass: root.living
            now: root.now
            week: root.isoWeek(root.now)
            net: root.net
            volume: root.volume
            muted: root.muted
            volumeShown: root.volumeShown
            leftDevices: root.leftDevices
            rightDevices: root.rightDevices
            onClockClicked: root.expanded = !root.expanded
            onNetClicked: root.run("setsid -f systemsettings kcm_networkmanagement >/dev/null 2>&1 < /dev/null")
            onSoundClicked: button => {
                if (button === Qt.MiddleButton) {
                    root.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && " + root.volumeCommand);
                    root.volumeShown = true;
                    shownTimer.restart();
                } else {
                    root.run("setsid -f systemsettings kcm_pulseaudio >/dev/null 2>&1 < /dev/null");
                }
            }
            onSoundWheeled: delta => root.changeVolume(delta)
            kakan: root.kakan
            accent: Kirigami.Theme.focusColor   // the accent chosen in Config → Utseende
            onKakanClicked: {
                if (root.kakan === "idle") {
                    root.kakanWaking = true;
                    wakingTimer.restart();
                }
                root.run("setsid -f /usr/libexec/goblincakes-ollama wake >/dev/null 2>&1 < /dev/null");
            }
        }

        PlasmaCore.ToolTipArea {
            parent: box.clockItem
            anchors.fill: parent
            mainText: Qt.locale("sv_SE").toString(root.now, "dddd d MMMM yyyy")
            subText: "Vecka " + root.isoWeek(root.now) + "\nKlicka för kalendern"
        }
        PlasmaCore.ToolTipArea {
            parent: box.netItem
            anchors.fill: parent
            mainText: root.net.kind === "ethernet" ? "Ethernet" : root.net.kind === "wifi" ? "Wi-Fi" : "Inte ansluten"
            subText: (root.net.name ? root.net.name + "\n" : "") + "Klicka för nätverksinställningarna"
        }
        PlasmaCore.ToolTipArea {
            parent: box.soundItem
            anchors.fill: parent
            mainText: root.volume < 0 ? "Inget ljud" : "Ljud " + root.volume + " %" + (root.muted ? " (tyst)" : "")
            onContainsMouseChanged: if (containsMouse) root.run(root.volumeCommand)
            subText: "Hjulet = högre/lägre, mittenklick = tyst av/på\nKlicka för ljudinställningarna"
        }
        PlasmaCore.ToolTipArea {
            parent: box.leftItem
            anchors.fill: parent
            mainText: "Batteri"
            subText: root.leftDevices.map(d => d.name + ": " + d.percent + " %" + (d.charging ? " (laddar)" : "")).join("\n")
        }
        PlasmaCore.ToolTipArea {
            parent: box.kakanItem
            anchors.fill: parent
            mainText: root.aiName
            subText: root.kakanTip()
            onContainsMouseChanged: if (containsMouse && root.kakan !== "" && root.kakan !== "resting") root.readKakan()
        }
        PlasmaCore.ToolTipArea {
            parent: box.rightItem
            anchors.fill: parent
            mainText: "Batteri"
            subText: root.rightDevices.map(d => d.name + ": " + d.percent + " %" + (d.charging ? " (laddar)" : "")).join("\n")
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 20
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Loader {
            anchors.fill: parent
            active: root.expanded
            source: "CalendarView.qml"
        }
    }

    Component.onCompleted: {
        Plasmoid.removeInternalAction("configure");
        root.run(root.aiFolderCommand);
    }
}
