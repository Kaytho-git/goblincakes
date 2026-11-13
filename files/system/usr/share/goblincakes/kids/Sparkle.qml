// A four-pointed sparkle: two thin crossed rays and a glow in the middle (the splash, the tiles, the backgrounds).
import QtQuick

Item {
    id: sp
    property real size: 24
    property color color: "#FFF4CF"
    width: size; height: size
    Rectangle {
        anchors.centerIn: parent
        width: sp.size * 0.7; height: width; radius: width / 2
        color: sp.color; opacity: 0.16
    }
    Rectangle {
        anchors.centerIn: parent
        width: Math.max(1.5, sp.size * 0.13); height: sp.size; radius: width / 2
        color: sp.color
    }
    Rectangle {
        anchors.centerIn: parent
        width: sp.size; height: Math.max(1.5, sp.size * 0.13); radius: height / 2
        color: sp.color
    }
    Rectangle {
        anchors.centerIn: parent
        width: sp.size * 0.28; height: width; radius: width / 2
        color: "white"
    }
}
