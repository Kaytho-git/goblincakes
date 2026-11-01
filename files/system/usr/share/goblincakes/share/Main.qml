// GoblinShare – files and messages to the computers and phones on the same network, in the style of
// GOBLINCAKES Config. Backend: /usr/bin/goblin-share ("backend"). Pieces (buttons, switches, scroll bar …)
// are copies of the ones in config/Main.qml – change both.
import QtQuick
import QtQuick.Window

Window {
    id: win

    width: 1080
    height: 720
    minimumWidth: 800
    minimumHeight: 560
    visible: true
    title: "GoblinShare"
    color: "#07090D"

    readonly property var st: JSON.parse(backend.status)
    readonly property var staged: JSON.parse(backend.staged)
    readonly property var peers: st.peers || []
    readonly property var requests: st.requests || []
    readonly property var transfers: st.transfers || []
    readonly property var history: st.history || []
    property string tab: "devices" // devices | history | settings
    property string note: ""
    property var textTo: null       // the device a message is being written to

    function size(n) { return backend.size(String(n || 0)) }
    function plural(n, one, many) { return n + " " + (n === 1 ? one : many) }
    function when(t) {
        const d = new Date(t * 1000), now = new Date();
        const hm = ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
        if (d.toDateString() === now.toDateString()) return "i dag " + hm;
        const y = new Date(now.getTime() - 86400000);
        if (d.toDateString() === y.toDateString()) return "i går " + hm;
        return d.getDate() + "/" + (d.getMonth() + 1) + " " + hm;
    }
    function kindText(p) {
        if (p.goblincakes) return "GOBLINCAKES";
        const m = p.model || "";
        return (m ? m + " · " : "") + "LocalSend";
    }
    function stagedText() {
        if (!staged.length) return "";
        if (staged.length === 1) return staged[0].name;
        return plural(staged.length, "sak", "saker") + ": " + staged.slice(0, 3).map(s => s.name).join(", ")
               + (staged.length > 3 ? " …" : "");
    }

    Shortcut { sequence: "Esc"; onActivated: win.textTo ? (win.textTo = null) : win.close() }
    Connections {
        target: backend
        function onMessage(text) { win.note = text; noteTimer.restart(); }
    }
    Timer { id: noteTimer; interval: 6000; onTriggered: win.note = "" }

    // ── Pieces (same as GOBLINCAKES Config) ──────────────────

    component FastWheel: WheelHandler {
        required property Flickable flick
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
            event.accepted = true;
            for (let f = flick; f; ) {
                const top = f.originY, bottom = top + Math.max(0, f.contentHeight - f.height);
                const y = Math.max(top, Math.min(bottom, f.contentY - delta));
                if (y !== f.contentY) {
                    f.cancelFlick();
                    f.contentY = y;
                    return;
                }
                let p = f.parent;
                while (p && (p.cancelFlick === undefined || p.contentY === undefined))
                    p = p.parent;
                f = p;
            }
        }
    }

    component FlatField: Rectangle {
        property alias text: input.text
        property alias field: input
        signal edited()
        signal accepted()
        property string hint
        height: 40
        color: "#07090D"
        border.width: 1
        border.color: input.activeFocus ? accent.color : "#2A3852"
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            verticalAlignment: TextInput.AlignVCenter
            color: "#E6ECF5"
            selectionColor: accent.color
            font.family: "IBM Plex Sans"
            font.pixelSize: 14
            clip: true
            selectByMouse: true
            onTextEdited: parent.edited()
            onAccepted: parent.accepted()
        }
        Text {
            anchors { fill: input }
            verticalAlignment: Text.AlignVCenter
            visible: !input.text && !input.activeFocus
            text: parent.hint
            color: "#5C6880"
            font.family: "IBM Plex Sans"
            font.pixelSize: 14
            elide: Text.ElideRight
        }
    }

    component FlatButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        property bool danger: false
        property bool enabledState: true
        property bool small: false
        signal clicked()

        width: Math.max(small ? 60 : 96, label.implicitWidth + (small ? 22 : 32))
        height: small ? 28 : 34
        opacity: enabledState ? 1 : 0.4
        color: primary ? (area.containsMouse && enabledState ? accent.hover : accent.color)
                       : (area.containsMouse && enabledState ? (danger ? "#3A1418" : "#1A2438") : "transparent")
        border.width: primary ? 0 : 1
        border.color: danger && area.containsMouse ? accent.error : "#2A3852"

        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: btn.primary ? accent.on : "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.weight: Font.Medium
            font.pixelSize: btn.small ? 12 : 13
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
        color: on ? accent.color : "transparent"
        border.width: on ? 0 : 1
        border.color: "#2A3852"
        opacity: enabledState ? 1 : 0.35
        Rectangle {
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            x: sw.on ? parent.width - width - 4 : 4
            color: sw.on ? accent.on : "#8B98AD"
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: sw.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (sw.enabledState) sw.toggled()
        }
    }

    component CheckSquare: Rectangle {
        property bool checked
        width: 18
        height: 18
        color: checked ? accent.color : "transparent"
        border.width: checked ? 0 : 1
        border.color: "#2A3852"
        property color mark: accent.on
        Canvas {
            anchors.fill: parent
            visible: parent.checked
            property color mark: parent.mark
            onMarkChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = mark;
                ctx.lineWidth = 2.2;
                ctx.beginPath();
                ctx.moveTo(4.5, 9.5);
                ctx.lineTo(7.8, 12.8);
                ctx.lineTo(13.5, 5.8);
                ctx.stroke();
            }
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
        Rectangle { anchors.fill: parent; color: "#0E1420" }
        Rectangle {
            id: handle
            width: parent.width
            height: Math.max(32, bar.flick.visibleArea.heightRatio * bar.height)
            y: bar.flick.visibleArea.yPosition / Math.max(0.0001, 1 - bar.flick.visibleArea.heightRatio)
               * (bar.height - height)
            color: handleArea.pressed ? accent.color : handleArea.containsMouse ? "#8B98AD" : "#2A3852"
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

    // A computer or a phone, drawn flat (no font glyphs)
    component DeviceGlyph: Canvas {
        property string kind: "desktop"
        property color tone: "#8B98AD"
        width: 34
        height: 34
        onToneChanged: requestPaint()
        onKindChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.strokeStyle = tone;
            c.fillStyle = tone;
            c.lineWidth = 2.5;
            if (kind === "mobile") {
                c.strokeRect(10, 3, 14, 28);
                c.fillRect(15, 26, 4, 2);
            } else if (kind === "web") {
                c.beginPath();
                c.arc(17, 17, 13, 0, Math.PI * 2);
                c.moveTo(4, 17); c.lineTo(30, 17);
                c.moveTo(17, 4); c.bezierCurveTo(9, 10, 9, 24, 17, 30);
                c.moveTo(17, 4); c.bezierCurveTo(25, 10, 25, 24, 17, 30);
                c.stroke();
            } else {
                c.strokeRect(3, 5, 28, 19);
                c.fillRect(13, 26, 8, 2.5);
                c.fillRect(9, 29, 16, 2.5);
            }
        }
    }

    component ProgressLine: Rectangle {
        property real value: 0
        property color tone: accent.color
        height: 4
        color: "#1A2438"
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.value))
            height: parent.height
            color: parent.tone
            Behavior on width { NumberAnimation { duration: 250 } }
        }
    }

    // ── Header ───────────────────────────────────────────────

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 150

        Row {
            anchors { left: parent.left; leftMargin: 40; top: parent.top; topMargin: 26 }
            spacing: 20
            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: iconUrl
                sourceSize.width: 60
                sourceSize.height: 60
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    text: "GOBLINSHARE"
                    color: "#E6ECF5"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 30
                    font.letterSpacing: 4
                }
                Text {
                    width: Math.min(implicitWidth, header.width - 40 - 80 - onRow.width - 80)
                    text: !win.st.running ? (win.st.on || win.st.starting ? "Startar …" : "Avstängt – ingen på nätverket ser dig")
                        : win.st.error ? win.st.error
                        : "Andra ser dig som " + win.st.alias + (win.st.addresses && win.st.addresses.length
                          ? " · " + win.st.addresses.join(", ") : " · inget nätverk")
                    color: win.st.error ? accent.errorBright : "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                    elide: Text.ElideRight
                }
            }
        }

        Row {
            id: onRow
            anchors { right: parent.right; rightMargin: 40; top: parent.top; topMargin: 40 }
            spacing: 14
            FlatButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!win.st.running
                text: win.st.sweeping ? "Letar …" : "Leta igen"
                enabledState: !win.st.sweeping
                onClicked: backend.scan()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Synlig på nätverket"
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 13
                leftPadding: 10
            }
            ToggleSwitch {
                anchors.verticalCenter: parent.verticalCenter
                on: !!win.st.running || !!win.st.on
                onToggled: on ? backend.turnOff() : backend.turnOn()
            }
        }

        Row {
            anchors { left: parent.left; leftMargin: 40; bottom: parent.bottom }
            spacing: 32
            visible: !!win.st.running
            Repeater {
                model: [{ "id": "devices", "label": "ENHETER" + (win.peers.length ? " (" + win.peers.length + ")" : "") },
                        { "id": "history", "label": "HISTORIK" },
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
                        color: tabItem.active ? "#E6ECF5" : tabArea.containsMouse ? "#C9D3E3" : "#8B98AD"
                        font.family: "Chakra Petch"
                        font.weight: Font.DemiBold
                        font.pixelSize: 15
                        font.letterSpacing: 2
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 3
                        color: tabItem.active ? accent.color : "transparent"
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
        }
    }

    // ── Off: what it is and the button ───────────────────────

    Column {
        visible: !win.st.running
        anchors { top: header.bottom; topMargin: 60; horizontalCenter: parent.horizontalCenter }
        width: Math.min(620, win.width - 80)
        spacing: 18
        Text {
            text: "SKICKA FILER HEMMA"
            color: "#E6ECF5"
            font.family: "Chakra Petch"
            font.weight: Font.DemiBold
            font.pixelSize: 20
            font.letterSpacing: 2
        }
        Note {
            width: parent.width
            font.pixelSize: 15
            text: "GoblinShare skickar filer, mappar och meddelanden direkt mellan datorerna i huset – utan konto, " +
                  "utan internet och krypterat. Andra GOBLINCAKES-datorer syns av sig själva. Telefoner (iPhone och " +
                  "Android) och Windows-datorer når du med den kostnadsfria appen LocalSend – samma språk.\n\n" +
                  "Inget tas emot utan att du säger ja (utom från enheter du själv litar på)."
        }
        FlatButton {
            primary: true
            text: win.st.on || win.st.starting ? "Startar …" : "Slå på GoblinShare"
            enabledState: !(win.st.on || win.st.starting)
            onClicked: backend.turnOn()
        }
        Note {
            visible: !!win.st.on && !win.st.running
            width: parent.width
            text: "Startar den inte? Kolla: journalctl --user -u goblincakes-share"
        }
    }

    // ── Devices ──────────────────────────────────────────────

    Flickable {
        id: devFlick
        visible: !!win.st.running && win.tab === "devices"
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: devCol.height + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        FastWheel { flick: devFlick }

        Column {
            id: devCol
            x: 40
            y: 28
            width: devFlick.width - 80
            spacing: 22

            // Files from Dolphin / goblin share skicka, waiting for a device
            Rectangle {
                visible: win.staged.length > 0
                width: parent.width
                height: 64
                color: accent.dim
                border.width: 1
                border.color: accent.color
                Text {
                    anchors { left: parent.left; leftMargin: 20; right: stagedCancel.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    text: "Att skicka – " + win.stagedText() + ". Klicka på den som ska få " + (win.staged.length === 1 ? "den." : "dem.")
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                FlatButton {
                    id: stagedCancel
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    text: "Avbryt"
                    onClicked: backend.clearStaged()
                }
            }

            // Someone wants to send something
            Repeater {
                model: win.requests
                Rectangle {
                    id: req
                    required property var modelData
                    width: devCol.width
                    height: reqCol.height + 36
                    color: "#0E1420"
                    border.width: 1
                    border.color: accent.color
                    Column {
                        id: reqCol
                        anchors { left: parent.left; leftMargin: 22; right: reqButtons.left; rightMargin: 20; top: parent.top; topMargin: 18 }
                        spacing: 6
                        Text {
                            text: req.modelData.alias + " vill skicka " + (req.modelData.count === 1 ? req.modelData.files[0].name
                                  : win.plural(req.modelData.count, "fil", "filer")) + " (" + win.size(req.modelData.size) + ")"
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.Medium
                            font.pixelSize: 16
                            width: parent.width
                            elide: Text.ElideRight
                        }
                        Note {
                            width: parent.width
                            visible: req.modelData.count > 1
                            text: req.modelData.files.map(f => f.name).join(", ") + (req.modelData.count > req.modelData.files.length ? " …" : "")
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Note {
                            text: (req.modelData.model ? req.modelData.model + " · " : "") + "svara inom " + req.modelData.left + " s"
                            color: "#5C6880"
                        }
                    }
                    Row {
                        id: reqButtons
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        FlatButton { text: "Neka"; onClicked: backend.answer(req.modelData.id, false) }
                        FlatButton { primary: true; text: "Ta emot"; onClicked: backend.answer(req.modelData.id, true) }
                    }
                }
            }

            // Sending and receiving right now (and just finished)
            Column {
                visible: win.transfers.length > 0
                width: parent.width
                spacing: 10
                SectionTitle { text: "PÅGÅR" }
                Repeater {
                    model: win.transfers
                    Rectangle {
                        id: tr
                        required property var modelData
                        readonly property bool active: modelData.state === "skickar" || modelData.state === "tar emot"
                                                       || modelData.state === "väntar på svar"
                        readonly property bool failed: modelData.state === "fel" || modelData.state === "nekad"
                                                       || modelData.state === "avbruten"
                        width: devCol.width
                        height: 66
                        color: "#0B1018"
                        border.width: 1
                        border.color: "#1E2A40"
                        Column {
                            anchors { left: parent.left; leftMargin: 18; right: trButton.left; rightMargin: 18; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            Row {
                                width: parent.width
                                spacing: 10
                                Text {
                                    text: (tr.modelData.dir === "in" ? "Från " : "Till ") + tr.modelData.alias
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.weight: Font.Medium
                                    font.pixelSize: 14
                                }
                                Text {
                                    width: parent.width - x - stateText.width - 20
                                    text: tr.modelData.count > 1 ? win.plural(tr.modelData.count, "fil", "filer") : tr.modelData.name
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 14
                                    elide: Text.ElideMiddle
                                }
                                Text {
                                    id: stateText
                                    text: tr.modelData.why ? tr.modelData.why
                                        : tr.modelData.state === "väntar på svar" ? "väntar på att de tar emot …"
                                        : tr.active && tr.modelData.total ? win.size(tr.modelData.done) + " av " + win.size(tr.modelData.total)
                                        : tr.modelData.state
                                    color: tr.failed ? accent.errorBright : tr.modelData.state === "klart" ? "#3FB950" : "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 13
                                }
                            }
                            ProgressLine {
                                width: parent.width
                                value: tr.modelData.state === "klart" ? 1 : tr.modelData.total ? tr.modelData.done / tr.modelData.total : 0
                                tone: tr.failed ? accent.error : tr.modelData.state === "klart" ? "#3FB950" : accent.color
                            }
                        }
                        FlatButton {
                            id: trButton
                            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            small: true
                            visible: tr.active || (tr.modelData.dir === "in" && tr.modelData.state === "klart")
                            text: tr.active ? "Avbryt" : "Öppna mappen"
                            danger: tr.active
                            onClicked: tr.active ? backend.cancel(tr.modelData.id) : backend.openPath(tr.modelData.folder)
                        }
                    }
                }
            }

            SectionTitle { text: win.staged.length ? "VEM SKA FÅ " + (win.staged.length === 1 ? "DEN" : "DEM") + "?" : "PÅ NÄTVERKET" }

            // No one found yet
            Rectangle {
                visible: win.peers.length === 0
                width: parent.width
                height: emptyCol.height + 48
                color: "#0B1018"
                border.width: 1
                border.color: "#1E2A40"
                Column {
                    id: emptyCol
                    anchors { left: parent.left; right: parent.right; margins: 24; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    Text {
                        text: win.st.sweeping ? "Letar efter enheter …" : "Inga enheter hittade än"
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.Medium
                        font.pixelSize: 16
                    }
                    Note {
                        width: parent.width
                        text: "Andra GOBLINCAKES-datorer syns när GoblinShare är påslaget där (Config → Program → System). " +
                              "Telefoner och Windows: öppna appen LocalSend (App Store, Google Play, localsend.org) på samma wifi " +
                              "och tryck Leta igen. Gästnätverk i routern brukar stänga av att enheter ser varandra."
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 16
                Repeater {
                    model: win.peers
                    Rectangle {
                        id: card
                        required property var modelData
                        readonly property color tone: modelData.goblincakes ? (modelData.accent || "#2F6FED") : "#8B98AD"
                        readonly property bool hot: cardArea.containsMouse || drop.containsDrag
                        width: 236
                        height: 186
                        color: hot ? "#12203A" : "#0E1420"
                        border.width: drop.containsDrag || (win.staged.length && cardArea.containsMouse) ? 2 : 1
                        border.color: drop.containsDrag || (win.staged.length && cardArea.containsMouse) ? accent.color : "#1E2A40"

                        Rectangle { // the device's own accent colour (another GOBLINCAKES computer)
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            height: 4
                            color: card.modelData.goblincakes ? card.tone : "#1E2A40"
                        }
                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: win.staged.length ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (win.staged.length) backend.sendStaged(card.modelData.fingerprint)
                        }
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            keys: ["text/uri-list"]
                            onDropped: d => {
                                if (d.hasUrls) {
                                    backend.sendUrls(card.modelData.fingerprint, d.urls);
                                    d.acceptProposedAction();
                                }
                            }
                        }
                        Column {
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18; topMargin: 22 }
                            spacing: 6
                            Row {
                                spacing: 12
                                DeviceGlyph { kind: card.modelData.type; tone: card.tone }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        width: 236 - 36 - 34 - 12
                                        text: card.modelData.alias
                                        color: "#E6ECF5"
                                        font.family: "Chakra Petch"
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 17
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: 236 - 36 - 34 - 12
                                        text: win.kindText(card.modelData)
                                        color: card.modelData.goblincakes ? card.tone : "#8B98AD"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            Text {
                                topPadding: 4
                                text: card.modelData.ip + (card.modelData.ago > 180 ? " · sedd för " + Math.round(card.modelData.ago / 60) + " min sedan" : "")
                                color: "#5C6880"
                                font.family: "IBM Plex Mono"
                                font.pixelSize: 11
                            }
                        }
                        // Drop / click hint, or the buttons
                        Text {
                            visible: drop.containsDrag || win.staged.length > 0
                            anchors { left: parent.left; leftMargin: 18; bottom: parent.bottom; bottomMargin: 54 }
                            text: drop.containsDrag ? "Släpp för att skicka" : "Klicka för att skicka hit"
                            color: accent.text
                            font.family: "IBM Plex Sans"
                            font.weight: Font.Medium
                            font.pixelSize: 13
                        }
                        Row {
                            visible: !win.staged.length && !drop.containsDrag
                            anchors { left: parent.left; leftMargin: 18; bottom: parent.bottom; bottomMargin: 50 }
                            spacing: 8
                            FlatButton { small: true; text: "Filer"; onClicked: backend.sendFiles(card.modelData.fingerprint) }
                            FlatButton { small: true; text: "Mapp"; onClicked: backend.sendFolder(card.modelData.fingerprint) }
                            FlatButton { small: true; text: "Text"; onClicked: { win.textTo = card.modelData; textEdit.text = ""; textEdit.forceActiveFocus(); } }
                        }
                        Row { // trusted: taken without asking
                            anchors { left: parent.left; leftMargin: 18; bottom: parent.bottom; bottomMargin: 16 }
                            spacing: 8
                            CheckSquare { anchors.verticalCenter: parent.verticalCenter; checked: card.modelData.trusted }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Ta emot utan att fråga"
                                color: card.modelData.trusted ? "#E6ECF5" : "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                            }
                        }
                        MouseArea { // the trust row
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 44
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.trust(card.modelData.fingerprint, !card.modelData.trusted)
                        }
                    }
                }
            }
            Note {
                visible: win.peers.length > 0
                width: parent.width
                color: "#5C6880"
                text: "Dra filer från Dolphin till en ruta, eller högerklicka på filer i Dolphin → Skicka med GoblinShare. " +
                      "Saknas någon? Telefoner syns bara när LocalSend-appen är öppen."
            }
        }
    }
    FlatScrollBar { flick: devFlick }

    // ── History ──────────────────────────────────────────────

    ListView {
        id: histList
        visible: !!win.st.running && win.tab === "history"
        anchors { top: header.bottom; topMargin: 24; left: parent.left; leftMargin: 40; right: parent.right; rightMargin: 40; bottom: parent.bottom; bottomMargin: 20 }
        model: win.history
        spacing: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        FastWheel { flick: histList }
        header: Item {
            width: histList.width
            height: win.history.length ? 52 : 120
            Note {
                visible: !win.history.length
                anchors.verticalCenter: parent.verticalCenter
                text: "Inget skickat eller mottaget än."
                font.pixelSize: 15
            }
            Row {
                visible: win.history.length > 0
                anchors { right: parent.right; rightMargin: 12; top: parent.top }
                spacing: 10
                FlatButton { text: "Öppna mappen"; onClicked: backend.openPath(win.st.folder) }
                FlatButton { text: "Rensa historiken"; danger: true; onClicked: backend.clearHistory() }
            }
        }
        delegate: Rectangle {
            id: h
            required property var modelData
            readonly property bool isText: modelData.kind === "text"
            readonly property bool failed: modelData.state !== "klart"
            width: histList.width - 14
            height: hCol.height + 28
            color: "#0B1018"
            border.width: 1
            border.color: "#1E2A40"
            Column {
                id: hCol
                anchors { left: parent.left; leftMargin: 18; right: hButtons.left; rightMargin: 18; verticalCenter: parent.verticalCenter }
                spacing: 6
                Row {
                    spacing: 10
                    Text {
                        text: (h.modelData.dir === "in" ? "FRÅN " : "TILL ") + h.modelData.alias.toUpperCase()
                        color: h.modelData.dir === "in" ? accent.text : "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.DemiBold
                        font.pixelSize: 13
                        font.letterSpacing: 1
                    }
                    Text {
                        text: win.when(h.modelData.t) + (h.isText ? " · meddelande" : " · " + (h.modelData.count === 1 ? win.size(h.modelData.size)
                              : win.plural(h.modelData.count, "fil", "filer") + ", " + win.size(h.modelData.size)))
                              + (h.failed ? " · " + (h.modelData.why || h.modelData.state) : "")
                        color: h.failed ? accent.errorBright : "#5C6880"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                }
                Text {
                    width: parent.width
                    text: h.isText ? h.modelData.text : (h.modelData.files || []).join(", ")
                    color: "#C9D3E3"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    maximumLineCount: h.isText ? 6 : 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }
            Row {
                id: hButtons
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 8
                FlatButton {
                    small: true
                    visible: h.isText
                    text: "Kopiera"
                    onClicked: backend.copyText(h.modelData.text)
                }
                FlatButton {
                    small: true
                    visible: !h.isText && h.modelData.dir === "in" && (h.modelData.paths || []).length > 0
                    text: h.modelData.count === 1 ? "Öppna" : "Visa"
                    onClicked: h.modelData.count === 1 ? backend.openPath(h.modelData.paths[0]) : backend.showFile(h.modelData.paths[0])
                }
                FlatButton {
                    small: true
                    text: "Ta bort"
                    onClicked: backend.forget(h.modelData.t)
                }
            }
        }
    }
    FlatScrollBar { flick: histList }

    // ── Settings ─────────────────────────────────────────────

    Flickable {
        id: setFlick
        visible: !!win.st.running && win.tab === "settings"
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: setCol.height + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        FastWheel { flick: setFlick }
        Column {
            id: setCol
            x: 40
            y: 28
            width: Math.min(760, setFlick.width - 80)
            spacing: 14

            SectionTitle { text: "DITT NAMN" }
            Note { width: parent.width; text: "Det här ser de andra – på sina GOBLINCAKES-datorer och i LocalSend-appen." }
            Row {
                spacing: 10
                FlatField {
                    id: aliasField
                    width: 320
                    hint: win.st.alias || ""
                    Component.onCompleted: text = win.st.aliasSet ? win.st.alias : ""
                    onAccepted: backend.setAlias(text)
                }
                FlatButton { text: "Spara"; primary: true; onClicked: { backend.setAlias(aliasField.text); win.note = "Namnet sparat"; noteTimer.restart(); } }
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "MOTTAGNA FILER" }
            Note { width: parent.width; text: "Hamnar här. Mappar kommer med sina undermappar; en fil med samma namn som en som redan finns får (2) efter namnet." }
            Row {
                spacing: 10
                Rectangle {
                    width: Math.min(460, setCol.width - 260)
                    height: 34
                    color: "#07090D"
                    border.width: 1
                    border.color: "#2A3852"
                    Text {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: Text.AlignVCenter
                        text: win.st.folder || ""
                        color: "#C9D3E3"
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                    }
                }
                FlatButton { text: "Välj …"; onClicked: backend.chooseFolder() }
                FlatButton { visible: !!win.st.folderSet; text: "Standard"; onClicked: backend.resetFolder() }
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "BETRODDA ENHETER" }
            Note {
                width: parent.width
                text: "Från dem tas filer emot direkt, utan fråga. Kryssa i \"Ta emot utan att fråga\" på en enhet under Enheter."
            }
            Repeater {
                model: win.peers.filter(p => p.trusted).concat(win.st.trustedAway || [])
                Row {
                    id: trustRow
                    required property var modelData
                    spacing: 14
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 260
                        text: trustRow.modelData.alias + (trustRow.modelData.ip ? "" : "  (inte här nu)")
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                    FlatButton { small: true; text: "Sluta lita på"; onClicked: backend.trust(trustRow.modelData.fingerprint, false) }
                }
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "TELEFONER OCH ANDRA DATORER" }
            Note {
                width: parent.width
                text: "GoblinShare talar samma språk som LocalSend (gratis, öppen källkod): installera LocalSend från App Store eller " +
                      "Google Play – eller localsend.org för Windows och Mac – så syns enheten här när appen är öppen, och du syns i appen. " +
                      "Allt går direkt i hemnätverket, krypterat (HTTPS), aldrig via internet."
            }
            Note {
                width: parent.width
                color: "#5C6880"
                font.family: "IBM Plex Mono"
                font.pixelSize: 11
                text: "port " + win.st.port + " (TCP + UDP) · " + (win.st.protocol || "").toUpperCase() + " · fingeravtryck " +
                      (win.st.fingerprint || "").slice(0, 16) + "…"
            }
            Item { width: 1; height: 14 }
            FlatButton { text: "Stäng av GoblinShare"; danger: true; onClicked: backend.turnOff() }
        }
    }
    FlatScrollBar { flick: setFlick }

    // ── Writing a message ────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        visible: !!win.textTo
        color: "#C007090D"
        z: 10
        MouseArea { anchors.fill: parent; onClicked: win.textTo = null }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(560, win.width - 80)
            height: textCol.height + 48
            color: "#0E1420"
            border.width: 1
            border.color: "#1E2A40"
            MouseArea { anchors.fill: parent }
            Column {
                id: textCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                spacing: 14
                SectionTitle { text: "MEDDELANDE TILL " + (win.textTo ? win.textTo.alias.toUpperCase() : "") }
                Rectangle {
                    width: parent.width
                    height: 150
                    color: "#07090D"
                    border.width: 1
                    border.color: textEdit.activeFocus ? accent.color : "#2A3852"
                    Flickable {
                        id: textFlick
                        anchors { fill: parent; margins: 12 }
                        contentHeight: textEdit.contentHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        FastWheel { flick: textFlick }
                        TextEdit {
                            id: textEdit
                            width: textFlick.width
                            color: "#E6ECF5"
                            selectionColor: accent.color
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 14
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            Keys.onReturnPressed: e => {
                                if (e.modifiers & Qt.ControlModifier) {
                                    backend.sendText(win.textTo.fingerprint, text);
                                    win.textTo = null;
                                } else {
                                    e.accepted = false;
                                }
                            }
                        }
                    }
                }
                Note { text: "En länk, en adress, en kod – kommer fram som ett meddelande som kan kopieras. Ctrl+Enter skickar."; width: parent.width }
                Row {
                    anchors.right: parent.right
                    spacing: 10
                    FlatButton { text: "Avbryt"; onClicked: win.textTo = null }
                    FlatButton {
                        primary: true
                        text: "Skicka"
                        enabledState: textEdit.text.trim().length > 0
                        onClicked: { backend.sendText(win.textTo.fingerprint, textEdit.text); win.textTo = null; }
                    }
                }
            }
        }
    }

    // A short note at the bottom (copied, errors)
    Rectangle {
        visible: win.note !== ""
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 24 }
        width: noteText.implicitWidth + 40
        height: 40
        color: "#12203A"
        border.width: 1
        border.color: accent.color
        z: 11
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
