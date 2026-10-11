// GoblinRecorder – automatic WoW recordings, in the style of GOBLINCAKES Config.
// Backend: /usr/bin/goblin-recorder ("backend"). Pieces (buttons, switches, scroll bar …)
// are copies of the ones in config/Main.qml – change both.
import QtQuick
import QtQuick.Window
import QtMultimedia

Window {
    id: win

    width: 1320
    height: 860
    minimumWidth: 980
    minimumHeight: 640
    visible: true
    title: "GoblinRecorder" // the desktop adds nothing when the title is the program name
    color: "#07090D"

    readonly property var st: JSON.parse(backend.status)
    readonly property var cfg: JSON.parse(backend.config)
    readonly property var enc: JSON.parse(backend.encoders)
    readonly property var videos: JSON.parse(backend.videos)
    property string tab: "videos" // videos | settings
    property var selected: null
    property string note: ""
    property bool wclBusy: false

    function set(key, value) { backend.setConfig(key, JSON.stringify(value)); }

    function clock(sec) {
        sec = Math.max(0, Math.floor(sec));
        const h = Math.floor(sec / 3600), m = Math.floor(sec / 60) % 60, s = sec % 60;
        return (h ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(s).padStart(2, "0");
    }

    function size(bytes) {
        return bytes > 1e9 ? (bytes / 1e9).toFixed(1).replace(".", ",") + " GB" : Math.round(bytes / 1e6) + " MB";
    }

    function when(t) {
        const d = new Date(t * 1000);
        return d.toLocaleDateString(Qt.locale("sv_SE"), "ddd d MMM") + " " + d.toLocaleTimeString(Qt.locale("sv_SE"), "HH:mm");
    }

    function resultText(v) {
        return ({ kill: "KILL", wipe: "WIPE", timed: "I TID", depleted: "FÖR SENT" })[v.result] || "AVBRUTEN";
    }

    function resultColor(v) {
        return v.result === "kill" || v.result === "timed" ? "#3FB950" : v.result === "wipe" || v.result === "depleted" ? "#E5534B" : "#8B98AD";
    }

    function title(v) {
        return v.kind === "mplus" ? "+" + v.level + " " + v.name : v.name;
    }

    // One sentence about what is going on right now
    function stateLine() {
        if (!st.service)
            return "Inspelningstjänsten kör inte.";
        if (st.obs === "missing")
            return "OBS behövs – installera det i GOBLINCAKES Config → Program.";
        if (st.current)
            return "Spelar in " + (st.current.kind === "mplus" ? "nyckeln" : st.current.name + " (" + st.current.difficulty + ")") + " …";
        if (st.waiting)
            return "Sparar filmen …";
        if (st.wow && !st.logging)
            return "WoW kör men skriver ingen stridslogg – skriv /combatlog i chatten.";
        if (st.wow && st.zone)
            return "I " + st.zone + " – väntar på nästa boss.";
        if (st.wow)
            return "WoW kör – inspelningen startar i raid och Mythic+.";
        return "Väntar på WoW. Raidbossar och Mythic+-nycklar spelas in av sig själva.";
    }

    Connections {
        target: backend
        function onMessage(text) {
            win.note = text;
            noteTimer.restart();
        }
        function onWclBusy(busy) { win.wclBusy = busy; }
        function onVideosChanged() {
            if (win.selected && !win.videos.some(v => v.path === win.selected.path))
                win.selected = null;
            if (win.selected)
                win.selected = win.videos.find(v => v.path === win.selected.path) || null;
            if (!win.selected && win.videos.length)
                win.selected = win.videos[0];
        }
    }
    Component.onCompleted: if (videos.length) selected = videos[0]
    Timer { id: noteTimer; interval: 6000; onTriggered: win.note = "" }

    // ── Pieces (same as GOBLINCAKES Config) ──────────────────

    component FastWheel: WheelHandler {
        required property Flickable flick
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
            const top = flick.originY, bottom = top + Math.max(0, flick.contentHeight - flick.height);
            flick.cancelFlick();
            flick.contentY = Math.max(top, Math.min(bottom, flick.contentY - delta));
            event.accepted = true;
        }
    }

    component FlatField: Rectangle {
        property alias text: input.text
        property alias echoMode: input.echoMode
        property string hint
        height: 40
        color: "#07090D"
        border.width: 1
        border.color: input.activeFocus ? "#2F6FED" : "#2A3852"
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            verticalAlignment: TextInput.AlignVCenter
            color: "#E6ECF5"
            selectionColor: "#2F6FED"
            font.family: "IBM Plex Mono"
            font.pixelSize: 13
            clip: true
            selectByMouse: true
        }
        Text {
            anchors { fill: input }
            verticalAlignment: Text.AlignVCenter
            visible: !input.text && !input.activeFocus
            text: parent.hint
            color: "#5C6880"
            font.family: "IBM Plex Sans"
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    component FlatButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        property bool danger: false
        property bool enabledState: true
        signal clicked()

        width: Math.max(120, label.implicitWidth + 40)
        height: 40
        opacity: enabledState ? 1 : 0.4
        color: primary ? (area.containsMouse && enabledState ? "#4A82F0" : "#2F6FED")
                       : (area.containsMouse && enabledState ? (danger ? "#3A1418" : "#1A2438") : "transparent")
        border.width: primary ? 0 : 1
        border.color: danger && area.containsMouse ? "#A4262C" : "#2A3852"

        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.weight: Font.Medium
            font.pixelSize: 14
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.enabledState) btn.clicked()
        }
    }

    component ToggleSwitch: Rectangle {
        id: sw
        property bool on
        property bool enabledState: true
        signal toggled()
        width: 48
        height: 26
        color: on ? "#2F6FED" : "transparent"
        border.width: on ? 0 : 1
        border.color: "#2A3852"
        opacity: enabledState ? 1 : 0.35
        Rectangle {
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            x: sw.on ? parent.width - width - 4 : 4
            color: sw.on ? "#E6ECF5" : "#8B98AD"
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: sw.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (sw.enabledState) sw.toggled()
        }
    }

    component FlatScrollBar: Item {
        id: bar
        required property Flickable flick
        readonly property bool needed: flick.visible && flick.contentHeight > flick.height + 1
        anchors { right: flick.right; rightMargin: 4; top: flick.top; topMargin: 4; bottom: flick.bottom; bottomMargin: 4 }
        width: 8
        visible: needed
        z: 2

        Rectangle {
            anchors.fill: parent
            color: "#0E1420"
        }
        Rectangle {
            id: handle
            width: parent.width
            height: Math.max(32, bar.flick.visibleArea.heightRatio * bar.height)
            y: bar.flick.visibleArea.yPosition / Math.max(0.0001, 1 - bar.flick.visibleArea.heightRatio)
               * (bar.height - height)
            color: handleArea.pressed ? "#2F6FED" : handleArea.containsMouse ? "#8B98AD" : "#2A3852"

            MouseArea {
                id: handleArea
                anchors.fill: parent
                hoverEnabled: true
                property real startY
                property real startContentY
                onPressed: mouse => {
                    startY = mapToItem(bar, 0, mouse.y).y;
                    startContentY = bar.flick.contentY;
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const dy = mapToItem(bar, 0, mouse.y).y - startY;
                    const span = bar.flick.contentHeight - bar.flick.height;
                    bar.flick.contentY = Math.max(0, Math.min(span, startContentY + dy * span / Math.max(1, bar.height - handle.height)));
                }
            }
        }
    }

    component SectionTitle: Text {
        color: "#8B98AD"
        font.family: "Chakra Petch"
        font.weight: Font.DemiBold
        font.pixelSize: 14
        font.letterSpacing: 2.5
    }

    component Note: Text {
        color: "#8B98AD"
        font.family: "IBM Plex Sans"
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        lineHeight: 1.15
    }

    // A small status square + word in the header
    component StatusChip: Row {
        id: chip
        property string label
        property string value
        property color tone: "#8B98AD"
        spacing: 8
        Rectangle {
            width: 10
            height: 10
            anchors.verticalCenter: parent.verticalCenter
            color: chip.tone
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            color: "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: 13
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.value
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.weight: Font.Medium
            font.pixelSize: 13
        }
    }

    // A choice among a few (fps, codec, space): square card with a blue edge when chosen
    component Choice: Rectangle {
        id: ch
        property string text
        property string sub
        property bool chosen
        property bool enabledState: true
        signal picked()
        width: 210
        height: sub ? 72 : 48
        color: chosen ? "#12203A" : (chArea.containsMouse && enabledState ? "#0E1420" : "transparent")
        border.width: chosen ? 2 : 1
        border.color: chosen ? "#2F6FED" : "#2A3852"
        opacity: enabledState ? 1 : 0.35
        Column {
            anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 4
            Text {
                text: ch.text
                color: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.weight: Font.Medium
                font.pixelSize: 15
            }
            Text {
                visible: ch.sub !== ""
                width: parent.width
                text: ch.sub
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: chArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: ch.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (ch.enabledState) ch.picked()
        }
    }

    // ── Header ───────────────────────────────────────────────

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 168

        Row {
            anchors { left: parent.left; leftMargin: 40; top: parent.top; topMargin: 28 }
            spacing: 20

            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: logoUrl
                sourceSize.width: 60
                sourceSize.height: 60
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Row {
                    spacing: 14
                    Text {
                        text: "GOBLINRECORDER"
                        color: "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: 30
                        font.letterSpacing: 4
                    }
                    Rectangle { // red while recording
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!win.st.current
                        width: recText.implicitWidth + 24
                        height: 26
                        color: "#3A1418"
                        border.width: 1
                        border.color: "#E5534B"
                        Text {
                            id: recText
                            anchors.centerIn: parent
                            text: "● SPELAR IN"
                            color: "#E5534B"
                            font.family: "Chakra Petch"
                            font.weight: Font.Bold
                            font.pixelSize: 12
                            font.letterSpacing: 1.5
                        }
                        SequentialAnimation on opacity {
                            running: !!win.st.current
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.45; duration: 700 }
                            NumberAnimation { to: 1; duration: 700 }
                        }
                    }
                }
                Text {
                    text: win.stateLine()
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                }
            }
        }

        // Status and the OBS button, top right
        Column {
            anchors { right: parent.right; rightMargin: 40; top: parent.top; topMargin: 26 }
            spacing: 12

            Row {
                anchors.right: parent.right
                spacing: 22
                StatusChip {
                    label: "WoW"
                    value: win.st.wow ? "kör" : "av"
                    tone: win.st.wow ? "#3FB950" : "#2A3852"
                }
                StatusChip {
                    label: "Stridslogg"
                    value: !win.st.wow ? "–" : win.st.logging ? (win.st.logDelay !== null && win.st.logDelay !== undefined
                           ? "skrivs (" + Math.round(win.st.logDelay) + " s sen)" : "skrivs") : "av"
                    tone: !win.st.wow ? "#2A3852" : win.st.logging ? "#3FB950" : "#D29922"
                }
                StatusChip {
                    label: "OBS"
                    value: ({ connected: "redo", stopped: "av", "no-ws": "behöver startas om", missing: "saknas", error: "svarar inte" })[win.st.obs] || "–"
                    tone: win.st.obs === "connected" ? "#3FB950" : win.st.obs === "stopped" ? "#2A3852" : "#D29922"
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 10
                FlatButton {
                    visible: !win.st.service
                    text: "Starta inspelningstjänsten"
                    onClicked: backend.startService()
                }
                FlatButton {
                    visible: win.st.audioPlugin === false && win.st.obs !== "missing"
                    text: "Hämta ljudtillägget"
                    onClicked: backend.installAudioPlugin()
                }
                FlatButton {
                    primary: win.st.obs !== "connected"
                    enabledState: win.st.obs !== "missing" && win.st.obs !== "connected" && !win.st.recording
                    text: win.st.obs === "no-ws" || win.st.obs === "error" ? "Starta om OBS"
                        : win.st.obs === "connected" ? "OBS är igång" : "Starta OBS"
                    onClicked: win.st.obs === "no-ws" || win.st.obs === "error" ? backend.restartObs() : backend.startObs()
                }
            }
        }

        Row {
            anchors { left: parent.left; leftMargin: 40; bottom: parent.bottom }
            spacing: 32
            Repeater {
                model: [{ "id": "videos", "label": "INSPELNINGAR" + (win.videos.length ? " (" + win.videos.length + ")" : "") },
                        { "id": "settings", "label": "INSTÄLLNINGAR" }]
                Item {
                    id: tabItem
                    required property var modelData
                    readonly property bool active: win.tab === modelData.id
                    width: tabLabel.implicitWidth
                    height: 44
                    Text {
                        id: tabLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: tabItem.modelData.label
                        color: tabItem.active || tabArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                        font.family: "Chakra Petch"
                        font.weight: Font.DemiBold
                        font.pixelSize: 15
                        font.letterSpacing: 2.5
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 2
                        color: "#2F6FED"
                        visible: tabItem.active
                    }
                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.tab = tabItem.modelData.id
                    }
                }
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: "#1E2A40"
            z: -1
        }
    }

    // ── Recordings ───────────────────────────────────────────

    Item {
        id: videosPage
        visible: win.tab === "videos"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }

        Column {
            visible: win.videos.length === 0
            anchors.centerIn: parent
            width: Math.min(560, parent.width - 80)
            spacing: 12
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "INGA INSPELNINGAR ÄN"
                color: "#E6ECF5"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: 20
                font.letterSpacing: 3
            }
            Note {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Ha OBS igång och stridsloggen på (/combatlog i WoW). Varje raidboss blir en egen film, "
                      + "och en Mythic+-nyckel blir en film från start till slut. De hamnar här."
            }
        }

        // The list of videos, newest first
        ListView {
            id: list
            FastWheel { flick: list }
            visible: win.videos.length > 0
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 24; topMargin: 20; bottomMargin: 20 }
            width: 400
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: win.videos

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property bool active: win.selected && win.selected.path === modelData.path
                width: list.width - 16
                height: 84
                color: active ? "#12203A" : cardArea.containsMouse ? "#0E1420" : "transparent"
                border.width: active ? 2 : 1
                border.color: active ? "#2F6FED" : "#1E2A40"

                Rectangle {
                    id: thumbBox
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120
                    height: 68
                    color: "#0E1420"
                    Image {
                        anchors.fill: parent
                        source: card.modelData.thumb ? backend.fileUrl(card.modelData.thumb) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Column {
                    anchors { left: thumbBox.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    Row {
                        spacing: 8
                        width: parent.width
                        Text {
                            width: Math.min(implicitWidth, parent.width - tag.width - 8)
                            text: win.title(card.modelData)
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            id: tag
                            width: tagText.implicitWidth + 12
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            color: "transparent"
                            border.width: 1
                            border.color: win.resultColor(card.modelData)
                            Text {
                                id: tagText
                                anchors.centerIn: parent
                                text: win.resultText(card.modelData)
                                color: win.resultColor(card.modelData)
                                font.family: "Chakra Petch"
                                font.weight: Font.Bold
                                font.pixelSize: 11
                                font.letterSpacing: 1
                            }
                        }
                    }
                    Text {
                        text: card.modelData.difficulty + " · " + win.when(card.modelData.started)
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                    Text {
                        text: win.clock(card.modelData.fight) + " strid · " + win.size(card.modelData.size)
                              + (card.modelData.keep ? " · sparad" : "") + (card.modelData.wcl ? " · WCL" : "")
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    id: cardArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.selected = card.modelData
                }
            }
        }
        FlatScrollBar { flick: list }

        // The player
        Item {
            id: playerPane
            visible: win.videos.length > 0 && !!win.selected
            anchors { left: list.right; leftMargin: 20; right: parent.right; rightMargin: 32; top: parent.top; topMargin: 20; bottom: parent.bottom; bottomMargin: 20 }

            readonly property var v: win.selected
            readonly property real dur: player.duration > 0 ? player.duration / 1000 : (v ? v.duration : 0)

            onVChanged: {
                player.stop();
                player.source = v ? backend.fileUrl(v.path) : "";
                player.activeAudioTrack = 0;
            }

            MediaPlayer {
                id: player
                videoOutput: video
                audioOutput: AudioOutput { id: audio; volume: 0.8 }
            }

            Rectangle {
                id: screen
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: Math.min(width * 9 / 16, parent.height - controls.height - info.height - 24)
                color: "#000000"
                border.width: 1
                border.color: "#1E2A40"
                VideoOutput {
                    id: video
                    anchors.fill: parent
                    anchors.margins: 1
                }
                Image { // the thumbnail until it plays
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: player.playbackState === MediaPlayer.StoppedState && playerPane.v && playerPane.v.thumb
                    source: playerPane.v && playerPane.v.thumb ? backend.fileUrl(playerPane.v.thumb) : ""
                    fillMode: Image.PreserveAspectFit
                }
                Rectangle { // big play mark
                    anchors.centerIn: parent
                    visible: player.playbackState !== MediaPlayer.PlayingState
                    width: 72
                    height: 72
                    color: "#C007090D"
                    border.width: 2
                    border.color: "#E6ECF5"
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.fillStyle = "#E6ECF5";
                            ctx.beginPath();
                            ctx.moveTo(28, 22);
                            ctx.lineTo(52, 36);
                            ctx.lineTo(28, 50);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
                    onDoubleClicked: win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen()
                }
            }

            // Timeline with the pull start and deaths
            Item {
                id: timeline
                anchors { left: parent.left; right: parent.right; top: screen.bottom; topMargin: 14 }
                height: 34

                Rectangle {
                    id: track
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    height: 8
                    color: "#1A2438"
                    Rectangle {
                        width: playerPane.dur > 0 ? parent.width * Math.min(1, player.position / 1000 / playerPane.dur) : 0
                        height: parent.height
                        color: "#2F6FED"
                    }
                }
                Repeater {
                    model: playerPane.v ? playerPane.v.markers : []
                    Rectangle {
                        id: mark
                        required property var modelData
                        x: playerPane.dur > 0 ? timeline.width * modelData.t / playerPane.dur - 1 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 24
                        color: modelData.kind === "death" ? "#E5534B" : "#8B98AD"
                        MouseArea {
                            id: markArea
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: player.position = Math.max(0, mark.modelData.t - 5) * 1000
                        }
                        Rectangle {
                            visible: markArea.containsMouse
                            y: -32
                            x: -width / 2
                            width: tipText.implicitWidth + 14
                            height: 24
                            color: "#0E1420"
                            border.width: 1
                            border.color: "#2A3852"
                            z: 5
                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: (mark.modelData.kind === "death" ? "☠ " : "") + mark.modelData.text + "  " + win.clock(mark.modelData.t)
                                color: "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
                Rectangle { // where the pull/key starts
                    visible: !!playerPane.v && playerPane.dur > 0
                    x: playerPane.v && playerPane.dur > 0 ? timeline.width * playerPane.v.fightStart / playerPane.dur - 1 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 30
                    color: "#E6ECF5"
                }
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    function seek(x) { player.position = Math.max(0, Math.min(1, x / width)) * playerPane.dur * 1000; }
                    onPressed: mouse => seek(mouse.x)
                    onPositionChanged: mouse => { if (pressed) seek(mouse.x); }
                }
            }

            Row {
                id: controls
                anchors { left: parent.left; right: parent.right; top: timeline.bottom; topMargin: 10 }
                spacing: 10
                height: 40

                FlatButton {
                    width: 110
                    primary: true
                    text: player.playbackState === MediaPlayer.PlayingState ? "Pausa" : "Spela"
                    onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120
                    text: win.clock(player.position / 1000) + " / " + win.clock(playerPane.dur)
                    color: "#E6ECF5"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 13
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: player.audioTracks.length > 1
                    text: "LJUD"
                    color: "#8B98AD"
                    font.family: "Chakra Petch"
                    font.weight: Font.DemiBold
                    font.pixelSize: 12
                    font.letterSpacing: 2
                }
                Repeater {
                    model: player.audioTracks.length > 1 ? Math.min(player.audioTracks.length, 3) : 0
                    Choice {
                        required property int index
                        width: 92
                        height: 40
                        text: (playerPane.v && playerPane.v.tracks ? playerPane.v.tracks[index] : "Spår " + (index + 1))
                        chosen: player.activeAudioTrack === index
                        onPicked: player.activeAudioTrack = index
                    }
                }
            }

            Item {
                id: info
                anchors { left: parent.left; right: parent.right; top: controls.bottom; topMargin: 18 }
                height: 120

                Column {
                    anchors { left: parent.left; right: actions.left; rightMargin: 20 }
                    spacing: 6
                    Text {
                        width: parent.width
                        text: playerPane.v ? win.title(playerPane.v) + " – " + playerPane.v.difficulty : ""
                        color: "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: 20
                        elide: Text.ElideRight
                    }
                    Note {
                        width: parent.width
                        text: {
                            const v = playerPane.v;
                            if (!v)
                                return "";
                            const deaths = v.markers.filter(m => m.kind === "death");
                            const pct = v.wcl && v.result === "wipe" && v.wcl.bossPercentage !== null && v.wcl.bossPercentage !== undefined
                                ? " på " + Math.round(v.wcl.bossPercentage) + " %" : "";
                            return win.when(v.started) + " · " + win.resultText(v).toLowerCase() + pct + " efter " + win.clock(v.fight)
                                + " · " + (deaths.length ? deaths.length + " dödsfall (röda streck – klicka för att hoppa dit)" : "inga dödsfall")
                                + "";
                        }
                    }
                }
                Row {
                    id: actions
                    anchors.right: parent.right
                    spacing: 10
                    FlatButton {
                        visible: !!(playerPane.v && (playerPane.v.wcl || backend.wclConfigured))
                        primary: !!(playerPane.v && playerPane.v.wcl)
                        enabledState: !win.wclBusy
                        text: playerPane.v && playerPane.v.wcl ? "Öppna i Warcraft Logs" : win.wclBusy ? "Söker …" : "Sök i Warcraft Logs"
                        onClicked: playerPane.v.wcl ? backend.openUrl(playerPane.v.wcl.url) : backend.wclFind(playerPane.v.path)
                    }
                    FlatButton {
                        text: playerPane.v && playerPane.v.keep ? "Sparas för alltid ✓" : "Spara för alltid"
                        onClicked: {
                            const p = playerPane.v.path, k = !playerPane.v.keep;
                            backend.setKeep(p, k);
                            win.selected = win.videos.find(v => v.path === p) || null;
                        }
                    }
                    FlatButton {
                        text: "Öppna i annat program"
                        onClicked: { player.pause(); backend.openExternal(playerPane.v.path); }
                    }
                    FlatButton {
                        danger: true
                        text: "Ta bort"
                        onClicked: { player.stop(); player.source = ""; backend.removeVideo(playerPane.v.path); }
                    }
                }
            }
        }
    }

    // ── Settings ─────────────────────────────────────────────

    Flickable {
        id: settingsView
        FastWheel { flick: settingsView }
        visible: win.tab === "settings"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        contentHeight: settingsCol.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: settingsCol
            x: 40
            y: 30
            width: settingsView.width - 80
            spacing: 14

            SectionTitle { text: "VAR FILMERNA SPARAS" }
            Row {
                spacing: 12
                Rectangle {
                    width: Math.min(620, settingsCol.width - 360)
                    height: 40
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#2A3852"
                    Text {
                        anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        text: win.cfg.folder
                        color: "#E6ECF5"
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 13
                        elide: Text.ElideMiddle
                    }
                }
                FlatButton { text: "Välj mapp …"; onClicked: backend.chooseFolder() }
                FlatButton { text: "Öppna mappen"; onClicked: backend.openFolder() }
            }
            Note {
                width: Math.min(820, parent.width)
                text: "En raidboss blir 30–100 MB per minut beroende på bilder per sekund och codec. Välj en disk med gott om plats."
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "BILDER PER SEKUND" }
            Row {
                spacing: 12
                Repeater {
                    model: [{ "fps": 60, "sub": "Mjukast – som du ser spelet" }, { "fps": 30, "sub": "Hälften så stora filer" }]
                    Choice {
                        required property var modelData
                        text: modelData.fps + " fps"
                        sub: modelData.sub
                        chosen: win.cfg.fps === modelData.fps
                        onPicked: win.set("fps", modelData.fps)
                    }
                }
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "KODARE" }
            Flow {
                width: settingsCol.width
                spacing: 12
                Repeater {
                    model: [{ "id": "h264", "name": "NVENC H.264", "sub": "Grafikkortet · spelas upp överallt" },
                            { "id": "hevc", "name": "NVENC HEVC", "sub": "Grafikkortet · mindre filer" },
                            { "id": "av1", "name": "NVENC AV1", "sub": "Grafikkortet · minst filer, RTX 40xx+" },
                            { "id": "x264", "name": "x264", "sub": "Processorn · tar kraft från spelet" }]
                    Choice {
                        required property var modelData
                        readonly property bool works: !win.enc.known || !!win.enc.codecs[modelData.id]
                        width: 240
                        text: modelData.name
                        sub: works ? modelData.sub : (win.enc.hardware ? "Grafikkortet klarar inte AV1" : "Kräver ett Nvidia-kort")
                        enabledState: works
                        chosen: win.cfg.codec === modelData.id
                        onPicked: win.set("codec", modelData.id)
                    }
                }
            }
            Note {
                width: Math.min(820, parent.width)
                text: (win.enc.hardware ? "NVENC = grafikkortets egen videokrets – spelet märker knappt något. "
                                        : "Inget Nvidia-kort hittat – OBS spelar in med processorn (x264). ")
                      + "Byter du kodare startas OBS om (dolt) före nästa inspelning."
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "KVALITET" }
            Row {
                spacing: 12
                Repeater {
                    model: [{ "id": "high", "name": "Hög" }, { "id": "normal", "name": "Normal" }, { "id": "small", "name": "Liten" }]
                    Choice {
                        required property var modelData
                        // MB per minute, as recorder.encoder_settings counts it (video + 3 audio tracks)
                        readonly property real mb: ({ high: 25, normal: 10, small: 5 })[modelData.id]
                            * (win.cfg.codec === "h264" || win.cfg.codec === "x264" ? 1.5 : 1)
                            * (win.cfg.fps <= 30 ? 0.7 : 1) * 7.5 + 3.6
                        text: modelData.name
                        sub: "≈ " + Math.round(mb / 5) * 5 + " MB per minut"
                        chosen: (win.cfg.quality || "normal") === modelData.id
                        onPicked: win.set("quality", modelData.id)
                    }
                }
            }
            Note {
                width: Math.min(820, parent.width)
                text: "Normal räcker gott för WoW. Hög om du vill klippa ihop filmer i efterhand, Liten om disken är liten. "
                      + "Storleken är det mesta – en lugn stund blir mindre."
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "LJUD" }
            Item {
                width: Math.min(820, settingsCol.width)
                height: 54
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        text: "Min mikrofon"
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.Medium
                        font.pixelSize: 15
                    }
                    Note { text: "Din röst på spåren Allt och Discord – med brusreducering, så att tangentbordet hörs mindre." }
                }
                ToggleSwitch {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    on: win.cfg.mic !== false
                    onToggled: win.set("mic", win.cfg.mic === false)
                }
            }
            Text {
                topPadding: 8
                text: "WoW-ljudet i filmen"
                color: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.weight: Font.Medium
                font.pixelSize: 15
            }
            Row {
                spacing: 12
                Repeater {
                    model: [{ "db": 0, "name": "Som i spelet" }, { "db": 6, "name": "+6 dB" }, { "db": 12, "name": "+12 dB" }, { "db": 18, "name": "+18 dB" }]
                    Choice {
                        required property var modelData
                        width: 150
                        text: modelData.name
                        chosen: (win.cfg.gameBoost === undefined ? 12 : win.cfg.gameBoost) === modelData.db
                        onPicked: win.set("gameBoost", modelData.db)
                    }
                }
            }
            Note {
                width: Math.min(820, parent.width)
                text: "WoW spelar ofta svagt bredvid Discord. Förstärkningen gäller bara filmen – en spärr ser till att det aldrig skär sig."
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "VAD SOM SPELAS IN" }
            Repeater {
                model: [{ "key": "raid", "name": "Raidbossar", "sub": "Varje försök blir en egen film – kill eller wipe." },
                        { "key": "mplus", "name": "Mythic+", "sub": "Hela nyckeln, från start till slut." },
                        { "key": "autoStartObs", "name": "Starta OBS när WoW startar", "sub": "OBS lägger sig dolt i systemfältet." }]
                Item {
                    required property var modelData
                    width: Math.min(820, settingsCol.width)
                    height: 54
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            text: modelData.name
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.Medium
                            font.pixelSize: 15
                        }
                        Note { text: modelData.sub }
                    }
                    ToggleSwitch {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        on: !!win.cfg[modelData.key]
                        onToggled: win.set(modelData.key, !win.cfg[modelData.key])
                    }
                }
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "HUR MYCKET PLATS FILMERNA FÅR TA" }
            Row {
                spacing: 12
                Repeater {
                    model: [50, 100, 200, 500]
                    Choice {
                        required property var modelData
                        width: 120
                        text: modelData + " GB"
                        chosen: win.cfg.maxGB === modelData
                        onPicked: win.set("maxGB", modelData)
                    }
                }
            }
            Note {
                width: Math.min(820, parent.width)
                text: "När gränsen nås tas de äldsta filmerna bort – inte de du sparat för alltid."
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "WARCRAFT LOGS" }
            Note {
                width: Math.min(820, parent.width)
                text: backend.wclConfigured
                    ? "Kopplat. När en strid laddats upp till Warcraft Logs (med Archon) får filmen en knapp till rätt försök – "
                      + "GoblinRecorder letar var 5:e minut under ett dygn. Bara publika loggar hittas."
                    : "Koppla filmerna till dina loggar på Warcraft Logs. Skapa en gratis API-klient en gång: "
                      + "tryck på knappen, logga in, Create Client, skriv ett namn (t.ex. GoblinRecorder) och en "
                      + "Redirect URL (t.ex. http://localhost) och lämna Public Client av. Klistra sedan in Client ID och Client Secret här."
            }
            Row {
                visible: !backend.wclConfigured
                spacing: 12
                FlatButton { text: "Skapa API-klient …"; onClicked: backend.openWclClients() }
                FlatField { id: wclId; width: 260; hint: "Client ID" }
                FlatField { id: wclSecret; width: 260; hint: "Client Secret"; echoMode: TextInput.Password }
                FlatButton {
                    primary: true
                    enabledState: wclId.text.length > 10 && wclSecret.text.length > 10 && !win.wclBusy
                    text: win.wclBusy ? "Provar …" : "Spara"
                    onClicked: backend.setWcl(wclId.text, wclSecret.text)
                }
            }
            FlatButton {
                visible: backend.wclConfigured
                text: "Koppla bort Warcraft Logs"
                onClicked: backend.forgetWcl()
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "LJUDSPÅR" }
            Note {
                width: Math.min(820, parent.width)
                text: "Filmerna har tre ljudspår: Allt, bara WoW och Discord (med din röst) – välj under filmen."
            }
        }
    }
    FlatScrollBar { flick: settingsView }

    // Short messages at the bottom
    Rectangle {
        visible: win.note !== ""
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 24 }
        width: noteText.implicitWidth + 40
        height: 42
        color: "#12203A"
        border.width: 1
        border.color: "#2F6FED"
        z: 10
        Text {
            id: noteText
            anchors.centerIn: parent
            text: win.note
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: 14
        }
    }
}
