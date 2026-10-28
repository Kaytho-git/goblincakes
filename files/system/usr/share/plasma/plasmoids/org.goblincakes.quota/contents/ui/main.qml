/*
    GOBLINCAKES Quota – two small bars in the top bar: how much of the 5-hour limit is used in
    Claude (left) and ChatGPT/Codex (right). Orange from 75 %, red from 90 %. Click = a box with
    both services' 5 h and week in % and when they reset.
    /usr/libexec/goblincakes-quota fetches (every 5 minutes and when the box opens) and saves
    ~/.cache/goblincakes/quota.json; at start the saved file is shown at once (--cached).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color frost: "#E6ECF5"
    readonly property color muted: "#8B98AD"
    readonly property color line: "#2A3852"
    readonly property color accent: Kirigami.Theme.focusColor // the accent chosen in Config → Utseende
    readonly property color warn: "#F0883E"
    readonly property color full: "#F85149"

    readonly property string helper: "/usr/libexec/goblincakes-quota"
    readonly property string fetchCommand: helper
    readonly property string cachedCommand: helper + " --cached"

    property var services: []
    property int updated: 0
    property bool fetching: false
    property double now: Date.now() / 1000

    function service(id) {
        return services.find(s => s.id === id) || null;
    }
    function percent(s, label) {
        const w = s ? (s.windows || []).find(w => w.label === label) : null;
        return w ? w.percent : -1;
    }
    function colourFor(p) {
        return p >= 90 ? full : p >= 75 ? warn : accent;
    }
    function clock(epoch) {
        return Qt.formatTime(new Date(epoch * 1000), "HH:mm");
    }
    // "kl 20:10" today, "tis 4 nov 07:00" another day
    function when(epoch) {
        const d = new Date(epoch * 1000);
        if (d.toDateString() === new Date().toDateString())
            return "kl " + clock(epoch);
        return d.toLocaleString(Qt.locale("sv_SE"), "ddd d MMM HH:mm");
    }
    // "om 3 h 20 min", "om 6 d 14 h"
    function left(epoch) {
        const m = Math.max(0, Math.round((epoch - now) / 60));
        if (m < 60)
            return "om " + m + " min";
        if (m < 24 * 60)
            return "om " + Math.floor(m / 60) + " h " + (m % 60) + " min";
        return "om " + Math.floor(m / 1440) + " d " + Math.floor((m % 1440) / 60) + " h";
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            try {
                const state = JSON.parse(data["stdout"] || "{}");
                if (state.services) {
                    root.services = state.services;
                    root.updated = state.updated || 0;
                }
            } catch (e) {
            }
            if (source === root.fetchCommand)
                root.fetching = false;
            disconnectSource(source);
        }
    }

    function fetch() {
        if (fetching)
            return;
        fetching = true;
        exec.connectSource(fetchCommand);
    }

    Component.onCompleted: {
        exec.connectSource(cachedCommand);
        fetch();
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.fetch()
    }
    // The countdowns in the box
    Timer {
        interval: 30000
        running: root.expanded
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now() / 1000
    }
    onExpandedChanged: if (expanded) fetch()

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: "Kvot (5 h)"
    toolTipSubText: services.map(s => {
        const p = percent(s, "5 h");
        return (s.id === "codex" ? "ChatGPT" : s.name) + ": " + (p < 0 ? "kunde inte läsas" : p + " %");
    }).join("\n")

    compactRepresentation: Item {
        Layout.minimumWidth: bars.width + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true

        Row {
            id: bars
            anchors.centerIn: parent
            spacing: Math.round(Kirigami.Units.iconSizes.small / 8)

            Repeater {
                model: ["claude", "codex"]
                // A thin square frame filled from below
                Rectangle {
                    required property string modelData
                    readonly property int p: root.percent(root.service(modelData), "5 h")
                    width: Math.round(Kirigami.Units.iconSizes.small * 0.36)
                    height: Kirigami.Units.iconSizes.small
                    color: "transparent"
                    border.width: 1
                    border.color: p < 0 ? root.line : root.muted
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 2
                        height: Math.round((parent.height - 4) * Math.min(100, Math.max(0, parent.p)) / 100)
                        color: root.colourFor(parent.p)
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 19
        Layout.preferredHeight: box.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight

        ColumnLayout {
            id: box
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Text {
                text: "KVOT"
                color: root.frost
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                font.letterSpacing: 1
            }

            Text {
                visible: root.services.length === 0
                text: root.fetching ? "Läser …" : "Kunde inte läsas"
                color: root.muted
                font: Kirigami.Theme.defaultFont
            }

            Repeater {
                model: root.services
                ColumnLayout {
                    id: part
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: part.modelData.name.toUpperCase()
                            color: root.frost
                            font.family: "Chakra Petch"
                            font.weight: Font.DemiBold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                            font.letterSpacing: 1
                            Layout.fillWidth: true
                        }
                        Text {
                            text: part.modelData.plan || ""
                            color: root.muted
                            font: Kirigami.Theme.smallFont
                        }
                    }

                    Repeater {
                        model: part.modelData.windows || []
                        ColumnLayout {
                            id: win
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: win.modelData.label
                                    color: root.muted
                                    font: Kirigami.Theme.defaultFont
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                }
                                // Flat square bar
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 0.5)
                                    color: "#12203A"
                                    border.width: 1
                                    border.color: root.line
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: Math.round(parent.width * Math.min(100, win.modelData.percent) / 100)
                                        color: root.colourFor(win.modelData.percent)
                                    }
                                }
                                Text {
                                    text: win.modelData.percent + " %"
                                    color: root.frost
                                    font.family: "IBM Plex Mono"
                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.6
                                }
                            }
                            Text {
                                visible: win.modelData.resets > 0
                                text: win.modelData.resets <= root.now ? "Nollställd"
                                    : "Nollställs " + root.when(win.modelData.resets) + " (" + root.left(win.modelData.resets) + ")"
                                color: root.muted
                                font: Kirigami.Theme.smallFont
                                Layout.leftMargin: Kirigami.Units.gridUnit * 3 + Kirigami.Units.smallSpacing
                            }
                        }
                    }

                    // Old values or the session log: say so, and why
                    Text {
                        readonly property var s: part.modelData
                        visible: text !== ""
                        text: s.error ? "Kunde inte läsas: " + s.error + (s.stale ? " – visar värden från " + root.when(s.stale) : "")
                            : s.source === "log" ? "Från Codex senaste session (" + root.when(s.logTime) + ")"
                            : ""
                        color: s.error ? root.warn : root.muted
                        font: Kirigami.Theme.smallFont
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.fetching ? "Läser …" : root.updated ? "Uppdaterad " + root.clock(root.updated) : ""
                    color: root.muted
                    font: Kirigami.Theme.smallFont
                    Layout.fillWidth: true
                }
                Text {
                    text: "UPPDATERA"
                    color: refresh.containsMouse ? root.frost : root.accent
                    font.family: "Chakra Petch"
                    font.weight: Font.DemiBold
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.letterSpacing: 1
                    MouseArea {
                        id: refresh
                        anchors.fill: parent
                        anchors.margins: -Kirigami.Units.smallSpacing
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fetch()
                    }
                }
            }
        }
    }
}
