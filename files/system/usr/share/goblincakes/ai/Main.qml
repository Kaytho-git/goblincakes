// Goblin AI: chat with free AI services. Flat, square, in the GOBLINCAKES palette.
// Backend: /usr/bin/goblin-ai ("backend").
import QtQuick
import QtQuick.Window
import QtQuick.Dialogs

Window {
    id: win

    width: 1120
    height: 800
    minimumWidth: 760
    minimumHeight: 520
    visible: true
    title: "Goblin AI"
    color: "#07090D"

    property string view: backend.hasKeys ? "chat" : "settings"
    property string attachment: ""
    property var pendingSave: null // {index, seg} while the "save as" dialog is open

    readonly property var examples: [
        "Rätta stavningen i en fil",
        "Ge mig ett recept på kanelbullar",
        "Varför startar inte Steam?",
        "Hur mycket diskutrymme har jag kvar?"
    ]

    function send() {
        if (backend.busy || (input.text.trim() === "" && attachment === ""))
            return;
        backend.send(input.text, attachment);
        input.text = "";
        attachment = "";
    }

    function reload() {
        chatModel.clear();
        for (const m of JSON.parse(backend.messages))
            chatModel.append({ "msg": JSON.stringify(m) });
    }

    ListModel { id: chatModel }

    Component.onCompleted: reload()

    Connections {
        target: backend
        function onConversationChanged() {
            win.reload();
            win.view = "chat";
        }
        function onMessageAdded(json) {
            chatModel.append({ "msg": json });
            messagesView.positionViewAtEnd();
        }
        function onMessageUpdated(index, json) {
            chatModel.set(index, { "msg": json });
        }
        function onNotice(text) {
            toast.show(text);
        }
        function onRaiseWindow() {
            win.show();
            win.raise();
            win.requestActivate();
        }
        function onKeyTested(id, ok, message) {
            const r = Object.assign({}, win.keyResults);
            r[id] = message;
            win.keyResults = r;
        }
        function onLocalProgress(text, fraction) {
            win.localText = text;
            win.localFraction = fraction;
        }
        function onLocalDone(ok, message) {
            win.localText = message;
            win.localFraction = -1;
            win.localError = !ok;
        }
    }

    property var keyResults: ({})
    // Local AI (Ollama): status, places and suggestions from goblincakes-ollama
    readonly property var local: JSON.parse(backend.local || "{}")
    readonly property var localStatus: local.status || {}
    property string localPlace: ""
    property string localText: ""
    property real localFraction: -1
    property bool localError: false
    property bool localMoving: false
    property bool localRemoving: false
    function gb(n) { return (Math.round(n * 10) / 10).toString().replace(".", ",") + " GB"; }

    FileDialog {
        id: openDialog
        title: "Bifoga en textfil"
        onAccepted: win.attachment = selectedFile.toString()
    }

    FileDialog {
        id: saveDialog
        title: "Spara som"
        fileMode: FileDialog.SaveFile
        onAccepted: if (win.pendingSave) backend.saveFileAs(win.pendingSave.index, win.pendingSave.seg, selectedFile.toString())
    }

    DropArea {
        anchors.fill: parent
        onDropped: drop => {
            if (drop.hasUrls && drop.urls.length > 0) {
                win.attachment = drop.urls[0].toString();
                win.view = "chat";
            }
        }
    }

    // ── Pieces ───────────────────────────────────────────────

    // Mouse wheel: each notch moves the list a fixed step at once (Flickable's own wheel
    // handling only gives it a small push that slows down – sluggish on a real computer)
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

    component FlatButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        property bool enabledState: true
        property bool small: false
        signal clicked()

        width: Math.max(small ? 70 : 120, label.implicitWidth + (small ? 24 : 40))
        height: small ? 30 : 40
        opacity: enabledState ? 1 : 0.4
        color: primary ? (area.containsMouse && enabledState ? accent.hover : accent.color)
                       : (area.containsMouse && enabledState ? "#1A2438" : "transparent")
        border.width: primary ? 0 : 1
        border.color: "#2A3852"

        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: btn.primary ? accent.on : "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.weight: Font.Medium
            font.pixelSize: btn.small ? 13 : 14
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.enabledState) btn.clicked()
        }
    }

    component Label: Text {
        color: "#8B98AD"
        font.family: "Chakra Petch"
        font.weight: Font.DemiBold
        font.pixelSize: 12
        font.letterSpacing: 2
    }

    // Code shown in a dark box (commands, files, other code)
    component CodeBox: Rectangle {
        id: box
        property string code
        property int maxHeight: 280
        width: parent ? parent.width : 400
        height: Math.min(codeText.implicitHeight + 24, maxHeight)
        color: "#07090D"
        border.width: 1
        border.color: "#1A2438"
        clip: true
        Flickable {
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: codeText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            TextEdit {
                id: codeText
                width: parent.width
                text: box.code
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                color: "#E6ECF5"
                selectionColor: accent.color
                font.family: "IBM Plex Mono"
                font.pixelSize: 13
            }
        }
    }

    // ── Sidebar ──────────────────────────────────────────────

    Rectangle {
        id: sidebar
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 264
        color: "#0B1018"

        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 1
            color: "#1E2A40"
        }

        Row {
            id: brand
            anchors { left: parent.left; leftMargin: 22; top: parent.top; topMargin: 24 }
            spacing: 12
            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: logoUrl
                sourceSize.width: 36
                sourceSize.height: 36
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "GOBLIN AI"
                color: "#E6ECF5"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: 20
                font.letterSpacing: 3
            }
        }

        FlatButton {
            id: newButton
            anchors { left: parent.left; right: parent.right; margins: 18; top: brand.bottom; topMargin: 24 }
            width: parent.width - 36
            primary: true
            text: "+  Ny chatt"
            enabledState: !backend.busy
            onClicked: { backend.newConversation(); win.view = backend.hasKeys ? "chat" : "settings"; }
        }

        Label {
            id: recentLabel
            anchors { left: parent.left; leftMargin: 22; top: newButton.bottom; topMargin: 26 }
            text: "SENASTE"
        }

        ListView {
            id: convList
            FastWheel { flick: convList }
            anchors { left: parent.left; right: parent.right; top: recentLabel.bottom; topMargin: 10; bottom: settingsButton.top; bottomMargin: 12 }
            clip: true
            model: JSON.parse(backend.conversations)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: convItem
                required property var modelData
                readonly property bool active: modelData.id === backend.conversationId && win.view === "chat"
                width: convList.width
                height: 40
                color: convArea.containsMouse || active ? "#121B2B" : "transparent"

                Rectangle {
                    visible: convItem.active
                    width: 2
                    height: parent.height
                    color: accent.color
                }
                Text {
                    anchors { left: parent.left; leftMargin: 22; right: del.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: convItem.modelData.title
                    color: convItem.active ? "#E6ECF5" : "#B8C2D3"
                    elide: Text.ElideRight
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                }
                MouseArea {
                    id: convArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.openConversation(convItem.modelData.id)
                }
                Text {
                    id: del
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    visible: convArea.containsMouse || delArea.containsMouse
                    text: "×"
                    color: delArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                    font.pixelSize: 18
                    MouseArea {
                        id: delArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.deleteConversation(convItem.modelData.id)
                    }
                }
            }
        }

        FlatButton {
            id: settingsButton
            anchors { left: parent.left; right: parent.right; margins: 18; bottom: parent.bottom; bottomMargin: 20 }
            width: parent.width - 36
            text: "AI-tjänster"
            onClicked: win.view = "settings"
        }
    }

    // ── Chat ─────────────────────────────────────────────────

    Item {
        id: chatArea
        visible: win.view === "chat"
        anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }

        // Empty: welcome + examples
        Column {
            visible: chatModel.count === 0 && !backend.busy
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -60
            spacing: 18
            width: Math.min(560, parent.width - 80)

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: logoUrl
                sourceSize.width: 72
                sourceSize.height: 72
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "VAD KAN JAG HJÄLPA DIG MED?"
                color: "#E6ECF5"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: 24
                font.letterSpacing: 3
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Fråga vad du vill, be om hjälp med datorn, eller bifoga en textfil som ska rättas. Kommandon körs bara när du trycker Kör."
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 14
            }
            Flow {
                width: parent.width
                spacing: 10
                Repeater {
                    model: win.examples
                    FlatButton {
                        required property string modelData
                        small: true
                        text: modelData
                        onClicked: { input.text = modelData; input.forceActiveFocus(); }
                    }
                }
            }
        }

        ListView {
            id: messagesView
            FastWheel { flick: messagesView }
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: inputBar.top }
            anchors.leftMargin: 40
            anchors.rightMargin: 40
            topMargin: 32
            bottomMargin: 24
            spacing: 22
            clip: true
            model: chatModel
            boundsBehavior: Flickable.StopAtBounds
            onCountChanged: Qt.callLater(positionViewAtEnd)

            footer: Item {
                width: messagesView.width
                height: backend.busy ? 48 : 0
                visible: backend.busy
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        text: backend.status
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                    }
                    Rectangle {
                        width: 160
                        height: 3
                        color: "#12203A"
                        clip: true
                        Rectangle {
                            width: 48
                            height: parent.height
                            color: accent.color
                            SequentialAnimation on x {
                                running: backend.busy
                                loops: Animation.Infinite
                                NumberAnimation { from: -48; to: 160; duration: 1100; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }
            }

            delegate: Item {
                id: msgItem
                required property string msg
                required property int index
                readonly property var m: JSON.parse(msg)
                readonly property real maxWidth: Math.min(860, messagesView.width)

                width: messagesView.width
                height: m.role === "user" ? userBox.height : m.role === "error" ? errorText.height : answer.height

                // The user's question: box to the right
                Rectangle {
                    id: userBox
                    visible: msgItem.m.role === "user"
                    anchors.right: parent.right
                    width: Math.min(userCol.implicitWidth + 32, msgItem.maxWidth * 0.75)
                    height: userCol.height + 24
                    color: "#12203A"
                    border.width: 1
                    border.color: "#1E2A40"
                    Column {
                        id: userCol
                        x: 16
                        y: 12
                        width: parent.width - 32
                        spacing: 8
                        TextEdit {
                            width: Math.min(implicitWidth, msgItem.maxWidth * 0.75 - 32)
                            visible: msgItem.m.text !== ""
                            text: msgItem.m.text
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            color: "#E6ECF5"
                            selectionColor: accent.color
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 15
                        }
                        Text {
                            visible: msgItem.m.file !== ""
                            text: "📎  " + msgItem.m.file
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                    }
                }

                Text {
                    id: errorText
                    visible: msgItem.m.role === "error"
                    width: msgItem.maxWidth
                    text: msgItem.m.text + "\n\nKolla nätverket, eller lägg till fler tjänster under AI-tjänster."
                    wrapMode: Text.WordWrap
                    color: "#E8A0A4"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                }

                // The answer: text, command cards, new file versions, code
                Column {
                    id: answer
                    visible: msgItem.m.role === "assistant"
                    width: msgItem.maxWidth
                    spacing: 14

                    Repeater {
                        model: msgItem.m.role === "assistant" ? msgItem.m.segments : []

                        Item {
                            id: segItem
                            required property var modelData
                            required property int index
                            readonly property var s: modelData
                            width: answer.width
                            height: s.type === "text" ? mdText.height : card.height

                            TextEdit {
                                id: mdText
                                visible: segItem.s.type === "text"
                                width: parent.width
                                text: segItem.s.type === "text" ? segItem.s.text : ""
                                textFormat: TextEdit.MarkdownText
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                                color: "#E6ECF5"
                                selectionColor: accent.color
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 15
                                onLinkActivated: link => Qt.openUrlExternally(link)
                            }

                            Rectangle {
                                id: card
                                visible: segItem.s.type !== "text"
                                width: parent.width
                                height: segItem.s.type === "text" ? 0 : cardCol.height + 32
                                color: "#0E1420"
                                border.width: 1
                                border.color: segItem.s.type === "command" && segItem.s.danger ? accent.error
                                    : segItem.s.state === "running" ? accent.color : "#1E2A40"

                                Column {
                                    id: cardCol
                                    x: 16
                                    y: 16
                                    width: parent.width - 32
                                    spacing: 12

                                    Label {
                                        text: segItem.s.type === "command" ? (segItem.s.danger ? "KOMMANDO – ÄNDRAR SYSTEMET, LÄS IGENOM" : "KOMMANDO")
                                            : segItem.s.type === "file" ? "NY VERSION AV " + segItem.s.name.toUpperCase()
                                            : (segItem.s.lang ? segItem.s.lang.toUpperCase() : "TEXT")
                                        color: segItem.s.type === "command" && segItem.s.danger ? "#E8A0A4" : "#8B98AD"
                                    }

                                    CodeBox {
                                        code: segItem.s.code || ""
                                        maxHeight: segItem.s.type === "file" ? 320 : 220
                                    }

                                    // Command: run / skip, then the output
                                    Row {
                                        visible: segItem.s.type === "command" && segItem.s.state === "new"
                                        spacing: 10
                                        FlatButton {
                                            primary: true
                                            small: true
                                            text: "Kör"
                                            enabledState: !backend.busy
                                            onClicked: backend.runCommand(msgItem.index, segItem.index)
                                        }
                                        FlatButton {
                                            small: true
                                            text: "Hoppa över"
                                            onClicked: backend.skipCommand(msgItem.index, segItem.index)
                                        }
                                    }
                                    Text {
                                        visible: segItem.s.type === "command" && segItem.s.state !== "new"
                                        text: segItem.s.state === "running" ? "Kör…"
                                            : segItem.s.state === "skipped" ? "Hoppades över"
                                            : "Klart" + (segItem.s.code_result !== undefined && segItem.s.code_result !== 0 ? " (fel " + segItem.s.code_result + ")" : "")
                                        color: "#8B98AD"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                    }
                                    CodeBox {
                                        visible: segItem.s.type === "command" && (segItem.s.output || "") !== ""
                                        code: segItem.s.output || ""
                                        maxHeight: 220
                                    }

                                    // New version of a file: save over it / save as / copy
                                    Row {
                                        visible: segItem.s.type === "file"
                                        spacing: 10
                                        FlatButton {
                                            visible: !!segItem.s.canOverwrite
                                            primary: true
                                            small: true
                                            text: "Spara i " + (segItem.s.name || "filen")
                                            onClicked: backend.saveFile(msgItem.index, segItem.index)
                                        }
                                        FlatButton {
                                            small: true
                                            text: "Spara som…"
                                            onClicked: {
                                                win.pendingSave = { "index": msgItem.index, "seg": segItem.index };
                                                saveDialog.open();
                                            }
                                        }
                                        FlatButton {
                                            small: true
                                            text: "Kopiera"
                                            onClicked: backend.copy(segItem.s.code)
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WrapAnywhere
                                        visible: segItem.s.type === "file" && segItem.s.state === "saved"
                                        text: "Sparad i " + (segItem.s.savedTo || "") + (segItem.s.canOverwrite ? " (den gamla finns kvar som .bak)" : "")
                                        color: "#8B98AD"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                    }

                                    FlatButton {
                                        visible: segItem.s.type === "code"
                                        small: true
                                        text: "Kopiera"
                                        onClicked: backend.copy(segItem.s.code)
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 14
                        Text {
                            text: msgItem.m.service || ""
                            color: "#5C6880"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                        Text {
                            text: "Kopiera svaret"
                            color: copyArea.containsMouse ? "#E6ECF5" : "#5C6880"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                            MouseArea {
                                id: copyArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.copy(msgItem.m.text)
                            }
                        }
                    }
                }
            }
        }

        // ── Input ──
        Rectangle {
            id: inputBar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 24 }
            height: inputCol.height + 24
            color: "#0E1420"
            border.width: 1
            border.color: input.activeFocus ? accent.color : "#1E2A40"

            Column {
                id: inputCol
                anchors { left: parent.left; right: buttons.left; leftMargin: 16; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 8

                Row {
                    visible: win.attachment !== ""
                    spacing: 8
                    Text {
                        text: "📎  " + (win.attachment !== "" ? backend.fileName(win.attachment) : "")
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                    Text {
                        text: "×"
                        color: "#8B98AD"
                        font.pixelSize: 16
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.attachment = ""
                        }
                    }
                }

                Flickable {
                    width: parent.width
                    height: Math.min(Math.max(input.implicitHeight, 24), 160)
                    contentHeight: input.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: input
                        width: parent.width
                        focus: true
                        wrapMode: TextEdit.Wrap
                        color: "#E6ECF5"
                        selectionColor: accent.color
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 15
                        Keys.onReturnPressed: event => {
                            if (event.modifiers & Qt.ShiftModifier)
                                event.accepted = false;
                            else
                                win.send();
                        }
                        Keys.onEnterPressed: win.send()

                        Text {
                            visible: input.text === ""
                            text: "Skriv din fråga…  (Enter skickar, Shift+Enter ny rad)"
                            color: "#5C6880"
                            font: input.font
                        }
                    }
                }
            }

            Row {
                id: buttons
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 8
                FlatButton {
                    small: true
                    text: "Bifoga fil"
                    onClicked: openDialog.open()
                }
                FlatButton {
                    small: true
                    primary: true
                    text: "Skicka"
                    enabledState: !backend.busy && (input.text.trim() !== "" || win.attachment !== "")
                    onClicked: win.send()
                }
            }
        }
    }

    // ── Settings: AI services and keys ───────────────────────

    Flickable {
        id: settings
        FastWheel { flick: settings }
        visible: win.view === "settings"
        anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }
        contentHeight: settingsCol.height + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: settingsCol
            x: 48
            y: 40
            width: Math.min(820, settings.width - 96)
            spacing: 16

            Text {
                text: "AI-TJÄNSTER"
                color: "#E6ECF5"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: 28
                font.letterSpacing: 4
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Goblin AI använder gratisnivåerna hos Gemini och OpenRouter – en gratis nyckel räcker, men fler gör att Goblin AI kan byta när en tjänst har slut på gratisfrågor. Tjänsterna märkta betald (Claude, OpenAI, DeepSeek, Grok, Perplexity, Mistral) kostar per fråga och används bara om du lägger in en nyckel – då före gratistjänsterna. Tjänsterna används i den här ordningen."
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 14
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Obs: på gratisnivåerna får tjänsterna oftast använda frågorna för att förbättra sina AI:er. Skriv inga lösenord eller annat hemligt."
                color: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.pixelSize: 14
            }


            // ── Local AI (15 Oct): Ollama on this computer ──
            Rectangle {
                width: settingsCol.width
                height: localCol.height + 36
                color: "#0E1420"
                border.width: 1
                border.color: win.localStatus.installed ? accent.color : "#1E2A40"

                Column {
                    id: localCol
                    x: 20
                    y: 18
                    width: parent.width - 40
                    spacing: 12

                    Row {
                        spacing: 12
                        Text {
                            text: "Lokal AI (Ollama)"
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                        }
                        Text {
                            text: !win.local.status ? "Kollar…"
                                : !win.localStatus.installed ? "Inte installerad"
                                : win.localStatus.waiting ? "Väntar på disken"
                                : (win.localStatus.running ? "Igång" : "Startar…") + " · Ollama " + win.localStatus.version
                            color: win.localStatus.installed ? accent.text : "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "AI som körs på din egen dator – gratis, utan nyckel och utan att något skickas iväg. "
                              + "Snabbast med ett grafikkort med mycket minne. Modellen släpps ur grafikminnet när ett spel startar."
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        visible: !!win.local.recommend
                        text: {
                            const r = win.local.recommend || {};
                            const g = r.graphics || {};
                            return (g.vram ? "Din dator: " + (g.name || "grafikkort") + " med " + win.gb(g.vram) + " grafikminne"
                                           : "Din dator: " + win.gb(r.ram || 0) + " vanligt minne")
                                   + (r.note ? ". " + r.note : ".");
                        }
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }

                    // Where it goes: when installing or moving
                    Column {
                        visible: !win.localStatus.installed || win.localMoving
                        width: parent.width
                        spacing: 8
                        Label { text: win.localMoving ? "FLYTTA TILL" : "VAR SKA DEN LIGGA?" }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "Programmet tar ungefär 2 GB och varje modell 3–25 GB. Välj en disk med gott om plats – "
                                  + "en annan disk än systemets går bra (den måste vara inkopplad när du använder lokal AI)."
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                        Repeater {
                            model: win.local.places || []
                            Rectangle {
                                id: placeRow
                                required property var modelData
                                readonly property bool chosen: (win.localPlace || (win.local.places || [{}])[0].path) === modelData.path
                                width: localCol.width
                                height: 40
                                color: chosen ? "#12203A" : placeArea.containsMouse ? "#111A2A" : "transparent"
                                border.width: chosen ? 2 : 1
                                border.color: chosen ? accent.color : "#2A3852"
                                opacity: modelData.writable ? 1 : 0.4
                                Text {
                                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                    text: placeRow.modelData.label + "  ·  " + win.gb(placeRow.modelData.free) + " ledigt"
                                          + (placeRow.modelData.slow ? "  ·  " + placeRow.modelData.fs + " – fungerar men långsammare" : "")
                                          + (placeRow.modelData.writable ? "" : "  ·  går inte att skriva till")
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    id: placeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (placeRow.modelData.writable) win.localPlace = placeRow.modelData.path
                                }
                            }
                        }
                        Row {
                            spacing: 10
                            FlatButton {
                                primary: true
                                enabledState: !backend.localBusy && !!win.local.places
                                text: win.localMoving ? "Flytta hit" : "Installera lokal AI"
                                onClicked: {
                                    const place = win.localPlace || (win.local.places || [{}])[0].path;
                                    win.localError = false;
                                    if (win.localMoving) { backend.moveLocal(place); win.localMoving = false; }
                                    else backend.installLocal(place);
                                }
                            }
                            FlatButton {
                                visible: win.localMoving
                                text: "Avbryt"
                                onClicked: win.localMoving = false
                            }
                        }
                    }

                    // Installed: the order, the models, the rest
                    Column {
                        visible: !!win.localStatus.installed && !win.localMoving
                        width: parent.width
                        spacing: 10
                        Label { text: "NÄR SKA DEN ANVÄNDAS?" }
                        Flow {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: [{ "id": "local-first", "name": "Lokalt först", "sub": "Molnet svarar bara om den lokala inte kan" },
                                        { "id": "cloud-first", "name": "Molnet först", "sub": "Den lokala svarar när molntjänsterna inte kan" },
                                        { "id": "local-only", "name": "Bara lokalt", "sub": "Inget lämnar datorn" },
                                        { "id": "cloud-only", "name": "Bara molnet", "sub": "Den lokala används inte" }]
                                FlatButton {
                                    required property var modelData
                                    small: true
                                    primary: win.localStatus.order === modelData.id
                                    text: modelData.name
                                    onClicked: backend.setLocalOrder(modelData.id)
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: ({ "local-first": "Lokalt först: din dator svarar, molntjänsterna bara om den inte kan.",
                                     "cloud-first": "Molnet först: molntjänsterna svarar, din dator när de inte kan.",
                                     "local-only": "Bara lokalt: inget lämnar datorn.",
                                     "cloud-only": "Bara molnet: den lokala AI:n används inte." })[win.localStatus.order] || ""
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }

                        Label { text: "VAD VILL DU ANVÄNDA DEN TILL?" }
                        Repeater {
                            model: (win.local.recommend || {}).roles || []
                            Rectangle {
                                id: roleRow
                                required property var modelData
                                readonly property bool have: (win.localStatus.models || []).some(m => m.name === modelData.model
                                                                 || m.name === modelData.model + ":latest")
                                width: localCol.width
                                height: 56
                                color: "#0B1018"
                                border.width: 1
                                border.color: have ? accent.color : "#1E2A40"
                                Column {
                                    anchors { left: parent.left; leftMargin: 14; right: roleButton.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                    spacing: 2
                                    Text {
                                        text: roleRow.modelData.name + "  ·  " + roleRow.modelData.model
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: roleRow.modelData.text
                                        color: "#8B98AD"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 12
                                    }
                                }
                                FlatButton {
                                    id: roleButton
                                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                    small: true
                                    primary: !roleRow.have
                                    enabledState: !roleRow.have && !backend.localBusy
                                    text: roleRow.have ? "Hämtad" : "Hämta"
                                    onClicked: { win.localError = false; backend.pullLocal(roleRow.modelData.model, roleRow.modelData.id); }
                                }
                            }
                        }

                        Label { text: "HÄMTADE MODELLER"; visible: (win.localStatus.models || []).length > 0 }
                        Repeater {
                            model: win.localStatus.models || []
                            Row {
                                required property var modelData
                                spacing: 12
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 320
                                    text: modelData.name + "  ·  " + win.gb(modelData.size)
                                          + ((win.localStatus.loaded || []).indexOf(modelData.name) >= 0 ? "  ·  i minnet" : "")
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Mono"
                                    font.pixelSize: 13
                                }
                                FlatButton {
                                    small: true
                                    text: "Ta bort"
                                    enabledState: !backend.localBusy
                                    onClicked: backend.removeLocalModel(modelData.name)
                                }
                            }
                        }
                        Row {
                            spacing: 10
                            Rectangle {
                                width: 300
                                height: 30
                                color: "#07090D"
                                border.width: 1
                                border.color: otherModel.activeFocus ? accent.color : "#1E2A40"
                                TextInput {
                                    id: otherModel
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Mono"
                                    font.pixelSize: 13
                                    onAccepted: if (text.trim()) { backend.pullLocal(text, ""); text = ""; }
                                    Text {
                                        visible: otherModel.text === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Annan modell, t.ex. gpt-oss:20b"
                                        color: "#5C6880"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                    }
                                }
                            }
                            FlatButton {
                                small: true
                                text: "Hämta"
                                enabledState: otherModel.text.trim() !== "" && !backend.localBusy
                                onClicked: { win.localError = false; backend.pullLocal(otherModel.text, ""); otherModel.text = ""; }
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: 8
                            FlatButton { small: true; text: "Uppdatera Ollama"; enabledState: !backend.localBusy; onClicked: backend.updateLocal() }
                            FlatButton { small: true; text: "Flytta …"; enabledState: !backend.localBusy; onClicked: { win.localPlace = ""; win.localMoving = true; } }
                            FlatButton { small: true; text: "Ta bort lokal AI …"; enabledState: !backend.localBusy; onClicked: win.localRemoving = !win.localRemoving }
                            FlatButton { small: true; visible: win.localRemoving; text: "Ta bort, behåll modellerna"; onClicked: { win.localRemoving = false; backend.uninstallLocal(false); } }
                            FlatButton { small: true; visible: win.localRemoving; text: "Ta bort allt"; onClicked: { win.localRemoving = false; backend.uninstallLocal(true); } }
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "Plats: " + (win.localStatus.dir || "") + ". I terminalen finns kommandot ollama (t.ex. ollama run "
                                  + (((win.local.recommend || {}).roles || [{}])[0].model || "gemma4") + ")."
                            color: "#5C6880"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                    }

                    // Progress and the last message
                    Rectangle {
                        visible: backend.localBusy && win.localFraction >= 0
                        width: parent.width
                        height: 4
                        color: "#1A2438"
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, win.localFraction))
                            height: parent.height
                            color: accent.color
                        }
                    }
                    Text {
                        visible: win.localText !== ""
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: win.localText
                        color: win.localError ? accent.errorBright : "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                }
            }

            Repeater {
                model: JSON.parse(backend.providers)

                Rectangle {
                    id: prov
                    required property var modelData
                    width: settingsCol.width
                    height: provCol.height + 36
                    color: "#0E1420"
                    border.width: 1
                    border.color: modelData.hasKey ? accent.color : "#1E2A40"

                    Column {
                        id: provCol
                        x: 20
                        y: 18
                        width: parent.width - 40
                        spacing: 10

                        Row {
                            spacing: 12
                            Text {
                                text: prov.modelData.name
                                color: "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.weight: Font.DemiBold
                                font.pixelSize: 16
                            }
                            Text {
                                text: prov.modelData.hasKey ? "Inställd" : "Inte inställd"
                                color: prov.modelData.hasKey ? accent.text : "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: prov.modelData.how
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                        Row {
                            spacing: 10
                            FlatButton {
                                small: true
                                text: "Hämta nyckel"
                                onClicked: backend.openKeyPage(prov.modelData.id)
                            }
                            Rectangle {
                                width: 300
                                height: 30
                                color: "#07090D"
                                border.width: 1
                                border.color: keyInput.activeFocus ? accent.color : "#1E2A40"
                                TextInput {
                                    id: keyInput
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    clip: true
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Mono"
                                    font.pixelSize: 13
                                    onAccepted: backend.setKey(prov.modelData.id, text)
                                    Text {
                                        visible: keyInput.text === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Klistra in nyckeln här"
                                        color: "#5C6880"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                    }
                                }
                            }
                            FlatButton {
                                small: true
                                primary: true
                                text: "Spara"
                                enabledState: keyInput.text !== ""
                                onClicked: { backend.setKey(prov.modelData.id, keyInput.text); keyInput.text = ""; }
                            }
                            FlatButton {
                                visible: prov.modelData.hasKey
                                small: true
                                text: "Ta bort"
                                onClicked: backend.removeKey(prov.modelData.id)
                            }
                        }
                        Text {
                            visible: text !== ""
                            text: win.keyResults[prov.modelData.id] || ""
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                    }
                }
            }

            FlatButton {
                visible: backend.hasKeys
                primary: true
                text: "Till chatten"
                onClicked: win.view = "chat"
            }
        }
    }

    // ── Short messages at the bottom ─────────────────────────

    Rectangle {
        id: toast
        property string text
        function show(t) {
            text = t;
            opacity = 1;
            hideTimer.restart();
        }
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 110 }
        width: toastText.implicitWidth + 32
        height: 38
        color: "#12203A"
        border.width: 1
        border.color: "#2A3852"
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text {
            id: toastText
            anchors.centerIn: parent
            text: toast.text
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: 13
        }
        Timer {
            id: hideTimer
            interval: 3500
            onTriggered: toast.opacity = 0
        }
    }
}
