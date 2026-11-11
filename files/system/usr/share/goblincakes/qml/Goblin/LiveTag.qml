// ● PÅGÅR (Levande utseende step 5, 11 Nov): something happening now – tonight's raid, a build. Shown in both
// looks; with Stil: Levande it pulses slowly – also while a game runs (the raid is a game), but only while its
// window is shown.
import QtQuick

Row {
    id: tag
    property string text: "PÅGÅR"
    property color tone: "#F0B232"
    readonly property bool living: typeof look !== "undefined" && !!look && look.living === true
    readonly property bool shown: visible && Window.window !== null && Window.window.visible
    spacing: 6
    Rectangle {
        id: dot
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        color: tag.tone
    }
    Text {
        id: word
        anchors.verticalCenter: parent.verticalCenter
        text: tag.text
        color: tag.tone
        font.family: "Chakra Petch"
        font.weight: Font.DemiBold
        font.pixelSize: 11
        font.letterSpacing: 2
    }
    SequentialAnimation {
        running: tag.living && tag.shown
        loops: Animation.Infinite
        onRunningChanged: if (!running) dot.opacity = 1
        NumberAnimation { target: dot; property: "opacity"; to: 0.25; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { target: dot; property: "opacity"; to: 1; duration: 900; easing.type: Easing.InOutSine }
    }
}
