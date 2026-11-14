// The frame around Barnläge's cards in Kakan's pixel art (14 Nov): grey riveted steel with big gems (förslag 3 of
// her second round – the user: "lite grå, industriaktig … gemsen ska synas ordentligt"). Built from pieces of
// pixelart/<name>.png (128 × 128) so nothing gets stretched out of shape: the four corners with their gems as she
// drew them, the bars repeated one riveted segment at a time, and the gems in the middle of each side laid on
// unchanged (the bottom one is the top one – hers came out broken in the cleaning). Drawn at 1/unit size and scaled
// up, so every picture pixel stays a sharp square. Over the card's edge: anchors.fill: <card>; anchors.margins: -outside.
import QtQuick

Item {
    id: cf
    property int unit: 2
    property string name: "ram"
    readonly property string src: Qt.resolvedUrl("pixelart/" + name + ".png")
    readonly property int corner: 25        // the corner gems
    readonly property int bar: 11           // the bars' thickness
    readonly property real outside: bar * unit * 0.5
    readonly property real w: Math.round(width / unit)    // in picture pixels
    readonly property real h: Math.round(height / unit)

    component Piece: Image {
        source: cf.src
        smooth: false
        mipmap: false
    }

    Item {
        width: cf.w; height: cf.h
        scale: cf.unit
        transformOrigin: Item.TopLeft

        // the bars, one 20-pixel riveted segment repeated
        Piece { x: cf.corner; y: 0; width: cf.w - 2 * cf.corner; height: cf.bar
                sourceClipRect: Qt.rect(18, 0, 20, cf.bar); fillMode: Image.Tile }
        Piece { x: cf.corner; y: cf.h - cf.bar; width: cf.w - 2 * cf.corner; height: cf.bar
                sourceClipRect: Qt.rect(18, 128 - cf.bar, 20, cf.bar); fillMode: Image.Tile }
        Piece { x: 0; y: cf.corner; width: cf.bar; height: cf.h - 2 * cf.corner
                sourceClipRect: Qt.rect(0, 28, cf.bar, 20); fillMode: Image.Tile }
        Piece { x: cf.w - cf.bar; y: cf.corner; width: cf.bar; height: cf.h - 2 * cf.corner
                sourceClipRect: Qt.rect(128 - cf.bar, 28, cf.bar, 20); fillMode: Image.Tile }

        // the corners
        Piece { x: 0; y: 0; sourceClipRect: Qt.rect(0, 0, cf.corner, cf.corner) }
        Piece { x: cf.w - cf.corner; y: 0; sourceClipRect: Qt.rect(128 - cf.corner, 0, cf.corner, cf.corner) }
        Piece { x: 0; y: cf.h - cf.corner; sourceClipRect: Qt.rect(0, 128 - cf.corner, cf.corner, cf.corner) }
        Piece { x: cf.w - cf.corner; y: cf.h - cf.corner
                sourceClipRect: Qt.rect(128 - cf.corner, 128 - cf.corner, cf.corner, cf.corner) }

        // the gems in the middle of the sides (whole picture pixels, so they stay on the grid)
        Piece { x: Math.round((cf.w - 21) / 2); y: 0; sourceClipRect: Qt.rect(54, 0, 21, 20) }
        Piece { x: Math.round((cf.w - 21) / 2); y: cf.h - 20; sourceClipRect: Qt.rect(54, 0, 21, 20) }
        Piece { x: 0; y: Math.round((cf.h - 19) / 2); sourceClipRect: Qt.rect(0, 53, 14, 19) }
        Piece { x: cf.w - 14; y: Math.round((cf.h - 19) / 2); sourceClipRect: Qt.rect(114, 53, 14, 19) }
    }
}
