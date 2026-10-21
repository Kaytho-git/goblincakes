// GoblinAmp (21 Oct, the user's wish "tänk Winamp"): a small player window that steers the music
// program over MPRIS (goblin-amp). Winamp's main window in GOBLINCAKES' look – flat, square,
// Void/Night with thin frames, the time and title in the user's accent colour (accent.*),
// IBM Plex Mono for the digits, Chakra Petch for the name.
import QtQuick

Window {
    id: win
    title: "GoblinAmp"
    flags: Qt.Window | Qt.FramelessWindowHint
    width: 380
    height: shade ? 22 : 152
    minimumWidth: 380
    maximumWidth: 380
    minimumHeight: height
    maximumHeight: height
    visible: true
    color: "#07090D"

    property bool shade: false          // rolled up to the title line (double-click on it)
    property bool remaining: false      // the time counts down (click on the time)
    readonly property var st: JSON.parse(amp.state || "{}")
    readonly property bool hasPlayer: !!st.service
    readonly property bool playing: st.status === "Playing"
    property real now: Date.now()
    property real dragSeek: -1          // where the seek bar is being dragged to (seconds)

    // The time between two looks at the player: counted on here
    readonly property real position: {
        if (!hasPlayer)
            return 0;
        let p = st.position + (playing ? (now - st.readAt) / 1000 : 0);
        return st.length > 0 ? Math.min(p, st.length) : p;
    }
    Timer {
        interval: 250
        running: win.playing
        repeat: true
        onTriggered: win.now = Date.now()
    }

    function clock(seconds) {
        seconds = Math.max(0, Math.floor(seconds));
        const m = Math.floor(seconds / 60), s = seconds % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Connections {
        target: amp
        function onRaiseWindow() {
            win.show();
            win.raise();
            win.requestActivate();
        }
    }

    Shortcut { sequence: "Space"; onActivated: amp.control("playpause") }
    Shortcut { sequence: "Z"; onActivated: amp.control("previous") }
    Shortcut { sequence: "X"; onActivated: amp.control("play") }
    Shortcut { sequence: "C"; onActivated: amp.control("pause") }
    Shortcut { sequence: "V"; onActivated: amp.control("stop") }
    Shortcut { sequence: "B"; onActivated: amp.control("next") }
    Shortcut { sequence: "Esc"; onActivated: Qt.quit() }

    // ── Small parts ──

    // A flat square button with a drawn symbol (no font needed for ⏮ ▶ ❚❚ ■ ⏭)
    component Btn: Rectangle {
        id: btn
        property string glyph: ""
        property string label: ""
        property bool active: false
        signal clicked()
        width: label ? labelText.implicitWidth + 14 : 30
        height: 20
        color: btnArea.pressed ? "#05070A" : btnArea.containsMouse ? "#16203A" : "#0E1420"
        border.width: 1
        border.color: active ? accent.color : btnArea.containsMouse ? "#2A3852" : "#1E2A40"
        Text {
            id: labelText
            visible: btn.label !== ""
            anchors.centerIn: parent
            text: btn.label
            color: btn.active ? accent.text : "#8B98AD"
            font.family: "Chakra Petch"
            font.weight: Font.DemiBold
            font.pixelSize: 10
            font.letterSpacing: 1
        }
        Canvas {
            id: symbol
            visible: btn.glyph !== ""
            anchors.centerIn: parent
            width: 14
            height: 10
            property color ink: btnArea.containsMouse ? "#E6ECF5" : "#B8C2D3"
            onInkChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.fillStyle = ink;
                const tri = function (x0, x1) { c.beginPath(); c.moveTo(x0, 0); c.lineTo(x1, 5); c.lineTo(x0, 10); c.closePath(); c.fill(); };
                const back = function (x0, x1) { c.beginPath(); c.moveTo(x1, 0); c.lineTo(x0, 5); c.lineTo(x1, 10); c.closePath(); c.fill(); };
                if (btn.glyph === "play") tri(3, 12);
                else if (btn.glyph === "pause") { c.fillRect(3, 0, 3, 10); c.fillRect(8, 0, 3, 10); }
                else if (btn.glyph === "stop") c.fillRect(2, 0, 10, 10);
                else if (btn.glyph === "prev") { c.fillRect(1, 0, 2, 10); back(3, 8); back(8, 13); }
                else if (btn.glyph === "next") { tri(1, 6); tri(6, 11); c.fillRect(11, 0, 2, 10); }
            }
        }
        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // ── The frame and the title line (drag = move, double-click = roll up) ──

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: "#1E2A40"
        z: 10
    }

    Rectangle {
        id: titleBar
        x: 1; y: 1
        width: parent.width - 2
        height: 20
        color: "#05070A"
        MouseArea {
            anchors.fill: parent
            onPressed: win.startSystemMove()
            onDoubleClicked: win.shade = !win.shade
        }
        Image {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14
            source: iconUrl
            sourceSize: Qt.size(28, 28)
            visible: status === Image.Ready
        }
        Text {
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            text: "GOBLINAMP"
            color: "#8B98AD"
            font.family: "Chakra Petch"
            font.weight: Font.Bold
            font.pixelSize: 11
            font.letterSpacing: 2
        }
        // Rolled up: the title and the time in the line itself, like Winamp's windowshade
        Text {
            visible: win.shade
            x: 112
            width: 190
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: win.hasPlayer ? (st.artist ? st.artist + " – " : "") + (st.title || st.player) : "Ingen musik spelar"
            color: accent.text
            font.family: "IBM Plex Sans"
            font.pixelSize: 11
        }
        Text {
            visible: win.shade && win.hasPlayer
            anchors { right: shadeBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: win.clock(win.position)
            color: accent.text
            font.family: "IBM Plex Mono"
            font.weight: Font.DemiBold
            font.pixelSize: 11
        }
        Row {
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            spacing: 2
            Repeater {
                model: [["▁", "min"], [win.shade ? "▾" : "▴", "shade"], ["✕", "close"]]
                Rectangle {
                    id: tb
                    required property var modelData
                    width: 18; height: 14
                    color: tbArea.containsMouse ? (modelData[1] === "close" ? "#A4262C" : "#16203A") : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: tb.modelData[0]
                        color: tbArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                        font.pixelSize: 10
                    }
                    MouseArea {
                        id: tbArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (tb.modelData[1] === "close") Qt.quit();
                            else if (tb.modelData[1] === "min") win.showMinimized();
                            else win.shade = !win.shade;
                        }
                    }
                }
            }
        }
        Item { id: shadeBtn; anchors.right: parent.right; anchors.rightMargin: 66; width: 1; height: 1 }
    }

    // ── The display: time, state, bars | the title scrolling, the player, volume ──

    Item {
        visible: !win.shade
        x: 1; y: 22
        width: parent.width - 2
        height: parent.height - 23

        Rectangle {
            id: display
            x: 8; y: 6
            width: 112
            height: 60
            color: "#05070A"
            border.width: 1
            border.color: "#1A2438"

            // ▶ / ❚❚ / ■ in a tiny square, like Winamp's play indicator
            Rectangle {
                x: 6; y: 8
                width: 6; height: 6
                color: win.playing ? accent.color : "transparent"
                border.width: 1
                border.color: win.hasPlayer ? accent.color : "#2A3852"
                visible: win.st.status !== "Paused"
            }
            Row {
                x: 6; y: 8
                spacing: 2
                visible: win.st.status === "Paused"
                Rectangle { width: 2; height: 6; color: accent.color }
                Rectangle { width: 2; height: 6; color: accent.color }
            }
            Text {
                id: timeText
                anchors { right: parent.right; rightMargin: 8; top: parent.top; topMargin: 2 }
                text: !win.hasPlayer ? "--:--"
                      : (win.remaining && win.st.length > 0 ? "-" + win.clock(win.st.length - win.position) : win.clock(win.position))
                color: win.hasPlayer ? accent.text : "#2A3852"
                opacity: win.st.status === "Paused" ? (blink.on ? 1 : 0.25) : 1
                font.family: "IBM Plex Mono"
                font.weight: Font.Bold
                font.pixelSize: 24
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.remaining = !win.remaining
                }
            }
            // Paused: the time blinks, as in Winamp
            Timer {
                id: blink
                property bool on: true
                interval: 600
                running: win.st.status === "Paused"
                repeat: true
                onTriggered: on = !on
                onRunningChanged: on = true
            }
            // The little bars: the music itself (goblin graph's reading)
            Row {
                anchors { left: parent.left; leftMargin: 6; bottom: parent.bottom; bottomMargin: 4 }
                spacing: 1
                Repeater {
                    model: amp.levels
                    Item {
                        required property real modelData
                        width: 4
                        height: 22
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(1, Math.round(parent.height * modelData))
                            color: modelData > 0.8 ? accent.hover : accent.color
                            opacity: 0.55 + 0.45 * modelData
                        }
                    }
                }
            }
        }

        // The title, scrolling when it is longer than the box
        Rectangle {
            id: titleBox
            anchors { left: display.right; leftMargin: 8; right: parent.right; rightMargin: 8 }
            y: 6
            height: 22
            color: "#05070A"
            border.width: 1
            border.color: "#1A2438"
            clip: true
            readonly property string line: win.hasPlayer
                ? (win.st.artist ? win.st.artist + " – " : "") + (win.st.title || win.st.player)
                  + (win.st.album ? "  (" + win.st.album + ")" : "")
                : "Ingen musik spelar – tryck PL för spellistorna"
            Text {
                id: marquee
                y: (parent.height - height) / 2
                x: 6
                text: titleBox.line + (scroll.running ? "   ***   " + titleBox.line : "")
                color: win.hasPlayer ? accent.text : "#5C6880"
                font.family: "IBM Plex Sans"
                font.pixelSize: 12
            }
            readonly property real single: marqueeMeasure.implicitWidth
            Text {
                id: marqueeMeasure
                visible: false
                text: titleBox.line + "   ***   "
                font: marquee.font
            }
            NumberAnimation {
                id: scroll
                target: marquee
                property: "x"
                from: 6
                to: 6 - titleBox.single
                duration: titleBox.single * 28
                loops: Animation.Infinite
                running: marqueeMeasure.implicitWidth - 9 > titleBox.width - 12
                onRunningChanged: if (!running) marquee.x = 6
            }
        }

        // The player's name, and volume
        Text {
            anchors { left: titleBox.left; top: titleBox.bottom; topMargin: 8 }
            text: win.hasPlayer ? win.st.player.toUpperCase() : "—"
            color: "#5C6880"
            font.family: "Chakra Petch"
            font.weight: Font.DemiBold
            font.pixelSize: 10
            font.letterSpacing: 1.5
        }
        Item {
            id: volume
            visible: win.hasPlayer && win.st.volume >= 0
            anchors { right: titleBox.right; top: titleBox.bottom; topMargin: 10 }
            width: 110
            height: 10
            property real shown: win.st.volume >= 0 ? win.st.volume : 0
            Text {
                anchors { right: parent.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                text: "VOL"
                color: "#5C6880"
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: 9
                font.letterSpacing: 1
            }
            Rectangle { anchors.fill: parent; color: "#0E1420"; border.width: 1; border.color: "#1E2A40" }
            Rectangle {
                x: 1; y: 1
                height: parent.height - 2
                width: Math.max(0, (parent.width - 2) * volume.shown)
                color: accent.dim
            }
            Rectangle {
                x: Math.max(0, (parent.width - 6) * volume.shown)
                y: -2
                width: 6; height: parent.height + 4
                color: volArea.containsMouse || volArea.pressed ? accent.hover : accent.color
            }
            MouseArea {
                id: volArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function set(mx) {
                    volume.shown = Math.max(0, Math.min(1, (mx - 4) / volume.width));
                }
                onPressed: mouse => set(mouse.x)
                onPositionChanged: mouse => { if (pressed) set(mouse.x); }
                onReleased: amp.setVolume(volume.shown)
                onWheel: wheel => { volume.shown = Math.max(0, Math.min(1, volume.shown + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))); amp.setVolume(volume.shown); }
            }
        }

        // The seek bar
        Item {
            id: seekBar
            x: 8
            y: 74
            width: parent.width - 16
            height: 10
            readonly property real fraction: win.st.length > 0
                ? (win.dragSeek >= 0 ? win.dragSeek : win.position) / win.st.length : 0
            Rectangle { anchors.fill: parent; color: "#0E1420"; border.width: 1; border.color: "#1E2A40" }
            Rectangle {
                x: 1; y: 1
                height: parent.height - 2
                width: Math.max(0, (parent.width - 2) * seekBar.fraction)
                color: accent.dim
            }
            Rectangle {
                visible: win.st.length > 0
                x: Math.max(0, (parent.width - 10) * seekBar.fraction)
                y: -2
                width: 10; height: parent.height + 4
                color: seekArea.containsMouse || seekArea.pressed ? accent.hover : accent.color
            }
            MouseArea {
                id: seekArea
                anchors.fill: parent
                anchors.margins: -4
                enabled: win.st.length > 0 && win.st.canSeek !== false
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                function at(mx) {
                    return Math.max(0, Math.min(1, (mx - 4) / seekBar.width)) * win.st.length;
                }
                onPressed: mouse => win.dragSeek = at(mouse.x)
                onPositionChanged: mouse => { if (pressed) win.dragSeek = at(mouse.x); }
                onReleased: { amp.seek(win.dragSeek); win.dragSeek = -1; }
            }
        }

        // ⏮ ▶ ❚❚ ■ ⏭   SHUF REP   PL
        Row {
            x: 8
            y: 96
            spacing: 3
            Btn { glyph: "prev"; onClicked: amp.control("previous") }
            Btn { glyph: "play"; active: win.playing; onClicked: amp.control("play") }
            Btn { glyph: "pause"; onClicked: amp.control("pause") }
            Btn { glyph: "stop"; onClicked: amp.control("stop") }
            Btn { glyph: "next"; onClicked: amp.control("next") }
        }
        Row {
            anchors { right: parent.right; rightMargin: 8 }
            y: 96
            spacing: 3
            Btn {
                label: "SHUF"
                visible: win.st.shuffle !== null && win.st.shuffle !== undefined
                active: win.st.shuffle === true
                onClicked: amp.toggleShuffle()
            }
            Btn {
                label: win.st.loop === "Track" ? "REP 1" : "REP"
                visible: !!win.st.loop
                active: win.st.loop === "Playlist" || win.st.loop === "Track"
                onClicked: amp.cycleLoop()
            }
            Btn { label: "PL"; onClicked: amp.playlists() }
        }
    }
}
