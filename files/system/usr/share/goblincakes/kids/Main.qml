// GOBLINCAKES Barnläge (13 Nov): the whole main screen – the splash, then big pictures of his games and programs
// (Config → BARNLÄGE), a picture button for the background and an X (top right) that asks for the PIN code.
// The other screens get a calm night sky ("GOBLINCAKES barnläge 2" …, placed by kwin-on.js).
// Backend: /usr/bin/goblin-kids ("backend"). Only the mouse – no gamepad (the user's choice).
import QtQuick
import QtQuick.Window
import QtQml
import "../qml/Goblin" as G

Window {
    G.Backdrop {}   // Stil: Levande – the soft background (qml/Goblin)
    id: win
    title: "GOBLINCAKES barnläge"
    color: "#02030A"
    flags: Qt.FramelessWindowHint
    width: 1280
    height: 800
    screen: mainScreen
    visibility: testMode ? Window.Windowed : Window.FullScreen
    visible: true

    readonly property var items: JSON.parse(backend.items)
    readonly property var backgrounds: JSON.parse(backend.backgrounds)
    readonly property var songs: JSON.parse(backend.songs)
    // His games, and last the music picture (GOBLINCAKES' songs) when there are songs and it is chosen in Config
    readonly property var tiles: songs.length ? items.concat([{ "kind": "music", "name": "Musik" }]) : items
    property bool listening: false        // the music box
    property bool ready: false            // the splash is over
    property bool leaving: false
    property bool choosing: false         // the picture chooser
    property bool asking: false           // the PIN code

    onClosing: close => { close.accepted = win.leaving; }

    Component.onCompleted: backend.sound("magi")
    Connections {
        target: backend
        function onLeaving() { win.leaving = true; }
    }

    function rnd(i, seed) {
        const v = Math.sin(i * 12.9898 + seed * 78.233) * 43758.5453;
        return v - Math.floor(v);
    }

    // ── the background, and sparkles drifting up through it
    Scene { anchors.fill: parent; kind: backend.background }
    Repeater {
        model: 18
        Sparkle {
            id: drift
            required property int index
            property real p: win.rnd(index, 31)
            size: 8 + win.rnd(index, 32) * 14
            color: ["#FFF4CF", "#FFD6F0", "#D6F6FF"][index % 3]
            x: win.rnd(index, 33) * win.width + Math.sin(p * 6.28 * 2 + index) * 30
            y: win.height * (1.05 - p * 1.15)
            opacity: Math.sin(p * Math.PI) * 0.6
            NumberAnimation on p {
                from: 0; to: 1; loops: Animation.Infinite
                duration: 14000 + win.rnd(drift.index, 34) * 12000
            }
        }
    }

    // ── his games and programs
    Item {
        id: board
        anchors.fill: parent
        // The lower part of the screen – the middle and the top are left to the background (the user 13 Nov)
        anchors.leftMargin: parent.width * 0.06
        anchors.rightMargin: parent.width * 0.06
        anchors.topMargin: parent.height * 0.58
        anchors.bottomMargin: parent.height * 0.05
        visible: win.ready

        readonly property int gap: Math.max(24, width * 0.025)
        readonly property real ratio: 1.5      // Steam's covers: 600 × 900
        readonly property real minW: 140
        // The biggest pictures that fit; under minW they keep minW and the board scrolls
        readonly property var fit: {
            const n = Math.max(1, win.tiles.length);
            let best = { cols: 1, w: 0 };
            for (let cols = 1; cols <= n; cols++) {
                const rows = Math.ceil(n / cols);
                const w = Math.min((width - (cols - 1) * gap) / cols, ((height - (rows - 1) * gap) / rows) / ratio);
                if (w > best.w)
                    best = { cols: cols, w: w };
            }
            best.w = Math.min(best.w, (height - 24) / ratio, 200);   // not so big (the user 13 Nov)
            if (best.w < minW) {
                best.cols = Math.max(1, Math.floor((width + gap) / (minW + gap)));
                best.w = minW;
            }
            return best;
        }

        Flickable {
            id: flick
            G.FastWheel { flick: flick }
            anchors.fill: parent
            contentWidth: width
            contentHeight: Math.max(height, grid.height + 24)
            boundsBehavior: Flickable.StopAtBounds
            clip: interactive     // only when it scrolls – the bobbing and the glow may go outside
            interactive: contentHeight > height + 1

            Grid {
                id: grid
                columns: board.fit.cols
                spacing: board.gap
                x: (flick.width - width) / 2
                y: Math.max(12, flick.height - height - 12)   // standing on the bottom
                Repeater {
                    model: win.tiles
                    Tile {
                        required property var modelData
                        required property int index
                        item: modelData
                        number: index
                        width: board.fit.w
                        height: board.fit.w * board.ratio
                        shown: win.ready
                    }
                }
            }
        }
    }

    component Tile: Item {
        id: tile
        property var item
        property int number
        property bool shown: false
        property bool starting: false
        readonly property bool hover: area.containsMouse && !starting
        property real bob: 0
        property real pop: 0
        z: hover ? 2 : 1

        SequentialAnimation on bob {
            loops: Animation.Infinite
            NumberAnimation { from: -1; to: 1; duration: 2400 + tile.number * 230; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1; to: -1; duration: 2400 + tile.number * 230; easing.type: Easing.InOutSine }
        }
        onShownChanged: if (shown) popIn.start()
        SequentialAnimation {
            id: popIn
            PauseAnimation { duration: 120 + tile.number * 110 }
            NumberAnimation { target: tile; property: "pop"; from: 0; to: 1; duration: 650; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }

        Item {
            id: body
            width: parent.width
            height: parent.height
            y: tile.bob * 6
            scale: tile.pop * (tile.hover ? 1.06 : 1)
            opacity: Math.min(1, tile.pop * 1.5)
            Behavior on scale { enabled: tile.pop >= 1; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // the glow
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width + (3 - index) * 14
                    height: parent.height + (3 - index) * 14
                    color: "transparent"
                    border.width: 7
                    border.color: accent.color
                    opacity: (tile.hover ? 0.22 : 0.07) + index * (tile.hover ? 0.12 : 0.04)
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }
            }
            Rectangle {
                anchors.fill: parent
                color: "#0E1420"
                border.width: 4
                border.color: tile.hover ? "#FFF4CF" : "#2A3852"
                Behavior on border.color { ColorAnimation { duration: 200 } }
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    visible: !!tile.item.cover
                    source: tile.item.cover ? "file://" + tile.item.cover : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.height: 900
                }
                // A program: its icon big in a soft spotlight, its name under
                Item {
                    anchors.fill: parent
                    visible: !tile.item.cover && tile.item.kind !== "music"
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#1B2E5A" }
                            GradientStop { position: 1.0; color: "#0B1018" }
                        }
                    }
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height * 0.38 - height / 2
                            width: parent.width * (0.95 - index * 0.2); height: width; radius: width / 2
                            color: "#7FE3FF"; opacity: 0.05 + index * 0.04
                        }
                    }
                    // No icon (or a game without a cover): a big turning sparkle instead
                    Sparkle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height * 0.38 - height / 2
                        size: parent.width * 0.45
                        color: "#FFD93D"
                        visible: iconImage.status !== Image.Ready || iconImage.implicitWidth <= 1
                        RotationAnimation on rotation { from: 0; to: 360; duration: 9000; loops: Animation.Infinite }
                    }
                    Image {
                        id: iconImage
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height * 0.38 - height / 2
                        width: parent.width * 0.62; height: width
                        source: tile.item.icon ? "image://icon/" + tile.item.icon : ""
                        sourceSize.width: 256; sourceSize.height: 256
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    Text {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
                        height: parent.height * 0.28
                        text: tile.item.name || ""
                        color: "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: Math.max(16, tile.width * 0.1)
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 12
                    }
                }
                // The music picture: notes on purple, and dancing bars while a song plays
                MusicArt {
                    anchors.fill: parent
                    anchors.margins: 4
                    visible: tile.item.kind === "music"
                    seed: 0
                    dancing: backend.playing !== ""
                }
                // Starting: dimmed, with a ring of sparkles turning
                Rectangle {
                    anchors.fill: parent
                    color: "#02030A"
                    opacity: tile.starting ? 0.55 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
                Item {
                    anchors.centerIn: parent
                    width: parent.width * 0.5; height: width
                    visible: tile.starting
                    RotationAnimation on rotation { running: tile.starting; from: 0; to: 360; duration: 1800; loops: Animation.Infinite }
                    Repeater {
                        model: 8
                        Sparkle {
                            required property int index
                            size: 18 + (index % 3) * 6
                            color: ["#FFD93D", "#FF7EB6", "#7FE3FF", "#B69CFF"][index % 4]
                            x: parent.width / 2 + Math.cos(index / 8 * Math.PI * 2) * parent.width / 2 - size / 2
                            y: parent.height / 2 + Math.sin(index / 8 * Math.PI * 2) * parent.height / 2 - size / 2
                        }
                    }
                }
            }
        }

        // the burst when clicked
        Repeater {
            model: 14
            Sparkle {
                required property int index
                readonly property real a: index / 14 * Math.PI * 2
                property real p: 0
                size: 16 + (index % 4) * 6
                color: ["#FFD93D", "#FF7EB6", "#7FE3FF", "#B69CFF", "#8CFFB0"][index % 5]
                x: tile.width / 2 + Math.cos(a) * tile.width * 0.8 * p - size / 2
                y: tile.height / 2 + Math.sin(a) * tile.height * 0.6 * p - size / 2
                rotation: p * 360
                opacity: p > 0 && p < 1 ? 1 - p : 0
                NumberAnimation on p { id: fly; running: false; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
                Connections {
                    target: tile
                    function onStartingChanged() { if (tile.starting) fly.restart(); }
                }
            }
        }
        SequentialAnimation {
            id: press
            NumberAnimation { target: body; property: "rotation"; to: -3; duration: 80 }
            NumberAnimation { target: body; property: "rotation"; to: 3; duration: 110 }
            NumberAnimation { target: body; property: "rotation"; to: 0; duration: 90 }
        }
        Timer { id: startingTimer; interval: 8000; onTriggered: tile.starting = false }
        // The mouse resting on it a moment: Cori says the name (not while the mouse just passes over)
        Timer { id: nameTimer; interval: 400; onTriggered: tile.item.kind === "music" ? backend.sayMusic() : backend.sayName(tile.number) }
        onHoverChanged: hover ? nameTimer.restart() : nameTimer.stop()

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (tile.item.kind === "music") {
                    backend.sound("pling");
                    press.restart();
                    win.listening = true;
                    return;
                }
                if (tile.starting || !backend.launch(tile.number))
                    return;
                backend.sound("pling");
                tile.starting = true;
                press.restart();
                startingTimer.restart();
            }
        }
    }

    // ── the background button (top left – the games are at the bottom): his own choice of picture
    Item {
        id: bgButton
        visible: win.ready
        anchors { left: parent.left; top: parent.top; margins: Math.max(20, parent.height * 0.03) }
        width: Math.max(96, win.height * 0.11); height: width * 0.75
        scale: bgArea.containsMouse ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: 180 } }
        Rectangle { anchors.fill: parent; anchors.margins: -6; color: "transparent"; border.width: 4; border.color: "#FFF4CF"; opacity: bgArea.containsMouse ? 0.5 : 0.18 }
        Scene { anchors.fill: parent; kind: backend.background; small: true; still: true }
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 3; border.color: "#E6ECF5" }
        Sparkle { size: parent.width * 0.32; x: parent.width - size * 0.7; y: -size * 0.3; color: "#FFD93D"
            RotationAnimation on rotation { from: 0; to: 360; duration: 6000; loops: Animation.Infinite } }
        MouseArea {
            id: bgArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { backend.refreshBackgrounds(); win.choosing = true; }
        }
    }

    // ── the X (top right, quiet so it doesn't call to him): the PIN code
    Rectangle {
        id: closeButton
        anchors { right: parent.right; top: parent.top; margins: 18 }
        width: 44; height: 44
        color: closeArea.containsMouse ? "#0B1018" : "transparent"
        border.width: 1
        border.color: closeArea.containsMouse ? "#2A3852" : "transparent"
        opacity: closeArea.containsMouse ? 1 : 0.45
        Repeater {
            model: [45, -45]
            Rectangle {
                required property var modelData
                anchors.centerIn: parent
                width: 22; height: 2.5
                rotation: modelData
                color: "#E6ECF5"
            }
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { pin.reset(); win.asking = true; }
        }
    }

    // ── the picture chooser
    Item {
        anchors.fill: parent
        visible: win.choosing
        Rectangle { anchors.fill: parent; color: "#02030A"; opacity: 0.78 }
        MouseArea { anchors.fill: parent; onClicked: win.choosing = false }
        Flickable {
            id: pics
            G.FastWheel { flick: pics }
            anchors.fill: parent
            anchors.margins: parent.width * 0.06
            contentHeight: picFlow.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Flow {
                id: picFlow
                width: pics.width
                spacing: 28
                readonly property real w: Math.max(200, Math.min(340, (pics.width - 3 * 28) / 4))
                Repeater {
                    model: win.choosing ? win.backgrounds : []
                    Item {
                        id: pic
                        required property var modelData
                        required property int index
                        readonly property bool on: backend.background === modelData.id
                        width: picFlow.w; height: picFlow.w * 0.62
                        scale: picArea.containsMouse ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: 160 } }
                        Rectangle { anchors.fill: parent; anchors.margins: -8; color: "transparent"; border.width: 5; border.color: accent.color; visible: pic.on }
                        Scene { anchors.fill: parent; kind: pic.modelData.id; small: true; still: true }
                        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 3; border.color: pic.on ? "#FFF4CF" : "#2A3852" }
                        MouseArea {
                            id: picArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { backend.setBackground(pic.modelData.id); backend.sound("pling"); closeChooser.restart(); }
                        }
                    }
                }
            }
        }
        Timer { id: closeChooser; interval: 350; onTriggered: win.choosing = false }
    }

    // ── the music box: a big picture per song with ▶ Start and ■ Stopp
    Item {
        anchors.fill: parent
        visible: win.listening
        Rectangle { anchors.fill: parent; color: "#02030A"; opacity: 0.8 }
        MouseArea { anchors.fill: parent; onClicked: win.listening = false }
        Row {
            id: songRow
            anchors.centerIn: parent
            spacing: Math.max(28, win.width * 0.03)
            readonly property real side: Math.min(300, (win.width * 0.8 - spacing * (win.songs.length - 1)) / Math.max(1, win.songs.length),
                                                  win.height * 0.42)
            Repeater {
                model: win.listening ? win.songs : []
                Column {
                    id: song
                    required property var modelData
                    required property int index
                    readonly property bool on: backend.playing === modelData.path
                    spacing: 18
                    Item {
                        width: songRow.side; height: songRow.side
                        scale: song.on ? 1.04 : 1
                        Behavior on scale { NumberAnimation { duration: 250 } }
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -8
                            color: "transparent"; border.width: 6; border.color: accent.color
                            opacity: song.on ? 0.8 : 0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                        }
                        MusicArt { anchors.fill: parent; seed: song.index + 1; dancing: song.on }
                        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 3; border.color: song.on ? "#FFF4CF" : "#2A3852" }
                        MouseArea {   // the picture itself starts it too
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: song.on ? backend.stopSong() : backend.playSong(song.modelData.path)
                        }
                    }
                    Text {
                        width: songRow.side
                        text: song.modelData.name
                        color: "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: Math.max(16, songRow.side * 0.075)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16
                        BigButton {
                            label: "▶"
                            fill: "#2FA36B"
                            lit: song.on
                            onClicked: backend.playSong(song.modelData.path)
                        }
                        BigButton {
                            label: "■"
                            fill: "#D9485F"
                            lit: false
                            dim: !song.on
                            onClicked: backend.stopSong()
                        }
                    }
                }
            }
        }
    }

    component BigButton: Rectangle {
        id: big
        property string label
        property color fill
        property bool lit: false
        property bool dim: false
        signal clicked()
        width: Math.max(84, win.height * 0.085); height: width
        color: fill
        opacity: dim ? 0.35 : 1
        scale: bigArea.pressed ? 0.92 : bigArea.containsMouse ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        border.width: lit ? 5 : 0
        border.color: "#FFF4CF"
        Text {
            anchors.centerIn: parent
            text: big.label
            color: "white"
            font.pixelSize: big.width * 0.48
        }
        MouseArea {
            id: bigArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { backend.sound("pling"); big.clicked(); }
        }
    }

    // ── the PIN code (for the parent)
    Item {
        id: pin
        anchors.fill: parent
        visible: win.asking
        focus: win.asking
        property string code: ""
        property int wrong: 0
        property string note: ""
        readonly property bool locked: waitTimer.running

        function reset() { code = ""; note = ""; idle.restart(); }
        function digit(d) {
            if (locked || code.length >= 8)
                return;
            code += d;
            idle.restart();
            note = "";
            if (code.length >= 4 && backend.checkPin(code))
                backend.leave();
        }
        function back() { code = code.slice(0, -1); idle.restart(); }
        function ok() {
            if (locked || !code.length)
                return;
            if (backend.checkPin(code)) {
                backend.leave();
                return;
            }
            wrong++;
            code = "";
            shake.restart();
            if (wrong >= 5) {
                wrong = 0;
                waitTimer.restart();
                note = "Fel PIN-kod fem gånger – vänta 30 sekunder.";
            } else {
                note = "Fel PIN-kod.";
            }
        }
        Timer { id: waitTimer; interval: 30000; onTriggered: pin.note = "" }
        Timer { id: idle; interval: 30000; running: win.asking; onTriggered: win.asking = false }

        Keys.onPressed: event => {
            if (event.text >= "0" && event.text <= "9" && event.text.length === 1)
                pin.digit(event.text);
            else if (event.key === Qt.Key_Backspace)
                pin.back();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                pin.ok();
            else if (event.key === Qt.Key_Escape)
                win.asking = false;
            event.accepted = true;
        }
        onVisibleChanged: if (visible) forceActiveFocus()

        Rectangle { anchors.fill: parent; color: "#02030A"; opacity: 0.86 }
        MouseArea { anchors.fill: parent }   // nothing behind is clickable

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: 380; height: col.height + 64
            scale: Math.max(1, win.height / 820)
            color: "#0B1018"
            border.width: 1
            border.color: "#1E2A40"
            SequentialAnimation {
                id: shake
                NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: -14; duration: 50 }
                NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: 14; duration: 70 }
                NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: -8; duration: 70 }
                NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
            }
            Column {
                id: col
                x: 32; y: 32
                width: parent.width - 64
                spacing: 18
                Text {
                    text: "AVSLUTA BARNLÄGET"
                    color: "#E6ECF5"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 20
                    font.letterSpacing: 3
                }
                Text {
                    width: parent.width
                    text: pin.note || "Skriv PIN-koden."
                    color: pin.note ? accent.errorBright : "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                }
                Row {
                    spacing: 10
                    height: 20
                    Repeater {
                        model: Math.max(4, pin.code.length)
                        Rectangle {
                            required property int index
                            width: 16; height: 16
                            color: index < pin.code.length ? accent.color : "transparent"
                            border.width: 2
                            border.color: index < pin.code.length ? accent.color : "#2A3852"
                        }
                    }
                }
                Grid {
                    columns: 3
                    spacing: 10
                    Repeater {
                        model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]
                        Rectangle {
                            id: key
                            required property string modelData
                            width: (col.width - 20) / 3; height: 60
                            color: keyArea.pressed ? "#12203A" : keyArea.containsMouse ? "#0E1420" : "transparent"
                            border.width: 1
                            border.color: modelData === "OK" ? accent.color : "#1E2A40"
                            opacity: pin.locked ? 0.4 : 1
                            Text {
                                anchors.centerIn: parent
                                text: key.modelData
                                color: "#E6ECF5"
                                font.family: key.modelData === "OK" ? "Chakra Petch" : "IBM Plex Mono"
                                font.weight: Font.DemiBold
                                font.pixelSize: 22
                            }
                            MouseArea {
                                id: keyArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: key.modelData === "OK" ? pin.ok() : key.modelData === "⌫" ? pin.back() : pin.digit(key.modelData)
                            }
                        }
                    }
                }
                G.FlatButton {
                    width: parent.width
                    text: "Avbryt"
                    onClicked: win.asking = false
                }
            }
        }
    }

    // ── the splash, over everything
    Splash {
        id: splash
        anchors.fill: parent
        onFinishingChanged: if (finishing) win.ready = true
    }

    // ── ending: a quick fade to dark
    Rectangle {
        anchors.fill: parent
        color: "#02030A"
        opacity: win.leaving ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // ── the other screens: a calm night sky
    Instantiator {
        model: testMode ? 0 : Math.max(0, Qt.application.screens.length - 1)
        delegate: Window {
            required property int index
            title: "GOBLINCAKES barnläge " + (index + 2)
            flags: Qt.FramelessWindowHint
            color: "#02030A"
            screen: Qt.application.screens[index + 1]
            visibility: Window.FullScreen
            visible: !win.leaving
            onClosing: close => { close.accepted = win.leaving; }
            Scene { anchors.fill: parent; kind: "natt"; opacity: 0.45 }
        }
    }
}
