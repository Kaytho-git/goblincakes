// A sparkle for the splash: the drawn one (Sparkle) or, in pixel art (14 Nov), Kakan's gold "gnista" or white
// "stjarna" at a whole-number scale. Her pictures are gold and white (pink would have been taken for the magenta
// background when they were cleaned); the other colours are copies made by tools/pixelart-tint.py – a live colour
// effect isn't drawn without a graphics card.
import QtQuick

Item {
    id: g
    property real size: 24
    property color color: "#FFF4CF"
    property bool pixel: true
    property bool star: false       // the white star instead of the gold sparkle
    property int unit: 1            // pixel art: screen pixels per picture pixel
    readonly property var tinted: ["#ff7eb6", "#7fe3ff", "#b69cff", "#8cffb0", "#ffb86b"]
    readonly property string hex: String(color).toLowerCase()
    width: pixel ? art.width : size
    height: pixel ? art.height : size

    Sparkle { visible: !g.pixel; size: g.size; color: g.color }
    Pix {
        id: art
        visible: g.pixel
        name: !g.pixel ? "" : (g.star ? "stjarna" : "gnista") + (g.tinted.indexOf(g.hex) >= 0 ? "-" + g.hex.slice(1) : "")
        unit: g.unit
    }
}
