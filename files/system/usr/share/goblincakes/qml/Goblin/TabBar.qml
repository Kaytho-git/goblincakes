// The tabs of a page (docs/ux/norm.md 4 and 6, 22 Nov): Chakra Petch in capitals, an accent line under the chosen
// one. The whole tab is the click area, the gap to its neighbours included (12 units on each side – before, only
// the text was, and the gaps were dead). When the tabs don't fit they scroll sideways: the mouse wheel, a drag, or
// the arrow in a faded edge – never clipped. The chosen tab is scrolled into view.
//   model: [{ id, label }] · current: the chosen id · selected(id) when one is clicked
import QtQuick

Item {
    id: bar
    property var model: []
    property string current
    signal selected(string id)
    property int fontSize: 15
    property real letterSpacing: 2.5
    property int gap: 24
    property color fadeColor: "#07090D"
    readonly property bool overflow: row.width > width + 1

    implicitWidth: row.width
    implicitHeight: 44
    height: implicitHeight

    function reveal(item) {
        if (!item || !overflow)
            return;
        const left = item.x - 28, right = item.x + item.width + 28;
        if (left < flick.contentX)
            flick.contentX = Math.max(0, left);
        else if (right > flick.contentX + flick.width)
            flick.contentX = Math.min(row.width - flick.width, right - flick.width);
    }
    function nudge(dx) {
        flick.contentX = Math.max(0, Math.min(Math.max(0, row.width - flick.width), flick.contentX + dx));
    }
    onWidthChanged: if (!overflow) flick.contentX = 0

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: row.width
        contentHeight: height
        clip: bar.overflow
        interactive: bar.overflow
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        Behavior on contentX { enabled: !flick.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Row {
            id: row
            height: bar.height

            Repeater {
                id: tabs
                model: bar.model

                Item {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool active: bar.current === modelData.id
                    readonly property real padLeft: index > 0 ? bar.gap / 2 : 0
                    readonly property real padRight: index < tabs.count - 1 ? bar.gap / 2 : 0
                    width: padLeft + label.implicitWidth + padRight
                    height: bar.height
                    onActiveChanged: if (active) Qt.callLater(bar.reveal, tab)

                    Text {
                        id: label
                        x: tab.padLeft
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.label
                        color: tab.active || area.containsMouse ? "#E6ECF5" : "#8B98AD"
                        font.family: "Chakra Petch"
                        font.weight: Font.DemiBold
                        font.pixelSize: bar.fontSize
                        font.letterSpacing: bar.letterSpacing
                    }
                    Rectangle {
                        x: label.x
                        width: label.implicitWidth - bar.letterSpacing  // the text, not its trailing letter space
                        anchors.bottom: parent.bottom
                        height: 2
                        color: accent.color
                        visible: tab.active
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.selected(tab.modelData.id)
                    }
                }
            }
        }
    }

    // Too many to fit: the wheel scrolls them sideways
    WheelHandler {
        enabled: bar.overflow
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const d = event.pixelDelta.x !== 0 ? event.pixelDelta.x
                    : event.pixelDelta.y !== 0 ? event.pixelDelta.y
                    : (event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y) / 120 * 80;
            bar.nudge(-d);
        }
    }

    // The faded edges with an arrow – only where there is more to see
    Repeater {
        model: [{ side: "left" }, { side: "right" }]
        Item {
            id: edge
            required property var modelData
            readonly property bool isLeft: modelData.side === "left"
            visible: bar.overflow && (isLeft ? flick.contentX > 1 : flick.contentX < row.width - flick.width - 1)
            width: 40
            height: bar.height - 2
            x: isLeft ? 0 : bar.width - width
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: edge.isLeft ? bar.fadeColor : Qt.rgba(bar.fadeColor.r, bar.fadeColor.g, bar.fadeColor.b, 0) }
                    GradientStop { position: 0.6; color: bar.fadeColor }
                    GradientStop { position: 1; color: edge.isLeft ? Qt.rgba(bar.fadeColor.r, bar.fadeColor.g, bar.fadeColor.b, 0) : bar.fadeColor }
                }
            }
            Text {
                anchors { verticalCenter: parent.verticalCenter; left: edge.isLeft ? parent.left : undefined; right: edge.isLeft ? undefined : parent.right
                          leftMargin: 4; rightMargin: 4 }
                text: edge.isLeft ? "‹" : "›"
                color: arrowArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 22
            }
            MouseArea {
                id: arrowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.nudge((edge.isLeft ? -1 : 1) * Math.max(120, flick.width * 0.6))
            }
        }
    }
}
