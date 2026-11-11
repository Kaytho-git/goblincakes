// GOBLINCAKES' button – shared by every own window (Levande utseende step 1, 11 Nov). A window that wants
// other sizes keeps a short `component FlatButton: G.FlatButton { minWidth: …; fontSize: … }` of its own,
// so the look is changed here and nowhere else. The context properties accent (accent.py) and look
// (accent.py: look.living = Levande chosen in Config → Utseende, look.motion = may move) come from the engine.
import QtQuick

Rectangle {
    id: btn
    property string text
    property bool primary: false
    property bool danger: false          // red: on hover (or always with dangerFill)
    property bool dangerFill: false      // Goblin AI's STOPP: filled red
    property bool enabledState: true
    property bool small: false
    // Sizes – the windows differ (Config 150/48/44/15, GoblinRecorder 96/32/34/13 …)
    property int minWidth: 150
    property int padding: 48
    property int normalHeight: 44
    property int fontSize: 15
    property int smallMinWidth: 60
    property int smallPadding: 22
    property int smallHeight: 28
    property int smallFontSize: 12
    property int fontWeight: Font.Medium
    property color borderColor: "#2A3852"
    readonly property bool hovered: area.containsMouse && enabledState
    readonly property bool pressed: area.pressed && enabledState
    signal clicked()
    // Levande (Config → Utseende → Stil) and no game running: the changes glide (Levande utseende step 2)
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true

    width: Math.max(small ? smallMinWidth : minWidth, label.implicitWidth + (small ? smallPadding : padding))
    height: small ? smallHeight : normalHeight
    opacity: enabledState ? 1 : 0.4
    color: danger && dangerFill ? (area.containsMouse ? accent.errorBright : accent.error)
         : primary ? (hovered ? accent.hover : accent.color)
         : hovered ? (danger ? "#3A1418" : "#1A2438") : "transparent"
    border.width: primary ? 0 : 1
    border.color: danger && !dangerFill && hovered ? accent.error : borderColor
    // Levande: the colours fade (140 ms) and the button is pressed down 1 px while held
    Behavior on color { enabled: btn.moving; ColorAnimation { duration: 140 } }
    Behavior on border.color { enabled: btn.moving; ColorAnimation { duration: 140 } }
    transform: Translate { y: btn.moving && btn.pressed ? 1 : 0 }

    Text {
        id: label
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary && !(btn.danger && btn.dangerFill) ? accent.on : "#E6ECF5"
        font.family: "IBM Plex Sans"
        font.weight: btn.fontWeight
        font.pixelSize: btn.small ? btn.smallFontSize : btn.fontSize
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (btn.enabledState) btn.clicked()
    }
}
