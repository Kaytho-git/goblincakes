// GOBLINCAKES login splash: logo, wordmark, thin progress bar on black
import QtQuick

Rectangle {
    id: root
    color: "#000000"

    // Set by KSplash: 1 → 6 as Plasma starts up
    property int stage

    // Sizes from the 1920×1080 design, scaled to the screen
    readonly property real s: height / 1080

    Column {
        id: content
        anchors.centerIn: parent
        spacing: Math.round(36 * root.s)
        opacity: 0

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "images/logo.svg"
            sourceSize.width: Math.round(180 * root.s)
            sourceSize.height: Math.round(180 * root.s)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "GOBLINCAKES"
            color: "#E6ECF5"
            font.family: "Chakra Petch"
            font.weight: Font.Bold
            font.pixelSize: Math.round(40 * root.s)
            font.letterSpacing: Math.round(10 * root.s)
        }

        Item {
            width: 1
            height: Math.round(24 * root.s)
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(280 * root.s)
            height: Math.max(2, Math.round(3 * root.s))
            color: "#12203A"

            Rectangle {
                height: parent.height
                color: "#2F6FED"
                width: parent.width * Math.min(root.stage, 6) / 6
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Booting into GOBLINCAKES OS…"
            color: "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: Math.round(22 * root.s)
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
