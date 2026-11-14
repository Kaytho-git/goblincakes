// A frame in Barnläge's pixel style (14 Nov): a dark outline with its corner pixels left out (the rounded corner of
// 16-bit games) and a coloured line inside it, each p screen pixels thick – drawn outside the item it frames:
// PixelFrame { anchors.fill: <item>; p: …; color: … }.
import QtQuick

Item {
    id: f
    property int p: 3
    property color color: "#2A3852"
    property color outline: "#05070F"
    Item {
        anchors.fill: parent
        anchors.margins: -2 * f.p
        Rectangle { x: f.p; y: 0; width: parent.width - 2 * f.p; height: f.p; color: f.outline }
        Rectangle { x: f.p; y: parent.height - f.p; width: parent.width - 2 * f.p; height: f.p; color: f.outline }
        Rectangle { x: 0; y: f.p; width: f.p; height: parent.height - 2 * f.p; color: f.outline }
        Rectangle { x: parent.width - f.p; y: f.p; width: f.p; height: parent.height - 2 * f.p; color: f.outline }
        Rectangle {
            x: f.p; y: f.p; width: parent.width - 2 * f.p; height: parent.height - 2 * f.p
            color: "transparent"
            border.width: f.p
            border.color: f.color
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }
    }
}
