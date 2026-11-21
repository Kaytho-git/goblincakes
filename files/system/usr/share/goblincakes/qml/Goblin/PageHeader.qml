// The top of a window (docs/ux/norm.md 1 and 6, 22 Nov): logo, title and subtitle on the left, the window's own
// buttons/status on the right (`actions: [ … ]`), the tabs at the bottom (`tabs: G.TabBar { … }`), all inside the
// centred page (Norm). When the right group doesn't fit beside the title it moves down under it – the two never
// draw on top of each other (before: two groups anchored left and right, overlapping in a narrow window).
//   below: [ … ]   – something between the title and the tabs (Config's USB note)
//   badge: [ … ]   – beside the title (GoblinRecorder's "● SPELAR IN")
//   subtitleLines  – 2: the subtitle wraps onto a second line before it shortens
//   minWidth       – the narrowest the header can be without anything overlapping (for minimumWidth)
import QtQuick

Item {
    id: head
    property url logo
    property int logoSize: 64
    property string title
    property string subtitle
    property color subtitleColor: "#8B98AD"
    property int titleSize: 30
    property real titleSpacing: 4
    property int subtitleSize: 15
    property int subtitleLines: 1
    property int topMargin: 30
    property int sideMargin: Norm.margin
    property int maxWidth: Norm.page
    property bool rightOnTop: false     // the right group lines up with the title's top (Config's version) …
    property int tabsGap: 37            // … space between the title block and the tabs
    property alias actions: rightSlot.data
    property alias below: belowSlot.data
    property alias badge: badgeSlot.data
    property alias tabs: tabSlot.data
    readonly property alias page: pageItem
    property int tabsHeight: 44         // kept even when the tabs are hidden, so the page doesn't jump
    // the title (not the subtitle – it shortens) and the right group side by side, or the group under the title
    readonly property bool wrapped: rightSlot.width > 0
                                    && logoSize + 22 + titleRow.implicitWidth + 32 + rightSlot.width > pageItem.width
    readonly property real minWidth: 2 * sideMargin + Math.max(logoSize + 22 + Math.min(titleRow.implicitWidth, 420),
                                                               logoSize + 22 + rightSlot.width)

    implicitHeight: topMargin + leftRow.height + (wrapped ? 12 + rightSlot.height : 0)
                    + (belowSlot.height > 0 ? 16 + belowSlot.height : 0) + tabsGap + tabsHeight
    height: implicitHeight

    Item {
        id: pageItem
        x: Norm.pageX(head.width, head.maxWidth, head.sideMargin)
        width: Norm.pageWidth(head.width, head.maxWidth, head.sideMargin)
        height: parent.height

        Row {
            id: leftRow
            y: head.topMargin
            spacing: 22

            Image {
                visible: head.logo != ""
                anchors.verticalCenter: parent.verticalCenter
                source: head.logo
                sourceSize.width: head.logoSize
                sourceSize.height: head.logoSize
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Row {
                    id: titleRow
                    spacing: 14
                    Text {
                        id: titleText
                        width: Math.min(implicitWidth, pageItem.width - head.logoSize - 22 - (badgeSlot.width > 0 ? badgeSlot.width + 14 : 0))
                        text: head.title
                        color: "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: head.titleSize
                        font.letterSpacing: head.titleSpacing
                        elide: Text.ElideRight
                    }
                    Row {
                        id: badgeSlot
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Text {
                    visible: text !== ""
                    // beside the right group: up to it; under it: the whole page
                    readonly property real room: pageItem.width - head.logoSize - 22
                                                 - (head.wrapped || rightSlot.width === 0
                                                    // a low right group at the title's top (Config's version) is above it
                                                    || (head.rightOnTop && rightSlot.height <= titleRow.height) ? 0 : rightSlot.width + 32)
                    width: Math.min(implicitWidth, room)
                    wrapMode: head.subtitleLines > 1 ? Text.WordWrap : Text.NoWrap
                    maximumLineCount: head.subtitleLines
                    text: head.subtitle
                    color: head.subtitleColor
                    font.family: "IBM Plex Sans"
                    font.pixelSize: head.subtitleSize
                    elide: Text.ElideRight
                }
            }
        }

        Row {
            id: rightSlot
            x: head.wrapped ? head.logoSize + 22 : pageItem.width - width
            y: head.wrapped ? leftRow.y + leftRow.height + 12
             : head.rightOnTop ? head.topMargin
             : leftRow.y + Math.max(0, (leftRow.height - height) / 2)
        }

        Column {
            id: belowSlot
            y: leftRow.y + leftRow.height + (head.wrapped ? 12 + rightSlot.height : 0) + 16
            width: pageItem.width
        }

        Item {
            id: tabSlot
            anchors.bottom: parent.bottom
            width: pageItem.width
            height: head.tabsHeight
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: "#1E2A40"
        z: -1
    }
}
