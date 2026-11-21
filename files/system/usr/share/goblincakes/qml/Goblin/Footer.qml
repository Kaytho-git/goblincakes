// The bottom row of a window (docs/ux/norm.md 4 and 6, 22 Nov): a line and a band over the whole width, the text
// (`info: [ … ]`) and the buttons (`actions: [ … ]`) at the edges of the centred page – not 1 800 px apart in a
// maximized window.
import QtQuick

Rectangle {
    id: foot
    property int maxWidth: Norm.page
    property int sideMargin: Norm.margin
    property alias info: leftSlot.data
    property alias actions: rightSlot.data
    readonly property alias page: pageItem
    height: 84
    color: "#0B1018"

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: "#1E2A40"
    }

    Item {
        id: pageItem
        x: Norm.pageX(foot.width, foot.maxWidth, foot.sideMargin)
        width: Norm.pageWidth(foot.width, foot.maxWidth, foot.sideMargin)
        height: parent.height

        Item {
            id: leftSlot
            anchors { left: parent.left; right: rightSlot.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
            height: childrenRect.height
        }
        Row {
            id: rightSlot
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 12
        }
    }
}
