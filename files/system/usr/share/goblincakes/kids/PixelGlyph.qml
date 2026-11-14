// ▶, ■ or ✕ drawn with square pixels on a 9 × 9 grid (Barnläge's pixel style, 14 Nov) – the font's own signs
// would be smooth. cell = size / 9, whole screen pixels.
import QtQuick

Item {
    id: gl
    property string shape: "play"        // play | stop | x
    property color color: "white"
    property real size: 28
    readonly property int cell: Math.max(1, Math.floor(size / 9))
    width: cell * 9
    height: cell * 9

    function lit(c, r) {
        if (shape === "stop")
            return c >= 1 && c <= 7 && r >= 1 && r <= 7;
        if (shape === "x")
            return c === r || c === 8 - r;
        const reach = [4, 4, 3, 3, 2, 2, 1, 1, 0][c];   // play: column heights 9 9 7 7 5 5 3 3 1, pointing right
        return Math.abs(r - 4) <= reach;
    }

    Repeater {
        model: 81
        Rectangle {
            required property int index
            visible: gl.lit(index % 9, Math.floor(index / 9))
            x: (index % 9) * gl.cell
            y: Math.floor(index / 9) * gl.cell
            width: gl.cell; height: gl.cell
            color: gl.color
        }
    }
}
