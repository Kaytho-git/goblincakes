// GOBLINCAKES' tick box (shared, Levande utseende step 1). size 22 (Config) or 18 (GoblinShare); the tick follows.
import QtQuick

Rectangle {
    id: box
    property bool checked
    property int size: 22
    property color mark: accent.on      // the tick: dark on light accent colours
    // the tick's three points and line width: drawn by hand for 22 and 18, scaled from 22 for other sizes
    readonly property var tick: size === 18 ? [4.5, 9.5, 7.8, 12.8, 13.5, 5.8, 2.2]
                              : [5.5, 11.5, 9.5, 15.5, 16.5, 7, 2.5].map((v, i) => i === 6 ? Math.max(2.2, v * size / 22) : v * size / 22)
    // Levande (Config → Utseende → Stil) and no game running: the changes glide (Levande utseende step 2)
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    // Levande: the tick is drawn forward (0 → 1) when it is ticked; Platt: all of it at once
    property real drawn: checked ? 1 : 0
    Behavior on drawn { enabled: box.moving; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on color { enabled: box.moving; ColorAnimation { duration: 120 } }
    width: size
    height: size
    color: checked ? accent.color : "transparent"
    border.width: checked ? 0 : 1
    border.color: "#2A3852"
    Canvas {
        anchors.fill: parent
        visible: box.checked
        property color mark: box.mark
        onMarkChanged: requestPaint()
        onWidthChanged: requestPaint()
        property real drawn: box.drawn
        onDrawnChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            const t = box.tick;
            ctx.reset();
            ctx.strokeStyle = mark;
            ctx.lineWidth = t[6];
            // as much of the two strokes as is drawn
            const a = Math.hypot(t[2] - t[0], t[3] - t[1]), b = Math.hypot(t[4] - t[2], t[5] - t[3]);
            let left = drawn * (a + b);
            if (left <= 0)
                return;
            ctx.beginPath();
            ctx.moveTo(t[0], t[1]);
            const f1 = Math.min(1, left / a);
            ctx.lineTo(t[0] + (t[2] - t[0]) * f1, t[1] + (t[3] - t[1]) * f1);
            left -= a;
            if (left > 0) {
                const f2 = Math.min(1, left / b);
                ctx.lineTo(t[2] + (t[4] - t[2]) * f2, t[3] + (t[5] - t[3]) * f2);
            }
            ctx.stroke();
        }
    }
}
