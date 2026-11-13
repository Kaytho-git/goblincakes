/*
    One box of the desktop row (the dashboard layout, goblincakes-desktop-layout): a small label in capitals
    over one line of text, and a coloured square – like the mockup "Skrivbordet utan docka" (9 Nov). Left of
    the clock the text and the square sit on the right side (alignRight), right of it on the left side.
    Plain Qt Quick (no Plasma imports), so it can be tried without a desktop.
*/
import QtQuick

Rectangle {
    id: box
    property string label
    property string text
    property color mark: "#2F6FED"
    property bool dim: false          // nothing going on: the text and the square muted
    property bool alignRight: false
    property bool breathe: false      // the square breathes while something works (Kakan)
    readonly property bool hovered: area.hot
    // The size (10 Nov, the user: too big; 11 Nov: 20 % smaller again, both looks) – the same s as the clock box;
    // main.qml's widths are times s too
    property real s: 0.6
    // Stil: Levande (Levande utseende step 6, 11 Nov – the user: "ingen ram"): tinted glass instead of the dark box –
    // #0B1018 at 62 %, no frame, a faint light line in the top edge. Platt: the dark box with its frame as before.
    property bool glass: false
    signal clicked(int button)
    signal wheeled(int delta)

    implicitWidth: Math.round(300 * s)
    implicitHeight: Math.round(48 * s)
    color: glass ? Qt.rgba(0.043, 0.063, 0.094, area.hot ? 0.74 : 0.62) : "#0B1018"
    border.width: glass ? 0 : 1
    border.color: area.hot ? "#2A3852" : "#1E2A40"
    Rectangle {
        visible: box.glass
        width: parent.width
        height: 1
        color: Qt.rgba(0.902, 0.925, 0.961, box.hovered ? 0.12 : 0.07)
    }

    Row {
        id: inner
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.round(16 * box.s)
        anchors.rightMargin: Math.round(16 * box.s)
        spacing: Math.round(12 * box.s)
        layoutDirection: box.alignRight ? Qt.RightToLeft : Qt.LeftToRight

        Rectangle {
            id: square
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(10 * box.s)
            height: Math.round(10 * box.s)
            color: box.mark
            opacity: box.dim ? 0.35 : 1
            SequentialAnimation on opacity {
                running: box.breathe && box.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: inner.width - square.width - inner.spacing
            spacing: 1
            Text {
                width: parent.width
                text: box.label
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: Math.max(9, Math.round(11 * box.s))
                font.letterSpacing: 1
                elide: box.alignRight ? Text.ElideLeft : Text.ElideRight
                horizontalAlignment: box.alignRight ? Text.AlignRight : Text.AlignLeft
            }
            Text {
                width: parent.width
                text: box.text
                color: box.dim ? "#8B98AD" : "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.pixelSize: Math.max(9, Math.round(14 * box.s))
                elide: Text.ElideRight
                horizontalAlignment: box.alignRight ? Text.AlignRight : Text.AlignLeft
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // After a click the window it opens takes the mouse and no "exited" comes – the mark stayed lit (13 Nov):
        // dark after a click until the mouse moves over it again
        property bool stale: false
        property double clickedAt: 0
        readonly property bool hot: containsMouse && !stale
        onPositionChanged: if (Date.now() - clickedAt > 400) stale = false
        onExited: stale = false
        onClicked: mouse => { stale = true; clickedAt = Date.now(); box.clicked(mouse.button); }
        onWheel: wheel => box.wheeled(wheel.angleDelta.y)
    }
}
