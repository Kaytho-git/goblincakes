// A rainbow that draws itself in (progress 0 → 1): the splash and the Regnbåge background.
import QtQuick

Canvas {
    id: bow
    property real progress: 1
    property real centerY: height * 0.98
    property real radiusFactor: 0.42      // of the width
    property real bandFactor: 0.022       // one colour's width, of the width
    readonly property var colors: ["#FF5A5F", "#FF9F43", "#FFD93D", "#5CD65C", "#3FA7F5", "#7A5AF8"]
    onProgressChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        if (progress <= 0)
            return;
        const band = width * bandFactor, outer = width * radiusFactor;
        c.lineWidth = band + 0.5;
        for (let i = 0; i < colors.length; i++) {
            c.strokeStyle = colors[i];
            c.globalAlpha = 0.85;
            c.beginPath();
            c.arc(width / 2, centerY, outer - i * band, Math.PI, Math.PI + Math.PI * progress, false);
            c.stroke();
        }
    }
}
