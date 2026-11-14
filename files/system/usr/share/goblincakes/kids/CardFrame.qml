// The frame around Barnläge's cards in Kakan's pixel art (14 Nov, the user: "Kakan har visat sig duktig på detta"):
// pixelart/ram.png as a nine-slice – the corners as she drew them, the sides stretched between them – at a
// whole-number scale (drawn at 1/unit size and scaled up, so every picture pixel stays a sharp square).
// It covers the card's edge: CardFrame { anchors.fill: <card>; anchors.margins: -outside }.
import QtQuick

Item {
    id: cf
    property int unit: 3
    property int edge: 10               // corner size in picture pixels (ram.png: the bars are rows 0–9)
    property string name: "ram"
    readonly property real outside: edge * unit * 0.45   // how far it reaches outside the card
    BorderImage {
        source: Qt.resolvedUrl("pixelart/" + cf.name + ".png")
        width: cf.width / cf.unit
        height: cf.height / cf.unit
        border { left: cf.edge; right: cf.edge; top: cf.edge; bottom: cf.edge }
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
        smooth: false
        scale: cf.unit
        transformOrigin: Item.TopLeft
    }
}
