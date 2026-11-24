// The tabs of a page (docs/ux/norm.md 4 and 6, 22 Nov): Chakra Petch in capitals, an accent line under the chosen
// one. Only the text itself (its box, not above/below) is the click area and lights up under the mouse (22 Nov, the user's choice: with the gaps
// included, the neighbour lit up when the mouse was just left of a tab and two looked chosen). When the tabs don't fit they scroll sideways: the mouse wheel, a drag, or
// the arrow at the edge (the tabs stop before it, so it works on Levande's soft background too). The chosen tab is scrolled into view.
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
    // From where the tabs are going, not where they are mid-slide: a fast wheel lost most of each step (24 Nov, the user)
    property real goalX: 0
    function nudge(dx) {
        const from = slide.running ? goalX : flick.contentX;
        goalX = Math.max(0, Math.min(Math.max(0, row.width - flick.width), from + dx));
        flick.contentX = goalX;
    }
    // One wheel notch ≈ one tab; a mouse's fine steps (8 per notch) add up to the same. Pixels only from a touchpad.
    function wheelStep(event) {
        const pad = event.device && event.device.type === PointerDevice.TouchPad;
        if (pad && (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0))
            return event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.pixelDelta.y;
        return (event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y) / 120 * 150;
    }
    onWidthChanged: if (!overflow) flick.contentX = 0

    readonly property bool moreLeft: overflow && flick.contentX > 1
    readonly property bool moreRight: overflow && flick.contentX < row.width - flick.width - 1

    Flickable {
        id: flick
        anchors { fill: parent; leftMargin: bar.moreLeft ? 28 : 0; rightMargin: bar.overflow ? 28 : 0 }
        contentWidth: row.width
        contentHeight: height
        clip: bar.overflow
        interactive: bar.overflow
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        Behavior on contentX { enabled: !flick.dragging; NumberAnimation { id: slide; duration: 160; easing.type: Easing.OutCubic } }

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
                        // exactly the text's box – nothing beside, above or below it lights up (the user, 22 Nov)
                        x: label.x
                        y: label.y
                        width: label.implicitWidth - bar.letterSpacing
                        height: label.height
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
        onWheel: event => bar.nudge(-bar.wheelStep(event))
    }

    // The arrows at the edges – only where there is more to see
    Repeater {
        model: [{ side: "left" }, { side: "right" }]
        Item {
            id: edge
            required property var modelData
            readonly property bool isLeft: modelData.side === "left"
            visible: isLeft ? bar.moreLeft : bar.moreRight
            width: 28
            height: bar.height - 2
            x: isLeft ? 0 : bar.width - width
            Text {
                anchors.centerIn: parent
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
