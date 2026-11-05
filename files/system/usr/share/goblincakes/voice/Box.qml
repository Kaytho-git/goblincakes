// Kakan's voice box (step 9 D1, 5 Nov – the user's wish): what she heard and her answer, top right
// below the top bar on the screen the mouse is on. A layer-shell surface in the overlay layer (as Plasma's
// own OSD): above a fullscreen game too – a kept-above window was hidden behind WoW (5 Nov) – placed by
// KWin itself (the active screen = the mouse's, below the panels' exclusive zones), never a title bar.
// Never takes focus or clicks (a game or what you type keeps them). Driven by goblincakes-voice:
// box.state = listening / thinking / answer / nothing, box.heard, box.answer, box.hold (seconds).
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell

Window {
    id: root
    width: 420
    height: column.implicitHeight + 28
    visible: false
    color: "#0B1018"
    title: "Kakan"
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
    LayerShell.Window.scope: "goblincakes-voice-box"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight
    LayerShell.Window.margins.top: 12
    LayerShell.Window.margins.right: 16
    LayerShell.Window.exclusionZone: 0          // keeps clear of the top bar, takes no room itself
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.activateOnShow: false
    LayerShell.Window.screenConfiguration: LayerShell.Window.ScreenFromCompositor
    LayerShell.Window.wantsToBeOnActiveScreen: true

    readonly property string state: box.state
    readonly property color frost: "#E6ECF5"
    readonly property color muted: "#8B98AD"

    Component.onCompleted: show(state)
    onStateChanged: show(state)
    function show(state) {
        if (state === "nothing") {
            hideTimer.stop()
            root.visible = false
        } else {
            root.visible = true
            if (state === "answer") {
                hideTimer.interval = Math.max(3, box.hold) * 1000
                hideTimer.restart()
            } else {
                hideTimer.stop()
            }
        }
    }
    Connections {
        target: box
        function onChanged() {      // a new answer while one is shown: the time starts again
            if (root.state === "answer") {
                hideTimer.interval = Math.max(3, box.hold) * 1000
                hideTimer.restart()
            }
        }
    }
    Timer { id: hideTimer; onTriggered: { root.visible = false; box.hidden() } }

    Rectangle {      // the frame
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: "#1E2A40"
    }
    Rectangle {      // the accent line on the left
        width: 3
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        color: accent.color
    }

    Column {
        id: column
        x: 18
        y: 14
        width: root.width - 34
        spacing: 8

        Row {
            spacing: 8
            Rectangle {      // a dot that breathes while she listens or thinks
                id: dot
                width: 8
                height: 8
                anchors.verticalCenter: parent.verticalCenter
                color: accent.color
                opacity: 1
                SequentialAnimation on opacity {
                    running: root.visible && (root.state === "listening" || root.state === "thinking")
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) dot.opacity = 1
                    NumberAnimation { to: 0.25; duration: 550; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1; duration: 550; easing.type: Easing.InOutQuad }
                }
            }
            Text {
                text: "KAKAN · " + (root.state === "listening" ? "LYSSNAR"
                                    : root.state === "thinking" ? "TÄNKER" : "SVAR")
                color: accent.text
                font.family: "Chakra Petch"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 1.5
            }
        }
        Text {       // what she heard
            visible: text !== "" && root.state !== "listening"
            width: parent.width
            text: box.heard ? "”" + box.heard + "”" : ""
            color: root.muted
            font.family: "IBM Plex Sans"
            font.pixelSize: 14
            font.italic: true
            wrapMode: Text.Wrap
        }
        Text {       // her answer
            visible: text !== ""
            width: parent.width
            text: root.state === "listening" ? "Prata nu – släpp knappen när du är klar."
                  : root.state === "thinking" ? "" : box.answer
            color: root.state === "listening" ? root.muted : root.frost
            font.family: "IBM Plex Sans"
            font.pixelSize: 16
            lineHeight: 1.15
            wrapMode: Text.Wrap
        }
    }
}
