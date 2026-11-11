// GOBLINCAKES' text field (shared, Levande utseende step 1). Config: Sans 15 / 44 high; GoblinRecorder: Mono 13 with
// the hint in Sans; GoblinShare: Sans 14.
import QtQuick

Rectangle {
    id: fieldBox
    property alias text: input.text
    property alias echoMode: input.echoMode
    property alias validator: input.validator
    property alias field: input
    property string hint
    property string fontFamily: "IBM Plex Sans"
    property int fontSize: 15
    property string hintFamily: fontFamily
    property int hintSize: fontSize
    signal edited()
    // Levande (Config → Utseende → Stil) and no game running: the frame fades to the accent (Levande utseende step 2)
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    signal accepted()
    height: 44
    color: "#07090D"
    border.width: 1
    border.color: input.activeFocus ? accent.color : "#2A3852"
    Behavior on border.color { enabled: fieldBox.moving; ColorAnimation { duration: 140 } }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        verticalAlignment: TextInput.AlignVCenter
        color: "#E6ECF5"
        selectionColor: accent.color
        font.family: fieldBox.fontFamily
        font.pixelSize: fieldBox.fontSize
        clip: true
        selectByMouse: true
        onTextEdited: fieldBox.edited()
        onAccepted: fieldBox.accepted()
    }
    Text {
        anchors { fill: input }
        verticalAlignment: Text.AlignVCenter
        visible: !input.text && !input.activeFocus
        text: fieldBox.hint
        color: "#5C6880"
        font.family: fieldBox.hintFamily
        font.pixelSize: fieldBox.hintSize
        elide: Text.ElideRight
    }
}
