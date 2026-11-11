// Glide up into place (Levande utseende step 5, 11 Nov – the dashboard's frames when it opens): put it in the
// item to move, `G.Rise { order: 2; trigger: win.opened }`; each time trigger changes the item comes up 16 px
// from below and fades in, order × 45 ms after the first (order is capped at 6: all in place within 0.5 s).
// Platt or a game running: nothing happens. The item's own transform is replaced – not for FlatButton.
import QtQuick

Item {
    id: rise
    property Item target: parent
    property int order: 0
    property int trigger: 0
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    width: 0
    height: 0
    Translate { id: shift }
    Component.onCompleted: if (target) target.transform = [shift]
    onTriggerChanged: {
        if (!target)
            return;
        if (!moving) {
            play.stop();
            shift.y = 0;
            target.opacity = 1;
            return;
        }
        play.restart();
    }
    SequentialAnimation {
        id: play
        ScriptAction { script: { shift.y = 16; rise.target.opacity = 0; } }
        PauseAnimation { duration: Math.min(6, Math.max(0, rise.order)) * 45 }
        ParallelAnimation {
            NumberAnimation { target: shift; property: "y"; to: 0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: rise.target; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutQuad }
        }
    }
}
