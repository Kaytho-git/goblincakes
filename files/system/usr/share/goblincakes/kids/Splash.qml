// Barnläge's splash (13 Nov, the user: "något som fångar uppmärksamhet och förundran, magiskt"): in the dark the
// stars light up one by one, sparkles in every colour spiral into the middle, gather into a glowing orb that bursts
// in a flash of stars, a planet like Saturn comes in from far away (13 Nov – the rainbow before) – then his games appear. ~5 s, with the sound "magi" (kids.py).
// A click after the first moment skips to the end.
// 14 Nov: in Kakan's pixel art (kids.json "pixelart", as the backgrounds) – her space picture, gold and white sparkles
// tinted in every colour, her orb, a ring of square pixels and her Saturn; drawn as before when it is off.
import QtQuick

Item {
    id: splash
    signal done()
    property real t: 0                       // seconds since the start
    readonly property real cx: width / 2
    readonly property real cy: height * 0.46
    readonly property real reach: Math.max(width, height) * 0.62
    readonly property var starColours: ["#FFD93D", "#FF7EB6", "#7FE3FF", "#B69CFF", "#8CFFB0", "#FFFFFF", "#FFB86B"]
    property bool finishing: false
    property bool pixel: typeof backend === "undefined" || !backend || backend.pixelart !== false
    // pixel art: one background pixel (the 160 × 90 picture covering, ×12 on 1920 × 1080) and one figure pixel
    readonly property int u: Math.max(1, Math.ceil(Math.max(width / 160, height / 90)))
    readonly property int fu: Math.max(1, Math.round(u / 4))

    function rnd(i, seed) {
        const v = Math.sin(i * 12.9898 + seed * 78.233) * 43758.5453;
        return v - Math.floor(v);
    }
    function phase(start, length) { return Math.max(0, Math.min(1, (t - start) / length)); }
    function finish() {
        if (finishing)
            return;
        finishing = true;
        fadeOut.start();
    }

    NumberAnimation on t { id: clock; from: 0; to: 6; duration: 6000; running: true }
    onTChanged: if (t >= 5.0) finish()   // a moment to look at the planet

    Rectangle { anchors.fill: parent; color: "#02030A" }

    // pixel art: Kakan's space, fading in
    Pix {
        visible: splash.pixel
        name: splash.pixel ? "splash" : ""
        unit: splash.u
        x: (splash.width - width) / 2; y: (splash.height - height) / 2
        opacity: splash.phase(0.2, 1.6)
        scale: 1 + splash.phase(0, 5) * 0.04
    }

    // soft nebulae of colour behind everything
    Repeater {
        model: [{ x: 0.22, y: 0.3, c: "#5B3FD6", s: 0.7 }, { x: 0.78, y: 0.62, c: "#1F7FBF", s: 0.8 },
                { x: 0.5, y: 0.46, c: "#B03FA0", s: 0.55 }]
        Item {
            id: nebula
            required property var modelData
            required property int index
            visible: !splash.pixel
            readonly property real d: Math.max(splash.width, splash.height) * modelData.s
            x: splash.width * modelData.x - d / 2; y: splash.height * modelData.y - d / 2
            width: d; height: d
            opacity: splash.phase(0.4 + index * 0.35, 1.6) * 0.9
            scale: 0.85 + splash.phase(0, 5) * 0.25
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width * (1 - index * 0.15); height: width; radius: width / 2
                    color: nebula.modelData.c
                    opacity: 0.035
                }
            }
        }
    }

    // ── the stars light up
    Repeater {
        model: 150
        Item {
            id: star
            required property int index
            readonly property real born: splash.rnd(index, 1) * 1.6
            readonly property real s: 1.5 + splash.rnd(index, 2) * 3
            x: splash.rnd(index, 3) * splash.width
            y: splash.rnd(index, 4) * splash.height
            opacity: splash.phase(born, 0.5) * twinkle
            property real twinkle: 1
            SequentialAnimation on twinkle {
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 500 + splash.rnd(star.index, 5) * 1300; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 500 + splash.rnd(star.index, 6) * 1300; easing.type: Easing.InOutSine }
            }
            Rectangle {
                visible: star.index % 9 !== 0
                // pixel art: square, half a background pixel (every fourth a whole one)
                width: splash.pixel ? (star.index % 4 === 0 ? splash.u : Math.max(1, Math.round(splash.u / 2))) : star.s
                height: width; radius: splash.pixel ? 0 : width / 2
                color: star.index % 5 === 0 ? "#FFE7A8" : "#DDE8FF"
            }
            Glint {
                visible: star.index % 9 === 0
                pixel: splash.pixel; star: true; unit: 1
                size: star.s * 4
                x: -width / 2; y: -height / 2
                color: "#FFF4CF"
            }
        }
    }

    // ── sparkles spiral into the middle (0.5 → 2.5 s)
    Repeater {
        model: 56
        Glint {
            id: sw
            required property int index
            readonly property real start: 0.45 + splash.rnd(index, 7) * 0.7
            readonly property real p: splash.phase(start, 1.35 + splash.rnd(index, 8) * 0.35)
            readonly property real eased: 1 - Math.pow(1 - p, 2.2)
            readonly property real a: splash.rnd(index, 9) * Math.PI * 2 + eased * Math.PI * 1.7
            readonly property real r: splash.reach * (1 - eased)
            size: 10 + splash.rnd(index, 10) * 22
            pixel: splash.pixel
            star: index % 3 === 0
            unit: Math.max(1, Math.round(splash.fu * (0.3 + splash.rnd(index, 10) * 0.45)))
            color: splash.starColours[index % splash.starColours.length]
            x: splash.cx + Math.cos(a) * r - width / 2
            y: splash.cy + Math.sin(a) * r - height / 2
            rotation: splash.pixel ? 0 : eased * 360     // turned pixels look broken
            scale: 0.6 + (1 - eased) * 0.6
            opacity: p <= 0 || p >= 1 ? 0 : Math.min(1, p * 5) * Math.min(1, (1 - p) * 6 + 0.25)
        }
    }

    // ── the orb gathers (2.0 → 2.6 s) and bursts at 2.55 s
    Item {
        id: orb
        readonly property real grow: splash.phase(1.9, 0.65)
        readonly property real gone: splash.phase(2.55, 0.25)
        readonly property real pulse: 1 + Math.sin(splash.t * 22) * 0.04
        width: Math.min(splash.width, splash.height) * 0.22 * grow * (1 - gone) * pulse
        height: width
        x: splash.cx - width / 2
        y: splash.cy - height / 2
        visible: width > 0.5
        Repeater {
            model: splash.pixel ? 0 : 5
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: parent.width * (2.4 - index * 0.35); height: width; radius: width / 2
                color: index < 2 ? "#B69CFF" : index < 4 ? "#7FE3FF" : "#FFFFFF"
                opacity: 0.08 + index * 0.08
            }
        }
        Rectangle { visible: !splash.pixel; anchors.centerIn: parent; width: parent.width * 0.55; height: width; radius: width / 2; color: "white" }
        Pix {   // Kakan's orb, its own whole-number size, grown by scale
            visible: splash.pixel
            name: splash.pixel ? "ljusklot" : ""
            unit: Math.max(1, Math.round(Math.min(splash.width, splash.height) * 0.22 / 64))
            anchors.centerIn: parent
            scale: orb.width / width
        }
    }

    // the ring of the burst – pixel art: a ring of square pixels
    Repeater {
        model: splash.pixel ? 64 : 0
        Rectangle {
            required property int index
            readonly property real p: splash.phase(2.55, 1.0)
            readonly property real r: Math.max(splash.width, splash.height) * 0.8 * (1 - Math.pow(1 - p, 3))
            readonly property real a: index / 64 * Math.PI * 2
            width: splash.u * (p < 0.5 ? 2 : 1); height: width
            x: Math.round((splash.cx + Math.cos(a) * r) / splash.u) * splash.u - width / 2
            y: Math.round((splash.cy + Math.sin(a) * r) / splash.u) * splash.u - height / 2
            color: index % 2 ? "#FFF4CF" : "#FFD93D"
            opacity: p > 0 && p < 1 ? (1 - p) * 0.9 : 0
        }
    }
    Rectangle {
        visible: !splash.pixel
        readonly property real p: splash.phase(2.55, 1.0)
        width: Math.max(splash.width, splash.height) * 1.6 * (1 - Math.pow(1 - p, 3))
        height: width; radius: width / 2
        x: splash.cx - width / 2; y: splash.cy - height / 2
        color: "transparent"
        border.color: "#FFF4CF"
        border.width: 6 + 30 * (1 - p)
        opacity: p > 0 && p < 1 ? (1 - p) * 0.8 : 0
    }

    // stars flying out of the burst
    Repeater {
        model: 44
        Glint {
            required property int index
            readonly property real p: splash.phase(2.55 + splash.rnd(index, 11) * 0.12, 1.4 + splash.rnd(index, 12) * 0.8)
            readonly property real a: splash.rnd(index, 13) * Math.PI * 2
            readonly property real r: splash.reach * (0.25 + splash.rnd(index, 14) * 0.85) * (1 - Math.pow(1 - p, 3))
            size: 14 + splash.rnd(index, 15) * 30
            pixel: splash.pixel
            star: index % 2 === 0
            unit: Math.max(1, Math.round(splash.fu * (0.3 + splash.rnd(index, 15) * 0.5)))
            color: splash.starColours[(index + 3) % splash.starColours.length]
            x: splash.cx + Math.cos(a) * r - width / 2
            y: splash.cy + Math.sin(a) * r - height / 2 + p * p * splash.height * 0.12   // they sink a little
            rotation: splash.pixel ? 0 : p * 540
            opacity: p > 0 && p < 1 ? Math.min(1, (1 - p) * 2.5) : 0
        }
    }

    // ── a planet like Saturn comes in from far away (2.6 → 4.4 s), turning a little as it nears
    Saturn {
        visible: !splash.pixel && p > 0
        readonly property real p: splash.phase(2.6, 1.8)
        readonly property real eased: 1 - Math.pow(1 - p, 3)
        width: Math.min(splash.width, splash.height) * 0.9
        height: width
        x: splash.cx - width / 2
        y: splash.cy - height / 2 - (1 - eased) * splash.height * 0.08
        scale: 0.02 + eased * 0.98 + splash.phase(4.4, 1.0) * 0.06
        rotation: -12 * (1 - eased)
        opacity: Math.min(1, p * 4)
    }
    Pix {   // Kakan's Saturn: ends at exactly its whole-number size, so it stays sharp while he looks at it
        visible: splash.pixel && p > 0
        readonly property real p: splash.phase(2.6, 1.8)
        readonly property real eased: 1 - Math.pow(1 - p, 3)
        name: splash.pixel ? "saturnus" : ""
        unit: Math.max(1, Math.floor(Math.min(splash.width, splash.height) * 0.8 / 128))
        x: splash.cx - width / 2
        y: splash.cy - height / 2 - (1 - eased) * splash.height * 0.08
        scale: 0.02 + eased * 0.98
        rotation: -12 * (1 - eased)
        opacity: Math.min(1, p * 4)
    }

    // the flash
    Rectangle {
        anchors.fill: parent
        color: "white"
        opacity: splash.t < 2.55 ? 0 : Math.max(0, 0.6 - (splash.t - 2.55) * 1.6)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (splash.t > 1.2) splash.finish()
    }

    NumberAnimation {
        id: fadeOut
        target: splash
        property: "opacity"
        to: 0
        duration: 700
        easing.type: Easing.InOutQuad
        onFinished: { clock.stop(); splash.visible = false; splash.done(); }
    }
}
