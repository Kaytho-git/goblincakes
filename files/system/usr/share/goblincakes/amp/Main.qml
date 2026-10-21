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
    height: shade ? 22 : 152 + (pl.open ? plHeight : 0)
    readonly property int plHeight: 300
    readonly property var pl: JSON.parse(amp.pl || "{}")
    // The playing track's Spotify address (MPRIS: /com/spotify/track/<id>)
    readonly property string playingUri: (st.trackid || "").indexOf("/com/spotify/track/") === 0
        ? "spotify:track:" + st.trackid.split("/").pop() : ""
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

    Item {
        id: plPanel
        visible: !win.shade && win.pl.open
        x: 1
        y: 152
        width: parent.width - 2
        height: win.plHeight - 1
        readonly property var entry: win.pl.list || null
        readonly property string filter: plFilter.text.toLowerCase()
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
                visible: !plPanel.entry
                text: "SPELLISTA" + (win.pl.name ? "  ·  " + win.pl.name : "")
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: 10
                font.letterSpacing: 1.5
            }
            SmallLink {
                visible: !!plPanel.entry
                width: Math.min(implicitWidth, parent.width - 130)
                elide: Text.ElideRight
                text: "◀  " + (plPanel.entry ? plPanel.entry.name : "")
                color: accent.text
                font.weight: Font.DemiBold
                onClicked: { plFilter.text = ""; amp.backToLists(); }
            }
            SmallLink {
                visible: !!plPanel.entry && plPanel.entry.id !== "queue"
                anchors { right: refresh.left; rightMargin: 12 }
                text: "▶ Spela listan"
                onClicked: amp.playList(plPanel.entry.id)
            }
            SmallLink {
                id: refresh
                visible: win.pl.signedIn
                anchors.right: parent.right
                text: "↻"
                font.pixelSize: 13
                onClicked: plPanel.entry ? amp.openList(plPanel.entry.id) : amp.refreshLists()
            }
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
                color: accent.text
                font.family: "IBM Plex Sans"
                font.pixelSize: 11
            }
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
            y: 26
            width: parent.width - 8
            height: parent.height - 26 - 30
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: plPanel.shown
            FastWheel { flick: plView }
            delegate: Rectangle {
                id: rowItem
                required property var modelData
                required property int index
                readonly property var r: modelData.row
                readonly property bool isTrack: !!plPanel.entry
                readonly property bool current: isTrack && r.uri === win.playingUri && r.uri !== ""
                width: plView.width
                height: 18
                color: rowArea.containsMouse ? "#16203A" : current ? "#12203A" : "transparent"
                Text {
                    x: 4
                    width: parent.width - 60
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: rowItem.isTrack
                          ? (rowItem.modelData.index + 1) + ". " + (rowItem.r.artist ? rowItem.r.artist + " – " : "") + rowItem.r.title
                          : (rowItem.r.special ? "♪ " : "") + rowItem.r.name
                            + (!rowItem.r.special && !rowItem.r.mine && rowItem.r.owner ? "  · " + rowItem.r.owner : "")
                    color: rowItem.current ? accent.text : rowItem.r.local ? "#5C6880" : "#C8D1DE"
                    font.family: "IBM Plex Sans"
                    font.weight: rowItem.current ? Font.DemiBold : Font.Normal
                    font.pixelSize: 11
                }
                Text {
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: rowItem.isTrack ? win.clock(rowItem.r.seconds) : (rowItem.r.count !== undefined ? rowItem.r.count : "")
                    color: rowItem.current ? accent.text : "#5C6880"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 10
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (!rowItem.isTrack) { plFilter.text = ""; amp.openList(rowItem.r.id); }
                    onDoubleClicked: rowItem.isTrack ? amp.playRow(rowItem.modelData.index) : amp.playList(rowItem.r.id)
                }
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 30
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: plView.count === 0 && !win.pl.busy && !win.pl.message
                text: plFilter.text ? "Inget som matchar" : plPanel.entry ? "Listan är tom" : "Inga listor än – tryck ↻"
                color: "#5C6880"
                font.family: "IBM Plex Sans"
                font.pixelSize: 11
            }
        }

        // What is happening, or what went wrong
        Rectangle {
            visible: !!win.pl.busy || !!win.pl.message
            anchors { left: parent.left; right: parent.right; bottom: plFoot.top; margins: 6 }
            height: busyText.implicitHeight + 10
            color: win.pl.message ? "#2A1418" : "#12203A"
            border.width: 1
            border.color: win.pl.message ? accent.error : accent.dim
            Text {
                id: busyText
                anchors { fill: parent; margins: 5 }
                wrapMode: Text.WordWrap
                text: win.pl.busy || win.pl.message || ""
                color: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.pixelSize: 11
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
                width: 130
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
                    Text {
                        visible: plFilter.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Sök i listan…"
                        color: "#5C6880"
                        font: plFilter.font
                    }
                }
            }
            Text {
                anchors { left: filterBox.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                text: {
                    if (!plPanel.entry)
                        return (win.pl.lists || []).length ? Math.max(0, win.pl.lists.length - 2) + " listor" : "";
                    const rows = win.pl.rows || [];
                    let sum = 0;
                    for (let i = 0; i < rows.length; i++)
                        sum += rows[i].seconds;
                    return rows.length + " låtar · " + win.clockLong(sum);
                }
                color: "#5C6880"
                font.family: "IBM Plex Mono"
                font.pixelSize: 10
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 10
                SmallLink { text: plPanel.showHelp ? "Tillbaka" : "Hjälp"; onClicked: plPanel.showHelp = !plPanel.showHelp }
                SmallLink { text: "Spotify-fönstret"; onClicked: amp.playlists() }
                SmallLink { text: "Logga ut"; onClicked: amp.signOut() }
            }
        }
    }
}
