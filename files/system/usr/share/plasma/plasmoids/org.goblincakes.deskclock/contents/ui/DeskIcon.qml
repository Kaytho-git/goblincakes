/*
    The desktop row's line icons, drawn like the mockup "Skrivbordet utan docka" (24-unit grid, 2 px line,
    square ends): ethernet, wifi, offline, sound (high/low/muted), mouse, keyboard, gaming controller, headset, Kakan (the logo's cupcake – fluted when loaded).
    Plain Qt Quick, so the clock box can be tried without a desktop.
*/
import QtQuick
import QtQuick.Shapes

Item {
    id: icon
    property string name: "ethernet"
    property color color: "#E6ECF5"
    property real size: 22
    implicitWidth: size
    implicitHeight: size

    readonly property var paths: ({
        "ethernet": "M3 14h18v7H3z M7 14V9h10v5 M12 9V3",
        "offline": "M3 14h18v7H3z M7 14V9h10v5 M12 9V3 M2 2L22 22",
        "wifi": "M2 9a15 15 0 0 1 20 0 M5 12.5a10 10 0 0 1 14 0 M8.5 16a5 5 0 0 1 7 0 M11 19.5h2v1h-2z",
        "sound-high": "M4 9h4l5-4v14l-5-4H4z M16 9c1.5 1.5 1.5 4.5 0 6 M19 6c3 3 3 9 0 12",
        "sound-low": "M4 9h4l5-4v14l-5-4H4z M16 9c1.5 1.5 1.5 4.5 0 6",
        "sound-muted": "M4 9h4l5-4v14l-5-4H4z M16 9l6 6 M22 9l-6 6",
        "mouse": "M6 3h12v18H6z M12 3v6",
        "keyboard": "M2 6h20v12H2z M6 10h1 M10 10h1 M14 10h1 M18 10h1 M7 14h10",
        "gaming-input": "M2 8h20v10H2z M7 11v4 M5 13h4 M15 12h1 M18 14h1",
        "headset": "M4 15v-3a8 8 0 0 1 16 0v3 M3 14h4v6H3z M17 14h4v6h-4z",
        "headphones": "M4 15v-3a8 8 0 0 1 16 0v3 M3 14h4v6H3z M17 14h4v6h-4z",
        "cupcake": "M5 12h14l-2 9H7z M5 12a7 7 0 0 1 14 0 M10 12l0.6 9 M14 12l-0.6 9",
        "cupcake-off": "M5 12h14l-2 9H7z M5 12a7 7 0 0 1 14 0",
        "speakers": "M6 3h12v18H6z M10 8h4 M12 13a2 2 0 1 0 0.01 0"
    })

    Shape {
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: icon.color
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: icon.paths[icon.name] || icon.paths["mouse"] }
        }
    }
}
