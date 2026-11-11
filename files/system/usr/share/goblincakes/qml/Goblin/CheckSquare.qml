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
        onPaint: {
            const ctx = getContext("2d");
            const t = box.tick;
            ctx.reset();
            ctx.strokeStyle = mark;
            ctx.lineWidth = t[6];
            ctx.beginPath();
            ctx.moveTo(t[0], t[1]);
            ctx.lineTo(t[2], t[3]);
            ctx.lineTo(t[4], t[5]);
            ctx.stroke();
        }
    }
}
