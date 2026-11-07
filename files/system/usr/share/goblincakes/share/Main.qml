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
    visible: !chatOnly   // goblin-share --chat: only the chat window
    title: "GoblinShare"
    color: "#07090D"

    readonly property var st: JSON.parse(backend.status)
    readonly property var staged: JSON.parse(backend.staged)
    readonly property var peers: st.peers || []
    readonly property var requests: st.requests || []
    readonly property var transfers: st.transfers || []
    readonly property var history: (st.history || []).filter(h => h.kind !== "text")   // messages: the chats
    readonly property var orders: st.orders || []   // orders to Kakan here (3 Nov)
    readonly property var chats: st.chats || {}     // per device: unread messages (the Text button)
    readonly property var ssh: st.ssh || {}         // the terminal (4 Nov): allowed here, paired, asks
    property var chatWindows: ({})
    function openChat(fp, alias) {
        let w = chatWindows[fp];
        if (!w) {
            w = chatComp.createObject(null, { fingerprint: fp, fallbackAlias: alias || "" });
            chatWindows[fp] = w;   // kept and hidden when closed, never destroyed mid-click
        }
        w.show();
    }
    Component { id: chatComp; ChatWindow {} }
    property string tab: "devices" // devices | history | settings
    property string note: ""
    property var textTo: null       // the device a message is being written to
    property bool ordering: false   // … or an order to its Kakan
    property var codeTo: null       // Terminal: the computer whose help code is being typed (4 Nov)
    property string codeWhy: ""     // … and why the last code didn't work
    readonly property var help: (st.ssh || {}).help || null   // Be om hjälp here: the code / who is in
    function mmss(n) { return Math.floor(n / 60) + ":" + ("0" + (n % 60)).slice(-2) }
    // A big (maximized) window: everything bigger instead of small text spread out – as GoblinRecorder
    readonly property real zoom: Math.max(1, Math.min(1.6, Math.min(width / 1080, height / 720)))

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

    Shortcut { sequence: "Esc"; onActivated: win.codeTo ? (win.codeTo = null) : win.textTo ? (win.textTo = null) : win.close() }
    function sendWritten() {
        if (win.ordering) backend.sendOrder(win.textTo.fingerprint, textEdit.text);
        else backend.sendText(win.textTo.fingerprint, textEdit.text);
        win.textTo = null;
    }
    Connections {
        target: backend
        function onMessage(text) { if (win.active) { win.note = text; noteTimer.restart(); } }
        function onChatRequested(fp) { win.openChat(fp, ""); }
        function onAskCode(fp, alias) { win.codeWhy = ""; win.codeTo = { "fingerprint": fp, "alias": alias }; codeField.text = ""; codeField.field.forceActiveFocus(); }
        function onCodeResult(fp, ok, why) { if (ok) win.codeTo = null; else if (win.codeTo) { win.codeWhy = why; codeField.text = ""; } }
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

    // The chat with one device (Text on its card, the notification's "Öppna chatten" – 3 Nov):
    // its own small window, messages from the service's chats.json (backend.chat), polled while open.
    component ChatWindow: Window {
        id: cw
        property string fingerprint
        property string fallbackAlias
        readonly property var st: JSON.parse(backend.status)
        readonly property var peer: (st.peers || []).find(p => p.fingerprint === fingerprint) || null
        readonly property string alias: peer ? peer.alias : (((st.chats || {})[fingerprint] || {}).alias || fallbackAlias || "Okänd")
        readonly property bool phone: !!peer && !peer.goblincakes
        readonly property color tone: peer && peer.goblincakes ? (peer.accent || accent.color) : "#8B98AD"
        property var messages: []
        property string raw: ""
        property string note: ""
        width: 460
        height: 640
        minimumWidth: 360
        minimumHeight: 420
        title: alias + " – GoblinShare"
        color: "#07090D"

        function refresh() {
            const text = backend.chat(fingerprint, cw.visible && cw.active);
            if (text === raw) return;
            const atEnd = list.nearEnd() || !messages.length;
            const grew = JSON.parse(text);
            const mine = grew.length > messages.length && grew[grew.length - 1].dir === "out";
            const y = list.contentY;
            raw = text;
            messages = grew;   // a new model: the view resets and lays the bubbles out afterwards
            if (atEnd || mine) list.follow();
            else list.keepAt(y);
        }
        function show() {
            visible = true;
            raise();
            requestActivate();
            refresh();
            list.follow();
            input.forceActiveFocus();
        }
        function send() {
            const t = input.text;
            if (!t.trim()) return;
            backend.sendText(fingerprint, t);
            input.text = "";
            refresh();
        }
        function when(t) {
            const d = new Date(t * 1000), now = new Date();
            const hm = ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
            if (d.toDateString() === now.toDateString()) return hm;
            const y = new Date(now.getTime() - 86400000);
            if (d.toDateString() === y.toDateString()) return "i går " + hm;
            return d.getDate() + "/" + (d.getMonth() + 1) + " " + hm;
        }
        // Plain text with clickable links (StyledText: only <a> and <br> from us)
        function linked(t, color) {
            const esc = t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
            const a = color ? '<a href="$1" style="color:' + color + '">$1</a>' : '<a href="$1">$1</a>';
            return esc.replace(/(https?:\/\/[^\s<]+[^\s<.,;:!?)"'])/g, a).replace(/\n/g, "<br>");
        }

        Timer { interval: 700; repeat: true; running: cw.visible; onTriggered: cw.refresh() }
        onActiveChanged: if (active) refresh()
        Timer { id: cwNoteTimer; interval: 3000; onTriggered: cw.note = "" }
        Connections {
            target: backend
            function onMessage(text) { if (cw.active) { cw.note = text; cwNoteTimer.restart(); } }
        }
        Shortcut { sequence: "Esc"; onActivated: cw.close() }

        Rectangle { // the device's colour
            id: strip
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 4
            color: cw.tone
        }
        Item {
            id: cwHead
            anchors { left: parent.left; right: parent.right; top: strip.bottom }
            height: 76
            Row {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                spacing: 12
                DeviceGlyph { anchors.verticalCenter: parent.verticalCenter; kind: cw.peer ? cw.peer.type : "desktop"; tone: cw.tone }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        width: cw.width - 20 - 34 - 12 - 150
                        text: cw.alias
                        color: "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.DemiBold
                        font.pixelSize: 18
                        elide: Text.ElideRight
                    }
                    Text {
                        text: !cw.peer ? "Syns inte i nätverket just nu" : cw.phone ? "Telefon – kan bara ta emot" : "GOBLINCAKES"
                        color: !cw.peer ? "#5C6880" : cw.phone ? "#8B98AD" : cw.tone
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                }
            }
            FlatButton {
                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                small: true
                danger: true
                visible: cw.messages.length > 0
                text: "Rensa chatten"
                onClicked: Qt.callLater(() => { backend.chatClear(cw.fingerprint); cw.refresh(); })
            }
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: "#1A2438" }
        }

        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: cwHead.bottom; bottom: writeBox.top; bottomMargin: 12 }
            topMargin: 16
            bottomMargin: 4
            leftMargin: 16
            rightMargin: 20
            spacing: 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: cw.messages
            // New messages at the bottom (4 Nov, the user: they ended up below the view): the new
            // model resets the view and the bubbles' heights are known only once laid out, so for a
            // moment after a change the view goes to the end (or back where the user was reading).
            property real holdY: NaN
            function endY() { return Math.max(originY - topMargin, originY + contentHeight + bottomMargin - height); }
            function nearEnd() { return contentY >= endY() - 40; }
            function follow() { holdY = NaN; settleNow(); settle.restart(); }
            function keepAt(y) { holdY = y; contentY = y; settle.restart(); }
            function settleNow() {
                if (isNaN(holdY)) { positionViewAtEnd(); contentY = endY(); }   // the bubbles are made, then the exact end with the margin
                else contentY = holdY;
            }
            Timer { id: settle; interval: 400; onTriggered: list.settleNow() }
            onContentHeightChanged: if (settle.running) settleNow()
            onContentYChanged: if (settle.running && !isNaN(holdY) && contentY !== holdY) Qt.callLater(settleNow)
            FastWheel { flick: list }
            header: Note {
                visible: !cw.messages.length
                width: list.width - 36
                height: visible ? implicitHeight + 16 : 0
                horizontalAlignment: Text.AlignHCenter
                text: "Inga meddelanden än. Skriv nedan – Enter skickar, Shift+Enter ger ny rad."
            }
            delegate: Item {
                id: m
                required property var modelData
                readonly property bool out: modelData.dir === "out"
                readonly property bool failed: out && modelData.state !== "klart" && modelData.state !== "skickar"
                width: list.width - list.leftMargin - list.rightMargin
                height: bubble.height + stamp.height + 4
                Rectangle {
                    id: bubble
                    anchors { right: m.out ? parent.right : undefined; left: m.out ? undefined : parent.left }
                    width: Math.min(m.width * 0.8, body.implicitWidth + 28)
                    height: body.height + 20
                    color: m.out ? (m.failed ? "#3A1418" : accent.color) : "#0E1420"
                    border.width: m.out && !m.failed ? 0 : 1
                    border.color: m.failed ? accent.error : bubbleArea.containsMouse ? "#2A3852" : "#1E2A40"
                    opacity: m.modelData.state === "skickar" ? 0.7 : 1
                    MouseArea { // click on the edge = copy all (the text itself: see below)
                        id: bubbleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.copyText(m.modelData.text)
                    }
                    Text { // only measures: the bubble's width as before (TextEdit has no unwrapped width)
                        id: measure
                        visible: false
                        width: Math.min(m.width * 0.8 - 28, implicitWidth)
                        text: body.text
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        font: body.font
                    }
                    // The user (8 Nov): mark part of a message instead of copying all of it. Drag = select,
                    // the marked text is copied when the mouse stops (and Ctrl+C); a click = the whole message
                    // as before; links still open with a click.
                    TextEdit {
                        id: body
                        x: 14
                        y: 10
                        width: measure.width
                        text: cw.linked(m.modelData.text, m.out && !m.failed ? accent.on : accent.text)
                        textFormat: TextEdit.RichText
                        wrapMode: TextEdit.Wrap
                        readOnly: true
                        selectByMouse: true
                        persistentSelection: false
                        color: m.out && !m.failed ? accent.on : "#E6ECF5"
                        selectionColor: m.out && !m.failed ? "#0B1018" : accent.color
                        selectedTextColor: m.out && !m.failed ? "#E6ECF5" : accent.on
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        onLinkActivated: link => Qt.openUrlExternally(link)
                        onSelectedTextChanged: if (selectedText !== "") copySel.restart()
                        Timer { id: copySel; interval: 350; onTriggered: if (body.selectedText !== "") backend.copyText(body.selectedText) }
                        TapHandler {
                            onTapped: if (body.selectedText === "" && body.hoveredLink === "") backend.copyText(m.modelData.text)
                        }
                        HoverHandler { cursorShape: body.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor }
                    }
                }
                Text {
                    id: stamp
                    anchors { top: bubble.bottom; topMargin: 4; right: m.out ? parent.right : undefined; left: m.out ? undefined : parent.left }
                    text: cw.when(m.modelData.t) + (!m.out ? "" : m.modelData.state === "skickar" ? " · skickar …"
                          : m.failed ? " · ✗ " + (m.modelData.why || "skickades inte") : " · ✓")
                    color: m.failed ? accent.errorBright : "#5C6880"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 11
                }
            }
        }
        FlatScrollBar { flick: list }

        Rectangle {
            id: writeBox
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
            height: Math.min(140, Math.max(46, input.contentHeight + 24))
            color: "#0B1018"
            border.width: 1
            border.color: input.activeFocus ? accent.color : "#2A3852"
            Flickable {
                id: inputFlick
                anchors { left: parent.left; leftMargin: 14; right: sendBtn.left; rightMargin: 10; top: parent.top; topMargin: 12; bottom: parent.bottom; bottomMargin: 12 }
                contentHeight: input.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                FastWheel { flick: inputFlick }
                TextEdit {
                    id: input
                    width: inputFlick.width
                    color: "#E6ECF5"
                    selectionColor: accent.color
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    onCursorRectangleChanged: if (cursorRectangle.y + cursorRectangle.height > inputFlick.contentY + inputFlick.height)
                                                  inputFlick.contentY = cursorRectangle.y + cursorRectangle.height - inputFlick.height
                    Keys.onReturnPressed: e => {
                        if (e.modifiers & Qt.ShiftModifier) e.accepted = false;
                        else cw.send();
                    }
                    Keys.onEnterPressed: e => cw.send()
                }
                Text {
                    visible: !input.text && !input.activeFocus
                    text: cw.phone ? "Skriv till telefonen …" : "Skriv ett meddelande …"
                    color: "#5C6880"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                }
            }
            FlatButton {
                id: sendBtn
                anchors { right: parent.right; rightMargin: 8; bottom: parent.bottom; bottomMargin: 8 }
                small: true
                primary: true
                text: "Skicka"
                enabledState: input.text.trim().length > 0
                onClicked: cw.send()
            }
        }

        Rectangle { // a short note (copied, errors)
            visible: cw.note !== ""
            anchors { horizontalCenter: parent.horizontalCenter; bottom: writeBox.top; bottomMargin: 14 }
            width: cwNote.implicitWidth + 32
            height: 34
            color: "#12203A"
            border.width: 1
            border.color: accent.color
            z: 3
            Text { id: cwNote; anchors.centerIn: parent; text: cw.note; color: "#E6ECF5"; font.family: "IBM Plex Sans"; font.pixelSize: 13 }
        }
    }

    // Everything below is drawn at 1080×720 and scaled up with the window (win.zoom)
    Item {
        id: stage
        width: win.width / win.zoom
        height: win.height / win.zoom
        scale: win.zoom
        transformOrigin: Item.TopLeft

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
                FlatButton { // someone helps on this computer: a code to read out (4 Nov)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!win.st.running && !win.help
                    text: win.st.sshBusy ? "Slår på …" : "Be om hjälp"
                    enabledState: !win.st.sshBusy
                    onClicked: { win.tab = "devices"; backend.helpStart(); }
                }
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
            width: Math.min(620, stage.width - 80)
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
                      "Android) med den kostnadsfria appen LocalSend kan få filer härifrån.\n\n" +
                      "Bara andra GOBLINCAKES-datorer kan skicka hit – och inget tas emot utan att du säger ja " +
                      "(utom från datorer du själv litar på)."
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

                // Orders to Kakan here: Starta when it suits (3 Nov)
                Column {
                    visible: win.orders.length > 0
                    width: parent.width
                    spacing: 10
                    SectionTitle { text: "BESTÄLLNINGAR" }
                    Repeater {
                        model: win.orders
                        Rectangle {
                            id: ord
                            required property var modelData
                            readonly property bool busy: modelData.state === "pågår"
                            readonly property bool failed: modelData.state === "fel" || modelData.state === "ej skickad"
                            width: devCol.width
                            height: ordCol.height + 32
                            color: "#0E1420"
                            border.width: 1
                            border.color: ord.modelData.state === "väntar" ? accent.color : "#1E2A40"
                            Column {
                                id: ordCol
                                anchors { left: parent.left; leftMargin: 22; right: ordButtons.left; rightMargin: 20; top: parent.top; topMargin: 16 }
                                spacing: 6
                                Text {
                                    text: "FRÅN " + ord.modelData.alias.toUpperCase() + "  ·  " + win.when(ord.modelData.t)
                                    color: accent.text
                                    font.family: "Chakra Petch"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 13
                                    font.letterSpacing: 1
                                }
                                Text {
                                    width: parent.width
                                    text: ord.modelData.text
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 15
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                                Note {
                                    width: parent.width
                                    text: ord.busy ? (ord.modelData.via === "chatgpt"
                                            ? "ChatGPT-appen är öppen med beställningen – tryck Enter där. Bilden skickas när den är klar."
                                            : "Goblin AI jobbar på den …")
                                        : ord.failed ? (ord.modelData.why || ord.modelData.state)
                                        : "Väntar – välj vem som gör den när det passar"
                                          + (win.st.chatgpt ? " (ChatGPT ritar bättre bilder)" : "")
                                    color: ord.failed ? accent.errorBright : "#8B98AD"
                                }
                            }
                            Row {
                                id: ordButtons
                                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                                spacing: 10
                                FlatButton { visible: !ord.busy; text: "Ta bort"; onClicked: backend.forgetOrder(ord.modelData.id) }
                                FlatButton {
                                    visible: !ord.busy && ord.modelData.state === "ej skickad"
                                    primary: true
                                    text: "Skicka igen"
                                    onClicked: backend.startOrder(ord.modelData.id, "")
                                }
                                // Who does it (3 Nov, the user): the ChatGPT app for proper pictures, or Goblin AI here
                                FlatButton {
                                    visible: !ord.busy && ord.modelData.state !== "ej skickad" && !!win.st.chatgpt
                                    text: "ChatGPT"
                                    onClicked: backend.startOrder(ord.modelData.id, "chatgpt")
                                }
                                FlatButton {
                                    visible: !ord.busy && ord.modelData.state !== "ej skickad"
                                    primary: true
                                    text: "Goblin AI"
                                    onClicked: backend.startOrder(ord.modelData.id, "ai")
                                }
                            }
                        }
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

                // Be om hjälp here: the code to read out, then who is in (4 Nov)
                Rectangle {
                    visible: !!win.help
                    width: devCol.width
                    height: helpCol.height + 40
                    color: "#0E1420"
                    border.width: 1
                    border.color: accent.color
                    Column {
                        id: helpCol
                        anchors { left: parent.left; leftMargin: 22; right: helpButtons.left; rightMargin: 20; top: parent.top; topMargin: 20 }
                        spacing: 8
                        SectionTitle { text: !win.help ? "" : win.help.state === "kod" ? "BE OM HJÄLP" : "HJÄLP PÅGÅR" }
                        Text {
                            visible: !!win.help && win.help.state === "kod"
                            text: win.help ? win.help.code.slice(0, 3) + " " + win.help.code.slice(3) : ""
                            color: accent.text
                            font.family: "Chakra Petch"
                            font.weight: Font.Bold
                            font.pixelSize: 44
                            font.letterSpacing: 6
                        }
                        Text {
                            width: parent.width
                            text: !win.help ? "" : win.help.state === "kod"
                                  ? "Läs upp koden för den som ska hjälpa dig. Hen trycker Terminal på din ruta i GoblinShare och skriver in den."
                                  : win.help.state === "ansluter" ? win.help.alias + " loggar in …"
                                  : win.help.alias + " är inne i din dator sedan " + win.when(win.help.since)
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.Medium
                            font.pixelSize: 16
                            wrapMode: Text.Wrap
                        }
                        Note {
                            width: parent.width
                            text: !win.help ? "" : win.help.state === "kod"
                                  ? "Koden gäller i " + win.mmss(win.help.left) + " och bara en gång. Utan den kommer ingen in."
                                  : "Hen kan köra kommandon i en terminal här tills hen stänger den – sedan behövs en ny kod. Avsluta = ut direkt."
                        }
                    }
                    Row {
                        id: helpButtons
                        anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                        FlatButton {
                            danger: !!win.help && win.help.state !== "kod"
                            text: !!win.help && win.help.state === "kod" ? "Avbryt" : "Avsluta"
                            onClicked: backend.helpStop()
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
                                  "Telefoner: öppna appen LocalSend (App Store, Google Play) på samma wifi och tryck Leta igen – " +
                                  "de kan få filer härifrån. Gästnätverk i routern brukar stänga av att enheter ser varandra."
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
                            width: modelData.goblincakes ? 310 : 236 // room for Beställ (3 Nov)
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
                                    text: card.modelData.ip + (card.modelData.ago > 0 ? " · sedd för " + Math.round(card.modelData.ago / 60) + " min sedan" : "")
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
                                FlatButton {
                                    id: textBtn
                                    readonly property int unread: (win.chats[card.modelData.fingerprint] || {}).unread || 0
                                    small: true
                                    text: "Text"
                                    onClicked: { const fp = card.modelData.fingerprint, alias = card.modelData.alias; Qt.callLater(() => win.openChat(fp, alias)); }
                                    Rectangle { // new messages
                                        visible: textBtn.unread > 0
                                        anchors { right: parent.right; rightMargin: -7; top: parent.top; topMargin: -7 }
                                        width: Math.max(18, unreadText.implicitWidth + 8)
                                        height: 18
                                        color: accent.color
                                        Text {
                                            id: unreadText
                                            anchors.centerIn: parent
                                            text: textBtn.unread > 99 ? "99+" : textBtn.unread
                                            color: accent.on
                                            font.family: "IBM Plex Sans"
                                            font.weight: Font.Bold
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                                FlatButton { // an order to the other computer's Kakan (only GOBLINCAKES)
                                    small: true
                                    visible: card.modelData.goblincakes
                                    text: "Beställ"
                                    onClicked: { win.ordering = true; win.textTo = card.modelData; textEdit.text = ""; textEdit.forceActiveFocus(); }
                                }
                            }
                            Row { // trusted: taken without asking (only GOBLINCAKES computers can send here)
                        visible: card.modelData.goblincakes
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
                        visible: card.modelData.goblincakes
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 44
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.trust(card.modelData.fingerprint, !card.modelData.trusted)
                            }
                            FlatButton { // a terminal there (ssh) – asks that computer the first time (4 Nov)
                                visible: card.modelData.goblincakes
                                anchors { right: parent.right; rightMargin: 14; bottom: parent.bottom; bottomMargin: 10 }
                                small: true
                                enabledState: card.modelData.sshState !== "väntar"
                                text: card.modelData.sshState === "väntar" ? "Ansluter …" : "Terminal"
                                onClicked: { const fp = card.modelData.fingerprint; Qt.callLater(() => backend.terminal(fp)); }
                            }
                        }
                    }
                }
                Note {
                    visible: win.peers.length > 0
                    width: parent.width
                    color: "#5C6880"
                    text: "Dra filer från Dolphin till en ruta, eller högerklicka på filer i Dolphin → Skicka med GoblinShare. " +
                          "Telefoner syns bara när LocalSend-appen är öppen, och kan bara ta emot – bara GOBLINCAKES-datorer kan skicka hit."
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
                readonly property bool isText: modelData.kind === "text" || modelData.kind === "order"
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
                            text: win.when(h.modelData.t) + (h.modelData.kind === "order" ? " · beställning" : h.isText ? " · meddelande" : " · " + (h.modelData.count === 1 ? win.size(h.modelData.size)
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
                SectionTitle { text: "HJÄLP VIA TERMINAL" }
                Row {
                    spacing: 14
                    ToggleSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        on: !!win.ssh.allowed
                        enabledState: !win.st.sshBusy
                        onToggled: backend.setSshAllowed(!win.ssh.allowed)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.st.sshBusy ? "Ändrar … (skriv lösenordet)" : "Tillåt hjälp via terminal på den här datorn"
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                    }
                }
                Note {
                    width: parent.width
                    text: "När du behöver hjälp med datorn: tryck Be om hjälp (överst) och läs upp koden som visas. Den som hjälper " +
                          "dig trycker Terminal på din ruta och skriver in koden – sedan kan hen köra kommandon här så länge hens " +
                          "terminal är öppen. Varje gång behövs en ny kod; utan den kommer ingen in. Bara från hemnätverket, aldrig " +
                          "med lösenord och aldrig som administratör. Av = SSH stängs av igen."
                }
                Note {
                    visible: (win.ssh.paired || []).length > 0
                    width: parent.width
                    text: "Datorer du har hjälpt – medan din terminal till dem är öppen fungerar kommandot bredvid i vilken terminal " +
                          "som helst, också åt Claude Code:"
                }
                Repeater {
                    model: win.ssh.paired || []
                    Row {
                        id: pairRow
                        required property var modelData
                        spacing: 14
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200
                            text: pairRow.modelData.alias + (pairRow.modelData.here ? "" : "  (inte här nu)")
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 260
                            text: "ssh " + pairRow.modelData.host + " <kommando>"
                            color: accent.text
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        FlatButton { small: true; text: "Glöm"; onClicked: backend.sshForget(pairRow.modelData.fingerprint) }
                    }
                }

                Item { width: 1; height: 14 }
                SectionTitle { text: "TELEFONER OCH ANDRA DATORER" }
                Note {
                    width: parent.width
                    text: "GoblinShare talar samma språk som LocalSend (gratis, öppen källkod): med LocalSend på telefonen (App Store, " +
                          "Google Play) syns den här när appen är öppen, och du kan skicka filer och text dit. Det som LocalSend " +
                          "försöker skicka hit nekas direkt – bara andra GOBLINCAKES-datorer med GoblinShare kan skicka till dig. " +
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

        // ── Terminal: the code the other computer shows (4 Nov) ──

        Rectangle {
            anchors.fill: parent
            visible: !!win.codeTo
            color: "#C007090D"
            z: 11
            MouseArea { anchors.fill: parent; onClicked: win.codeTo = null }
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(520, stage.width - 80)
                height: codeCol.height + 48
                color: "#0E1420"
                border.width: 1
                border.color: "#1E2A40"
                MouseArea { anchors.fill: parent }
                Column {
                    id: codeCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                    spacing: 14
                    SectionTitle { text: "TERMINAL PÅ " + (win.codeTo ? win.codeTo.alias.toUpperCase() : "") }
                    Note {
                        width: parent.width
                        text: "Be " + (win.codeTo ? win.codeTo.alias : "") + " trycka Be om hjälp i GoblinShare och läsa upp koden som visas där."
                    }
                    FlatField {
                        id: codeField
                        width: 220
                        hint: "123 456"
                        field.font.family: "IBM Plex Mono"
                        field.font.pixelSize: 20
                        field.inputMethodHints: Qt.ImhDigitsOnly
                        onAccepted: if (win.codeTo && text.replace(/\D/g, "").length === 6) backend.connectWithCode(win.codeTo.fingerprint, text)
                    }
                    Note {
                        visible: win.codeWhy !== ""
                        width: parent.width
                        text: win.codeWhy
                        color: accent.errorBright
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 10
                        FlatButton { text: "Avbryt"; onClicked: win.codeTo = null }
                        FlatButton {
                            primary: true
                            text: win.codeTo && (win.peers.find(p => p.fingerprint === win.codeTo.fingerprint) || {}).sshState === "väntar" ? "Ansluter …" : "Anslut"
                            enabledState: codeField.text.replace(/\D/g, "").length === 6
                            onClicked: backend.connectWithCode(win.codeTo.fingerprint, codeField.text)
                        }
                    }
                }
            }
        }

        // ── Writing a message ────────────────────────────────────

        Rectangle {
            anchors.fill: parent
            visible: !!win.textTo
            color: "#C007090D"
            z: 10
            MouseArea { anchors.fill: parent; onClicked: win.textTo = null }
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(560, stage.width - 80)
                height: textCol.height + 48
                color: "#0E1420"
                border.width: 1
                border.color: "#1E2A40"
                MouseArea { anchors.fill: parent }
                Column {
                    id: textCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                    spacing: 14
                    SectionTitle { text: (win.ordering ? "BESTÄLLNING TILL " : "MEDDELANDE TILL ") + (win.textTo ? win.textTo.alias.toUpperCase() : "") }
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
                                        win.sendWritten();
                                    } else {
                                        e.accepted = false;
                                    }
                                }
                            }
                        }
                    }
                    Note {
                        text: win.ordering
                            ? "Vad ska Goblin AI på " + (win.textTo ? win.textTo.alias : "") + " göra? T.ex. \"en bild på en katt i rustning, tecknad\". "
                              + "Hen får en notis och startar den när det passar – bilden eller svaret kommer hit av sig själv. Ctrl+Enter skickar."
                            : "En länk, en adress, en kod – kommer fram som ett meddelande som kan kopieras. Ctrl+Enter skickar."
                        width: parent.width
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 10
                        FlatButton { text: "Avbryt"; onClicked: win.textTo = null }
                        FlatButton {
                            primary: true
                            text: "Skicka"
                            enabledState: textEdit.text.trim().length > 0
                            onClicked: win.sendWritten()
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
}
