// GOBLINCAKES login splash: white outline goblin in a cupcake on dark blue
import QtQuick

Rectangle {
    id: root
    color: "#0c1a3a"

    // Set by KSplash: 1 → 6 as Plasma starts up
    property int stage

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 28
        opacity: 0

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "images/goblin-cupcake.svg"
            sourceSize.width: Math.round(root.height / 3)
            sourceSize.height: Math.round(root.height / 3)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "GOBLINCAKES"
            color: "#ffffff"
            font.pixelSize: Math.round(root.height / 18)
            font.weight: Font.Light
            font.letterSpacing: font.pixelSize * 0.25
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(root.width / 6)
            height: 3
            radius: 2
            color: "#1e3a8a"

            Rectangle {
                height: parent.height
                radius: parent.radius
                color: "#ffffff"
                width: parent.width * Math.min(root.stage, 6) / 6
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    OpacityAnimator {
        target: content
        from: 0
        to: 1
        duration: 600
        running: true
    }
}
