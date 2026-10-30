// GoblinAmp (21 Oct, the user's wish "tänk Winamp"): a small player window that steers the music
// program over MPRIS (goblin-amp). Winamp's main window in GOBLINCAKES' look – flat, square,
// Void/Night with thin frames, the time and title in the user's accent colour (accent.*),
// IBM Plex Mono for the digits, Chakra Petch for the name.
// Own music and goblin graph inside (21 Oct): the playlist's LOKALT tab (local files, Nu spelas,
// Musikmappen, own .m3u8 lists) and GRAF (goblin graph's views under the player).
import QtQuick
import QtQuick.Dialogs
import "../graph" as GG

Window {
    id: win
    title: "GoblinAmp"
    flags: Qt.Window | Qt.FramelessWindowHint
    width: 380
    readonly property int wantedHeight: shade ? 22 : 152 + (amp.graphShown ? graphHeight : 0) + (pl.open && !plDetached ? plHeight : 0)
    // The playlist in its own window (plWin) or under the player
    readonly property bool plDetached: amp.plDetached
    readonly property bool plShown: pl.open && (plDetached || !shade)
    readonly property Item plHost: plDetached ? plWin.contentItem : win.contentItem
    height: wantedHeight
    // the playlist's height: dragged at the window's bottom edge, kept in amp.json (plHeight)
    property int plHeight: Math.max(minPlHeight, amp.savedPlHeight)
    readonly property int minPlHeight: 200
    readonly property int graphHeight: 140
    readonly property var pl: JSON.parse(amp.pl || "{}")
    readonly property var loc: JSON.parse(amp.localState || "{}")
    readonly property var lrows: JSON.parse(amp.localRows || "[]")
    // The playing track's Spotify address (MPRIS: /com/spotify/track/<id>)
    readonly property string playingUri: (st.trackid || "").indexOf("/com/spotify/track/") === 0
        ? "spotify:track:" + st.trackid.split("/").pop() : ""
    minimumWidth: 380
    maximumWidth: 380
    // a fixed height: the limits moved in the right order, else the old one cuts the new height
    minimumHeight: wantedHeight
    maximumHeight: wantedHeight
    onWantedHeightChanged: {
        if (wantedHeight > height) {
            maximumHeight = wantedHeight;
            height = wantedHeight;
            minimumHeight = wantedHeight;
        } else {
            minimumHeight = wantedHeight;
            height = wantedHeight;
            maximumHeight = wantedHeight;
        }
    }
    visible: true
    // Not see-through any more: GRAF without a background (29 Oct) didn't look good, the user 30 Oct
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
    Shortcut { sequence: "Esc"; onActivated: win.closeWin() }

    // ✕ (21 Oct, the user's wish): hide in the system tray, or close GoblinAmp and Spotify –
    // asks until remembered; a right-click on ✕ always asks (the tray menu: "Fråga igen")
    property bool closeAsk: false
    property bool closeRemember: false
    onClosing: close => {
        close.accepted = false;
        win.closeWin();
    }
    function closeWin() {
        const act = hasTray ? amp.closeAction : "quit";
        if (act === "quit")
            amp.quitAll();
        else if (act === "tray")
            win.hide();
        else
            win.askClose();
    }
    function askClose() {
        win.shade = false;
        win.closeRemember = false;
        win.closeAsk = true;
    }
    function closeAs(act) {
        if (win.closeRemember)
            amp.setCloseAction(act);
        win.closeAsk = false;
        if (act === "quit")
            amp.quitAll();
        else
            win.hide();
    }

    // ── Small parts ──

    // A flat square button with a drawn symbol (no font needed for ⏮ ▶ ❚❚ ■ ⏭)
    component Btn: Rectangle {
        id: btn
        property string glyph: ""
        property string label: ""
        property bool active: false
        readonly property bool hovered: btnArea.containsMouse
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
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => {
                if (mouse.button === Qt.RightButton)
                    win.accentMenu(mouse.x, mouse.y + 12);
                else
                    win.startSystemMove();
            }
            onDoubleClicked: mouse => { if (mouse.button === Qt.LeftButton) win.shade = !win.shade; }
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
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (tb.modelData[1] === "close") mouse.button === Qt.RightButton && hasTray ? win.askClose() : win.closeWin();
                            else if (mouse.button === Qt.RightButton) return;
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
            width: titleBox.width - volume.width - 34
            elide: Text.ElideRight
            text: win.st.message ? win.st.message : win.hasPlayer ? win.st.player.toUpperCase() : "—"
            color: win.st.message ? accent.errorBright : "#5C6880"
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
                // The percent while the mouse is on the slider (28 Oct, the user's wish)
                text: volArea.containsMouse || volArea.pressed ? Math.round(volume.shown * 100) + " %" : "VOL"
                color: volArea.containsMouse || volArea.pressed ? accent.text : "#5C6880"
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
            Btn { label: "GRAF"; active: amp.graphShown; onClicked: amp.toggleGraph() }
            Btn { label: "PL"; active: win.pl.open; onClicked: amp.togglePlaylist() }
        }
    }

    // ── The playlist (PL): Spotify's lists, liked songs and the queue (Winamp's PL window) ──

    component FastWheel: WheelHandler {
        required property Flickable flick
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2;
            event.accepted = true;
            const top = flick.originY, bottom = top + Math.max(0, flick.contentHeight - flick.height);
            flick.cancelFlick();
            flick.contentY = Math.max(top, Math.min(bottom, flick.contentY - delta));
        }
    }

    component SmallLink: Text {
        readonly property bool hovered: linkArea.containsMouse
        signal clicked()
        color: linkArea.containsMouse ? "#E6ECF5" : "#8B98AD"
        font.family: "IBM Plex Sans"
        font.pixelSize: 11
        MouseArea {
            id: linkArea
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    function clockLong(seconds) {
        const h = Math.floor(seconds / 3600);
        return h > 0 ? h + ":" + win.clock(seconds % 3600) : win.clock(seconds);
    }

    // ── goblin graph inside the window (GRAF; the user's wish 21 Oct – instead of its own window) ──
    Item {
        id: graphPanel
        visible: !win.shade && amp.graphShown
        x: 1
        y: 152
        width: parent.width - 2
        height: win.graphHeight
        Rectangle { anchors.fill: parent; color: "#05070A" }
        Rectangle { width: parent.width; height: 1; color: "#1E2A40" }
        Loader {
            anchors { fill: parent; topMargin: 1 }
            active: amp.graphShown
            sourceComponent: GG.Views { barOpacity: 0.85; margin: 6 }
        }
        HoverHandler { id: graphHover }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => { if (mouse.button === Qt.RightButton) graph.toggleMode(); }
            onDoubleClicked: mouse => { if (mouse.button === Qt.LeftButton) graph.cycleView(); }
            onWheel: wheel => graph.stepClass(wheel.angleDelta.y > 0 ? -1 : 1)
        }
        Text {
            anchors { left: parent.left; top: parent.top; margins: 7 }
            visible: graphHover.hovered
            text: ({ bars: "STAPLAR", scope: "VÅG", circle: "CIRKEL", burst: "EXPLOSION" })[graph.view] + "  ·  "
                  + (graph.mode === "all" ? "ALLA KLASSER" : graph.className.toUpperCase())
            color: graph.mode === "all" ? "#E6ECF5" : graph.classColor
            style: Text.Outline
            styleColor: "#05070A"
            font.family: "Chakra Petch"
            font.weight: Font.DemiBold
            font.pixelSize: 10
            font.letterSpacing: 1.5
        }
        Text {
            anchors { left: parent.left; bottom: parent.bottom; margins: 7 }
            visible: graphHover.hovered
            text: "Dubbelklick: nästa vy · högerklick: färger · hjul: klass"
            color: "#8B98AD"
            style: Text.Outline
            styleColor: "#05070A"
            font.family: "IBM Plex Sans"
            font.pixelSize: 10
        }
        Btn {
            anchors { right: parent.right; top: parent.top; margins: 5 }
            visible: graphHover.hovered
            label: "EGET FÖNSTER"
            onClicked: amp.popOutGraph()
        }
    }

    // ── The playlist (PL): LOKALT (own music) and SPOTIFY tabs ──
    // In GoblinAmp under the player, or in its own window (plWin, 29 Oct – the user's wish: "kopplas
    // loss och dras vart man vill"): the same items move between the windows (parent).
    Item {
        id: plArea
        parent: win.plHost
        visible: win.plShown
        x: 0
        y: win.plDetached ? 21 : 152 + (amp.graphShown ? win.graphHeight : 0)
        width: parent ? parent.width : win.width
        height: win.plDetached ? (parent ? parent.height : 0) - 21 : win.plHeight
        z: 1

        Item {
            id: plFrame
            x: 1
            y: 0
            width: parent.width - 2
            height: plArea.height - 1
            Rectangle { anchors.fill: parent; color: "#0B1018" }
            Rectangle { width: parent.width; height: 1; color: "#1E2A40" }
            Row {
                x: 6; y: 5
                spacing: 3
                Repeater {
                    model: [["local", "LOKALT"], ["spotify", "SPOTIFY"], ["genre", "GENRER"]]
                    Btn {
                        required property var modelData
                        label: modelData[1]
                        active: win.loc.tab === modelData[0]
                        onClicked: amp.setPlTab(modelData[0])
                    }
                }
            }
            Btn {   // the playlist in its own window (back with FÄST in that window's title line)
                id: detachBtn
                visible: !win.plDetached
                anchors.right: parent.right
                anchors.rightMargin: 6
                y: 5
                label: "LOSSA"
                onClicked: amp.setPlDetached(true)
            }
            Btn {   // the album Spotify plays now, opened in the SPOTIFY/GENRER tab
                id: albumBtn
                visible: win.pl.signedIn
                anchors.right: detachBtn.visible ? detachBtn.left : parent.right
                anchors.rightMargin: detachBtn.visible ? 3 : 6
                y: 5
                label: "♪ ALBUMET"
                onClicked: amp.openPlayingAlbum()
            }
            Item {
                id: localPane
                visible: win.loc.tab === "local"
                y: 28
                width: parent.width
                height: parent.height - 28
                readonly property var entry: win.loc.list || null
                readonly property string listId: entry ? entry.id : ""
                readonly property bool editable: !!entry && listId !== "library"
                readonly property string filter: localFilter.text.toLowerCase()
                property var sel: []            // picked rows (indexes in the full list)
                property int anchorRow: -1      // Shift+click picks from here
                property bool dragging: false
                property int dropAt: -1
                onListIdChanged: { sel = []; anchorRow = -1; localFilter.text = ""; }
                // the rows shown: lists, or tracks (filtered); each keeps its index in the full list
                readonly property var shown: {
                    const all = entry ? win.lrows : (win.loc.lists || []);
                    const out = [];
                    for (let i = 0; i < all.length; i++) {
                        const r = all[i];
                        const text = (entry ? (r.artist + " " + r.title + " " + r.album) : r.name).toLowerCase();
                        if (!filter || text.indexOf(filter) >= 0)
                            out.push({ row: r, index: i });
                    }
                    return out;
                }
                function picked(i) { return sel.indexOf(i) >= 0 ? sel : [i]; }
                function isCurrent(i, r) {
                    if (!win.st.local)
                        return false;
                    return listId === "now" ? i === win.st.index : r.path === win.st.path;
                }
                function pick(i, mods) {
                    if (mods & Qt.ShiftModifier && anchorRow >= 0) {
                        const out = [];
                        for (let k = Math.min(anchorRow, i); k <= Math.max(anchorRow, i); k++)
                            out.push(k);
                        sel = out;
                    } else if (mods & Qt.ControlModifier) {
                        const k = sel.indexOf(i);
                        sel = k >= 0 ? sel.filter(x => x !== i) : sel.concat([i]);
                        anchorRow = i;
                    } else {
                        sel = [i];
                        anchorRow = i;
                    }
                }
                function openList(id) { amp.localOpen(id); }
                // Right-click on a track: what can be done with the picked rows
                function trackMenu(i, x, y) {
                    if (sel.indexOf(i) < 0) { sel = [i]; anchorRow = i; }
                    const rows = JSON.stringify(sel), n = sel.length;
                    const items = [
                        { text: "Spela", act: () => amp.localPlay(sel[0]) },
                        { text: "Spela härnäst", act: () => amp.localEnqueue(rows, true), hide: listId === "now" },
                        { text: "Lägg i Nu spelas", act: () => amp.localEnqueue(rows, false), hide: listId === "now" },
                        { sep: true },
                    ];
                    for (const l of win.loc.lists || [])
                        if (!l.special && l.id !== listId)
                            items.push({ text: "Lägg till i " + l.name, act: () => amp.localAddTo(l.id, rows) });
                    items.push({ text: "Lägg till i en ny lista…", act: () => win.askName("newfrom", "", rows, "") });
                    items.push({ sep: true });
                    if (editable)
                        items.push({ text: n > 1 ? "Ta bort " + n + " låtar ur listan" : "Ta bort ur listan", act: () => amp.localRemove(rows) });
                    items.push({ text: "Visa i mappen", act: () => amp.showFile(win.lrows[sel[0]].path) });
                    win.openMenu(items.filter(m => !m.hide), x, y);
                }
                // Right-click on a list, or ⋯ in an open list
                function listMenu(l, x, y) {
                    const items = [{ text: l.id === "now" ? "Spela" : "Spela listan", act: () => amp.localPlayList(l.id) }];
                    if (l.id === win.loc.list?.id) {
                        items.push({ sep: true });
                        for (const s of [["artist", "Sortera efter artist"], ["album", "Sortera efter album"], ["title", "Sortera efter titel"],
                                         ["path", "Sortera efter filnamn"], ["length", "Sortera efter längd"]])
                            items.push({ text: s[1], act: () => amp.localSort(s[0]) });
                        if (l.id !== "library") {
                            items.push({ text: "Blanda ordningen", act: () => amp.localSort("shuffle") });
                            items.push({ text: "Vänd ordningen", act: () => amp.localSort("reverse") });
                        }
                    }
                    items.push({ sep: true });
                    if (l.id === "now") {
                        items.push({ text: "Spara som en ny lista…", act: () => win.askName("saveas", "", "", "") });
                        items.push({ text: "Töm Nu spelas", act: () => amp.localClear() });
                    } else if (l.id === "library") {
                        items.push({ text: "Läs om musikmappen", act: () => amp.localRescan() });
                    } else {
                        items.push({ text: "Byt namn…", act: () => win.askName("rename", l.id, "", l.name) });
                        items.push({ text: "Visa filen", act: () => amp.showList(l.id) });
                        items.push({ text: "Ta bort listan", act: () => amp.localDelete(l.id) });
                    }
                    win.openMenu(items, x, y);
                }

                // The header: LOKAL MUSIK / ◀ the list's name
                Item {
                    x: 8; y: 2
                    width: parent.width - 16
                    height: 16
                    Text {
                        visible: !localPane.entry
                        text: "LOKAL MUSIK"
                        color: "#8B98AD"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                    }
                    SmallLink {
                        visible: !!localPane.entry
                        width: Math.min(implicitWidth, parent.width - 120)
                        elide: Text.ElideRight
                        text: "◀  " + (localPane.entry ? localPane.entry.name : "")
                        color: accent.text
                        font.weight: Font.DemiBold
                        onClicked: amp.localBack()
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 12
                        SmallLink {
                            visible: !localPane.entry
                            text: "+ Ny lista"
                            onClicked: win.askName("new", "", "", "")
                        }
                        SmallLink {
                            visible: !!localPane.entry && win.lrows.length > 0
                            text: "▶ Spela"
                            onClicked: amp.localPlayList(localPane.listId)
                        }
                        SmallLink {
                            id: moreLink
                            visible: !!localPane.entry
                            text: "⋯"
                            font.pixelSize: 14
                            onClicked: {
                                const p = moreLink.mapToItem(null, 0, moreLink.height);
                                localPane.listMenu(localPane.entry, p.x - 160, p.y + 2);
                            }
                        }
                    }
                }

                // A name for a list (new, rename, save Nu spelas)
                Row {
                    id: nameRow
                    visible: win.nameMode !== "" && win.nameMode.indexOf("sp-") !== 0
                    x: 8; y: 22
                    spacing: 6
                    Rectangle {
                        width: 210
                        height: 20
                        color: "#07090D"
                        border.width: 1
                        border.color: nameInput.activeFocus ? accent.color : "#1E2A40"
                        TextInput {
                            id: nameInput
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            color: "#E6ECF5"
                            selectionColor: accent.color
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 11
                            onAccepted: win.nameDone(true)
                            Keys.onEscapePressed: win.nameDone(false)
                            Text {
                                visible: nameInput.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Listans namn"
                                color: "#5C6880"
                                font: nameInput.font
                            }
                        }
                    }
                    Btn { label: "OK"; active: true; onClicked: win.nameDone(true) }
                    Btn { label: "AVBRYT"; onClicked: win.nameDone(false) }
                }

                ListView {
                    id: localView
                    x: 4
                    y: nameRow.visible ? 46 : 22
                    width: parent.width - 8
                    height: parent.height - y - 30
                    clip: true
                    focus: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: localPane.shown
                    FastWheel { flick: localView }
                    Keys.onDeletePressed: if (localPane.editable && localPane.sel.length) amp.localRemove(JSON.stringify(localPane.sel))
                    Keys.onReturnPressed: if (localPane.entry && localPane.sel.length) amp.localPlay(localPane.sel[0])
                    Keys.onPressed: event => {
                        if (localPane.entry && event.key === Qt.Key_A && event.modifiers & Qt.ControlModifier) {
                            localPane.sel = win.lrows.map((r, i) => i);
                            event.accepted = true;
                        }
                    }
                    delegate: Rectangle {
                        id: lrow
                        required property var modelData
                        required property int index
                        readonly property var r: modelData.row
                        readonly property int full: modelData.index
                        readonly property bool isTrack: !!localPane.entry
                        readonly property bool current: isTrack && localPane.isCurrent(full, r)
                        readonly property bool picked: isTrack && localPane.sel.indexOf(full) >= 0
                        readonly property bool playingList: !isTrack && r.id === "now" && !!win.st.local && win.playing
                        width: localView.width
                        height: 18
                        color: picked ? accent.dim : lrowArea.containsMouse ? "#16203A" : current ? "#12203A" : "transparent"
                        Text {
                            x: 4
                            width: parent.width - 60
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: lrow.isTrack
                                  ? (lrow.full + 1) + ". " + (lrow.r.artist ? lrow.r.artist + " – " : "") + lrow.r.title + (lrow.r.missing ? "  (saknas)" : "")
                                  : (lrow.r.special ? (lrow.playingList ? "▶ " : "♪ ") : "") + lrow.r.name + (lrow.r.note ? "  · " + lrow.r.note : "")
                            color: lrow.current || lrow.playingList ? accent.text : lrow.picked ? accent.on : lrow.r.missing ? "#5C6880" : "#C8D1DE"
                            font.family: "IBM Plex Sans"
                            font.weight: lrow.current ? Font.DemiBold : Font.Normal
                            font.strikeout: !!lrow.r.missing
                            font.pixelSize: 11
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: lrow.isTrack ? (lrow.r.seconds ? win.clock(lrow.r.seconds) : "")
                                  : (lrow.r.count === null || lrow.r.count === undefined ? "" : lrow.r.count)
                            color: lrow.current ? accent.text : lrow.picked ? accent.on : "#5C6880"
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: lrowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            property real pressY: 0
                            onPressed: mouse => {
                                localView.forceActiveFocus();
                                pressY = mouse.y;
                                if (lrow.isTrack && mouse.button === Qt.LeftButton && !(mouse.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))
                                        && localPane.sel.indexOf(lrow.full) < 0)
                                    localPane.pick(lrow.full, 0);
                            }
                            onPositionChanged: mouse => {
                                if (!pressed || !lrow.isTrack || !localPane.editable || localPane.filter)
                                    return;
                                if (!localPane.dragging && Math.abs(mouse.y - pressY) < 6)
                                    return;
                                localPane.dragging = true;
                                const p = mapToItem(localView, mouse.x, mouse.y);
                                if (p.y < 12) localView.contentY = Math.max(0, localView.contentY - 6);
                                else if (p.y > localView.height - 12)
                                    localView.contentY = Math.min(Math.max(0, localView.contentHeight - localView.height), localView.contentY + 6);
                                localPane.dropAt = Math.max(0, Math.min(win.lrows.length, Math.round((p.y + localView.contentY) / 18)));
                            }
                            onReleased: mouse => {
                                if (localPane.dragging) {
                                    amp.localMove(JSON.stringify(localPane.picked(lrow.full)), localPane.dropAt);
                                    localPane.dragging = false;
                                    localPane.dropAt = -1;
                                }
                            }
                            onClicked: mouse => {
                                if (!lrow.isTrack) {
                                    if (mouse.button === Qt.RightButton) {
                                        const p = mapToItem(null, mouse.x, mouse.y);
                                        localPane.listMenu(lrow.r, p.x, p.y);
                                    } else {
                                        localPane.openList(lrow.r.id);
                                    }
                                    return;
                                }
                                if (mouse.button === Qt.RightButton) {
                                    const p = mapToItem(null, mouse.x, mouse.y);
                                    localPane.trackMenu(lrow.full, p.x, p.y);
                                } else {
                                    localPane.pick(lrow.full, mouse.modifiers);
                                }
                            }
                            onDoubleClicked: mouse => {
                                if (mouse.button !== Qt.LeftButton) return;
                                lrow.isTrack ? amp.localPlay(lrow.full) : amp.localPlayList(lrow.r.id);
                            }
                        }
                    }
                    // Where the dragged rows go
                    Rectangle {
                        visible: localPane.dragging && localPane.dropAt >= 0
                        x: 0
                        y: localPane.dropAt * 18 - localView.contentY - 1
                        width: localView.width
                        height: 2
                        color: accent.color
                        z: 5
                    }
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 30
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        visible: localView.count === 0 && !win.loc.busy
                        text: localFilter.text ? "Inget som matchar"
                              : localPane.listId === "library" ? "Ingen musik i " + win.loc.musicDir + " än"
                              : localPane.entry ? "Listan är tom – dra in filer eller mappar från Dolphin, eller tryck + Filer"
                              : ""
                        color: "#5C6880"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 11
                    }
                }

                // Dropped from Dolphin: files, folders, lists
                DropArea {
                    anchors.fill: parent
                    onEntered: drag => drag.accept(Qt.CopyAction)
                    onDropped: drop => {
                        if (drop.hasUrls) {
                            amp.localAddPaths(JSON.stringify(drop.urls.map(u => String(u))));
                            drop.acceptProposedAction();
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: parent.containsDrag
                        color: "#C0101828"
                        border.width: 1
                        border.color: accent.color
                        Text {
                            anchors.centerIn: parent
                            text: localPane.entry && localPane.listId !== "library"
                                  ? "Släpp för att lägga till i " + localPane.entry.name
                                  : "Släpp för att lägga till i Nu spelas"
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                    }
                }

                // What is happening, or what went wrong
                Rectangle {
                    visible: !!win.loc.busy || !!win.loc.message
                    anchors { left: parent.left; right: parent.right; bottom: localFoot.top; margins: 6 }
                    height: localBusy.implicitHeight + 10
                    color: "#12203A"
                    border.width: 1
                    border.color: accent.dim
                    Text {
                        id: localBusy
                        anchors { fill: parent; margins: 5 }
                        wrapMode: Text.WordWrap
                        text: win.loc.busy || win.loc.message || ""
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 11
                    }
                    MouseArea { anchors.fill: parent; onClicked: amp.localClearMessage() }
                    Timer {
                        running: !!win.loc.message && !win.loc.busy
                        interval: 5000
                        onTriggered: amp.localClearMessage()
                    }
                }

                // The foot: filter, count and length, add files/folders, bring in a list
                Item {
                    id: localFoot
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
                    height: 20
                    Rectangle {
                        id: localFilterBox
                        visible: !!localPane.entry
                        width: 112
                        height: 20
                        color: "#07090D"
                        border.width: 1
                        border.color: localFilter.activeFocus ? accent.color : "#1E2A40"
                        TextInput {
                            id: localFilter
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            color: "#E6ECF5"
                            selectionColor: accent.color
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 11
                            Keys.onEscapePressed: text = ""
                            Text {
                                visible: localFilter.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Sök…"
                                color: "#5C6880"
                                font: localFilter.font
                            }
                        }
                    }
                    Text {
                        anchors { left: localPane.entry ? localFilterBox.right : parent.left; leftMargin: localPane.entry ? 8 : 2; verticalCenter: parent.verticalCenter }
                        text: {
                            if (!localPane.entry)
                                return Math.max(0, (win.loc.lists || []).length - 2) + " egna listor";
                            let sum = 0;
                            for (let i = 0; i < win.lrows.length; i++)
                                sum += win.lrows[i].seconds || 0;
                            return (localPane.sel.length > 1 ? localPane.sel.length + " av " : "") + win.lrows.length + " · " + win.clockLong(sum);
                        }
                        color: "#5C6880"
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 10
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        SmallLink { visible: !localPane.entry; text: "Öppna lista…"; onClicked: importDialog.open() }
                        SmallLink { visible: !localPane.entry; text: "Musikmappen"; onClicked: amp.openMusicDir() }
                        SmallLink { visible: localPane.editable || localPane.listId === "library"; text: "+ Filer"; onClicked: filesDialog.open() }
                        SmallLink { visible: localPane.editable || localPane.listId === "library"; text: "+ Mapp"; onClicked: folderDialog.open() }
                    }
                }
            }
        }

        Item {
            id: plPanel
            visible: win.loc.tab === "spotify" || win.loc.tab === "genre"
            x: 1
            y: plFrame.y + 28
            width: parent.width - 2
            height: plArea.height - 29
            readonly property var entry: win.pl.list || null
            readonly property bool searching: !!entry && entry.id === "search"
            // GENRER: the genres (home), and what was opened from them (a genre, an artist, "Liknande")
            readonly property bool home: !!entry && !!entry.home
            readonly property bool found: !!entry && !!entry.found
            readonly property string entryId: entry ? entry.id : ""
            onEntryIdChanged: if (searching) plFilter.text = win.pl.query || "";
            // the foot's field: the words for Spotify's search, else a filter of the open list
            readonly property string filter: searching ? "" : plFilter.text.toLowerCase()
            readonly property bool editable: !!entry && !!entry.mine && !entry.special
            property int dragRow: -1        // an own list's row being dragged (one at a time – Spotify moves ranges)
            property int dropAt: -1
            onEntryChanged: { dragRow = -1; dropAt = -1; }
            // the rows shown: lists or tracks, filtered; each keeps its index in the full list
            readonly property var shown: {
                const all = entry ? (win.pl.rows || []) : (win.pl.lists || []);
                const out = [];
                for (let i = 0; i < all.length; i++) {
                    const r = all[i];
                    const text = (entry ? (r.artist + " " + r.title) : r.name).toLowerCase();
                    if (!filter || text.indexOf(filter) >= 0)
                        out.push({ row: r, index: i });
                }
                return out;
            }
            function openEntry(id) {
                plFilter.text = id === "search" ? (win.pl.query || "") : "";
                amp.openList(id);
                if (id === "search")
                    plFilter.forceActiveFocus();
            }
            // a found album: its tracks (the search words leave the field, it filters the album)
            function openAlbum(i) {
                plFilter.text = "";
                amp.openAlbum(i);
            }
            // a found album's name as a saved list: "Artist – Album"
            function albumName(r) {
                return (r.artist ? r.artist + " – " : "") + r.title;
            }
            // the own list an album is already saved as (same album, or the same name), else null
            function savedAlbum(uri, name) {
                const lower = name.trim().toLowerCase();
                return (win.pl.lists || []).find(l => l.own && !l.special
                    && ((uri && l.fromAlbum === uri) || (l.name || "").trim().toLowerCase() === lower)) || null;
            }
            function saveAlbum(uri, name, count) {
                const saved = savedAlbum(uri, name);
                if (saved)
                    plPanel.openEntry(saved.id);
                else
                    amp.spSaveAlbum(uri, name, count || 0);
            }
            // own lists to add to (the open one left out); at most 8 in the menu
            function targets() {
                return (win.pl.lists || []).filter(l => l.mine && !l.special && (!entry || l.id !== entry.id)).slice(0, 8);
            }
            // ◀ in a view opened from the search or a genre: back the way it came
            function goBack() {
                plFilter.text = "";
                amp.goBack();
            }
            function openGenre(name) {
                plFilter.text = "";
                amp.openGenre(name);
            }
            function askLastfm() {
                amp.openLastfmPage();
                win.askName("sp-lastfm", "", "", "");
            }
            // Right-click on a track (a list's, the queue's or a search's)
            function trackMenu(i, x, y) {
                const r = win.pl.rows[i];
                if (["more", "head", "genre", "similar", "lastfm"].indexOf(r.kind) >= 0)
                    return;
                const items = [];
                if (r.kind === "artist")
                    items.push({ text: "Öppna artisten", act: () => amp.openArtist(i) });
                if (r.kind === "album") {
                    items.push({ text: "Öppna albumet", act: () => plPanel.openAlbum(i) });
                    const saved = savedAlbum(r.uri, albumName(r));
                    items.push({ text: saved ? "✓ Sparat – öppna " + saved.name : "Spara albumet som lista",
                                 act: () => plPanel.saveAlbum(r.uri, albumName(r), r.count) });
                }
                if (entry.id !== "queue")
                    items.push({ text: r.kind === "album" ? "Spela albumet" : r.kind === "playlist" ? "Spela listan"
                                       : r.kind === "artist" ? "Spela artisten" : "Spela", act: () => amp.playRow(i) });
                if (!r.kind || r.kind === "track") {
                    if (!r.local) {
                        items.push({ text: "Lägg i kön", act: () => amp.spEnqueue(JSON.stringify([r.uri])) });
                        items.push({ sep: true });
                        for (const l of targets())
                            items.push({ text: "Lägg till i " + l.name, act: () => amp.spAddTo(l.id, JSON.stringify([r.uri])) });
                        items.push({ text: "Lägg till i en ny lista…", act: () => win.askName("sp-newfrom", "", JSON.stringify([r.uri]), "") });
                    }
                    if (editable) {
                        items.push({ sep: true });
                        items.push({ text: "Ta bort ur listan", act: () => amp.spRemove(i) });
                    }
                }
                win.openMenu(items, x, y);
            }
            // Right-click on a list, or ⋯ in an open one
            function listMenu(l, x, y) {
                const items = [];
                if (l.id !== "queue" && l.id !== "search")
                    items.push({ text: "Spela listan", act: () => amp.playList(l.id) });
                if (!l.special) {
                    items.push({ sep: true });
                    if (l.own)
                        items.push({ text: "Byt namn…", act: () => win.askName("sp-rename", l.id, "", l.name) });
                    items.push({ text: "Ta bort ur dina listor…", act: () => win.openMenu([
                        { text: "Ja, ta bort " + l.name, act: () => amp.spDelete(l.id) },
                        { text: "Avbryt", act: () => {} }], x, y) });
                }
                if (items.length)
                    win.openMenu(items, x, y);
            }
            // ⋯ in the foot: what used to be links there
            function footMenu(x, y) {
                const genre = win.loc.tab === "genre";
                win.openMenu((genre ? [
                    { text: "Last.fm-nyckel…", act: () => plPanel.askLastfm() }]
                    .concat(win.pl.lastfm ? [{ text: "Ta bort Last.fm-nyckeln", act: () => amp.setLastfmKey("") }] : [])
                : [
                    { text: "Ny lista…", act: () => win.askName("sp-new", "", "", "") },
                    { text: "Sök i hela Spotify", act: () => openEntry("search") },
                    { text: "Uppdatera listorna", act: () => amp.refreshLists() }]).concat([
                    { sep: true },
                    { text: "Spotify-fönstret", act: () => amp.playlists() },
                    { text: "Färg…", act: () => win.accentMenu(x, y) },
                    { text: "Hjälp", act: () => plPanel.showHelp = true },
                    { sep: true },
                    { text: "Logga ut", act: () => amp.signOut() }]), x, y);
            }

            Rectangle { anchors.fill: parent; color: "#0B1018" }
            Rectangle { width: parent.width; height: 1; color: "#1E2A40" }

            // The header: SPELLISTA / ◀ the list's name
            Item {
                id: plHead
                x: 8; y: 6
                width: parent.width - 16
                height: 16
                Text {
                    id: plTitle
                    visible: !plPanel.entry || plPanel.home
                    text: plPanel.home ? "GENRER" + (win.pl.lastfm ? "  ·  SPOTIFY + LAST.FM" : "  ·  SPOTIFY")
                          : "SPOTIFY" + (win.pl.name ? "  ·  " + win.pl.name : "")
                    color: "#8B98AD"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
                SmallLink {
                    id: plBack
                    visible: !!plPanel.entry && !plPanel.home
                    width: Math.min(implicitWidth, parent.width - (plTools.visible ? plTools.width + 12 : 0))
                    elide: Text.ElideRight
                    text: "◀  " + (plPanel.entry ? plPanel.entry.name : "")
                    color: accent.text
                    font.weight: Font.DemiBold
                    onClicked: {
                        if (plPanel.entry.album || plPanel.found)   // opened from the search or a genre: back there
                            plPanel.goBack();
                        else {
                            plFilter.text = "";
                            amp.backToLists();
                        }
                    }
                }
                Row {
                    id: plTools
                    visible: win.pl.signedIn && !plPanel.showHelp
                    anchors.right: parent.right
                    spacing: 12
                    SmallLink {
                        visible: !plPanel.entry
                        text: "+ Ny lista"
                        onClicked: win.askName("sp-new", "", "", "")
                    }
                    SmallLink {
                        readonly property var saved: plPanel.entry && plPanel.entry.album
                                                     ? plPanel.savedAlbum(plPanel.entry.uri, plPanel.entry.name) : null
                        visible: !!plPanel.entry && !!plPanel.entry.album
                        text: saved ? "✓ Sparat" : "+ Spara albumet"
                        onClicked: plPanel.saveAlbum(plPanel.entry.uri, plPanel.entry.name, plPanel.entry.count)
                    }
                    SmallLink {
                        visible: !!plPanel.entry && plPanel.entry.id !== "queue" && !plPanel.searching && !plPanel.home
                        text: !plPanel.entry ? "" : plPanel.entry.album ? "▶ Spela albumet"
                              : plPanel.entry.artistView ? "▶ Spela artisten" : plPanel.found ? "▶ Spela alla" : "▶ Spela listan"
                        onClicked: amp.playList(plPanel.entry.id)
                    }
                    SmallLink {
                        id: plMore
                        visible: !!plPanel.entry && !plPanel.entry.special
                        text: "⋯"
                        font.pixelSize: 14
                        onClicked: {
                            const p = plMore.mapToItem(null, 0, plMore.height);
                            plPanel.listMenu(plPanel.entry, p.x - 160, p.y + 2);
                        }
                    }
                    SmallLink {
                        visible: !plPanel.searching && !plPanel.home && !plPanel.found
                        text: "↻"
                        font.pixelSize: 13
                        onClicked: plPanel.entry ? amp.openList(plPanel.entry.id) : amp.refreshLists()
                    }
                }
            }

            // A name for a Spotify list (new, new with a track, rename)
            Row {
                id: spNameRow
                visible: win.nameMode.indexOf("sp-") === 0
                x: 8; y: 24
                z: 3
                spacing: 6
                Rectangle {
                    width: 210
                    height: 20
                    color: "#07090D"
                    border.width: 1
                    border.color: spNameInput.activeFocus ? accent.color : "#1E2A40"
                    TextInput {
                        id: spNameInput
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: "#E6ECF5"
                        selectionColor: accent.color
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 11
                        onAccepted: win.nameDone(true)
                        Keys.onEscapePressed: win.nameDone(false)
                        Text {
                            visible: spNameInput.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.nameMode === "sp-lastfm" ? "Last.fm: API key (klistra in)" : "Listans namn i Spotify"
                            color: "#5C6880"
                            font: spNameInput.font
                        }
                    }
                }
                Btn { label: "OK"; active: true; onClicked: win.nameDone(true) }
                Btn { label: "AVBRYT"; onClicked: win.nameDone(false) }
            }

            property bool showHelp: false   // "Hjälp" in the foot: the setup steps again
            // ── Not signed in (or Hjälp): how to set it up (once) ──
            Column {
                visible: !win.pl.signedIn || plPanel.showHelp
                x: 10; y: 30
                width: parent.width - 20
                spacing: 7
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Spellistan hämtar dina listor från Spotify med en egen, gratis Spotify-app (görs en gång, kräver Premium):"
                    color: "#B8C2D3"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 11
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "1. Öppna Spotifys utvecklarsida och logga in med ditt Spotify-konto.\n"
                          + "2. Create app – namn t.ex. GoblinAmp.\n"
                          + "3. Redirect URI: " + win.pl.redirect + " (exakt så) – kryssa i Web API och spara.\n"
                          + "4. Appen → Settings: kopiera Client ID hit och tryck Logga in (ingen secret behövs)."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 11
                    lineHeight: 1.2
                }
                Row {
                    spacing: 6
                    Btn { label: "UTVECKLARSIDAN"; onClicked: amp.openDashboard() }
                    Btn { label: "KOPIERA REDIRECT URI"; onClicked: amp.copyText(win.pl.redirect) }
                }
                Text {
                    visible: win.pl.signedIn
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Du är inloggad som " + win.pl.name + ". Samma steg finns i terminalen: goblin amp hjälp."
                          + (win.pl.canEdit ? "" : "\nFör att skapa och ändra listor: Logga ut och logga in igen en gång.")
                    color: accent.text
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 11
                }
                Btn { visible: win.pl.signedIn; label: "TILLBAKA"; onClicked: plPanel.showHelp = false }
                Row {
                    visible: !win.pl.signedIn
                    spacing: 6
                    Rectangle {
                        width: 230
                        height: 22
                        color: "#07090D"
                        border.width: 1
                        border.color: clientInput.activeFocus ? accent.color : "#1E2A40"
                        TextInput {
                            id: clientInput
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            text: win.pl.clientId || ""
                            color: "#E6ECF5"
                            selectionColor: accent.color
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 11
                            onAccepted: amp.signIn(text)
                            Text {
                                visible: clientInput.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Client ID"
                                color: "#5C6880"
                                font: clientInput.font
                            }
                        }
                    }
                    Btn { label: "LOGGA IN"; active: true; onClicked: amp.signIn(clientInput.text) }
                }
            }

            // ── Signed in: the lists, or a list's tracks ──
            ListView {
                id: plView
                visible: win.pl.signedIn && !plPanel.showHelp
                x: 4
                y: spNameRow.visible ? 48 : 26
                width: parent.width - 8
                height: parent.height - y - 30
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // rows (and their covers, fetched by each row) made ahead of the scrolling too – a cover was
                // still slow now and then for rows that just scrolled in (30 Oct)
                cacheBuffer: 1200
                model: plPanel.shown
                FastWheel { flick: plView }
                delegate: Rectangle {
                    id: rowItem
                    required property var modelData
                    required property int index
                    readonly property var r: modelData.row
                    readonly property bool isTrack: !!plPanel.entry
                    readonly property string kind: r.kind || "track"
                    readonly property bool current: isTrack && r.uri === win.playingUri && r.uri !== ""
                    readonly property bool dragged: plPanel.dragRow === modelData.index
                    width: plView.width
                    height: 18
                    readonly property bool plain: kind === "head"   // a heading in a genre view: not clickable
                    color: dragged ? accent.dim : rowArea.containsMouse && kind !== "more" && !plain ? "#16203A" : current ? "#12203A" : "transparent"
                    // The cover fetched while the row is shown (same size as coverTip's, so its cache has it): on
                    // hover it was fetched only after the wait and was seldom there the first time (30 Oct)
                    Image {
                        visible: false
                        source: rowItem.r.image || ""
                        sourceSize: Qt.size(320, 320)
                        asynchronous: true
                        cache: true
                    }
                    Text {
                        x: 4
                        width: parent.width - 60
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: !rowItem.isTrack
                              ? (rowItem.r.special ? (rowItem.r.id === "search" ? "⌕ " : "♪ ") : "") + rowItem.r.name
                                + (!rowItem.r.special && !rowItem.r.mine && rowItem.r.owner ? "  · " + rowItem.r.owner : "")
                              : rowItem.kind === "more" ? "Visa fler låtar…"
                              : rowItem.kind === "album" ? "Album: " + (rowItem.r.artist ? rowItem.r.artist + " – " : "") + rowItem.r.title
                              : rowItem.kind === "playlist" ? "Lista: " + rowItem.r.title + (rowItem.r.artist ? "  · " + rowItem.r.artist : "")
                              : rowItem.kind === "artist" ? "Artist: " + rowItem.r.title
                              : rowItem.kind === "genre" ? "♪ " + rowItem.r.title
                              : rowItem.kind === "head" || rowItem.kind === "similar" || rowItem.kind === "lastfm" ? rowItem.r.title
                              : (plPanel.found ? "" : (rowItem.modelData.index + 1) + ". ")
                                + (rowItem.r.artist ? rowItem.r.artist + " – " : "") + rowItem.r.title
                        color: rowItem.current || ["more", "similar", "lastfm"].indexOf(rowItem.kind) >= 0 ? accent.text
                               : rowItem.dragged ? accent.on : rowItem.plain ? "#5C6880"
                               : rowItem.r.local ? "#5C6880" : rowItem.kind === "track" || rowItem.kind === "genre" ? "#C8D1DE" : "#9AA7BC"
                        font.family: rowItem.plain ? "Chakra Petch" : "IBM Plex Sans"
                        font.weight: rowItem.current || rowItem.plain ? Font.DemiBold : Font.Normal
                        font.pixelSize: rowItem.plain ? 9 : 11
                        font.letterSpacing: rowItem.plain ? 1.2 : 0
                    }
                    Text {   // a found album that is already saved as a list
                        anchors { right: parent.right; rightMargin: 34; verticalCenter: parent.verticalCenter }
                        visible: rowItem.kind === "album" && !!plPanel.savedAlbum(rowItem.r.uri, plPanel.albumName(rowItem.r))
                        text: "✓"
                        color: accent.text
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        text: !rowItem.isTrack ? (rowItem.r.count !== undefined ? rowItem.r.count : "")
                              : rowItem.kind === "track" ? win.clock(rowItem.r.seconds)
                              : rowItem.kind === "album" || rowItem.kind === "playlist" ? rowItem.r.count : ""
                        color: rowItem.current ? accent.text : "#5C6880"
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 10
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        // an album's (or list's) cover while hovered, like Spotify (coverTip)
                        onContainsMouseChanged: {
                            if (containsMouse && rowItem.r.image && plPanel.dragRow < 0)
                                coverTip.show(rowItem.r.image, rowItem.mapToItem(plArea, 0, 0).y, rowItem.height);
                            else if (!containsMouse && coverTip.url === rowItem.r.image)
                                coverTip.hide();
                        }
                        Component.onDestruction: if (containsMouse) coverTip.hide()
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        property real pressY: 0
                        onPressed: mouse => { pressY = mouse.y; coverTip.hide(); }
                        // own lists: drag a row to move it (not while filtered)
                        onPositionChanged: mouse => {
                            if (!pressed || !rowItem.isTrack || !plPanel.editable || plPanel.filter || win.pl.busy)
                                return;
                            if (plPanel.dragRow < 0 && Math.abs(mouse.y - pressY) < 6)
                                return;
                            plPanel.dragRow = rowItem.modelData.index;
                            const p = mapToItem(plView, mouse.x, mouse.y);
                            if (p.y < 12) plView.contentY = Math.max(0, plView.contentY - 6);
                            else if (p.y > plView.height - 12)
                                plView.contentY = Math.min(Math.max(0, plView.contentHeight - plView.height), plView.contentY + 6);
                            plPanel.dropAt = Math.max(0, Math.min(win.pl.rows.length, Math.round((p.y + plView.contentY) / 18)));
                        }
                        onReleased: {
                            if (plPanel.dragRow >= 0) {
                                amp.spMove(plPanel.dragRow, plPanel.dropAt);
                                plPanel.dragRow = -1;
                                plPanel.dropAt = -1;
                            }
                        }
                        onClicked: mouse => {
                            const p = mapToItem(null, mouse.x, mouse.y);
                            if (!rowItem.isTrack) {
                                if (mouse.button === Qt.RightButton)
                                    plPanel.listMenu(rowItem.r, p.x, p.y);
                                else
                                    plPanel.openEntry(rowItem.r.id);
                            } else if (mouse.button === Qt.RightButton) {
                                plPanel.trackMenu(rowItem.modelData.index, p.x, p.y);
                            } else if (rowItem.kind === "more") {
                                amp.searchMore();
                            } else if (rowItem.kind === "album") {
                                plPanel.openAlbum(rowItem.modelData.index);
                            } else if (rowItem.kind === "artist") {
                                amp.openArtist(rowItem.modelData.index);
                            } else if (rowItem.kind === "genre") {
                                plPanel.openGenre(rowItem.r.title);
                            } else if (rowItem.kind === "similar") {
                                amp.openSimilar();
                            } else if (rowItem.kind === "lastfm") {
                                plPanel.askLastfm();
                            }
                        }
                        onDoubleClicked: mouse => {
                            // these open a view on the first click (the second would land in it)
                            if (mouse.button !== Qt.LeftButton || rowItem.kind !== "track" && rowItem.isTrack
                                    && rowItem.kind !== "playlist")
                                return;
                            if (!rowItem.isTrack)
                                rowItem.r.id === "search" ? plPanel.openEntry("search") : amp.playList(rowItem.r.id);
                            else
                                amp.playRow(rowItem.modelData.index);
                        }
                    }
                }
                // Where the dragged row goes
                Rectangle {
                    visible: plPanel.dragRow >= 0 && plPanel.dropAt >= 0
                    y: plPanel.dropAt * 18 - plView.contentY - 1
                    width: plView.width
                    height: 2
                    color: accent.color
                    z: 5
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 30
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: plView.count === 0 && !win.pl.busy && !win.pl.message
                    text: plPanel.searching ? (win.pl.query ? "Inget hittades för " + win.pl.query : "Skriv i rutan nedanför och tryck Enter – låtar, album och listor i hela Spotify")
                          : plFilter.text ? "Inget som matchar" : plPanel.entry ? "Listan är tom" : "Inga listor än – tryck ↻"
                    color: "#5C6880"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 11
                }
            }

            // What is happening, or what went wrong
            Rectangle {
                visible: !!win.pl.busy || !!win.pl.message || !!win.pl.note
                anchors { left: parent.left; right: parent.right; bottom: plFoot.top; margins: 6 }
                height: busyText.implicitHeight + 10
                color: win.pl.message && !win.pl.busy ? "#2A1418" : "#12203A"
                border.width: 1
                border.color: win.pl.message && !win.pl.busy ? accent.error : accent.dim
                Text {
                    id: busyText
                    anchors { fill: parent; margins: 5 }
                    wrapMode: Text.WordWrap
                    text: win.pl.busy || win.pl.message || win.pl.note || ""
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 11
                }
                // "Tillagd i …" and the like go away by themselves
                Timer {
                    running: !!win.pl.note && !win.pl.busy && !win.pl.message
                    interval: 4000
                    onTriggered: amp.clearNote()
                }
            }

            // The foot: filter, count and length, the web app, sign out
            Item {
                id: plFoot
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
                height: 20
                visible: win.pl.signedIn
                Rectangle {
                    id: filterBox
                    width: plPanel.searching || plPanel.home ? parent.width - 30 : 150
                    height: 20
                    color: "#07090D"
                    border.width: 1
                    border.color: plFilter.activeFocus ? accent.color : "#1E2A40"
                    TextInput {
                        id: plFilter
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: "#E6ECF5"
                        selectionColor: accent.color
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 11
                        Keys.onEscapePressed: text = ""
                        onAccepted: {
                            if (plPanel.searching)
                                amp.searchSpotify(text);
                            else if (plPanel.home && text.trim())
                                plPanel.openGenre(text);
                        }
                        Text {
                            visible: plFilter.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: plPanel.searching ? "Sök i hela Spotify… (Enter)" : plPanel.home ? "Skriv en genre… (Enter)"
                                  : plPanel.entry ? "Sök i listan…" : "Filtrera listorna…"
                            color: "#5C6880"
                            font: plFilter.font
                        }
                    }
                }
                Text {
                    visible: !plPanel.searching && !plPanel.home
                    anchors { left: filterBox.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: {
                        if (!plPanel.entry)
                            return (win.pl.lists || []).length ? Math.max(0, win.pl.lists.filter(l => !l.special).length) + " listor" : "";
                        const rows = (win.pl.rows || []).filter(r => !plPanel.found || r.kind === "track");
                        if (plPanel.found && !rows.length)
                            return "";
                        let sum = 0;
                        for (let i = 0; i < rows.length; i++)
                            sum += rows[i].seconds;
                        return rows.length + " låtar · " + win.clockLong(sum);
                    }
                    color: "#5C6880"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 10
                }
                SmallLink {
                    id: footMore
                    anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
                    text: "⋯"
                    font.pixelSize: 14
                    onClicked: {
                        const p = footMore.mapToItem(null, 0, 0);
                        plPanel.footMenu(p.x - 190, p.y - 170);
                    }
                }
            }
        }

        // ♪ ALBUMET's hover: which album plays, when another view is open (over the playlist)
        Rectangle {
            id: albumTip
            readonly property var entry: win.pl.list || null
            readonly property bool open: !!entry && !!entry.album && !!win.st.album
                                         && (entry.name === win.st.album || entry.name.endsWith(" – " + win.st.album))
            visible: albumBtn.visible && albumBtn.hovered && plFrame.visible && !!win.st.album && !win.st.local && !open
            z: 20
            x: Math.max(6, plFrame.x + plFrame.width - 6 - width)
            y: plFrame.y + 29
            width: Math.min(Math.max(tipAlbum.implicitWidth, tipArtist.implicitWidth) + 16, plArea.width - 12)
            height: (tipArtist.visible ? 36 : 22)
            color: "#0B1018"
            border.width: 1
            border.color: accent.color
            Text {
                id: tipAlbum
                x: 8; y: 4
                width: albumTip.width - 16
                text: win.st.album || ""
                color: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                id: tipArtist
                x: 8; y: 19
                width: albumTip.width - 16
                text: win.st.artist || ""
                visible: text !== ""
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // The playlist title's hover: the whole name, when it is cut short with …
        Rectangle {
            id: backTip
            readonly property point at: plBack.visible && plBack.hovered ? plBack.mapToItem(plArea, 0, plBack.height) : Qt.point(0, 0)
            visible: plBack.visible && plBack.hovered && plBack.truncated
            z: 20
            x: Math.max(6, Math.min(at.x - 4, plArea.width - 6 - width))
            y: at.y + 4
            width: Math.min(backTipText.implicitWidth + 16, plArea.width - 12)
            height: backTipText.height + 8
            color: "#0B1018"
            border.width: 1
            border.color: accent.color
            Text {
                id: backTipText
                x: 8; y: 4
                width: backTip.width - 16
                text: plPanel.entry ? plPanel.entry.name : ""
                color: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.pixelSize: 12
                font.weight: Font.Medium
                wrapMode: Text.Wrap
            }
        }

        // The hovered album's cover (29 Oct, the user's wish – Spotify shows it): at the right
        // side, next to the row, after a short wait so it doesn't flicker past while scrolling
        Rectangle {
            id: coverTip
            property string url: ""
            property string wanted: ""
            property real rowY: 0
            property real rowH: 0
            function show(u, y, h) { wanted = u; rowY = y; rowH = h; coverWait.restart(); }
            function hide() { coverWait.stop(); wanted = ""; url = ""; }
            Timer { id: coverWait; interval: 250; onTriggered: coverTip.url = coverTip.wanted }
            visible: url !== "" && coverImg.status === Image.Ready
            z: 20
            width: 162; height: 162
            x: plArea.width - width - 12
            // below the row if it fits, else above it
            y: rowY + rowH + 4 + height <= plArea.height - 6 ? rowY + rowH + 4 : Math.max(30, rowY - height - 4)
            color: "#05070A"
            border.width: 1
            border.color: accent.color
            Image {
                id: coverImg
                anchors { fill: parent; margins: 1 }
                source: coverTip.wanted  // loading starts with the hover, shown after the wait
                sourceSize: Qt.size(320, 320)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
        }

        // ── The playlist's height: drag the bottom edge (or the grip in the corner) ──
        // In its own window: the window's size (KWin resizes it; the size is kept in amp.json)
        Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 5
            z: 10
            // Winamp's corner grip, drawn
            Canvas {
                anchors { right: parent.right; bottom: parent.bottom; margins: 1 }
                width: 9; height: 9
                onPaint: {
                    const c = getContext("2d");
                    c.fillStyle = "#3A4A66";
                    for (const [x, y] of [[6, 0], [3, 3], [6, 3], [0, 6], [3, 6], [6, 6]])
                        c.fillRect(x, y, 2, 2);
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -3
                cursorShape: win.plDetached && mouseX > width - 14 ? Qt.SizeFDiagCursor : Qt.SizeVerCursor
                hoverEnabled: win.plDetached
                property real startY: 0
                property int startHeight: 0
                onPressed: mouse => {
                    if (win.plDetached) {
                        plWin.startSystemResize(mouse.x > width - 14 ? (Qt.BottomEdge | Qt.RightEdge) : Qt.BottomEdge);
                        return;
                    }
                    startY = mapToGlobal(mouse.x, mouse.y).y;
                    startHeight = win.plHeight;
                }
                onPositionChanged: mouse => {
                    if (!pressed || win.plDetached)
                        return;
                    const top = 152 + (amp.graphShown ? win.graphHeight : 0);
                    const most = Math.max(win.minPlHeight, Screen.desktopAvailableHeight - top - 40);
                    // the window grows under the mouse, so the window-relative y moves with it: use the screen's
                    const y = mapToGlobal(mouse.x, mouse.y).y;
                    win.plHeight = Math.round(Math.max(win.minPlHeight, Math.min(most, startHeight + y - startY)) / 18) * 18 + 6;
                }
                onReleased: { if (!win.plDetached) amp.setPlHeight(win.plHeight); }
                onDoubleClicked: { if (!win.plDetached) { win.plHeight = 330; amp.setPlHeight(330); } }
            }
        }
    }

    // ── A small right-click menu (no Controls): items {text, act} or {sep: true} ──
    property var menuItems: []
    property point menuAt: Qt.point(0, 0)
    // x, y in the window's own coordinates (mapToItem(null, …)); the menu opens in the window that
    // was clicked – GoblinAmp's or the playlist's own
    property Item menuHost: win.contentItem
    function openMenu(items, x, y) {
        menuHost = plDetached && plWin.active ? plWin.contentItem : win.contentItem;
        menuAt = Qt.point(x, y);
        menuItems = items;
    }
    // GoblinAmp's colour: GOBLINCAKES' own or a class colour just for GoblinAmp (right-click the title bar, ⋯)
    function accentMenu(x, y) {
        const mark = id => amp.accentChoice === id ? "✓  " : "";
        openMenu([{ text: mark("") + "Följ GOBLINCAKES", swatch: amp.osAccent(), act: () => amp.setAccent("") }, { sep: true }]
            .concat(amp.accentList.map(a => ({ text: mark(a.id) + a.name, swatch: a.color, act: () => amp.setAccent(a.id) }))),
            x, y);
    }
    Item {
        id: menuLayer
        parent: win.menuHost
        anchors.fill: parent
        visible: win.menuItems.length > 0
        z: 50
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: win.menuItems = []
            onWheel: win.menuItems = []
        }
        Rectangle {
            id: menuBox
            width: 210
            height: menuCol.height + 6
            x: Math.max(2, Math.min(win.menuAt.x, menuLayer.width - width - 2))
            y: Math.max(2, Math.min(win.menuAt.y, menuLayer.height - height - 2))
            color: "#0E1420"
            border.width: 1
            border.color: "#2A3852"
            Column {
                id: menuCol
                x: 1; y: 3
                width: parent.width - 2
                Repeater {
                    model: win.menuItems
                    Rectangle {
                        id: mi
                        required property var modelData
                        width: menuCol.width
                        height: modelData.sep ? 7 : 22
                        color: !modelData.sep && miArea.containsMouse ? accent.dim : "transparent"
                        Rectangle {
                            visible: !!mi.modelData.sep
                            anchors.centerIn: parent
                            width: parent.width - 12
                            height: 1
                            color: "#1E2A40"
                        }
                        Rectangle {
                            visible: !!mi.modelData.swatch
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10; height: 10
                            color: mi.modelData.swatch || "transparent"
                        }
                        Text {
                            visible: !mi.modelData.sep
                            x: mi.modelData.swatch ? 28 : 10
                            width: parent.width - x - 6
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: mi.modelData.text || ""
                            color: miArea.containsMouse ? accent.on : "#C8D1DE"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: miArea
                            anchors.fill: parent
                            enabled: !mi.modelData.sep
                            hoverEnabled: true
                            onClicked: {
                                const act = mi.modelData.act;
                                win.menuItems = [];
                                act();
                            }
                        }
                    }
                }
            }
        }
    }

    // ── A list's name: new, new with the picked rows, rename, save Nu spelas ──
    property string nameMode: ""
    property string nameTarget: ""
    property string nameRows: ""
    function askName(mode, target, rows, current) {
        nameMode = mode;
        nameTarget = target;
        nameRows = rows;
        const field = mode.indexOf("sp-") === 0 ? spNameInput : nameInput;
        field.text = current;
        field.selectAll();
        field.forceActiveFocus();
    }
    function nameDone(ok) {
        const name = (nameMode.indexOf("sp-") === 0 ? spNameInput : nameInput).text.trim();
        const mode = nameMode;
        nameMode = "";
        if (!ok || !name)
            return;
        if (mode === "new")
            amp.localOpen(amp.localNewList(name, "[]"));
        else if (mode === "newfrom")
            amp.localNewList(name, nameRows);
        else if (mode === "rename")
            amp.localRename(nameTarget, name);
        else if (mode === "saveas")
            amp.localSaveNowAs(name);
        else if (mode === "sp-new" || mode === "sp-newfrom")
            amp.spNewList(name, nameRows || "[]");
        else if (mode === "sp-rename")
            amp.spRename(nameTarget, name);
        else if (mode === "sp-lastfm")
            amp.setLastfmKey(name);
    }

    // ── Choosing files, a folder, a list to bring in ──
    // The ✕'s question, over the player
    Rectangle {
        visible: win.closeAsk
        x: 1; y: 22
        width: parent.width - 2
        height: 129
        z: 60
        color: "#0B1018"
        border.width: 1
        border.color: accent.color
        MouseArea { anchors.fill: parent }   // nothing under it takes the clicks
        Column {
            x: 12; y: 12
            width: parent.width - 24
            spacing: 9
            Text {
                text: "STÄNGA GOBLINAMP?"
                color: "#E6ECF5"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: 12
                font.letterSpacing: 1.5
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "I systemfältet spelar musiken vidare – klick på ikonen tar fram fönstret. Stäng stänger även Spotify."
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 11
            }
            Row {
                spacing: 6
                Btn { label: "GÖM I SYSTEMFÄLTET"; active: true; onClicked: win.closeAs("tray") }
                Btn { label: "STÄNG ÄVEN SPOTIFY"; onClicked: win.closeAs("quit") }
                Btn { label: "AVBRYT"; onClicked: win.closeAsk = false }
            }
            Row {
                spacing: 6
                Rectangle {
                    width: 12; height: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: win.closeRemember ? accent.color : "transparent"
                    border.width: 1
                    border.color: win.closeRemember ? accent.color : "#2A3852"
                    Text { anchors.centerIn: parent; visible: win.closeRemember; text: "✓"; color: accent.on; font.pixelSize: 9 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Kom ihåg mitt val (högerklick på ✕ frågar igen)"
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 11
                    MouseArea { anchors.fill: parent; anchors.leftMargin: -18; onClicked: win.closeRemember = !win.closeRemember }
                }
            }
        }
    }

    // ── The playlist's own window (LOSSA in the playlist, FÄST here) ──
    // Same look as GoblinAmp's: frameless, a title line to drag. KWin's goblincakes-windows script
    // puts it where it was moved to (kwinrc ampPlPlace, by the title) – first time under GoblinAmp.
    Window {
        id: plWin
        title: "GoblinAmp – spellista"
        flags: Qt.Window | Qt.FramelessWindowHint
        visible: win.visible && win.plDetached && win.pl.open
        width: amp.savedPlSize[0]
        height: amp.savedPlSize[1]
        minimumWidth: 300
        minimumHeight: 200
        color: "#0B1018"
        onWidthChanged: plSizeSave.restart()
        onHeightChanged: plSizeSave.restart()
        Timer { id: plSizeSave; interval: 600; onTriggered: if (plWin.visible) amp.setPlSize(plWin.width, plWin.height) }
        // Winamp's keys here too (GoblinAmp's own Shortcuts only work in its window)
        Shortcut { sequence: "Space"; onActivated: amp.control("playpause") }
        Shortcut { sequence: "Z"; onActivated: amp.control("previous") }
        Shortcut { sequence: "X"; onActivated: amp.control("play") }
        Shortcut { sequence: "C"; onActivated: amp.control("pause") }
        Shortcut { sequence: "V"; onActivated: amp.control("stop") }
        Shortcut { sequence: "B"; onActivated: amp.control("next") }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: "#1E2A40"
            z: 10
        }
        Rectangle {
            x: 1; y: 1
            width: parent.width - 2
            height: 20
            color: "#05070A"
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: mouse => {
                    if (mouse.button === Qt.RightButton)
                        win.accentMenu(mouse.x, mouse.y + 12);
                    else
                        plWin.startSystemMove();
                }
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
                text: "GOBLINAMP · SPELLISTA"
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: 11
                font.letterSpacing: 2
            }
            Row {
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                spacing: 2
                Repeater {
                    // FÄST = back under the player; ✕ = the playlist closed (PL opens it here again)
                    model: [["FÄST", "attach"], ["✕", "close"]]
                    Rectangle {
                        id: ptb
                        required property var modelData
                        width: modelData[1] === "attach" ? ptbText.implicitWidth + 12 : 18
                        height: 14
                        color: ptbArea.containsMouse ? (modelData[1] === "close" ? "#A4262C" : "#16203A") : "transparent"
                        Text {
                            id: ptbText
                            anchors.centerIn: parent
                            text: ptb.modelData[0]
                            color: ptbArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                            font.family: ptb.modelData[1] === "attach" ? "Chakra Petch" : font.family
                            font.weight: ptb.modelData[1] === "attach" ? Font.Bold : Font.Normal
                            font.letterSpacing: ptb.modelData[1] === "attach" ? 1 : 0
                            font.pixelSize: ptb.modelData[1] === "attach" ? 9 : 10
                        }
                        MouseArea {
                            id: ptbArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (ptb.modelData[1] === "attach") amp.setPlDetached(false);
                                else amp.togglePlaylist();
                            }
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: filesDialog
        title: "Lägg till musik"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Musik (*.mp3 *.flac *.ogg *.oga *.opus *.m4a *.aac *.wav *.wma *.ape *.wv *.aif *.aiff *.mka *.mpc)",
                      "Spellistor (*.m3u *.m3u8 *.pls)", "Alla filer (*)"]
        onAccepted: amp.localAddPaths(JSON.stringify(selectedFiles.map(u => String(u))))
    }
    FolderDialog {
        id: folderDialog
        title: "Lägg till en mapp med musik"
        onAccepted: amp.localAddPaths(JSON.stringify([String(selectedFolder)]))
    }
    FileDialog {
        id: importDialog
        title: "Öppna en spellista (t.ex. från Winamp)"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Spellistor (*.m3u *.m3u8 *.pls)"]
        onAccepted: amp.localAddPaths(JSON.stringify(selectedFiles.map(u => String(u))))
    }
}
