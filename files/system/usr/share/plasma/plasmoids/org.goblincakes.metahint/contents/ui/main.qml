/*
    GOBLINCAKES Meta hint (11 Nov, the user: the mockup's hint, "bara de första gångerna"): low in the middle of the
    desktop in the dashboard layout – "Ingen docka, inget toppfält – tryck Meta för dashboarden", in a dashed box as
    in the mockup "Skrivbordet utan docka". Put on the desktop by goblincakes-desktop-layout; gone once the dashboard
    has been shown 3 times (goblin-dashboard counts in ~/.local/state/goblincakes/dashboard-shown, read every 10 s;
    the helper takes the widget away at the next login). Platt: a dark box with a dashed frame; Stil Levande: tinted
    glass without a frame, as the desktop row.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property int enough: 3
    property int shown: 0
    property bool living: false
    readonly property string shownCommand: "cat \"${XDG_STATE_HOME:-$HOME/.local/state}/goblincakes/dashboard-shown\" 2>/dev/null; true"
    readonly property string lookCommand: "cat \"$HOME/.config/goblincakes/utseende\" 2>/dev/null; true"

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const out = String(data["stdout"] || "").trim();
            if (source === root.shownCommand) {
                root.shown = parseInt(out) || 0;
            } else if (source === root.lookCommand) {
                root.living = out === "levande";
            }
            disconnectSource(source);
        }
    }
    Timer {
        interval: 10000
        running: root.shown < root.enough
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            exec.connectSource(root.shownCommand);
            exec.connectSource(root.lookCommand);
        }
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    fullRepresentation: Item {
        Layout.preferredWidth: hint.implicitWidth
        Layout.preferredHeight: hint.implicitHeight
        Layout.minimumWidth: hint.implicitWidth
        Layout.minimumHeight: hint.implicitHeight

        Rectangle {
            id: hint
            anchors.centerIn: parent
            visible: root.shown < root.enough
            implicitWidth: words.implicitWidth + 36
            implicitHeight: words.implicitHeight + 20
            // Platt: the dark box with the mockup's dashed frame; Levande: tinted glass without a frame, as the row
            color: root.living ? Qt.rgba(0.043, 0.063, 0.094, 0.62) : "#0B1018"
            Shape {
                anchors.fill: parent
                visible: !root.living
                ShapePath {
                    strokeColor: "#2A3A58"
                    strokeWidth: 1
                    fillColor: "transparent"
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [4, 3]
                    startX: 0.5; startY: 0.5
                    PathLine { x: hint.width - 0.5; y: 0.5 }
                    PathLine { x: hint.width - 0.5; y: hint.height - 0.5 }
                    PathLine { x: 0.5; y: hint.height - 0.5 }
                    PathLine { x: 0.5; y: 0.5 }
                }
            }
            Text {
                id: words
                anchors.centerIn: parent
                textFormat: Text.StyledText
                text: "Ingen docka, inget toppfält – tryck <b><font color=\"#E6ECF5\">Meta</font></b> för dashboarden"
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 14
            }
        }
    }

    Component.onCompleted: Plasmoid.removeInternalAction("configure")
}
