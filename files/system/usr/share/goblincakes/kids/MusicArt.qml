// Barnläge's music picture (13 Nov): two notes on a coloured background (seed = a colour per song), and bars dancing
// along the bottom while a song plays. The music picture among the games, and each song in the music box.
import QtQuick

Item {
    id: art
    property int seed: 0
    property bool dancing: false
    readonly property var colors: [["#6A3FD6", "#C2449F"], ["#1F7FBF", "#2FA39B"], ["#D9485F", "#F29A3C"],
                                   ["#3F5BD6", "#7A5AF8"], ["#2E8B57", "#B5C94A"]]
    readonly property var pair: colors[seed % colors.length]
    clip: true
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: art.pair[0] }
            GradientStop { position: 1.0; color: art.pair[1] }
        }
    }
    Repeater {   // soft circles of light
        model: 3
        Rectangle {
            required property int index
            x: art.width * [0.62, 0.08, 0.45][index]; y: art.height * [0.05, 0.5, 0.62][index]
            width: art.width * [0.5, 0.35, 0.25][index]; height: width; radius: width / 2
            color: "white"; opacity: 0.08
        }
    }
    // the notes (two beamed eighths)
    Item {
        id: notes
        width: art.width * 0.5; height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: art.height * 0.16
        rotation: art.dancing ? sway : -6
        property real sway: 0
        SequentialAnimation on sway {
            running: art.dancing
            loops: Animation.Infinite
            NumberAnimation { from: -8; to: 8; duration: 420; easing.type: Easing.InOutSine }
            NumberAnimation { from: 8; to: -8; duration: 420; easing.type: Easing.InOutSine }
        }
        readonly property real head: width * 0.3
        Rectangle { x: 0; y: notes.height - notes.head * 0.8; width: notes.head; height: notes.head * 0.78; radius: height / 2; color: "white"; rotation: -20 }
        Rectangle { x: notes.width - notes.head; y: notes.height - notes.head; width: notes.head; height: notes.head * 0.78; radius: height / 2; color: "white"; rotation: -20 }
        Rectangle { x: notes.head * 0.82; y: notes.height * 0.12; width: notes.width * 0.07; height: notes.height * 0.78; color: "white" }
        Rectangle { x: notes.width - notes.head * 0.18 - notes.width * 0.07; y: 0; width: notes.width * 0.07; height: notes.height * 0.72; color: "white" }
        Rectangle {
            x: notes.head * 0.82; y: notes.height * 0.04
            width: notes.width - notes.head; height: notes.height * 0.15
            color: "white"
            rotation: -9; transformOrigin: Item.Left
        }
    }
    // bars along the bottom
    Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: art.height * 0.07 }
        spacing: art.width * 0.03
        Repeater {
            model: 7
            Rectangle {
                id: bar
                required property int index
                width: art.width * 0.07
                property real level: art.dancing ? 0.3 : 0.12
                height: art.height * 0.24 * level
                anchors.bottom: parent.bottom
                color: "white"
                opacity: 0.85
                SequentialAnimation on level {
                    running: art.dancing
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.0; duration: 180 + bar.index * 37 % 140; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 0.25; duration: 210 + bar.index * 53 % 160; easing.type: Easing.InQuad }
                    NumberAnimation { to: 0.7; duration: 160 + bar.index * 29 % 120; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 0.2; duration: 230 + bar.index * 41 % 150; easing.type: Easing.InQuad }
                }
            }
        }
    }
}
