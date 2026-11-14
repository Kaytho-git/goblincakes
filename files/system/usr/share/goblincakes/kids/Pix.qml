// One of Kakan's pixel-art pictures (pixelart/<name>.png, 14 Nov) shown sharp at a whole-number scale:
// every picture pixel becomes unit × unit screen pixels, never smoothed.
import QtQuick

Image {
    property string name
    property int unit: 1
    source: name ? Qt.resolvedUrl("pixelart/" + name + ".png") : ""   // from this folder, wherever it is used
    smooth: false
    mipmap: false
    width: implicitWidth * unit
    height: implicitHeight * unit
}
