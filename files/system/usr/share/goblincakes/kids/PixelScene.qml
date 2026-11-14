// Barnläge's four backgrounds in Kakan's pixel art (14 Nov, the user: "Kakan gjorde ett fantastiskt fint jobb"):
// the picture (160 × 90, pixelart/<file>.png) at a whole-number scale covering the screen – exactly ×12 on
// 1920 × 1080 – and what moves as its own picture on top: stars and moon, bubbles, sun and clouds, the setting sun.
// The figures use a finer scale than the background (a quarter of it), like the drawn version's sizes.
import QtQuick

Item {
    id: scene
    property string kind: "natt"          // natt | hav | regnbage | solnedgang
    property bool small: false             // the chooser: fewer moving things
    property bool still: false             // nothing moves
    clip: true

    readonly property var files: ({ natt: "natthimmel", hav: "havet", regnbage: "regnbage", solnedgang: "solnedgang" })
    readonly property int u: Math.max(1, Math.ceil(Math.max(width / 160, height / 90)))   // one background pixel
    readonly property int fu: Math.max(1, Math.round(u / 4))                              // one figure pixel
    readonly property real ox: (width - 160 * u) / 2
    readonly property real oy: (height - 90 * u) / 2
    function px(col) { return ox + col * u }     // the background's column / row → the screen
    function py(row) { return oy + row * u }
    function rnd(i, seed) {
        const v = Math.sin(i * 12.9898 + seed * 78.233) * 43758.5453;
        return v - Math.floor(v);
    }

    Pix { name: scene.files[scene.kind] || "natthimmel"; unit: scene.u; x: scene.ox; y: scene.oy }

    // ── Natthimmel: stars of single pixels that twinkle (hers were too small to survive the cleaning), and the moon
    Item {
        anchors.fill: parent
        visible: scene.kind === "natt"
        Repeater {
            model: scene.small ? 30 : 90
            Rectangle {
                required property int index
                x: scene.px(Math.floor(scene.rnd(index, 1) * 160))
                y: scene.py(Math.floor(scene.rnd(index, 2) * 50))
                width: index % 8 === 0 ? scene.u : Math.max(1, Math.round(scene.u / 2)); height: width
                color: index % 7 === 0 ? "#FFE7A8" : "#E6ECF5"
                opacity: 0.45 + scene.rnd(index, 4) * 0.55
                SequentialAnimation on opacity {
                    running: !scene.still && !scene.small && index % 3 === 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.1; duration: 900 + scene.rnd(index, 5) * 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900 + scene.rnd(index, 6) * 1800; easing.type: Easing.InOutSine }
                }
            }
        }
        Repeater {   // a few big stars, Kakan's
            model: scene.small ? 0 : 5
            Pix {
                required property int index
                name: "stjarna"
                unit: Math.max(1, Math.round(scene.fu / 2))
                x: scene.px(8 + index * 24 + Math.floor(scene.rnd(index, 31) * 12))
                y: scene.py(4 + Math.floor(scene.rnd(index, 32) * 34))
                SequentialAnimation on opacity {
                    running: !scene.still
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 1500 + index * 370; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1500 + index * 370; easing.type: Easing.InOutSine }
                }
            }
        }
        Pix { name: "mane"; unit: scene.fu; x: scene.px(122); y: scene.py(6) }
    }

    // ── Havet: bubbles rising
    Item {
        anchors.fill: parent
        visible: scene.kind === "hav"
        Repeater {
            model: scene.small ? 6 : 18
            Pix {
                required property int index
                name: "bubbla"
                unit: Math.max(1, Math.round(scene.fu * (0.2 + scene.rnd(index, 9) * 0.5)))
                opacity: 0.85
                x: scene.rnd(index, 7) * (scene.width - width)
                property real rise: scene.rnd(index, 8)
                y: scene.height * 1.05 - rise * scene.height * 1.15
                NumberAnimation on rise {
                    running: !scene.still
                    from: 0; to: 1; loops: Animation.Infinite
                    duration: 7000 + scene.rnd(index, 10) * 7000
                }
            }
        }
    }

    // ── Regnbåge: the sun breathing a little in the empty sky to the right, clouds drifting
    Item {
        anchors.fill: parent
        visible: scene.kind === "regnbage"
        Pix {
            id: sun
            name: "sol"; unit: scene.fu
            x: scene.px(132)
            property real bob: 0
            y: scene.py(4) + bob * scene.u
            SequentialAnimation on bob {
                running: !scene.still && !scene.small
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 2600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 2600; easing.type: Easing.InOutSine }
            }
        }
        Repeater {
            model: 3
            Pix {
                id: cloud
                required property int index
                name: "moln"
                unit: index === 1 ? scene.fu : Math.max(1, scene.fu - 1)
                y: scene.py(5 + index * 13)
                property real drift: scene.rnd(index, 12)
                x: -width + drift * (scene.width + width)
                NumberAnimation on drift {
                    running: !scene.still && !scene.small
                    from: scene.rnd(cloud.index, 12); to: 1.0; duration: 60000 + cloud.index * 20000
                    onFinished: { cloud.drift = 0; restart(); }
                }
            }
        }
    }

    // ── Solnedgång: the sun half down behind the sea (the horizon is row 74), its path shimmering on the water
    Item {
        anchors.fill: parent
        visible: scene.kind === "solnedgang"
        Item {
            x: 0; y: 0; width: parent.width; height: scene.py(74)
            clip: true
            Pix {
                name: "solnedgangssol"; unit: scene.fu * 2
                x: (parent.width - width) / 2
                y: parent.height - height * 0.55
            }
        }
        Repeater {
            model: 6
            Rectangle {
                required property int index
                readonly property int cols: 28 - index * 4
                x: scene.px(80 - cols / 2); y: scene.py(75 + index * 2)
                width: cols * scene.u; height: Math.max(1, Math.round(scene.u / 2))
                color: "#FFC56E"; opacity: 0.7 - index * 0.08
                SequentialAnimation on opacity {
                    running: !scene.still && !scene.small
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 1300 + index * 210; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.75 - index * 0.08; duration: 1300 + index * 210; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
