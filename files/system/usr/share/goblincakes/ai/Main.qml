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

    // Learning mode (view "learn"): the course, the open module and the last run per task
    readonly property var learnState: JSON.parse(backend.learnState)
    readonly property var course: learnState.course
    property bool learnSetup: false        // choosing goal/tracks (also "Ändra mål")
    property var learnModule: null
    property string learnModuleId: ""
    property var learnRuns: ({})           // task id -> {ok, output, message}
    property string learnBusyText: ""
    property string testTask: ""           // "Jag kan redan det här": the task that is the test
    property string pickGoal: ""
    property var pickTracks: []
    property string pickLevel: "nybörjare"
    property string pickOrder: "local-only"
    function openModule(id) {
        learnModuleId = id;
        learnModule = id ? JSON.parse(backend.learnModule(id)) : null;
    }
    function reloadModule() { if (learnModuleId) openModule(learnModuleId); }
    Connections {
        target: backend
        function onLearnResult(taskId, json) {
            const r = Object.assign({}, win.learnRuns);
            r[taskId] = JSON.parse(json);
            win.learnRuns = r;
            if (r[taskId].ok && win.testTask === taskId)
                win.testTask = "";
            win.reloadModule();
        }
        function onLearnBusy(text) { win.learnBusyText = text; }
        function onLearnChanged() {
            if (win.course && !win.learnModuleId)
                win.openModule(win.course.current);
            else
                win.reloadModule();
        }
    }

    // Projects: the sidebar list, the chosen one and the one being edited (view "project")
    readonly property var projects: JSON.parse(backend.projects)
    readonly property var project: projects.find(p => p.id === backend.currentProject) || null
    property bool choosingTemplate: false
    property bool removingProject: false
    function editProject(change) {
        if (!win.project)
            return;
        const p = JSON.parse(JSON.stringify(win.project));
        change(p);
        backend.saveProject(JSON.stringify(p));
    }

    FileDialog {
        id: projectFileDialog
        title: "Fast fil i projektet"
        onAccepted: {
            const path = backend.localPath(selectedFile.toString());
            win.editProject(p => { if (p.files.indexOf(path) < 0) p.files.push(path); });
        }
    }
    FolderDialog {
        id: projectFolderDialog
        title: "Mapp för projektets filer"
        onAccepted: {
            const path = backend.localPath(selectedFolder.toString());
            win.editProject(p => { p.folder = path; });
        }
    }

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

        // Projects: own instructions, files, models and chats
        Item {
            id: projectHead
            anchors { left: parent.left; right: parent.right; top: newButton.bottom; topMargin: 24 }
            height: 22
            Label {
                anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                text: "PROJEKT"
            }
            Text {
                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                text: win.choosingTemplate ? "×" : "+"
                color: addArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                font.pixelSize: 20
                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.choosingTemplate = !win.choosingTemplate
                }
            }
        }
        Flow {
            id: templateRow
            anchors { left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 18; top: projectHead.bottom; topMargin: 8 }
            visible: win.choosingTemplate
            height: visible ? implicitHeight : 0
            spacing: 6
            Repeater {
                model: JSON.parse(backend.templates)
                FlatButton {
                    required property var modelData
                    small: true
                    text: modelData.name
                    onClicked: {
                        win.choosingTemplate = false;
                        backend.createProject(modelData.id);
                        win.view = "project";
                    }
                }
            }
        }
        ListView {
            id: projectList
            anchors { left: parent.left; right: parent.right; top: templateRow.bottom; topMargin: 6 }
            height: Math.min(count, 6) * 34
            clip: true
            interactive: count > 6
            model: win.projects
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: projItem
                required property var modelData
                readonly property bool active: modelData.id === backend.currentProject
                width: projectList.width
                height: 34
                color: projArea.containsMouse || active ? "#121B2B" : "transparent"
                Rectangle {
                    visible: projItem.active
                    width: 2
                    height: parent.height
                    color: accent.color
                }
                Text {
                    anchors { left: parent.left; leftMargin: 22; right: gear.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: "▸  " + projItem.modelData.name + (projItem.modelData.order === "local-only" ? "  ·  lokalt" : "")
                    color: projItem.active ? "#E6ECF5" : "#B8C2D3"
                    elide: Text.ElideRight
                    font.family: "IBM Plex Sans"
                    font.weight: projItem.active ? Font.DemiBold : Font.Normal
                    font.pixelSize: 14
                }
                MouseArea {
                    id: projArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.selectProject(projItem.active ? "" : projItem.modelData.id);
                        win.view = backend.hasKeys ? "chat" : "settings";
                    }
                }
                Text {
                    id: gear
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    visible: projArea.containsMouse || gearArea.containsMouse || (projItem.active && win.view === "project")
                    text: "⚙"
                    color: gearArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                    font.pixelSize: 15
                    MouseArea {
                        id: gearArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!projItem.active)
                                backend.selectProject(projItem.modelData.id);
                            win.removingProject = false;
                            win.view = "project";
                        }
                    }
                }
            }
        }
        Text {
            id: noProjects
            anchors { left: parent.left; leftMargin: 22; right: parent.right; rightMargin: 18; top: projectList.bottom }
            visible: win.projects.length === 0 && !win.choosingTemplate
            height: visible ? implicitHeight : 0
            text: "Samla chattar med egna instruktioner och filer – tryck +."
            color: "#5C6880"
            wrapMode: Text.WordWrap
            font.family: "IBM Plex Sans"
            font.pixelSize: 12
        }

        Label {
            id: recentLabel
            anchors { left: parent.left; leftMargin: 22; right: parent.right; rightMargin: 18; top: noProjects.bottom; topMargin: 22 }
            text: win.project ? "CHATTAR I " + win.project.name.toUpperCase() : "SENASTE"
            elide: Text.ElideRight
        }

        ListView {
            id: convList
            FastWheel { flick: convList }
            anchors { left: parent.left; right: parent.right; top: recentLabel.bottom; topMargin: 10; bottom: learnButton.top; bottomMargin: 12 }
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
            id: learnButton
            anchors { left: parent.left; right: parent.right; margins: 18; bottom: settingsButton.top; bottomMargin: 10 }
            width: parent.width - 36
            primary: win.view === "learn"
            text: "Lär dig koda"
            onClicked: {
                win.view = "learn";
                win.learnSetup = !win.course;
                if (win.course && !win.learnModuleId)
                    win.openModule(win.course.current);
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

        // The teacher's chats (project "Lärläge"): back to the lesson
        FlatButton {
            z: 5
            visible: backend.currentProject === "learn"
            anchors { right: parent.right; rightMargin: 24; top: parent.top; topMargin: 16 }
            small: true
            text: "← Tillbaka till lektionen"
            onClicked: { win.view = "learn"; win.learnSetup = false; win.reloadModule(); }
        }

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
                text: win.project ? win.project.name.toUpperCase() : "VAD KAN JAG HJÄLPA DIG MED?"
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
                text: win.project
                      ? "Ny chatt i projektet" + (win.project.files.length ? " – " + win.project.files.length + " fasta filer följer med" : "")
                        + ({ "local-only": " · bara lokal AI", "local-first": " · lokal AI först", "cloud-first": " · molnet först",
                             "cloud-only": " · bara molnet" }[win.project.order] || "") + "."
                      : "Fråga vad du vill, be om hjälp med datorn, eller bifoga en textfil som ska rättas. Kommandon körs bara när du trycker Kör."
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 14
            }
            Flow {
                width: parent.width
                visible: !win.project
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
                                            visible: !!(win.project && win.project.folder)
                                            primary: !segItem.s.canOverwrite
                                            small: true
                                            text: "Spara i " + (win.project ? win.project.folder.split("/").pop() : "")
                                            onClicked: backend.saveToProject(msgItem.index, segItem.index)
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

    // ── Learning mode: "Lär dig koda" (view "learn") ────────

    component Pick: Rectangle {
        id: pick
        property string title
        property string sub
        property string badge
        property bool chosen: false
        signal picked()
        width: 290
        height: pickCol.implicitHeight + 22
        color: chosen ? "#12203A" : pickArea.containsMouse ? "#111A2A" : "#0E1420"
        border.width: chosen ? 2 : 1
        border.color: chosen ? accent.color : "#1E2A40"
        Column {
            id: pickCol
            x: 12
            y: 11
            width: parent.width - 24
            spacing: 4
            Row {
                spacing: 8
                Text {
                    width: Math.min(implicitWidth, pickCol.width - (pick.badge !== "" ? 60 : 0))
                    elide: Text.ElideRight
                    text: pick.title
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.weight: Font.DemiBold
                    font.pixelSize: 14
                }
                Text {
                    visible: pick.badge !== ""
                    text: pick.badge
                    color: "#D29922"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: pick.sub
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 12
            }
        }
        MouseArea {
            id: pickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pick.picked()
        }
    }

    Item {
        id: learnView
        visible: win.view === "learn"
        anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }

        // ── Choosing: goal, tracks, own goal, level, the teacher ──
        Flickable {
            id: setupFlick
            FastWheel { flick: setupFlick }
            visible: win.learnSetup || !win.course
            anchors.fill: parent
            contentHeight: setupCol.height + 80
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: setupCol
                x: 48
                y: 40
                width: Math.min(900, setupFlick.width - 96)
                spacing: 14
                Text {
                    text: "LÄR DIG KODA"
                    color: "#E6ECF5"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 28
                    font.letterSpacing: 4
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Välj vad du vill kunna – ett färdigt mål, några spår eller ditt eget mål med egna ord. Du skriver koden själv; den körs på en avskild övningsdator och kontrolleras automatiskt. Läraren (Goblin AI) förklarar, ger ledtrådar och granskar – men gör inte jobbet åt dig."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                }
                Label { text: "VAD VILL DU KUNNA?" }
                Flow {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: win.learnState.goals
                        Pick {
                            required property var modelData
                            title: modelData.name
                            sub: modelData.desc
                            chosen: win.pickGoal === modelData.id
                            onPicked: win.pickGoal = chosen ? "" : modelData.id
                        }
                    }
                }
                Label { text: "ELLER VÄLJ SPÅR (FLERA GÅR BRA)" }
                Flow {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: win.learnState.tracks
                        Pick {
                            required property var modelData
                            title: modelData.name
                            sub: modelData.desc
                            badge: modelData.status === "ai" ? "AI-läge" : ""
                            chosen: win.pickTracks.indexOf(modelData.id) >= 0
                            onPicked: win.pickTracks = chosen ? win.pickTracks.filter(t => t !== modelData.id)
                                                              : win.pickTracks.concat([modelData.id])
                        }
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "AI-läge = lektionerna är inte skrivna än: läraren lär ut fritt, utan färdiga uppgifter och kontroller."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 12
                }
                Label { text: "ELLER BESKRIV DITT MÅL" }
                Rectangle {
                    width: parent.width
                    height: 38
                    color: "#07090D"
                    border.width: 1
                    border.color: ownGoal.activeFocus ? accent.color : "#1E2A40"
                    TextInput {
                        id: ownGoal
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        Text {
                            visible: ownGoal.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "T.ex. \"en hemsida där guilden kan anmäla sig till raider\""
                            color: "#5C6880"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 14
                        }
                    }
                }
                Label { text: "HUR MYCKET KAN DU REDAN?" }
                Row {
                    spacing: 8
                    Repeater {
                        model: [{ "id": "nybörjare", "name": "Nybörjare" }, { "id": "lite", "name": "Kan lite" }, { "id": "van", "name": "Van" }]
                        FlatButton {
                            required property var modelData
                            small: true
                            primary: win.pickLevel === modelData.id
                            text: modelData.name
                            onClicked: win.pickLevel = modelData.id
                        }
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Van = korta sammanfattningar och de svårare uppgifterna. I varje moment kan du också testa dig direkt (\"Jag kan redan det här\") och hoppa över det du kan."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 12
                }
                Label { text: "LÄRAREN" }
                Row {
                    spacing: 8
                    Repeater {
                        model: [{ "id": "local-only", "name": "Bara lokalt" }, { "id": "local-first", "name": "Lokalt först" },
                                { "id": "cloud-first", "name": "Molnet först" }]
                        FlatButton {
                            required property var modelData
                            small: true
                            primary: win.pickOrder === modelData.id
                            text: modelData.name
                            onClicked: win.pickOrder = modelData.id
                        }
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: win.pickOrder === "local-only"
                          ? "Bara lokalt: frågor och kod lämnar aldrig datorn" + (win.localStatus.installed ? "." : " – kräver lokal AI (AI-tjänster → Lokal AI).")
                          : "Svårare frågor kan gå till molntjänsterna (Claude m.fl.) – din kod skickas då dit."
                    color: !win.localStatus.installed && win.pickOrder === "local-only" ? accent.errorBright : "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 12
                }
                Row {
                    spacing: 10
                    FlatButton {
                        primary: true
                        enabledState: win.learnBusyText === "" && (win.pickGoal !== "" || win.pickTracks.length > 0 || ownGoal.text.trim() !== "")
                        text: win.learnBusyText || "Skapa läroplan"
                        onClicked: {
                            win.learnModuleId = "";
                            backend.startCourse(win.pickGoal, JSON.stringify(win.pickTracks), win.pickLevel, ownGoal.text, win.pickOrder);
                            win.learnSetup = false;
                        }
                    }
                    FlatButton {
                        visible: !!win.course
                        text: "Avbryt"
                        onClicked: win.learnSetup = false
                    }
                }
            }
        }

        // ── The course: the plan on the left, the lesson and tasks on the right ──
        Item {
            visible: !win.learnSetup && !!win.course
            anchors.fill: parent

            Rectangle {
                id: planPane
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 290
                color: "#0B1018"
                Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: "#1E2A40" }

                Column {
                    id: planHead
                    x: 20
                    y: 24
                    width: parent.width - 40
                    spacing: 8
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: win.course ? win.course.goal : ""
                        color: "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: 17
                    }
                    Text {
                        text: win.course ? win.course.done + " av " + win.course.plan.length + " moment klara · " + win.course.level : ""
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                    Rectangle {
                        width: parent.width
                        height: 4
                        color: "#1A2438"
                        Rectangle {
                            width: win.course && win.course.plan.length ? parent.width * win.course.done / win.course.plan.length : 0
                            height: parent.height
                            color: accent.color
                        }
                    }
                    FlatButton {
                        small: true
                        text: "Ändra mål"
                        onClicked: {
                            win.pickTracks = win.course ? win.course.tracks : [];
                            win.pickLevel = win.course ? win.course.level : "nybörjare";
                            win.pickOrder = win.course ? win.course.order : "local-only";
                            win.learnSetup = true;
                        }
                    }
                }
                ListView {
                    id: planList
                    FastWheel { flick: planList }
                    anchors { left: parent.left; right: parent.right; top: planHead.bottom; topMargin: 14; bottom: parent.bottom; bottomMargin: 12 }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.course ? win.course.review.map(r => Object.assign({ "review": true }, r))
                                        .concat(win.course.plan) : []
                    delegate: Rectangle {
                        id: planItem
                        required property var modelData
                        required property int index
                        readonly property var prev: index > 0 ? planList.model[index - 1] : null
                        readonly property bool newTrack: !modelData.review && (!prev || prev.review || prev.track !== modelData.track)
                        readonly property bool active: !modelData.review && modelData.id === win.learnModuleId
                        width: planList.width
                        height: 34 + (newTrack ? 26 : 0)
                        color: "transparent"
                        Text {
                            visible: planItem.newTrack
                            x: 20
                            y: 8
                            text: ((win.learnState.tracks.find(t => t.id === planItem.modelData.track) || {}).name || "").toUpperCase()
                            color: "#5C6880"
                            font.family: "Chakra Petch"
                            font.weight: Font.DemiBold
                            font.pixelSize: 11
                            font.letterSpacing: 2
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 34
                            color: planArea.containsMouse || planItem.active ? "#121B2B" : "transparent"
                            Rectangle { visible: planItem.active; width: 2; height: parent.height; color: accent.color }
                            Text {
                                anchors { left: parent.left; leftMargin: 20; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                elide: Text.ElideRight
                                text: planItem.modelData.review ? "↻  Repetera: " + planItem.modelData.title
                                    : (planItem.modelData.done ? "✓  " : planItem.modelData.id === win.course.current ? "●  " : "○  ")
                                      + planItem.modelData.title + (planItem.modelData.locked ? "  🔒" : "")
                                color: planItem.modelData.done ? "#8B98AD" : "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            MouseArea {
                                id: planArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openModule(planItem.modelData.review ? planItem.modelData.module : planItem.modelData.id)
                            }
                        }
                    }
                }
            }

            Flickable {
                id: lessonFlick
                FastWheel { flick: lessonFlick }
                anchors { left: planPane.right; right: parent.right; top: parent.top; bottom: parent.bottom }
                contentHeight: lessonCol.height + 80
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: lessonCol
                    x: 40
                    y: 32
                    width: Math.min(860, lessonFlick.width - 80)
                    spacing: 14

                    Text {
                        visible: !!win.course && win.course.aiTracks.length > 0
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "AI-läge för " + (win.course ? win.course.aiTracks.map(id => (win.learnState.tracks.find(t => t.id === id) || {}).name).join(", ") : "")
                              + ": lektionerna är inte skrivna än – fråga läraren, så lär den ut fritt."
                        color: "#D29922"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                    Text {
                        visible: !win.learnModule || !win.learnModule.id
                        text: win.course && win.course.plan.length ? "Välj ett moment till vänster." : "Det här målet har inga färdiga lektioner än – fråga läraren."
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                    }
                    Row {
                        visible: !!(win.learnModule && win.learnModule.id)
                        spacing: 12
                        Text {
                            text: win.learnModule ? win.learnModule.title : ""
                            color: "#E6ECF5"
                            font.family: "Chakra Petch"
                            font.weight: Font.Bold
                            font.pixelSize: 24
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!(win.learnModule && win.learnModule.done)
                            text: "Klar ✓"
                            color: "#3FB950"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!(win.learnModule && win.learnModule.locked)
                            text: "Säkerhetsmoment – kan inte hoppas över"
                            color: "#D29922"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                    }
                    Text {
                        visible: !!(win.learnModule && win.learnModule.id)
                        width: parent.width
                        wrapMode: Text.WordWrap
                        textFormat: Text.MarkdownText
                        text: win.learnModule ? win.learnModule.lesson : ""
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        lineHeight: 1.2
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                    FlatButton {
                        visible: !!(win.learnModule && win.learnModule.id && !win.learnModule.done && !win.learnModule.locked) && win.testTask === ""
                        small: true
                        text: "Jag kan redan det här – testa mig"
                        onClicked: win.testTask = backend.learnTestTask(win.learnModule.id)
                    }

                    Repeater {
                        model: win.learnModule && win.learnModule.tasks
                               ? (win.testTask ? win.learnModule.tasks.filter(t => t.id === win.testTask) : win.learnModule.tasks) : []
                        Rectangle {
                            id: taskCard
                            required property var modelData
                            readonly property var run: win.learnRuns[modelData.id] || null
                            width: lessonCol.width
                            height: taskCol.height + 32
                            color: "#0E1420"
                            border.width: 1
                            border.color: modelData.done ? "#3FB950" : win.testTask === modelData.id ? "#D29922" : "#1E2A40"
                            Column {
                                id: taskCol
                                x: 18
                                y: 16
                                width: parent.width - 36
                                spacing: 10
                                Text {
                                    text: (win.testTask === taskCard.modelData.id ? "PROV · " : "") + taskCard.modelData.title
                                          + (taskCard.modelData.done ? "  ✓" : "")
                                    color: taskCard.modelData.done ? "#3FB950" : "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 15
                                }
                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: taskCard.modelData.prompt
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 14
                                }
                                Rectangle {
                                    width: parent.width
                                    height: Math.max(140, Math.min(360, editor.contentHeight + 24))
                                    color: "#07090D"
                                    border.width: 1
                                    border.color: editor.activeFocus ? accent.color : "#1E2A40"
                                    Text {
                                        anchors { right: parent.right; top: parent.top; margins: 6 }
                                        text: taskCard.modelData.file
                                        color: "#5C6880"
                                        font.family: "IBM Plex Mono"
                                        font.pixelSize: 11
                                    }
                                    Flickable {
                                        id: editFlick
                                        anchors { fill: parent; margins: 12 }
                                        contentHeight: editor.contentHeight
                                        clip: true
                                        FastWheel { flick: editFlick }
                                        TextEdit {
                                            id: editor
                                            width: editFlick.width
                                            text: taskCard.modelData.code
                                            wrapMode: TextEdit.NoWrap
                                            selectByMouse: true
                                            color: "#E6ECF5"
                                            selectionColor: accent.color
                                            font.family: "IBM Plex Mono"
                                            font.pixelSize: 13
                                            tabStopDistance: 4 * fontMetrics.averageCharacterWidth
                                            FontMetrics { id: fontMetrics; font.family: "IBM Plex Mono"; font.pixelSize: 13 }
                                            Keys.onTabPressed: event => { insert(cursorPosition, "  "); event.accepted = true; }
                                            onActiveFocusChanged: if (!activeFocus) backend.learnDraft(taskCard.modelData.id, text)
                                        }
                                    }
                                }
                                Flow {
                                    width: parent.width
                                    spacing: 8
                                    FlatButton {
                                        small: true
                                        primary: true
                                        enabledState: win.learnBusyText === ""
                                        text: win.learnBusyText !== "" ? "Kör…" : "Kör och kontrollera"
                                        onClicked: backend.runTask(taskCard.modelData.id, editor.text, win.testTask === taskCard.modelData.id)
                                    }
                                    FlatButton {
                                        visible: taskCard.modelData.html
                                        small: true
                                        text: "Förhandsvisa"
                                        onClicked: backend.previewHtml(editor.text)
                                    }
                                    FlatButton {
                                        visible: win.testTask !== taskCard.modelData.id && taskCard.modelData.hintsShown < taskCard.modelData.hintCount
                                        small: true
                                        text: "Ledtråd (" + (taskCard.modelData.hintCount - taskCard.modelData.hintsShown) + " kvar)"
                                        onClicked: { backend.learnDraft(taskCard.modelData.id, editor.text); backend.learnHint(taskCard.modelData.id); }
                                    }
                                    FlatButton {
                                        visible: win.testTask !== taskCard.modelData.id && taskCard.modelData.solution === ""
                                        small: true
                                        text: "Visa lösningen"
                                        onClicked: { backend.learnDraft(taskCard.modelData.id, editor.text); backend.learnSolution(taskCard.modelData.id); }
                                    }
                                    FlatButton {
                                        visible: !!taskCard.run && !taskCard.run.ok
                                        small: true
                                        text: "Förklara felet"
                                        onClicked: { backend.askTutor(taskCard.modelData.id, editor.text, taskCard.run.output + "\n" + taskCard.run.message, ""); win.view = "chat"; }
                                    }
                                    FlatButton {
                                        small: true
                                        text: "Fråga läraren"
                                        onClicked: { backend.askTutor(taskCard.modelData.id, editor.text, taskCard.run ? taskCard.run.output : "", ""); win.view = "chat"; }
                                    }
                                    FlatButton {
                                        visible: win.testTask === taskCard.modelData.id
                                        small: true
                                        text: "Avbryt provet"
                                        onClicked: win.testTask = ""
                                    }
                                }
                                Text {
                                    visible: win.learnBusyText !== "" && win.learnBusyText !== "Kör…"
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: win.learnBusyText
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                }
                                Text {
                                    visible: !!taskCard.run
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: taskCard.run ? (taskCard.run.ok ? "✓ " : "✗ ") + taskCard.run.message : ""
                                    color: taskCard.run && taskCard.run.ok ? "#3FB950" : accent.errorBright
                                    font.family: "IBM Plex Sans"
                                    font.weight: Font.Medium
                                    font.pixelSize: 14
                                }
                                CodeBox {
                                    visible: !!taskCard.run && (taskCard.run.output || "") !== ""
                                    code: taskCard.run ? taskCard.run.output : ""
                                    maxHeight: 200
                                }
                                Repeater {
                                    model: taskCard.modelData.hints
                                    Text {
                                        required property string modelData
                                        required property int index
                                        width: taskCol.width
                                        wrapMode: Text.WordWrap
                                        text: "Ledtråd " + (index + 1) + ": " + modelData
                                        color: "#D29922"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                    }
                                }
                                Text {
                                    visible: taskCard.modelData.solution !== ""
                                    text: "LÖSNINGEN (prova att skriva den själv efteråt – den här uppgiften kommer tillbaka som repetition)"
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                }
                                CodeBox {
                                    visible: taskCard.modelData.solution !== ""
                                    code: taskCard.modelData.solution
                                    maxHeight: 260
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── A project's settings (view "project") ───────────────

    Flickable {
        id: projectView
        FastWheel { flick: projectView }
        visible: win.view === "project" && !!win.project
        anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }
        contentHeight: projCol.height + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: projCol
            x: 48
            y: 40
            width: Math.min(820, projectView.width - 96)
            spacing: 14

            Text {
                text: "PROJEKT"
                color: "#E6ECF5"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: 28
                font.letterSpacing: 4
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Allt här gäller bara chattarna i projektet. Ändringar sparas direkt."
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 14
            }

            Label { text: "NAMN" }
            Rectangle {
                width: 360
                height: 36
                color: "#07090D"
                border.width: 1
                border.color: projName.activeFocus ? accent.color : "#1E2A40"
                TextInput {
                    id: projName
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    text: win.project ? win.project.name : ""
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                    onEditingFinished: if (text.trim() && win.project && text.trim() !== win.project.name)
                        win.editProject(p => { p.name = text.trim(); })
                }
            }

            Label { text: "INSTRUKTIONER" }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Det AI:n alltid ska veta i projektet, t.ex. \"WoW Retail, aktuellt API, Lua\" eller \"Ianseo med PHP 8.3 och MariaDB\"."
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 13
            }
            Rectangle {
                width: parent.width
                height: 140
                color: "#07090D"
                border.width: 1
                border.color: projInstr.activeFocus ? accent.color : "#1E2A40"
                Flickable {
                    id: instrFlick
                    anchors { fill: parent; margins: 10 }
                    contentHeight: projInstr.contentHeight
                    clip: true
                    FastWheel { flick: instrFlick }
                    TextEdit {
                        id: projInstr
                        width: instrFlick.width
                        text: win.project ? win.project.instructions : ""
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        color: "#E6ECF5"
                        selectionColor: accent.color
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        onActiveFocusChanged: if (!activeFocus && win.project && text !== win.project.instructions)
                            win.editProject(p => { p.instructions = text; })
                    }
                }
            }

            Label { text: "VAR FÅR DET KÖRAS?" }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: [{ "id": "inherit", "name": "Som i AI-tjänster" }, { "id": "local-first", "name": "Lokalt först" },
                            { "id": "cloud-first", "name": "Molnet först" }, { "id": "local-only", "name": "Bara lokalt" },
                            { "id": "cloud-only", "name": "Bara molnet" }]
                    FlatButton {
                        required property var modelData
                        small: true
                        primary: !!win.project && win.project.order === modelData.id
                        text: modelData.name
                        onClicked: win.editProject(p => { p.order = modelData.id; })
                    }
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: !!win.project && win.project.order === "local-only"
                text: win.localStatus.installed ? "Bara lokalt: inget i projektet lämnar datorn – inte heller nätsökningar."
                                                : "Bara lokalt kräver lokal AI – installera den under AI-tjänster → Lokal AI."
                color: win.localStatus.installed ? "#8B98AD" : accent.errorBright
                font.family: "IBM Plex Sans"
                font.pixelSize: 13
            }

            Label { text: "LOKALA MODELLER"; visible: (win.localStatus.models || []).length > 0 }
            Repeater {
                model: (win.localStatus.models || []).length > 0 ? [{ "id": "vardag", "name": "Vardag" }, { "id": "kod", "name": "Kod" },
                                                                    { "id": "bild", "name": "Bilder" }] : []
                Flow {
                    id: roleFlow
                    required property var modelData
                    width: projCol.width
                    spacing: 6
                    Text {
                        width: 90
                        height: 30
                        verticalAlignment: Text.AlignVCenter
                        text: roleFlow.modelData.name
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                    FlatButton {
                        small: true
                        primary: !!win.project && !win.project.models[roleFlow.modelData.id]
                        text: "Som i AI-tjänster"
                        onClicked: win.editProject(p => { delete p.models[roleFlow.modelData.id]; })
                    }
                    Repeater {
                        model: win.localStatus.models || []
                        FlatButton {
                            required property var modelData
                            small: true
                            primary: !!win.project && win.project.models[roleFlow.modelData.id] === modelData.name
                            text: modelData.name
                            onClicked: win.editProject(p => { p.models[roleFlow.modelData.id] = modelData.name; })
                        }
                    }
                }
            }

            Label { text: "FASTA FILER" }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Följer med varje fråga i projektet (textfiler: kod, anteckningar, dokumentation). Läses om varje gång, så ändringar syns direkt."
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 13
            }
            Repeater {
                model: win.project ? win.project.files : []
                Row {
                    required property string modelData
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: projCol.width - 60
                        elide: Text.ElideMiddle
                        text: modelData
                        color: "#E6ECF5"
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 13
                    }
                    FlatButton {
                        small: true
                        text: "×"
                        onClicked: win.editProject(p => { p.files = p.files.filter(f => f !== modelData); })
                    }
                }
            }
            FlatButton {
                small: true
                text: "Lägg till fil…"
                onClicked: projectFileDialog.open()
            }

            Label { text: "SÖKA PÅ NÄTET" }
            Row {
                spacing: 8
                FlatButton {
                    small: true
                    primary: !!win.project && win.project.search
                    text: "På"
                    onClicked: win.editProject(p => { p.search = true; })
                }
                FlatButton {
                    small: true
                    primary: !!win.project && !win.project.search
                    text: "Av"
                    onClicked: win.editProject(p => { p.search = false; })
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Kräver en Tavily-nyckel (AI-tjänster). Gäller aldrig Bara lokalt."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 13
                }
            }

            Label { text: "MAPP FÖR SPARADE FILER" }
            Row {
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.project && win.project.folder ? win.project.folder : "Ingen – filkorten frågar var de ska sparas"
                    color: win.project && win.project.folder ? "#E6ECF5" : "#8B98AD"
                    font.family: win.project && win.project.folder ? "IBM Plex Mono" : "IBM Plex Sans"
                    font.pixelSize: 13
                }
                FlatButton {
                    small: true
                    text: "Välj mapp…"
                    onClicked: projectFolderDialog.open()
                }
                FlatButton {
                    small: true
                    visible: !!win.project && win.project.folder !== ""
                    text: "Ingen"
                    onClicked: win.editProject(p => { p.folder = ""; })
                }
            }

            Item { width: 1; height: 10 }
            Flow {
                width: parent.width
                spacing: 10
                FlatButton {
                    primary: true
                    text: "Till chatten"
                    onClicked: win.view = backend.hasKeys ? "chat" : "settings"
                }
                FlatButton {
                    text: "Ta bort projektet …"
                    onClicked: win.removingProject = !win.removingProject
                }
                FlatButton {
                    visible: win.removingProject
                    text: "Ta bort, behåll chattarna"
                    onClicked: { win.removingProject = false; backend.deleteProject(win.project.id, false); win.view = "chat"; }
                }
                FlatButton {
                    visible: win.removingProject
                    text: "Ta bort med chattarna"
                    onClicked: { win.removingProject = false; backend.deleteProject(win.project.id, true); win.view = "chat"; }
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
