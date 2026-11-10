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
    readonly property bool hovered: area.containsMouse
    // The size (10 Nov, the user: too big) – the same s as the clock box; main.qml's widths are times s too
    property real s: 0.75
    signal clicked(int button)
    signal wheeled(int delta)

    implicitWidth: Math.round(300 * s)
    implicitHeight: Math.round(48 * s)
    color: "#0B1018"
    border.width: 1
    border.color: area.containsMouse ? "#2A3852" : "#1E2A40"

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
                font.pixelSize: Math.round(14 * box.s)
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
        onClicked: mouse => box.clicked(mouse.button)
        onWheel: wheel => box.wheeled(wheel.angleDelta.y)
    }
}
