// Barnläge's backgrounds as they were drawn here before the pixel art (13 Nov): Natthimmel, Havet, Regnbåge,
// Solnedgång. Scene.qml uses this when kids.json says "pixelart": false.
import QtQuick

Item {
    id: scene
    property string kind: "natt"          // natt | hav | regnbage | solnedgang
    property bool small: false             // the chooser: fewer moving things
    property bool still: false             // nothing moves
    clip: true

    function rnd(i, seed) {
        const v = Math.sin(i * 12.9898 + seed * 78.233) * 43758.5453;
        return v - Math.floor(v);
    }

    // ── Natthimmel
    Item {
        anchors.fill: parent
        visible: scene.kind === "natt"
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#03050F" }
                GradientStop { position: 0.55; color: "#0B1638" }
                GradientStop { position: 1.0; color: "#1D2C66" }
            }
        }
        Repeater {
            model: scene.small ? 40 : 110
            Rectangle {
                required property int index
                readonly property real s: 1 + scene.rnd(index, 3) * (scene.small ? 1.5 : 2.6)
                x: scene.rnd(index, 1) * scene.width
                y: scene.rnd(index, 2) * scene.height * 0.78
                width: s; height: s; radius: s / 2
                color: index % 7 === 0 ? "#FFE7A8" : "#E6ECF5"
                opacity: 0.35 + scene.rnd(index, 4) * 0.6
                SequentialAnimation on opacity {
                    running: !scene.still && !scene.small && index % 3 === 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 900 + scene.rnd(index, 5) * 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.95; duration: 900 + scene.rnd(index, 6) * 1800; easing.type: Easing.InOutSine }
                }
            }
        }
        // The moon, with its glow
        Item {
            x: parent.width * 0.74; y: parent.height * 0.12
            width: Math.min(parent.width, parent.height) * 0.16; height: width
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width * (1.9 - index * 0.25); height: width; radius: width / 2
                    color: "#FFF4CF"; opacity: 0.035 + index * 0.02
                }
            }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#FFF6DA" }
            Rectangle { x: parent.width * 0.22; y: parent.height * 0.3; width: parent.width * 0.18; height: width; radius: width / 2; color: "#EFE3BC" }
            Rectangle { x: parent.width * 0.55; y: parent.height * 0.55; width: parent.width * 0.13; height: width; radius: width / 2; color: "#EFE3BC" }
            Rectangle { x: parent.width * 0.58; y: parent.height * 0.2; width: parent.width * 0.09; height: width; radius: width / 2; color: "#EFE3BC" }
        }
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"), w = width, h = height;
                c.reset();
                c.fillStyle = "#0A1230";
                c.beginPath(); c.moveTo(0, h);
                c.bezierCurveTo(w * 0.2, h * 0.72, w * 0.42, h * 0.8, w * 0.6, h * 0.86);
                c.bezierCurveTo(w * 0.75, h * 0.9, w * 0.9, h * 0.76, w, h * 0.8);
                c.lineTo(w, h); c.closePath(); c.fill();
                c.fillStyle = "#060B20";
                c.beginPath(); c.moveTo(0, h);
                c.bezierCurveTo(w * 0.25, h * 0.86, w * 0.5, h * 0.92, w, h * 0.9);
                c.lineTo(w, h); c.closePath(); c.fill();
            }
        }
    }

    // ── Havet
    Item {
        anchors.fill: parent
        visible: scene.kind === "hav"
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1B8FB8" }
                GradientStop { position: 0.45; color: "#0B5C86" }
                GradientStop { position: 1.0; color: "#042339" }
            }
        }
        Repeater {   // light from the surface
            model: 6
            Rectangle {
                required property int index
                x: scene.width * (0.08 + index * 0.17); y: -scene.height * 0.1
                width: scene.width * 0.06; height: scene.height * 1.1
                rotation: 14; transformOrigin: Item.Top
                color: "#BFF3FF"; opacity: 0.07
                SequentialAnimation on opacity {
                    running: !scene.still && !scene.small
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.02; duration: 2400 + index * 400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.09; duration: 2400 + index * 400; easing.type: Easing.InOutSine }
                }
            }
        }
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"), w = width, h = height;
                c.reset();
                c.fillStyle = "#E3C98F";
                c.beginPath(); c.moveTo(0, h);
                c.bezierCurveTo(w * 0.3, h * 0.84, w * 0.6, h * 0.95, w, h * 0.86);
                c.lineTo(w, h); c.closePath(); c.fill();
                c.fillStyle = "#2E8B57";   // seaweed
                for (let i = 0; i < 9; i++) {
                    const x = w * (0.05 + i * 0.11), top = h * (0.62 + (i % 3) * 0.06);
                    c.beginPath(); c.moveTo(x, h);
                    c.bezierCurveTo(x - w * 0.02, h * 0.85, x + w * 0.025, top + h * 0.08, x, top);
                    c.bezierCurveTo(x + w * 0.035, top + h * 0.1, x + w * 0.005, h * 0.85, x + w * 0.02, h);
                    c.closePath(); c.fill();
                }
            }
        }
        Repeater {   // bubbles
            model: scene.small ? 8 : 22
            Rectangle {
                id: bubble
                required property int index
                readonly property real s: 6 + scene.rnd(index, 9) * (scene.small ? 8 : 22)
                width: s; height: s; radius: s / 2
                color: "transparent"; border.color: "#D8F6FF"; border.width: Math.max(1, s / 10)
                opacity: 0.55
                x: scene.rnd(index, 7) * scene.width
                property real rise: scene.rnd(index, 8)
                y: scene.height * (1.05 - rise * 1.15)
                NumberAnimation on rise {
                    running: !scene.still
                    from: 0; to: 1; loops: Animation.Infinite
                    duration: 7000 + scene.rnd(index, 10) * 7000
                }
            }
        }
    }

    // ── Regnbåge
    Item {
        anchors.fill: parent
        visible: scene.kind === "regnbage"
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#4FB3EA" }
                GradientStop { position: 0.7; color: "#BDE6FA" }
                GradientStop { position: 1.0; color: "#E9F7FF" }
            }
        }
        Item {   // the sun
            x: parent.width * 0.08; y: parent.height * 0.08
            width: Math.min(parent.width, parent.height) * 0.17; height: width
            Item {
                anchors.fill: parent
                RotationAnimation on rotation { running: !scene.still && !scene.small; from: 0; to: 360; duration: 40000; loops: Animation.Infinite }
                Repeater {
                    model: 12
                    Rectangle {
                        required property int index
                        x: parent.width / 2 - width / 2; y: -parent.height * 0.32
                        width: parent.width * 0.07; height: parent.height * 0.3
                        radius: width / 2
                        color: "#FFD95A"
                        transform: Rotation { origin.x: width / 2; origin.y: parent.height * 0.82; angle: index * 30 }
                    }
                }
            }
            Rectangle { anchors.fill: parent; anchors.margins: parent.width * 0.12; radius: width / 2; color: "#FFE066" }
        }
        Rainbow { anchors.fill: parent; progress: 1 }
        Repeater {   // clouds
            model: 3
            Item {
                id: cloud
                required property int index
                readonly property real s: scene.width * (0.12 + index * 0.03)
                width: s; height: s * 0.5
                y: scene.height * (0.12 + index * 0.13)
                property real drift: scene.rnd(index, 12)
                x: -s + drift * (scene.width + s)
                NumberAnimation on drift {
                    running: !scene.still && !scene.small
                    from: scene.rnd(cloud.index, 12); to: 1.0; duration: 60000 + cloud.index * 20000
                    onFinished: { cloud.drift = 0; restart(); }
                }
                Rectangle { x: 0; y: parent.height * 0.4; width: parent.width; height: parent.height * 0.6; radius: height / 2; color: "white" }
                Rectangle { x: parent.width * 0.18; y: parent.height * 0.08; width: parent.width * 0.38; height: width; radius: width / 2; color: "white" }
                Rectangle { x: parent.width * 0.45; y: 0; width: parent.width * 0.42; height: width; radius: width / 2; color: "white" }
            }
        }
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"), w = width, h = height;
                c.reset();
                c.fillStyle = "#7BC86C";
                c.beginPath(); c.moveTo(0, h);
                c.bezierCurveTo(w * 0.2, h * 0.74, w * 0.45, h * 0.78, w * 0.62, h * 0.88);
                c.bezierCurveTo(w * 0.78, h * 0.8, w * 0.92, h * 0.78, w, h * 0.82);
                c.lineTo(w, h); c.closePath(); c.fill();
                c.fillStyle = "#5BAF55";
                c.beginPath(); c.moveTo(0, h);
                c.bezierCurveTo(w * 0.3, h * 0.88, w * 0.6, h * 0.94, w, h * 0.9);
                c.lineTo(w, h); c.closePath(); c.fill();
            }
        }
    }

    // ── Solnedgång
    Item {
        anchors.fill: parent
        visible: scene.kind === "solnedgang"
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2B1055" }
                GradientStop { position: 0.35; color: "#7A2A8C" }
                GradientStop { position: 0.58; color: "#E2508F" }
                GradientStop { position: 0.72; color: "#FFA45B" }
                GradientStop { position: 0.72; color: "#3B2463" }
                GradientStop { position: 1.0; color: "#160A33" }
            }
        }
        Item {
            x: parent.width / 2 - width / 2; y: parent.height * 0.72 - height / 2
            width: Math.min(parent.width, parent.height) * 0.36; height: width
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width * (1.8 - index * 0.2); height: width; radius: width / 2
                    color: "#FFD27A"; opacity: 0.05 + index * 0.03
                }
            }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#FFD27A" }
        }
        Rectangle {   // the sea in front of the sun's lower half
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * 0.28
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#3B2463" }
                GradientStop { position: 1.0; color: "#160A33" }
            }
        }
        Repeater {   // the sun's path on the water
            model: 7
            Rectangle {
                required property int index
                anchors.horizontalCenter: parent.horizontalCenter
                y: scene.height * (0.745 + index * 0.033)
                width: scene.width * (0.22 - index * 0.022); height: Math.max(2, scene.height * 0.008)
                color: "#FFC56E"; opacity: 0.7 - index * 0.08
                SequentialAnimation on opacity {
                    running: !scene.still && !scene.small
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 1300 + index * 210; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.75 - index * 0.08; duration: 1300 + index * 210; easing.type: Easing.InOutSine }
                }
            }
        }
        Repeater {
            model: scene.small ? 10 : 40
            Rectangle {
                required property int index
                x: scene.rnd(index, 21) * scene.width; y: scene.rnd(index, 22) * scene.height * 0.32
                width: 2; height: 2; radius: 1; color: "#FFE7F2"; opacity: 0.25 + scene.rnd(index, 23) * 0.5
            }
        }
    }
}
