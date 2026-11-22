// A program card (docs/ux/norm.md 6, granskning #15, 22 Nov) – Config's programs and Avinstallera's, before two
// copies: an icon to the left (`icon: Monogram { … }` / AppIcon), the name, up to three lines of description, a tick
// box top right, the whole card clickable. Children of the card (Config's switches at the bottom) go on top of it.
//   checked     – the tick box                  selected / tone – the frame in that colour (chosen, or red: goes)
//   tickColor   – the filled tick box's colour  interactive – hover and a pointing hand (false: installed, nothing to do)
import QtQuick

Rectangle {
    id: card
    property string title
    property string description
    property color descriptionColor: "#8B98AD"
    property bool checked: false
    property color tickColor: accent.color
    property color tickMark: accent.on
    property bool selected: checked
    property color tone: accent.color
    property bool interactive: true
    property alias icon: iconSlot.data
    readonly property alias hovered: area.containsMouse
    signal clicked()

    height: 112
    color: area.containsMouse && interactive ? "#111A2A" : "#0E1420"
    border.width: 1
    border.color: selected ? tone : area.containsMouse && interactive ? "#2A3852" : "#1E2A40"

    Light { hovered: area.containsMouse && card.interactive }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: card.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (card.interactive) card.clicked()
    }

    Item {
        id: iconSlot
        anchors { left: parent.left; leftMargin: 18; top: parent.top; topMargin: 20 }
        width: childrenRect.width
        height: childrenRect.height
    }

    Column {
        anchors {
            left: iconSlot.right; leftMargin: 16
            right: tick.left; rightMargin: 14
            top: parent.top; topMargin: 18
        }
        spacing: 5

        Text {
            width: parent.width
            text: card.title
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.weight: Font.DemiBold
            font.pixelSize: Type.body
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: card.description
            color: card.descriptionColor
            font.family: "IBM Plex Sans"
            font.pixelSize: Type.small
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            lineHeight: 1.15
        }
    }

    CheckSquare {
        id: tick
        anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 20 }
        checked: card.checked
        color: checked ? card.tickColor : "transparent"
        mark: card.tickMark
    }
}
