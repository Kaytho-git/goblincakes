// GOBLINCAKES' frame (ram – shared, Levande utseende step 1): the flat box behind a group of things. Panels and
// title bars #0B1018 (standard), cards and lists #0E1420 (color: "#0E1420"). With Stil: Levande the light
// (Light.qml, step 3) – hovered: <its MouseArea>.containsMouse for a frame you can press.
import QtQuick

Rectangle {
    id: frame
    property alias hovered: frameLight.hovered
    Light { id: frameLight }
    // Levande (Config → Utseende → Stil) and no game running: a frame that changes (chosen, under the mouse) fades (Levande utseende step 2)
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    color: "#0B1018"
    border.width: 1
    border.color: "#1E2A40"
    Behavior on color { enabled: frame.moving; ColorAnimation { duration: 160 } }
    Behavior on border.color { enabled: frame.moving; ColorAnimation { duration: 160 } }
}
