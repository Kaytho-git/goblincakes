// Barnläge's backgrounds: a picture (the parent's, or his own drawing from Tux Paint) or one of the four built in –
// Natthimmel, Havet, Regnbåge, Solnedgång – in Kakan's pixel art (PixelScene, 14 Nov) or drawn as before
// (DrawnScene, when kids.json says "pixelart": false). Used full size and as the chooser's small pictures.
import QtQuick

Item {
    id: scene
    property string kind: "natt"          // natt | hav | regnbage | solnedgang | a picture's path
    property bool small: false             // the chooser: fewer moving things
    property bool still: false             // nothing moves (the covers on the other screens move slowly anyway)
    property bool pixel: typeof backend === "undefined" || !backend || backend.pixelart !== false
    readonly property bool picture: kind.indexOf("/") === 0
    clip: true

    // ── a picture
    Rectangle { anchors.fill: parent; visible: scene.picture; color: "#0E1420" }
    Image {
        anchors.fill: parent
        visible: scene.picture
        source: scene.picture ? "file://" + scene.kind : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: scene.small ? 440 : 1920
    }

    // ── one of the four
    Loader {
        anchors.fill: parent
        active: !scene.picture
        sourceComponent: scene.pixel ? pixelScene : drawnScene
    }
    Component {
        id: pixelScene
        PixelScene { kind: scene.kind; small: scene.small; still: scene.still }
    }
    Component {
        id: drawnScene
        DrawnScene { kind: scene.kind; small: scene.small; still: scene.still }
    }
}
