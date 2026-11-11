// Text whose changed characters roll (Levande utseende step 4, 11 Nov) – the clock: at a new minute only the
// digits that change roll up, the new one in from below. `G.RollText { text: "07:17"; color: …; font.pixelSize: … }`.
// Platt or a game running: one plain Text, exactly as before (letters drawn one by one can sit a hair apart).
import QtQuick

Item {
    id: roll
    property string text
    property color color: "#E6ECF5"
    property font font
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    implicitWidth: moving ? chars.implicitWidth : plain.implicitWidth
    implicitHeight: plain.implicitHeight

    Text {
        id: plain
        visible: !roll.moving
        text: roll.text
        color: roll.color
        font: roll.font
    }

    component RollChar: Item {
        id: rc
        required property int index
        readonly property string ch: roll.text.charAt(index)
        property string last: ""
        width: now.implicitWidth
        height: now.implicitHeight
        clip: true
        Text { id: old; color: roll.color; font: roll.font; y: -rc.height; text: "" }
        Text { id: now; color: roll.color; font: roll.font; text: rc.ch }
        Component.onCompleted: last = ch
        onChChanged: {
            if (roll.moving && last !== "" && roll.visible) {
                old.text = last;
                rolling.restart();
            } else {
                rolling.stop();
                old.y = -rc.height;
                now.y = 0;
            }
            last = ch;
        }
        ParallelAnimation {
            id: rolling
            NumberAnimation { target: old; property: "y"; from: 0; to: -rc.height; duration: 320; easing.type: Easing.InOutCubic }
            NumberAnimation { target: now; property: "y"; from: rc.height; to: 0; duration: 320; easing.type: Easing.InOutCubic }
        }
    }
    Row {
        id: chars
        visible: roll.moving
        Repeater {
            model: roll.moving ? roll.text.length : 0
            RollChar {}
        }
    }
}
