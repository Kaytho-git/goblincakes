// The background of a window (Levande utseende step 3, 11 Nov) – only with Stil: Levande: a soft round tone
// from Night (#0E1420) up in the middle out to Void (#07090D), and a faint grain. First child of the Window:
// `G.Backdrop {}` (the window's own colour stays Void – Platt looks as before).
import QtQuick
import QtQuick.Shapes

Item {
    id: backdrop
    readonly property bool living: typeof look !== "undefined" && !!look && look.living === true
    anchors.fill: parent
    z: -1
    visible: living
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: backdrop.width / 2
                centerY: 0
                focalX: centerX
                focalY: centerY
                centerRadius: Math.max(backdrop.width, backdrop.height) * 0.9
                focalRadius: 0
                GradientStop { position: 0; color: "#0E1420" }
                GradientStop { position: 1; color: "#07090D" }
            }
            PathRectangle { x: 0; y: 0; width: backdrop.width; height: backdrop.height }
        }
    }
    Image {
        anchors.fill: parent
        source: "grain.png"
        fillMode: Image.Tile
        opacity: 0.022
        smooth: false
    }
}
