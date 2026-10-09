/*
    GOBLINCAKES Updates – a green arrow in the top bar when there is something new:
    a newer GOBLINCAKES version, one already fetched that needs a restart, or Flatpak
    programs. Hover = what; click = GOBLINCAKES Config → Uppdatera. Nothing new = no space taken.
    /usr/libexec/goblincakes-updates check (timer at login and every 4 hours, and after
    goblin update) writes ~/.cache/goblincakes/updates.json; this only reads it.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color green: "#3FB950"
    readonly property bool editMode: Plasmoid.containment.corona?.editMode ?? false

    property string system: ""      // "new", "staged" or ""
    property var flatpaks: []
    // "staged" (fetched, waiting for a restart) shows no arrow: nothing left to update.
    // goblincakes-updates gives a notice instead when it was fetched in the background.
    readonly property bool available: system === "new" || flatpaks.length > 0

    readonly property string readCommand: "cat \"$HOME/.cache/goblincakes/updates.json\" 2>/dev/null"

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.readCommand) {
                try {
                    const state = JSON.parse(data["stdout"]);
                    root.system = state.system || "";
                    root.flatpaks = state.flatpaks || [];
                } catch (e) {
                    root.system = "";
                    root.flatpaks = [];
                }
            }
            disconnectSource(source);
        }
    }

    // The file changes at most every few hours – reading it twice a minute is plenty
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource(root.readCommand)
    }

    function openUpdate() {
        exec.connectSource("setsid -f goblincakes-config --tab update >/dev/null 2>&1 < /dev/null");
    }

    preferredRepresentation: fullRepresentation
    // Drawn straight in the bar, so Plasma's own applet tooltip isn't shown: our own ToolTipArea
    toolTipMainText: ""
    toolTipSubText: ""
    readonly property string tipTitle: available ? "Uppdateringar finns" : ""
    readonly property string tipText: {
        const lines = [];
        if (system === "new")
            lines.push("Ny GOBLINCAKES-version");
        if (flatpaks.length > 0) {
            const shown = flatpaks.slice(0, 3).join(", ");
            lines.push(flatpaks.length === 1 ? "Program: " + shown
                       : flatpaks.length + " program: " + shown + (flatpaks.length > 3 ? " …" : ""));
        }
        if (lines.length > 0)
            lines.push("Klicka för att uppdatera");
        return lines.join("\n");
    }

    fullRepresentation: Item {
        readonly property bool shown: root.available || root.editMode
        Layout.minimumWidth: shown ? arrow.width + Kirigami.Units.smallSpacing * 2 : 0
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        visible: shown

        // Green arrow up on a short bar ("update"), drawn – no icon theme needed
        Canvas {
            id: arrow
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            opacity: root.available ? 1 : 0.4  // edit mode without updates: dimmed placeholder
            onPaint: {
                const ctx = getContext("2d");
                const s = width / 16;
                ctx.reset();
                ctx.fillStyle = root.green;
                ctx.beginPath();          // head
                ctx.moveTo(8 * s, 1 * s);
                ctx.lineTo(14 * s, 7.5 * s);
                ctx.lineTo(2 * s, 7.5 * s);
                ctx.closePath();
                ctx.fill();
                ctx.fillRect(6 * s, 7 * s, 4 * s, 5 * s);    // shaft
                ctx.fillRect(2 * s, 13.5 * s, 12 * s, 1.5 * s); // bar
            }
        }

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: root.tipTitle
            subText: root.tipText
            active: root.available
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.available
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openUpdate()
        }
    }
}
