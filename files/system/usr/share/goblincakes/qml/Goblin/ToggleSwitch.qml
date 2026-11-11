// GOBLINCAKES' switch (reglage – shared, Levande utseende step 1)
import QtQuick

Rectangle {
    id: sw
    property bool on
    property bool enabledState: true
    signal toggled()
    // Levande (Config → Utseende → Stil) and no game running: the changes glide (Levande utseende step 2)
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    width: 48
    height: 26
    color: on ? accent.color : "transparent"
    border.width: on ? 0 : 1
    border.color: "#2A3852"
    opacity: enabledState ? 1 : 0.35
    Behavior on color { enabled: sw.moving; ColorAnimation { duration: 140 } }
    Rectangle {
        width: 18
        height: 18
        anchors.verticalCenter: parent.verticalCenter
        x: sw.on ? parent.width - width - 4 : 4
        color: sw.on ? accent.on : "#8B98AD"
        // the knob glides in both looks (it always has); Levande: a little softer and the colour fades
        Behavior on x { NumberAnimation { duration: sw.moving ? 160 : 120; easing.type: sw.moving ? Easing.OutCubic : Easing.Linear } }
        Behavior on color { enabled: sw.moving; ColorAnimation { duration: 140 } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: sw.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (sw.enabledState) sw.toggled()
    }
}
