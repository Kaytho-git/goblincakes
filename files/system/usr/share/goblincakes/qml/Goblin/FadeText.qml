// Text that fades over when it changes (Levande utseende step 4, 11 Nov): give it `value` instead of `text`
// (`G.FadeText { value: song.title }`). Platt, a game running or hidden: the new text at once.
import QtQuick

Text {
    id: fadeText
    property string value
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    text: ""
    Component.onCompleted: text = value
    onValueChanged: {
        if (!moving || !visible || text === "") {
            fade.stop();
            opacity = 1;
            text = value;
        } else if (value !== text) {
            fade.restart();
        }
    }
    SequentialAnimation {
        id: fade
        NumberAnimation { target: fadeText; property: "opacity"; to: 0; duration: 90; easing.type: Easing.InQuad }
        ScriptAction { script: fadeText.text = fadeText.value }
        NumberAnimation { target: fadeText; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutQuad }
    }
}
