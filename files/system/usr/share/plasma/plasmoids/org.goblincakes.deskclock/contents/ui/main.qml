/*
    GOBLINCAKES Clock Box – the middle of the dashboard's desktop row (10 Nov, goblincakes-desktop-layout; the
    user's decisions 9 Nov, mockup "Skrivbordet utan docka"): the mouse's/keyboard's/controller's battery –
    ethernet – the clock with the date and week under it – sound – the headset's battery, in one box. Steam,
    Discord, Spelas nu and Kakan are two org.goblincakes.nowplaying widgets either side (config "part").
    The look is ClockBox.qml/DeskIcon.qml (plain Qt Quick); this file reads the values and does the clicks:
      clock    click = the calendar (Plasma's month view, week numbers, Swedish holidays)
      network  nmcli every 10 s; click = System Settings → Wi-Fi & Internet
      sound    wpctl every 2 s; wheel = ±5 %, middle click = mute, click = System Settings → Sound
      battery  /usr/libexec/goblincakes-device-battery every 30 s (like the top bar's Spelas nu), the names in
               the tooltip; headset/headphones/speakers right of the sound, everything else left of the network
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

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
    // ~/.config/goblincakes/utseende (platt/levande, no file = platt), read again every 5 s
    readonly property string lookCommand: "cat \"$HOME/.config/goblincakes/utseende\" 2>/dev/null; true"
    property bool living: false

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
                root.living = out.trim() === "levande";
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
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run(root.netCommand)
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run(root.volumeCommand)
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run(root.batteryCommand)
    }
    Timer {
        id: shownTimer
        interval: 1500
        onTriggered: root.volumeShown = false
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run(root.lookCommand)
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
            subText: "Hjulet = högre/lägre, mittenklick = tyst av/på\nKlicka för ljudinställningarna"
        }
        PlasmaCore.ToolTipArea {
            parent: box.leftItem
            anchors.fill: parent
            mainText: "Batteri"
            subText: root.leftDevices.map(d => d.name + ": " + d.percent + " %" + (d.charging ? " (laddar)" : "")).join("\n")
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

    Component.onCompleted: Plasmoid.removeInternalAction("configure")
}
