// The light on a frame (Levande utseende step 3, 11 Nov) – only with Stil: Levande. Put first in a frame
// (a Rectangle with a 1 px border): `G.Light {}`; G.Frame has it already.
//   - a faint light from above: frost 3.5 % → 0 over the top of the frame, and a 1 px line inside the top edge (5 %)
//   - hovered: a 2 px accent line in the top edge while it is true – bind it to the card's own MouseArea
//     (`G.Light { hovered: cardArea.containsMouse }`; a HoverHandler here gets nothing under a hovering MouseArea)
//   - a glow in the accent colour around the frame whenever its border is the accent (chosen, or under the mouse)
// Static light: it stays on during a game (nothing moves – only the fades are left out then).
import QtQuick

Item {
    id: light
    readonly property bool living: typeof look !== "undefined" && !!look && look.living === true
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    readonly property Item box: parent
    property bool hovered: false
    readonly property bool lit: living && !!box && box.border !== undefined && box.border.width > 0
                                && Qt.colorEqual(box.border.color, accent.color)
    width: box ? box.width : 0
    height: box ? box.height : 0
    visible: living

    // Light from above
    Rectangle {
        x: 1
        y: 1
        width: Math.max(0, parent.width - 2)
        height: Math.min(44, parent.height * 0.5)
        visible: parent.height >= 40
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.902, 0.925, 0.961, 0.035) }
            GradientStop { position: 1; color: Qt.rgba(0.902, 0.925, 0.961, 0) }
        }
    }
    Rectangle {
        x: 1
        y: 1
        width: Math.max(0, parent.width - 2)
        height: 1
        color: Qt.rgba(0.902, 0.925, 0.961, 0.05)
    }
    // The accent line in the top edge under the mouse
    Rectangle {
        width: parent.width
        height: 2
        color: accent.color
        opacity: light.hovered ? 1 : 0
        Behavior on opacity { enabled: light.moving; NumberAnimation { duration: 140 } }
    }
    // The glow: three thin rings outside the frame, fainter outwards
    Repeater {
        model: 3
        Rectangle {
            required property int index
            readonly property int out: index + 1
            x: -out
            y: -out
            width: light.width + 2 * out
            height: light.height + 2 * out
            color: "transparent"
            border.width: 1
            border.color: accent.color
            opacity: light.lit ? [0.28, 0.14, 0.06][index] : 0
            Behavior on opacity { enabled: light.moving; NumberAnimation { duration: 160 } }
        }
    }
}
