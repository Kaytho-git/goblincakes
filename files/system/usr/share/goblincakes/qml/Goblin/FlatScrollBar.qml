// GOBLINCAKES' scroll bar (shared, Levande utseende step 1): next to its Flickable, drag the handle (and with
// trackClick, press the track to jump). margin 6 (Config, Avinstallera), 4 (GoblinRecorder, GoblinShare), 2 (Dashboard).
import QtQuick

Item {
    id: bar
    required property Flickable flick
    property int margin: 6
    property int endMargin: margin       // above and below (the Dashboard: 0)
    property color trackColor: "#0E1420"
    property bool trackClick: false
    // Levande (Config → Utseende → Stil) and no game running: the changes glide (Levande utseende step 2)
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    readonly property bool needed: flick.visible && flick.contentHeight > flick.height + 1
    anchors { right: flick.right; rightMargin: margin; top: flick.top; topMargin: endMargin; bottom: flick.bottom; bottomMargin: endMargin }
    width: 8
    visible: needed
    z: 2

    Rectangle {
        anchors.fill: parent
        color: bar.trackColor
    }
    MouseArea {
        anchors.fill: parent
        enabled: bar.trackClick
        onPressed: mouse => {
            const ratio = Math.max(0, Math.min(1, (mouse.y - handle.height / 2) / (bar.height - handle.height)));
            bar.flick.contentY = ratio * (bar.flick.contentHeight - bar.flick.height);
        }
    }
    Rectangle {
        id: handle
        width: parent.width
        height: Math.max(32, bar.flick.visibleArea.heightRatio * bar.height)
        y: bar.flick.visibleArea.yPosition / Math.max(0.0001, 1 - bar.flick.visibleArea.heightRatio)
           * (bar.height - height)
        color: handleArea.pressed ? accent.color : handleArea.containsMouse ? "#8B98AD" : "#2A3852"
        Behavior on color { enabled: bar.moving; ColorAnimation { duration: 120 } }
        MouseArea {
            id: handleArea
            anchors.fill: parent
            hoverEnabled: true
            property real startY
            property real startContentY
            onPressed: mouse => {
                startY = mapToItem(bar, 0, mouse.y).y;
                startContentY = bar.flick.contentY;
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const dy = mapToItem(bar, 0, mouse.y).y - startY;
                const span = bar.flick.contentHeight - bar.flick.height;
                bar.flick.contentY = Math.max(0, Math.min(span, startContentY + dy * span / Math.max(1, bar.height - handle.height)));
            }
        }
    }
}
