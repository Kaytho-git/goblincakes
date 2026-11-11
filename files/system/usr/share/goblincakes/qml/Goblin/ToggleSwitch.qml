// GOBLINCAKES' switch (reglage – shared, Levande utseende step 1)
import QtQuick

Rectangle {
    id: sw
    property bool on
    property bool enabledState: true
    signal toggled()
    width: 48
    height: 26
    color: on ? accent.color : "transparent"
    border.width: on ? 0 : 1
    border.color: "#2A3852"
    opacity: enabledState ? 1 : 0.35
    Rectangle {
        width: 18
        height: 18
        anchors.verticalCenter: parent.verticalCenter
        x: sw.on ? parent.width - width - 4 : 4
        color: sw.on ? accent.on : "#8B98AD"
        Behavior on x { NumberAnimation { duration: 120 } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: sw.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (sw.enabledState) sw.toggled()
    }
}
