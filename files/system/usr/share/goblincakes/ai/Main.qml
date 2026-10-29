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
    visible: !startQuick  // started for the quick box only: the window comes with the answer
    title: "Goblin AI"
    color: "#07090D"
    onClosing: Qt.quit()

    property string view: backend.hasKeys ? "chat" : "settings"
    // The sidebar (28 Oct, the user's wish): open by default; « hides it at the left edge, where the mouse slides it
    // out over the chat; » keeps it open again (and gives it its own room)
    property bool sideOpen: backend.sidePinned
    readonly property int sideSpace: backend.sidePinned ? sidebar.width : 0
    property string attachment: ""
    property var pendingSave: null // {index, seg} while the "save as" dialog is open
    property string pendingImage: "" // the picture being saved with "Spara som…"
    property bool pictureMode: false // the Skapa bild button: the words go straight to the picture

    readonly property var examples: [
        "Rätta stavningen i en fil",
        "Ge mig ett recept på kanelbullar",
        "Varför startar inte Steam?",
        "Hur mycket diskutrymme har jag kvar?"
    ]

    // What a small mark under an answer does (♥, 👎): floats above it, outside the row's layout – a text that grew
    // on hover made the wrapping row jump away from the mouse and back (30 Oct)
    component HoverHint: Rectangle {
        property bool shown
        property alias text: hintText.text
        visible: shown
        z: 10
        x: 0
        y: -height - 4
        width: hintText.implicitWidth + 16
        height: 24
        color: "#0B1018"
        border.width: 1
        border.color: "#1E2A40"
        Text {
            id: hintText
            anchors.centerIn: parent
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: 12
        }
    }

    // Which model is best in its group (BÄST, BÄST TILL KOD, SNABBAST …), see goblinai.model_choices
    component ModelTag: Rectangle {
        property string tag
        visible: tag !== ""
        width: tagText.implicitWidth + 10
        height: 16
        color: "transparent"
        border.width: 1
        border.color: tag === "SNABBAST" ? "#2A3852" : accent.color
        Text {
            id: tagText
            anchors.centerIn: parent
            text: parent.tag
            color: parent.tag === "SNABBAST" ? "#8B98AD" : accent.text
            font.family: "Chakra Petch"
            font.weight: Font.DemiBold
            font.pixelSize: 10
            font.letterSpacing: 1
        }
    }

    // What the AI did for a question, step by step (the work loop, 25 Oct): ✓ done, ✗ failed, ■ stopped,
    // – a limit, a moving mark while it runs. Live in the footer while it works, foldable over the answer after.
    component StepList: Column {
        id: stepList
        property var steps: []
        spacing: 4
        Repeater {
            model: stepList.steps
            Row {
                id: stepRow
                required property var modelData
                spacing: 8
                width: stepList.width
                Text {
                    width: 14
                    text: ({ ok: "✓", fel: "✗", stopp: "■", "gräns": "–" })[stepRow.modelData.state] || "›"
                    color: stepRow.modelData.state === "fel" || stepRow.modelData.state === "stopp" ? accent.errorBright
                         : stepRow.modelData.state === "run" ? accent.text : "#8B98AD"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 13
                    SequentialAnimation on opacity {
                        running: stepRow.modelData.state === "run"
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.3; duration: 600 }
                        NumberAnimation { from: 0.3; to: 1; duration: 600 }
                    }
                }
                Text {
                    width: stepList.width - 22
                    text: stepRow.modelData.text
                          + (stepRow.modelData.secs !== undefined ? "  ·  " + stepRow.modelData.secs.toLocaleString(Qt.locale("sv_SE"), "f", 1) + " s" : "")
                          + (stepRow.modelData.note ? "  ·  " + stepRow.modelData.note : "")
                    color: stepRow.modelData.state === "run" ? "#E6ECF5" : "#8B98AD"
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 13
                }
            }
        }
    }

    // The button's text: "Automatiskt" or the chosen model (the part after the service id)
    function modelName(choice) {
        if (!choice)
            return "Automatiskt";
        const items = JSON.parse(backend.modelChoices);
        const hit = items.find(i => i.id === choice);
        return hit ? hit.name : choice.slice(choice.indexOf(":") + 1);
    }

    // A picture (by its name): attached pictures are shown and sent to the AI as pictures
    function isImage(path) {
        return /\.(png|jpe?g|webp|gif|bmp)$/i.test(path || "");
    }
    function fileUrl(path) {
        return path.startsWith("file:") ? path : "file://" + path;
    }

    function send(override) {
        const text = override !== undefined ? override : input.text;
        if (pictureMode) {
            if (text.trim() === "")
                return;
            if (override === undefined)
                remember(text);
            if (backend.canDraw)
                backend.createImage(text);
            else
                backend.drawChatGPT(text); // only ChatGPT can draw here
            input.text = "";
            pictureMode = false;
            return;
        }
        if (backend.busy || (text.trim() === "" && attachment === ""))
            return;
        if (override === undefined)
            remember(text);
        backend.send(text, attachment);
        input.text = "";
        attachment = "";
    }

    // Rita i ChatGPT (23 Oct, the user's wish): the description as a new chat in the ChatGPT app
    function sendChatGPT() {
        if (input.text.trim() === "")
            return;
        remember(input.text);
        backend.drawChatGPT(input.text);
        input.text = "";
        pictureMode = false;
    }

    // ── The input like a terminal (26 Oct, the user's wish: like Claude Code) ──
    // ↑/↓ = what was typed before (on the first/last line), Ctrl+R = search in it, / = commands.

    property var history: []          // oldest first, also from earlier sessions (backend.inputHistory)
    property int historyIndex: -1     // -1 = the line being written
    property string historyDraft: ""  // that line, back with ↓ after the newest
    property bool historySearch: false
    property int popupIndex: 0
    property bool popupClosed: false  // Esc: the list stays closed until the text changes
    property bool modelsAsked: false

    function remember(text) {
        text = text.trim();
        historyIndex = -1;
        if (text === "")
            return;
        history = history.filter(t => t !== text).concat([text]).slice(-500);
        backend.addHistory(text);
    }

    function recall(step) {
        if (step < 0) {
            if (historyIndex < 0) {
                historyDraft = input.text;
                historyIndex = history.length - 1;
            } else if (historyIndex > 0) {
                historyIndex--;
            } else {
                return;
            }
            input.text = history[historyIndex];
        } else {
            historyIndex++;
            if (historyIndex >= history.length) {
                historyIndex = -1;
                input.text = historyDraft;
            } else {
                input.text = history[historyIndex];
            }
        }
        input.cursorPosition = input.text.length;
        popupClosed = true;  // a remembered "/modell …" must not open the list
    }

    // å/ä/ö optional: /lar, /hjalp, /skarmbild, /sok and /installningar work too
    function plain(t) {
        return t.toLowerCase().replace(/[åä]/g, "a").replace(/ö/g, "o").replace(/é/g, "e");
    }

    readonly property var ownCommands: JSON.parse(backend.daily).map((d, i) => ({
        name: d.name.toLowerCase().trim().split(/\s+/).join("-"), note: "egen knapp – " + d.text, button: i }))
    readonly property var commands: [
        { name: "ny", note: "nytt samtal", aliases: ["new", "clear"] },
        { name: "bild", note: "skapa en bild – skriv vad den ska visa", args: true, hidden: !backend.canDraw && !backend.chatgpt },
        { name: "modell", note: "byt modell – t.ex. /modell claude", args: true },
        { name: "sök", note: "sök på nätet – med en fråga söker den direkt", args: true, hidden: !backend.canSearch },
        { name: "bifoga", note: "bifoga en fil" },
        { name: "skärmbild", note: "ta en skärmbild och bifoga den", args: true },
        { name: "projekt", note: "byt projekt – utan namn: lämna projektet", args: true },
        { name: "lär", note: "lärläget Lär dig koda, på eller av" },
        { name: "minne", note: "vad Goblin AI kommer ihåg om dig" },
        { name: "claude", note: "skicka senaste svaret till Claude Code – /claude fråga = bara läsa, svaret kommer hit", args: true, hidden: !backend.claude },
        { name: "testa", note: "kör Claudes testlista – /testa <namn>, /testa stopp", args: true },
        { name: "pdf", note: "spara senaste svaret som PDF" },
        { name: "word", note: "spara senaste svaret som Word" },
        { name: "inställningar", note: "AI-tjänster och inställningar", aliases: ["settings"] },
        { name: "hjälp", note: "alla kommandon", aliases: ["help", "?"] }
    ].filter(c => !c.hidden).concat(ownCommands)

    function findCommand(word) {
        const w = plain(word);
        return commands.find(c => plain(c.name) === w || (c.aliases || []).indexOf(w) >= 0) || null;
    }

    function commandArgs(name) {
        if (name === "modell")
            return [{ arg: "auto", note: "Automatiskt – GOBLINCAKES väljer" }].concat(
                JSON.parse(backend.modelChoices).filter(m => m.name !== "").map(m => ({ arg: m.name, note: m.group || m.note || "" })));
        if (name === "projekt")
            return win.projects.map(p => ({ arg: p.name, note: p.id === backend.currentProject ? "valt nu" : "" }));
        if (name === "skärmbild")
            return [{ arg: "skärm", note: "skärmen där muspekaren är" }, { arg: "båda", note: "båda skärmarna" },
                    { arg: "område", note: "dra en ruta – Esc avbryter" }];
        return [];
    }

    // The list above the input: commands, their choices, or (Ctrl+R) what was typed before
    readonly property var popupItems: {
        const t = input.text;
        if (popupClosed || view !== "chat")
            return [];
        if (historySearch) {
            const q = t.toLowerCase();
            return history.slice().reverse().filter(h => h.toLowerCase().indexOf(q) >= 0).slice(0, 30)
                .map(h => ({ fill: h, label: h.split("\n")[0], note: "" }));
        }
        if (!t.startsWith("/") || t.indexOf("\n") >= 0)
            return [];
        const space = t.indexOf(" ");
        if (space < 0) {
            const w = plain(t.slice(1));
            return commands.filter(c => plain(c.name).startsWith(w))
                .map(c => ({ fill: "/" + c.name, label: "/" + c.name, note: c.note, args: !!c.args }));
        }
        const c = findCommand(t.slice(1, space));
        if (!c || !c.args)
            return [];
        const w = plain(t.slice(space + 1).trim());
        const rank = a => { const p = plain(a.arg); return p === w ? 0 : p.startsWith(w) ? 1 : 2; };
        return commandArgs(c.name).filter(a => plain(a.arg).indexOf(w) >= 0)
            .sort((a, b) => rank(a) - rank(b))
            .map(a => ({ fill: "/" + c.name + " " + a.arg, label: a.arg, note: a.note }));
    }

    function takePopup(item, run) {
        if (historySearch) {
            historySearch = false;
            input.text = item.fill;
            input.cursorPosition = input.text.length;
            popupClosed = true;
        } else if (run) {
            runCommand(item.fill);
        } else {
            input.text = item.fill + (item.args ? " " : "");
            input.cursorPosition = input.text.length;
        }
        input.forceActiveFocus();
    }

    function submit() {
        if (input.text.trim().startsWith("/") && !pictureMode && runCommand(input.text))
            return;
        send();
    }

    // Keys in the input. Shift+Enter = a new line (not accepted: the TextEdit writes it).
    function inputKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
        const items = popupItems;
        const n = items.length;
        if (event.key === Qt.Key_R && ctrl) {
            if (!historySearch) {
                historyDraft = input.text;
                historySearch = true;
                input.text = "";
            } else if (n) {
                popupIndex = Math.min(popupIndex + 1, n - 1);  // Ctrl+R again: one older
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            if (historySearch) {
                historySearch = false;
                input.text = historyDraft;
                input.cursorPosition = input.text.length;
                popupClosed = true;
            } else if (n) {
                popupClosed = true;
            } else if (modelMenu.visible || shotMenu.visible) {
                modelMenu.visible = shotMenu.visible = false;
            } else if (backend.stoppable) {
                backend.stop();
            }
            event.accepted = true;
            return;
        }
        if (n && !(event.modifiers & Qt.ShiftModifier)) {
            const i = Math.min(popupIndex, n - 1);
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                popupIndex = (i + (event.key === Qt.Key_Up ? n - 1 : 1)) % n;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Tab || enter) {
                takePopup(items[i], enter);
                event.accepted = true;
                return;
            }
        }
        if (enter) {
            if (event.modifiers & Qt.ShiftModifier)
                return;
            if (historySearch) {  // nothing matched: keep the words, out of the search
                historySearch = false;
                popupClosed = true;
            } else {
                submit();
            }
            event.accepted = true;
            return;
        }
        if (historySearch || ctrl || !history.length)
            return;
        const caret = input.cursorRectangle;
        if (event.key === Qt.Key_Up && caret.y < 1) {
            recall(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down && historyIndex >= 0 && caret.y + caret.height >= input.contentHeight - 1) {
            recall(1);
            event.accepted = true;
        }
    }

    // A /command: done here, nothing is sent. False = not a command (sent as a question).
    function runCommand(text) {
        const m = text.trim().match(/^\/(\S+)\s*([\s\S]*)$/);
        const c = m ? findCommand(m[1]) : null;
        if (!c)
            return false;
        const arg = m[2].trim();
        remember(text);
        input.text = "";
        popupClosed = false;
        if (c.button !== undefined) {
            if (backend.busy)
                toast.show("Vänta tills svaret är klart.");
            else
                backend.runButton(c.button);
            return true;
        }
        switch (c.name) {
        case "ny":
            backend.newConversation();
            view = backend.hasKeys ? "chat" : "settings";
            break;
        case "bild":
            if (arg === "") {
                pictureMode = !pictureMode;
            } else {
                pictureMode = true;
                send(arg);
            }
            break;
        case "modell": {
            if (arg === "") {
                modelMenu.visible = true;
                backend.refreshModels();
                break;
            }
            if (["auto", "automatiskt"].indexOf(plain(arg)) >= 0) {
                backend.setModel("");
                toast.show("Modell: Automatiskt");
                break;
            }
            const w = plain(arg);
            const items = JSON.parse(backend.modelChoices).filter(i => i.name !== "");
            const hit = items.find(i => plain(i.name) === w || plain(i.id) === w)
                     || items.find(i => plain(i.name).indexOf(w) >= 0 || plain(i.id).indexOf(w) >= 0);
            if (hit) {
                backend.setModel(hit.id);
                toast.show("Modell: " + hit.name);
            } else {
                toast.show("Hittade ingen modell som heter " + arg + " – skriv /modell för listan.");
            }
            break;
        }
        case "sök":
            if (arg !== "") {
                backend.setSearchNext(true);
                send(arg);
            } else {
                backend.setSearchNext(!backend.searchNext);
                toast.show(backend.searchNext ? "Nästa fråga söker på nätet." : "Sök på nätet är av.");
            }
            break;
        case "bifoga":
            openDialog.open();
            break;
        case "skärmbild": {
            const scope = { "skarm": "screen", "den": "screen", "bada": "all", "alla": "all", "omrade": "region", "valj": "region" }[plain(arg.split(/\s+/)[0])];
            if (arg === "" || !scope)
                shotMenu.visible = true;
            else
                backend.takeScreenshot(scope);
            break;
        }
        case "projekt": {
            if (arg === "") {
                backend.selectProject("");
                view = backend.hasKeys ? "chat" : "settings";
                toast.show("Utanför projekten.");
                break;
            }
            const w = plain(arg);
            const hit = win.projects.find(p => plain(p.name) === w) || win.projects.find(p => plain(p.name).indexOf(w) >= 0);
            if (hit) {
                backend.selectProject(hit.id);
                view = backend.hasKeys ? "chat" : "settings";
            } else {
                toast.show("Hittade inget projekt som heter " + arg + ".");
            }
            break;
        }
        case "lär":
            if (view === "learn") {
                view = "chat";
            } else {
                view = "learn";
                learnSetup = !course;
                if (course && !learnModuleId)
                    openModule(course.current);
            }
            break;
        case "minne":
            view = "settings";
            memCard.open = true;
            Qt.callLater(() => settings.contentY = Math.max(0, Math.min(memCard.y, settings.contentHeight - settings.height)));
            break;
        case "claude": {
            const index = latestAnswer();
            if (index < 0)
                toast.show("Det finns inget svar att skicka än.");
            else
                backend.sendClaude(index, ["fraga", "las", "ask"].indexOf(plain(arg)) >= 0 ? "ask" : "fix");
            break;
        }
        case "testa":
            backend.startTest(arg);
            break;
        case "pdf":
        case "word":
            saveLatest(c.name === "word");
            break;
        case "inställningar":
            view = "settings";
            break;
        case "hjälp":
            input.text = "/";  // the list shows every command
            input.cursorPosition = 1;
            break;
        }
        return true;
    }

    // /pdf and /word: the latest answer, like "Spara som…" under it
    function latestAnswer() {
        for (let i = chatModel.count - 1; i >= 0; i--) {
            const m = JSON.parse(chatModel.get(i).msg);
            if (m.role === "assistant" && !m.stopped)
                return i;
        }
        return -1;
    }

    function saveLatest(word) {
        const index = latestAnswer();
        if (index < 0) {
            toast.show("Det finns inget svar att spara än.");
            return;
        }
        pendingPdf = index;
        const name = backend.pdfName(index);
        savePdfDialog.selectedNameFilter.index = word ? 1 : 0;
        savePdfDialog.selectedFile = word ? name.replace(/\.pdf$/, ".docx") : name;
        savePdfDialog.open();
    }

    function reload() {
        chatModel.clear();
        for (const m of JSON.parse(backend.messages))
            chatModel.append({ "msg": JSON.stringify(m) });
    }

    ListModel { id: chatModel }

    Component.onCompleted: {
        reload();
        history = JSON.parse(backend.inputHistory());
    }

    property int dailyPick: -1          // the button whose model list is open (-2 = the new one)
    property string dailyNewModel: ""   // the model for the one being added

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
        function onPendingQuestion(text) {
            input.text = text;
            win.view = "chat";
        }
        function onScreenshotReady(path) {
            win.attachment = path;
            win.view = "chat";
            input.forceActiveFocus();
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
        function onImageProgress(text, fraction) {
            win.imageText = text;
            win.imageFraction = fraction;
        }
        function onImageDone(ok, message) {
            win.imageText = message;
            win.imageFraction = -1;
            win.imageError = !ok;
        }
        function onQuickShow() { quick.open(); }
    }

    // Pictures on this computer (goblincakes-image): status, models
    readonly property var imageStatus: JSON.parse(backend.image || "{}")
    property string imagePlace: ""
    property string imageText: ""
    property real imageFraction: -1
    property bool imageError: false
    property bool imageRemoving: false
    property var imageVariant: ({})  // model -> the size picked in the window

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
    property var rolePick: ({})  // role -> the model picked in the window
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

    // The dialogs load KDE's style, which switches the whole program to native text – drawn small and
    // then zoomed (zoomRoot) that gives coloured, blurry letters. Back to Qt's own text right away.
    FileDialog {
        id: projectFileDialog
        title: "Fast fil i projektet"
        onVisibleChanged: backend.sharpText()
        onAccepted: {
            const path = backend.localPath(selectedFile.toString());
            win.editProject(p => { if (p.files.indexOf(path) < 0) p.files.push(path); });
        }
    }
    FolderDialog {
        id: projectFolderDialog
        title: "Mapp för projektets filer"
        onVisibleChanged: backend.sharpText()
        onAccepted: {
            const path = backend.localPath(selectedFolder.toString());
            win.editProject(p => { p.folder = path; });
        }
    }

    FileDialog {
        id: openDialog
        title: "Bifoga en textfil, bild eller PDF"
        onVisibleChanged: backend.sharpText()
        onAccepted: win.attachment = selectedFile.toString()
    }

    FileDialog {
        id: avatarDialog
        title: "Välj en bild som avatar"
        onVisibleChanged: backend.sharpText()
        nameFilters: ["Bilder (*.png *.jpg *.jpeg *.webp *.gif *.bmp)"]
        onAccepted: backend.setAvatar(selectedFile.toString())
    }

    FileDialog {
        id: avatarThinkingDialog
        title: "Välj en bild som tänkande avatar"
        onVisibleChanged: backend.sharpText()
        nameFilters: ["Bilder (*.png *.jpg *.jpeg *.webp *.gif *.bmp)"]
        onAccepted: backend.setAvatarThinking(selectedFile.toString())
    }

    FileDialog {
        id: saveImageDialog
        title: "Spara bilden som"
        onVisibleChanged: backend.sharpText()
        fileMode: FileDialog.SaveFile
        nameFilters: ["Bilder (*.png *.jpg *.webp)"]
        onAccepted: if (win.pendingImage) backend.saveImageAs(win.pendingImage, selectedFile.toString())
    }

    property int pendingPdf: -1  // the answer being saved as a PDF
    FileDialog {
        id: savePdfDialog
        title: "Spara svaret som"
        onVisibleChanged: backend.sharpText()
        fileMode: FileDialog.SaveFile
        nameFilters: ["PDF (*.pdf)", "Word (*.docx)", "OpenDocument – LibreOffice (*.odt)", "Text (*.txt)", "Markdown (*.md)"]
        onAccepted: if (win.pendingPdf >= 0)
            backend.savePdf(win.pendingPdf, selectedFile.toString(),
                            selectedNameFilter.extensions.length ? selectedNameFilter.extensions[0] : "pdf")
    }

    FileDialog {
        id: saveDialog
        title: "Spara som"
        onVisibleChanged: backend.sharpText()
        fileMode: FileDialog.SaveFile
        onAccepted: if (win.pendingSave) backend.saveFileAs(win.pendingSave.index, win.pendingSave.seg, selectedFile.toString())
    }

    // ── Quick question (Meta+§): a small box like KDE's search – the window opens with the answer ──

    Window {
        id: quick
        title: "Goblin AI – snabbfråga"  // the KWin script goblincakes-windows places it by this title
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        width: 680
        height: quickBox.height
        color: "#0B1018"
        property bool wasActive: false

        property bool picking: false  // the model list is open (Tab or a click on the model)
        property int pickIndex: 0
        onPickIndexChanged: {  // keep the highlighted one in view (rows are 34 px)
            const y = pickIndex * 34;
            if (y < quickPicks.contentY)
                quickPicks.contentY = y;
            else if (y + 34 > quickPicks.contentY + quickPicks.height)
                quickPicks.contentY = y + 34 - quickPicks.height;
        }
        readonly property var picks: JSON.parse(backend.modelChoices).filter(i => i.name !== "")

        function togglePicking() {
            picking = !picking;
            if (picking) {
                backend.refreshModels();
                pickIndex = Math.max(0, picks.findIndex(i => i.id === backend.model));
            }
            quickInput.forceActiveFocus();
        }
        function pick(i) {
            if (i >= 0 && i < picks.length)
                backend.setModel(picks[i].id);
            picking = false;
            quickInput.forceActiveFocus();
        }

        property var clip: ({})  // what was copied (backend.clipboard), sent along unless removed

        function open() {
            quickInput.text = "";
            quickNote.text = "";
            picking = false;
            histIndex = -1;
            clip = {};
            wasActive = false;
            show();
            raise();
            requestActivate();
            quickInput.forceActiveFocus();
        }
        // ↑/↓: the same history as the window (one line here – a question of several lines comes as one)
        property int histIndex: -1
        property string histDraft: ""
        function recall(step) {
            const h = win.history;
            if (!h.length)
                return;
            if (step < 0) {
                if (histIndex < 0) {
                    histDraft = quickInput.text;
                    histIndex = h.length - 1;
                } else if (histIndex > 0) {
                    histIndex--;
                }
                quickInput.text = h[histIndex].replace(/\s*\n\s*/g, " ");
            } else {
                if (histIndex < 0)
                    return;
                histIndex++;
                if (histIndex >= h.length) {
                    histIndex = -1;
                    quickInput.text = histDraft;
                } else {
                    quickInput.text = h[histIndex].replace(/\s*\n\s*/g, " ");
                }
            }
            quickInput.cursorPosition = quickInput.text.length;
        }
        function dismiss() {
            hide();
            if (!win.visible && !backend.busy)  // only started for the box
                Qt.quit();
        }
        function ask() {
            const text = quickInput.text.trim();
            if (text === "" && !clip.kind)
                return;
            if (!backend.quickSend(text, JSON.stringify(clip))) {
                quickNote.text = "Goblin AI svarar redan på något – vänta en stund.";
                return;
            }
            win.remember(text);
            histIndex = -1;
            hide();
            if (win.visible)
                win.view = "chat";
        }
        onActiveChanged: {
            if (active && !wasActive)  // the clipboard can only be read with the focus (Wayland)
                clip = JSON.parse(backend.clipboard());
            if (active)
                wasActive = true;
            else if (wasActive && visible)
                dismiss();
        }
        Component.onCompleted: if (startQuick) open()

        // Like the window's input (26 Oct): the words above, ❯ and the blinking block, ↑/↓ = earlier questions
        Rectangle {
            id: quickBox
            width: parent.width
            height: quickCol.height + 28
            color: "#0B1018"
            border.width: 2
            border.color: accent.color

            Column {
                id: quickCol
                x: 18
                y: 14
                width: parent.width - 36
                spacing: 10

                Item {
                    width: parent.width
                    height: quickModel.height
                    TextAction {
                        id: quickModel
                        on: quick.picking
                        text: win.modelName(backend.model).toLowerCase() + " ▾"
                        onClicked: quick.togglePicking()
                    }
                    Text {
                        id: quickHelp
                        anchors { right: parent.right; left: quickModel.right; leftMargin: 22 }
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        text: quick.picking ? "↑↓ välj · enter använder · esc tillbaka"
                                            : "enter frågar · ↑ tidigare · tab modell · esc stänger"
                        color: "#5C6880"
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 12
                    }
                }

                Rectangle { width: parent.width; height: 1; color: accent.color }

                Item {
                    width: parent.width
                    height: quickInput.height
                    Text {
                        id: quickMark
                        anchors.verticalCenter: parent.verticalCenter
                        text: "❯"
                        color: accent.text
                        font: quickInput.font
                    }
                    TextInput {
                        id: quickInput
                        anchors { left: quickMark.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
                        clip: true
                        color: "#E6ECF5"
                        selectionColor: accent.color
                        selectedTextColor: accent.on
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 18
                        cursorDelegate: BlockCaret { edit: quickInput }
                        Keys.onReturnPressed: quick.picking ? quick.pick(quick.pickIndex) : quick.ask()
                        Keys.onEnterPressed: quick.picking ? quick.pick(quick.pickIndex) : quick.ask()
                        Keys.onEscapePressed: quick.picking ? quick.picking = false : quick.dismiss()
                        Keys.onTabPressed: quick.togglePicking()
                        Keys.onUpPressed: quick.picking ? quick.pickIndex = Math.max(0, quick.pickIndex - 1) : quick.recall(-1)
                        Keys.onDownPressed: quick.picking ? quick.pickIndex = Math.min(quick.picks.length - 1, quick.pickIndex + 1) : quick.recall(1)
                        Text {
                            visible: quickInput.text === ""
                            text: "fråga " + (backend.aiName || "Goblin AI").toLowerCase() + "…"
                            color: "#5C6880"
                            font: quickInput.font
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: accent.color }

                Text {
                    id: quickNote
                    visible: text !== ""
                    color: accent.errorBright
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 12
                }
                // What was copied: goes along with the question (× = not)
                Row {
                    visible: !!quick.clip.kind
                    width: parent.width
                    spacing: 10
                    Image {
                        visible: quick.clip.kind === "image"
                        anchors.verticalCenter: parent.verticalCenter
                        source: visible ? win.fileUrl(quick.clip.path) : ""
                        sourceSize.height: 48
                        height: 48
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        width: parent.width - 40 - (quick.clip.kind === "image" ? 100 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: quick.clip.kind === "image" ? "📋  Bilden du kopierade följer med"
                              : "📋  Urklipp följer med: " + (quick.clip.text || "").replace(/\s+/g, " ")
                        color: "#8B98AD"
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 13
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "×"
                        color: clipX.containsMouse ? "#E6ECF5" : "#8B98AD"
                        font.pixelSize: 18
                        MouseArea {
                            id: clipX
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { quick.clip = {}; quickInput.forceActiveFocus(); }
                        }
                    }
                }

                // The model list (Tab): ↑/↓ and Enter, or a click
                Flickable {
                    id: quickPicks
                    visible: quick.picking
                    width: parent.width
                    height: Math.min(contentHeight, 8 * 34)
                    contentHeight: quickPickCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: quickPickCol
                        width: parent.width
                        Text {
                            visible: backend.modelsLoading && quick.picks.length <= 1
                            text: "Hämtar modellerna…"
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                        Repeater {
                            model: quick.picks
                            Rectangle {
                                id: qp
                                required property var modelData
                                required property int index
                                readonly property bool chosen: modelData.id === backend.model
                                width: quickPickCol.width
                                height: 34
                                color: quick.pickIndex === index || qpArea.containsMouse ? "#1A2438" : "transparent"
                                Rectangle { visible: qp.chosen; width: 3; height: parent.height; color: accent.color }
                                Text {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: qp.modelData.name + (qp.modelData.group ? "   " : "")
                                    color: qp.chosen ? accent.text : "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.weight: qp.chosen ? Font.DemiBold : Font.Normal
                                    font.pixelSize: 14
                                    ModelTag {
                                        id: qpTag
                                        tag: qp.modelData.tag || ""
                                        anchors { left: parent.right; verticalCenter: parent.verticalCenter }
                                    }
                                    Text {
                                        anchors { left: qpTag.visible ? qpTag.right : parent.right; leftMargin: qpTag.visible ? 8 : 0; baseline: parent.baseline }
                                        text: qp.modelData.group ? qp.modelData.group + " · " + qp.modelData.note : ""
                                        color: "#8B98AD"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 12
                                    }
                                }
                                MouseArea {
                                    id: qpArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: quick.pick(qp.index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Everything grows with a big window (maximized/full screen at 1080p) instead of leaving
    // the same small text in a corner: zoom up to 1.3 × when the window is bigger than its start size.
    Item {
        id: zoomRoot
        readonly property real zoom: Math.max(1, Math.min(1.3, win.width / 1120, win.height / 800))
        width: win.width / zoom
        height: win.height / zoom
        scale: zoom
        transformOrigin: Item.TopLeft

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
                event.accepted = true;
                // At its end (or with nothing to scroll) the list around it scrolls instead –
                // otherwise a code box or editor under the pointer stops the whole page
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

        // Two lessons maybe about the same thing (28 Oct, the user's idea): the AI found them, the user chooses –
        // the new one, the old one, or both (different things). Under a ♥/👎 answer and in Lärdomar.
        component SimilarBox: Column {
            id: simBox
            property string newId
            property var olds: []
            spacing: 8
            visible: olds.length > 0
            Repeater {
                model: simBox.olds
                Column {
                    id: simOld
                    required property var modelData
                    width: simBox.width
                    spacing: 6
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Liknar en äldre lärdom" + (simOld.modelData.added ? " (" + simOld.modelData.added + ")" : "") + ": "
                              + (simOld.modelData.kind === "avoid" ? "👎 " : simOld.modelData.kind === "solution" ? "🔧 " : "♥ ") + simOld.modelData.lesson
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: "Frågan då: " + simOld.modelData.question
                        color: "#5C6880"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        FlatButton { small: true; text: "Behåll nya"; onClicked: backend.resolveSimilar(simBox.newId, simOld.modelData.id, "new") }
                        FlatButton { small: true; text: "Behåll gamla"; onClicked: backend.resolveSimilar(simBox.newId, simOld.modelData.id, "old") }
                        FlatButton { small: true; text: "Behåll båda – olika saker"; onClicked: backend.resolveSimilar(simBox.newId, simOld.modelData.id, "both") }
                    }
                }
            }
        }

        component FlatButton: Rectangle {
            id: btn
            property string text
            property bool primary: false
            property bool danger: false  // STOPP
            property bool enabledState: true
            property bool small: false
            signal clicked()

            width: Math.max(small ? 70 : 120, label.implicitWidth + (small ? 24 : 40))
            height: small ? 30 : 40
            opacity: enabledState ? 1 : 0.4
            color: danger ? (area.containsMouse ? accent.errorBright : accent.error)
                 : primary ? (area.containsMouse && enabledState ? accent.hover : accent.color)
                           : (area.containsMouse && enabledState ? "#1A2438" : "transparent")
            border.width: primary ? 0 : 1
            border.color: "#2A3852"

            Text {
                id: label
                anchors.centerIn: parent
                text: btn.text
                color: btn.primary && !btn.danger ? accent.on : "#E6ECF5"
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

        // The inputs' cursor (26 Oct): a blinking block in the accent, the letter under it in accent.on – like a terminal
        component BlockCaret: Rectangle {
            id: caret
            required property Item edit
            property bool lit: true
            width: caretMetrics.advanceWidth("M")
            color: accent.color
            visible: edit.activeFocus && lit
            FontMetrics { id: caretMetrics; font: caret.edit.font }
            Text {
                text: caret.edit.text.length >= 0 ? caret.edit.getText(caret.edit.cursorPosition, caret.edit.cursorPosition + 1).trim() : ""
                color: accent.on
                font: caret.edit.font
            }
            Timer {
                id: blink
                interval: 530
                repeat: true
                running: caret.edit.activeFocus
                onTriggered: caret.lit = !caret.lit
            }
            Connections {
                target: caret.edit
                function onCursorPositionChanged() { caret.lit = true; blink.restart(); }
                function onTextChanged() { caret.lit = true; blink.restart(); }
            }
        }

        // A button as a word (the input, 26 Oct): dim, white under the pointer, accent when on
        component TextAction: Text {
            id: act
            property bool on: false
            property bool danger: false
            property bool enabledState: true
            signal clicked()
            color: danger ? accent.errorBright
                 : on ? accent.text
                 : actArea.containsMouse && enabledState ? "#E6ECF5" : "#8B98AD"
            opacity: enabledState ? 1 : 0.4
            font.family: "IBM Plex Mono"
            font.pixelSize: 13
            font.underline: actArea.containsMouse && enabledState
            MouseArea {
                id: actArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: act.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (act.enabledState) act.clicked()
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
                id: codeFlick
                FastWheel { flick: codeFlick }
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

        // Hidden: a thin strip at the left edge; the mouse there opens the sidebar
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 3
            z: 20
            visible: !win.sideOpen
            color: edgeHover.hovered ? accent.color : "#1E2A40"
            HoverHandler { id: edgeHover; margin: 4; onHoveredChanged: if (hovered) win.sideOpen = true }
        }

        Rectangle {
            id: sidebar
            anchors { top: parent.top; bottom: parent.bottom }
            x: win.sideOpen ? 0 : -width - 1
            z: 19
            width: 264
            color: "#0B1018"
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            // Out of the sidebar (not pinned): it slides away after a moment
            HoverHandler { id: sideHover }
            Timer {
                interval: 450
                running: win.sideOpen && !backend.sidePinned && !sideHover.hovered
                onTriggered: win.sideOpen = false
            }

            // The pin: keep it open (»|) or let it hide at the edge (|«)
            Text {
                anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 30 }
                z: 2
                text: backend.sidePinned ? "«" : "»"
                color: pinArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 20
                MouseArea {
                    id: pinArea
                    anchors { fill: parent; margins: -8 }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.setSidePinned(!backend.sidePinned);
                        win.sideOpen = backend.sidePinned;
                    }
                }
            }

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
                FastWheel { flick: projectList }
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
                        maximumLineCount: 1
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
            anchors { left: parent.left; leftMargin: win.sideSpace; right: parent.right; top: parent.top; bottom: parent.bottom }

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
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: ownButtons.top }
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
                    height: backend.busy ? Math.max(backend.avatarThinking !== "" ? 96 : 48, workCol.height + 24) : 0
                    visible: backend.busy
                    // The thinking avatar (24 Oct, the user's wish): the picture with the name instead of "tänker…"
                    Column {
                        id: thinkingBox
                        visible: backend.avatarThinking !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        width: 64
                        spacing: 6
                        Rectangle {
                            width: 64
                            height: 64
                            color: "#07090D"
                            border.width: 1
                            border.color: "#1E2A40"
                            Image {
                                anchors { fill: parent; margins: 1 }
                                source: backend.avatarThinking
                                sourceSize: Qt.size(128, 128)
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                asynchronous: true
                            }
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: backend.aiName || "Goblin AI"
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 12
                        }
                    }
                    Column {
                        id: workCol
                        x: thinkingBox.visible ? 80 : 0
                        width: Math.min(860, messagesView.width) - x
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        StepList {
                            width: parent.width
                            steps: JSON.parse(backend.steps)
                            visible: steps.length > 0
                        }
                        Text {
                            visible: !thinkingBox.visible
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
                    height: m.role === "user" ? userBox.height : m.role === "error" ? errorText.height
                            : Math.max(answer.height, avatarBox.visible ? avatarBox.height : 0)

                    // The user's question: "❯ the question", dim, like a line typed in a terminal (26 Oct)
                    Item {
                        id: userBox
                        visible: msgItem.m.role === "user"
                        width: msgItem.maxWidth
                        height: userCol.height
                        Text {
                            id: userMark
                            text: "❯"
                            color: accent.text
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 15
                        }
                        Column {
                            id: userCol
                            x: userMark.width + 10
                            width: parent.width - x
                            spacing: 8
                            Text {
                                visible: !!msgItem.m.picture
                                text: "SKAPA BILD"
                                color: accent.text
                                font.family: "Chakra Petch"
                                font.weight: Font.DemiBold
                                font.pixelSize: 11
                                font.letterSpacing: 2
                            }
                            TextEdit {
                                width: Math.min(implicitWidth, userCol.width)
                                visible: msgItem.m.text !== ""
                                text: msgItem.m.text
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                                color: "#B8C2D3"
                                selectionColor: accent.color
                                font.family: "IBM Plex Mono"
                                font.pixelSize: 15
                            }
                            Flow {
                                visible: !!msgItem.m.images && msgItem.m.images.length > 0
                                width: userCol.width
                                spacing: 8
                                Repeater {
                                    model: msgItem.m.images || []
                                    Image {
                                        required property string modelData
                                        source: win.fileUrl(modelData)
                                        sourceSize.width: 360
                                        width: Math.min(360, userCol.width)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Qt.openUrlExternally(win.fileUrl(parent.modelData))
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: msgItem.m.file !== ""
                                text: "📎  " + msgItem.m.file
                                color: "#8B98AD"
                                font.family: "IBM Plex Mono"
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

                    // The AI's avatar with its name under it, left of the answer (20 Oct) – only when it has one
                    Column {
                        id: avatarBox
                        visible: msgItem.m.role === "assistant" && backend.avatar !== ""
                        width: 64
                        spacing: 6
                        Rectangle {
                            width: 64
                            height: 64
                            color: "#07090D"
                            border.width: 1
                            border.color: "#1E2A40"
                            Image {
                                anchors { fill: parent; margins: 1 }
                                source: backend.avatar
                                sourceSize: Qt.size(128, 128)
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                asynchronous: true
                            }
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: backend.aiName || "Goblin AI"
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 12
                        }
                    }

                    // The answer: text, command cards, new file versions, code
                    Column {
                        id: answer
                        visible: msgItem.m.role === "assistant"
                        x: avatarBox.visible ? 80 : 0
                        width: msgItem.maxWidth - x
                        spacing: 14

                        // "▸ 4 steg · 12,3 s": what was done, folded out on a click
                        Column {
                            id: stepsBox
                            property bool open: false
                            readonly property var steps: msgItem.m.steps || []
                            visible: steps.length > 0
                            width: parent.width
                            spacing: 6
                            Text {
                                text: (stepsBox.open ? "▾ " : "▸ ") + stepsBox.steps.length + " steg · "
                                      + stepsBox.steps.reduce((a, s) => a + (s.secs || 0), 0).toLocaleString(Qt.locale("sv_SE"), "f", 1) + " s"
                                color: stepsArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                                MouseArea {
                                    id: stepsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: stepsBox.open = !stepsBox.open
                                }
                            }
                            StepList {
                                visible: stepsBox.open
                                width: parent.width
                                steps: stepsBox.steps
                            }
                        }

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
                                    // web → browser, folder → file manager, goblin-show: → the file selected in its folder
                                    onLinkActivated: link => link.startsWith("goblin-show:")
                                                     ? backend.showInFolder(decodeURIComponent(link.slice(12)))
                                                     : Qt.openUrlExternally(link)
                                    HoverHandler { cursorShape: mdText.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
                                }

                                Rectangle {
                                    id: card
                                    visible: segItem.s.type !== "text"
                                    width: parent.width
                                    height: segItem.s.type === "text" ? 0 : cardCol.height + 32
                                    color: "#0E1420"
                                    border.width: 1
                                    border.color: segItem.s.type === "blocked" ? accent.error
                                        : segItem.s.state === "running" ? accent.color : "#1E2A40"

                                    Column {
                                        id: cardCol
                                        x: 16
                                        y: 16
                                        width: parent.width - 32
                                        spacing: 12

                                        Label {
                                            // Three levels (25 Oct): reads = runs at once, changes = Tillåt, can't be undone = stopped
                                            text: segItem.s.type === "command" ? (segItem.s.level === "read" ? "KOMMANDO – LÄSER" + (segItem.s.auto ? " · KÖRDES DIREKT" : "")
                                                                                  : segItem.s.level === "change" ? "KOMMANDO – ÄNDRAR NÅGOT, BEHÖVER DITT OK" : "KOMMANDO")
                                                : segItem.s.type === "blocked" ? "STOPPAT – GÅR INTE ATT ÅNGRA"
                                                : segItem.s.type === "image" ? (segItem.s.report ? "RAPPORT" : "BILD")
                                                : segItem.s.type === "shot" ? "SKÄRMBILD"
                                                : segItem.s.type === "memory" ? "MINNE"
                                                : segItem.s.type === "solved" ? "KÄND LÖSNING"
                                                : segItem.s.type === "forget" ? "MINNE – GLÖMT"
                                                : segItem.s.type === "file" ? "NY VERSION AV " + segItem.s.name.toUpperCase()
                                                : (segItem.s.lang ? segItem.s.lang.toUpperCase() : "TEXT")
                                            color: segItem.s.type === "blocked" ? "#E8A0A4" : "#8B98AD"
                                        }

                                        CodeBox {
                                            visible: ["image", "shot", "memory", "forget", "blocked", "solved"].indexOf(segItem.s.type) < 0
                                            code: segItem.s.code || ""
                                            maxHeight: segItem.s.type === "file" ? 320 : 220
                                        }

                                        // A picture: drawn at once (this computer, Cloudflare or a paid service), shown here
                                        Column {
                                            visible: segItem.s.type === "image"
                                            width: parent.width
                                            spacing: 10
                                            Text {
                                                width: parent.width
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
                                                text: segItem.s.prompt || ""
                                                color: "#8B98AD"
                                                font.family: "IBM Plex Sans"
                                                font.italic: true
                                                font.pixelSize: 13
                                            }
                                            Column {
                                                visible: ["new", "waiting", "running"].indexOf(segItem.s.state) >= 0
                                                width: parent.width
                                                spacing: 8
                                                Text {
                                                    text: segItem.s.progress || "Ritar bilden…"
                                                    color: "#E6ECF5"
                                                    font.family: "IBM Plex Sans"
                                                    font.pixelSize: 14
                                                }
                                                Rectangle {
                                                    width: Math.min(parent.width, 360)
                                                    height: 4
                                                    color: "#1A2438"
                                                    clip: true
                                                    Rectangle {
                                                        visible: (segItem.s.fraction || -1) >= 0
                                                        width: parent.width * Math.max(0, Math.min(1, segItem.s.fraction || 0))
                                                        height: parent.height
                                                        color: accent.color
                                                    }
                                                    Rectangle {
                                                        visible: (segItem.s.fraction || -1) < 0
                                                        width: 60
                                                        height: parent.height
                                                        color: accent.color
                                                        SequentialAnimation on x {
                                                            running: segItem.s.type === "image" && (segItem.s.fraction || -1) < 0
                                                            loops: Animation.Infinite
                                                            NumberAnimation { from: -60; to: 360; duration: 1300; easing.type: Easing.InOutQuad }
                                                        }
                                                    }
                                                }
                                            }
                                            Image {
                                                id: picture
                                                visible: segItem.s.state === "done" && !!segItem.s.path
                                                source: visible ? "file://" + encodeURI(segItem.s.path) : ""
                                                sourceSize.width: 1120
                                                asynchronous: true
                                                fillMode: Image.PreserveAspectFit
                                                width: Math.min(parent.width, 560)
                                                height: visible && implicitWidth > 0 ? width * implicitHeight / implicitWidth : 0
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: backend.openImage(segItem.s.path)
                                                }
                                            }
                                            Text {
                                                visible: segItem.s.state === "done"
                                                text: (segItem.s.service || "") + "  ·  " + (segItem.s.path || "").split("/").pop()
                                                width: parent.width
                                                elide: Text.ElideMiddle
                                                color: "#5C6880"
                                                font.family: "IBM Plex Sans"
                                                font.pixelSize: 12
                                            }
                                            Flow {
                                                visible: segItem.s.state === "done"
                                                width: parent.width
                                                spacing: 10
                                                FlatButton { small: true; primary: true; text: "Öppna"; onClicked: backend.openImage(segItem.s.path) }
                                                FlatButton { small: true; text: "Visa i mappen"; onClicked: backend.showImageInFolder(segItem.s.path) }
                                                FlatButton {
                                                    small: true
                                                    text: "Spara som…"
                                                    onClicked: { win.pendingImage = segItem.s.path; saveImageDialog.open(); }
                                                }
                                                FlatButton { small: true; text: "Kopiera bilden"; onClicked: backend.copyImage(segItem.s.path) }
                                                FlatButton { visible: !segItem.s.report; small: true; text: "Gör en till"; onClicked: backend.anotherImage(msgItem.index, segItem.index) }
                                                FlatButton { visible: !segItem.s.report; small: true; text: "Använd som avatar"; onClicked: backend.setAvatar(segItem.s.path) }
                                                FlatButton { visible: !segItem.s.report; small: true; text: "Som tänkande avatar"; onClicked: backend.setAvatarThinking(segItem.s.path) }
                                                FlatButton { visible: !segItem.s.report && backend.chatgpt; small: true; text: "Gör om i ChatGPT"; onClicked: backend.imageChatGPT(msgItem.index, segItem.index) }
                                            }
                                            Text {
                                                visible: segItem.s.state === "error"
                                                width: parent.width
                                                wrapMode: Text.WordWrap
                                                text: segItem.s.error || ""
                                                color: accent.errorBright
                                                font.family: "IBM Plex Sans"
                                                font.pixelSize: 13
                                            }
                                            Row {
                                                visible: segItem.s.state === "error"
                                                spacing: 10
                                                FlatButton { small: true; primary: true; text: "Försök igen"; onClicked: backend.retryImage(msgItem.index, segItem.index) }
                                                FlatButton { small: true; text: "AI-tjänster"; onClicked: win.view = "settings" }
                                            }
                                        }

                                        // The memory: saved at once, can be undone
                                        Text {
                                            visible: segItem.s.type === "memory" || segItem.s.type === "forget"
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            textFormat: Text.PlainText
                                            text: {
                                                const done = segItem.s.done || [];
                                                if (segItem.s.state === "undone")
                                                    return "Ångrat.";
                                                if (done.length === 0)
                                                    return segItem.s.type === "memory" ? "Fanns redan i minnet." : "Hittade inget sådant i minnet.";
                                                return (segItem.s.type === "memory" ? "Kommer ihåg:\n" : "Glömde:\n")
                                                       + done.map(t => "• " + t).join("\n");
                                            }
                                            color: "#C9D3E3"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 14
                                        }
                                        FlatButton {
                                            visible: (segItem.s.type === "memory" || segItem.s.type === "forget")
                                                     && segItem.s.state === "saved" && (segItem.s.done || []).length > 0
                                            small: true
                                            text: "Ångra"
                                            onClicked: backend.undoMemory(msgItem.index, segItem.index)
                                        }

                                        // A known solution (28 Oct, point 12): saved at once, can be undone; alike an older one → the choice
                                        Text {
                                            visible: segItem.s.type === "solved"
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            textFormat: Text.PlainText
                                            text: segItem.s.state === "undone" ? "Ångrat."
                                                  : segItem.s.state === "merged" ? "Den äldre lösningen behölls."
                                                  : (segItem.s.action === "confirmed" ? "Bekräftade den kända lösningen – den har fungerat nu:\n"
                                                     : segItem.s.confirmed === false ? "Sparad som känd lösning (ej bekräftad – Kakan frågar om den hjälpte när den används):\n"
                                                     : "Sparad som känd lösning – känns igen nästa gång:\n")
                                                    + "Tecken: " + (segItem.s.question || segItem.s.problem || "") + "\n" + (segItem.s.lesson || "")
                                            color: "#C9D3E3"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 14
                                        }
                                        FlatButton {
                                            visible: segItem.s.type === "solved" && segItem.s.state === "saved"
                                            small: true
                                            text: "Ångra"
                                            onClicked: backend.undoMemory(msgItem.index, segItem.index)
                                        }
                                        SimilarBox {
                                            width: parent.width
                                            visible: segItem.s.type === "solved" && segItem.s.state === "saved" && (segItem.s.similar || []).length > 0
                                            newId: segItem.s.id || ""
                                            olds: segItem.s.type === "solved" ? (segItem.s.similar || []) : []
                                        }

                                        // The AI asks for a screenshot: nothing is taken until the user allows it
                                        Text {
                                            visible: segItem.s.type === "shot"
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            text: segItem.s.state === "new"
                                                  ? "Goblin AI vill se din skärm. Bilden skickas till " + backend.shotTarget + "."
                                                  : segItem.s.state === "running" ? "Tar skärmbilden…"
                                                  : segItem.s.state === "skipped" ? "Ingen skärmbild togs."
                                                  : segItem.s.state === "error" ? (segItem.s.error || "Skärmbilden gick inte att ta.")
                                                  : "Skärmbilden är skickad."
                                            color: segItem.s.state === "error" ? accent.errorBright : "#C9D3E3"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 14
                                        }
                                        Row {
                                            visible: segItem.s.type === "shot" && (segItem.s.state === "new" || segItem.s.state === "error")
                                            spacing: 10
                                            FlatButton {
                                                primary: true
                                                small: true
                                                text: segItem.s.scope === "all" ? "Tillåt – båda skärmarna" : "Tillåt – den här skärmen"
                                                enabledState: !backend.busy && !backend.shooting
                                                onClicked: backend.allowShot(msgItem.index, segItem.index, segItem.s.scope === "all" ? "all" : "screen")
                                            }
                                            FlatButton {
                                                small: true
                                                text: segItem.s.scope === "all" ? "Bara den här skärmen" : "Båda skärmarna"
                                                enabledState: !backend.busy && !backend.shooting
                                                onClicked: backend.allowShot(msgItem.index, segItem.index, segItem.s.scope === "all" ? "screen" : "all")
                                            }
                                            FlatButton {
                                                small: true
                                                text: "Välj område"
                                                enabledState: !backend.busy && !backend.shooting
                                                onClicked: backend.allowShot(msgItem.index, segItem.index, "region")
                                            }
                                            FlatButton {
                                                small: true
                                                text: "Nej"
                                                onClicked: backend.skipShot(msgItem.index, segItem.index)
                                            }
                                        }

                                        // Stopped: something that can't be undone – not shown as something to copy, only why
                                        Text {
                                            visible: segItem.s.type === "blocked"
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            text: (backend.aiName || "Goblin AI") + " föreslog något som " + (segItem.s.why || "inte går att ångra")
                                                  + ". Det körs inte – sådant gör du och Claude."
                                            color: "#E6ECF5"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 14
                                        }

                                        // Command: Tillåt / Nej (changes) or Kör / Hoppa över (reads, when not run at once), then the output
                                        Text {
                                            visible: segItem.s.type === "command" && segItem.s.state === "new" && !!segItem.s.note
                                            text: segItem.s.note || ""
                                            color: "#8B98AD"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 13
                                        }
                                        Row {
                                            visible: segItem.s.type === "command" && segItem.s.state === "new"
                                            spacing: 10
                                            FlatButton {
                                                primary: true
                                                small: true
                                                text: segItem.s.level === "change" ? "Tillåt" : "Kör"
                                                enabledState: !backend.busy
                                                onClicked: backend.runCommand(msgItem.index, segItem.index)
                                            }
                                            FlatButton {
                                                small: true
                                                text: segItem.s.level === "change" ? "Nej" : "Hoppa över"
                                                onClicked: backend.skipCommand(msgItem.index, segItem.index)
                                            }
                                        }
                                        Text {
                                            visible: segItem.s.type === "command" && segItem.s.state !== "new"
                                            text: segItem.s.state === "running" ? "Kör…"
                                                : segItem.s.state === "skipped" ? (segItem.s.level === "change" ? "Inte tillåtet" : "Hoppades över")
                                                : "Klart" + (segItem.s.code_result !== undefined && segItem.s.code_result !== null && segItem.s.code_result !== 0 ? " (fel " + segItem.s.code_result + ")" : "")
                                                  + (segItem.s.level === "change" ? "  ·  ångra under AI-tjänster → Körda kommandon" : "")
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

                        Flow {
                            visible: !msgItem.m.stopped  // STOPP: nothing to copy, save or ♥
                            width: parent.width  // wraps when the window is narrow (Skicka till Claude made it long)
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
                                    onClicked: backend.copyAnswer(msgItem.index)
                                }
                            }
                            Text {
                                text: "Spara som…"
                                color: pdfArea.containsMouse ? "#E6ECF5" : "#5C6880"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                                MouseArea {
                                    id: pdfArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.pendingPdf = msgItem.index;
                                        savePdfDialog.selectedFile = backend.pdfName(msgItem.index);
                                        savePdfDialog.open();
                                    }
                                }
                            }
                            Text {
                                visible: backend.chatgpt
                                text: "Skicka till ChatGPT"
                                color: chatgptArea.containsMouse ? "#E6ECF5" : "#5C6880"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                                MouseArea {
                                    id: chatgptArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.askChatGPT(msgItem.index)
                                }
                            }
                            // Skicka till Claude (point 14, 28 Oct): the chat as a report → Claude Code in a terminal;
                            // Fråga Claude = read-only, the answer comes back here. Both cost Claude quota.
                            Text {
                                visible: backend.claude
                                text: "Skicka till Claude"
                                color: claudeArea.containsMouse ? "#E6ECF5" : "#5C6880"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                                MouseArea {
                                    id: claudeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.sendClaude(msgItem.index, "fix")
                                }
                            }
                            Text {
                                visible: backend.claude
                                text: "Fråga Claude"
                                color: claudeAskArea.containsMouse ? "#E6ECF5" : "#5C6880"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                                MouseArea {
                                    id: claudeAskArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.sendClaude(msgItem.index, "ask")
                                }
                            }
                            Text {
                                text: "Spara som bild"
                                color: reportArea.containsMouse ? "#E6ECF5" : "#5C6880"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                                MouseArea {
                                    id: reportArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.saveReport(msgItem.index)
                                }
                            }
                            // ♥ (21 Oct): a good answer – the AI saves how it did it and does the same next time
                            Text {
                                id: heartText
                                visible: !msgItem.m.thumb
                                property string state_: msgItem.m.heart || ""
                                // The text keeps its width on hover: the row wraps (Flow), and a longer text jumped to
                                // the next line, away from the mouse, and back – flickering (30 Oct). The hint floats above.
                                text: state_ === "busy" ? "♥ Sparar…" : state_ !== "" ? "♥ Sparat" : "♥"
                                color: state_ !== "" && state_ !== "busy" ? accent.errorBright
                                       : heartArea.containsMouse ? "#E6ECF5" : "#5C6880"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                                HoverHint {
                                    shown: heartArea.containsMouse && heartText.state_ !== "busy"
                                    text: heartText.state_ !== "" ? "Ångra" : "Bra svar – gör likadant nästa gång"
                                }
                                MouseArea {
                                    id: heartArea
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.heart(msgItem.index)
                                }
                            }
                            // 👎 (21 Oct): a bad answer – the AI saves what to avoid (the user may say why)
                            Text {
                                visible: !msgItem.m.heart || !!msgItem.m.thumb
                                property string state_: msgItem.m.thumb ? msgItem.m.heart || "" : ""
                                text: state_ === "busy" ? "👎 Sparar…" : state_ !== "" ? "👎 Sparat" : "👎"
                                color: state_ !== "" && state_ !== "busy" ? "#F0883E"
                                       : thumbArea.containsMouse ? "#E6ECF5" : "#5C6880"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                                HoverHint {
                                    shown: thumbArea.containsMouse && parent.state_ !== "busy"
                                    text: parent.state_ !== "" ? "Ångra" : "Dåligt svar – gör inte så här igen"
                                }
                                MouseArea {
                                    id: thumbArea
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (msgItem.m.thumb) {
                                            if (msgItem.m.heart !== "busy")
                                                backend.undoLesson(msgItem.index);
                                        } else {
                                            whyRow.visible = !whyRow.visible;
                                            if (whyRow.visible)
                                                whyInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }
                        // 👎 – what was wrong (optional), then the AI writes the lesson
                        Row {
                            id: whyRow
                            visible: false
                            spacing: 10
                            Rectangle {
                                width: Math.min(460, answer.width - 220)
                                height: 30
                                color: "#07090D"
                                border.width: 1
                                border.color: whyInput.activeFocus ? accent.color : "#1E2A40"
                                TextInput {
                                    id: whyInput
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    maximumLength: 400
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 13
                                    onAccepted: { backend.thumbDown(msgItem.index, text); text = ""; whyRow.visible = false; }
                                    Keys.onEscapePressed: whyRow.visible = false
                                    Text {
                                        visible: whyInput.text === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Vad var fel? (går att hoppa över)"
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
                                onClicked: { backend.thumbDown(msgItem.index, whyInput.text); whyInput.text = ""; whyRow.visible = false; }
                            }
                            FlatButton {
                                small: true
                                text: "Avbryt"
                                onClicked: { whyInput.text = ""; whyRow.visible = false; }
                            }
                        }
                        // Quick buttons (21 Oct): the answer again – shorter, more formal, corrected or in English
                        Row {
                            spacing: 14
                            visible: !!msgItem.m.text && !backend.busy
                            Repeater {
                                model: [["kortare", "Gör kortare"], ["formell", "Mer formell"],
                                        ["stavning", "Rätta stavningen"], ["engelska", "Översätt till engelska"]]
                                Text {
                                    required property var modelData
                                    text: "↻ " + modelData[1]
                                    color: rwArea.containsMouse ? "#E6ECF5" : "#5C6880"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                    MouseArea {
                                        id: rwArea
                                        anchors.fill: parent
                                        anchors.margins: -3
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.rewrite(msgItem.index, parent.modelData[0])
                                    }
                                }
                            }
                        }
                        Text {
                            visible: !!msgItem.m.lesson
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: (msgItem.m.thumb ? "👎 Undvik: " : "♥ Lärdom: ") + (msgItem.m.lesson || "")
                                  + "   (ändra eller ta bort under AI-tjänster → Lärdomar)"
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                        SimilarBox {
                            width: parent.width
                            newId: msgItem.m.heart || ""
                            olds: msgItem.m.similar || []
                        }
                    }
                }
            }

            // ── Own buttons (20 Oct): a saved instruction with its own model, AI-tjänster → Egna knappar ──
            // As words like the rest of the input (26 Oct); also /<namn>
            Flow {
                id: ownButtons
                anchors { left: parent.left; right: parent.right; bottom: inputBar.top; leftMargin: 24; rightMargin: 24; bottomMargin: items.length ? 12 : 0 }
                property var items: JSON.parse(backend.daily)
                height: items.length ? implicitHeight : 0
                spacing: 22
                Repeater {
                    model: ownButtons.items
                    TextAction {
                        required property var modelData
                        required property int index
                        text: "▸ " + modelData.name.toLowerCase()
                        enabledState: !backend.busy
                        onClicked: backend.runButton(index)
                    }
                }
            }

            // ── Input, like a terminal (26 Oct, the user's wish: like Claude Code) ──
            // The buttons are words above the line, ❯ and a blinking block, ↑/↓, Ctrl+R, /commands.
            Item {
                id: inputBar
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 24 }
                height: inputCol.height

                Column {
                    id: inputCol
                    width: parent.width
                    spacing: 10

                    Item {
                        width: parent.width
                        height: tools.height

                        Row {
                            id: tools
                            spacing: 22
                            TextAction {
                                visible: !win.pictureMode && backend.canSearch
                                on: backend.searchNext
                                text: backend.searchNext ? "sök på nätet ✓" : "sök på nätet"
                                onClicked: { backend.setSearchNext(!backend.searchNext); input.forceActiveFocus(); }
                            }
                            TextAction {
                                id: modelButton
                                visible: !win.pictureMode
                                on: modelMenu.visible
                                text: win.modelName(backend.model).toLowerCase() + " ▾"
                                onClicked: {
                                    modelMenu.visible = !modelMenu.visible;
                                    if (modelMenu.visible)
                                        backend.refreshModels();
                                }
                            }
                            TextAction {
                                id: shotButton
                                visible: !win.pictureMode
                                on: shotMenu.visible
                                text: backend.shooting ? "tar bilden…" : "skärmbild ▾"
                                enabledState: !backend.shooting
                                onClicked: shotMenu.visible = !shotMenu.visible
                            }
                            TextAction {
                                visible: !win.pictureMode
                                text: "bifoga fil"
                                onClicked: openDialog.open()
                            }
                            TextAction {
                                visible: backend.canDraw || backend.chatgpt
                                on: win.pictureMode
                                text: win.pictureMode ? "fråga i stället" : "skapa bild"
                                onClicked: { win.pictureMode = !win.pictureMode; input.forceActiveFocus(); }
                            }
                            TextAction {
                                visible: win.pictureMode && backend.chatgpt && backend.canDraw
                                text: "rita i chatgpt"
                                enabledState: input.text.trim() !== ""
                                onClicked: win.sendChatGPT()
                            }
                        }

                        // Right: STOPP while the AI works (the work loop, 25 Oct – it stops after the step it is on), else the keys
                        TextAction {
                            anchors.right: parent.right
                            visible: !win.pictureMode && backend.stoppable
                            danger: true
                            text: "■ stopp (esc)"
                            onClicked: backend.stop()
                        }
                        Text {
                            anchors.right: parent.right
                            visible: win.pictureMode || !backend.stoppable
                            text: win.historySearch ? "↑↓ välj · enter tar · ctrl+r äldre · esc avbryter"
                                : win.pictureMode ? (backend.canDraw ? "enter ritar" : "enter öppnar chatgpt") + " · shift+enter ny rad"
                                : "/ kommandon · ↑ tidigare · ctrl+r sök"
                            color: "#5C6880"
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: input.activeFocus || win.pictureMode ? accent.color : "#1E2A40"
                    }

                    Row {
                        visible: win.attachment !== ""
                        spacing: 8
                        Image {
                            visible: win.isImage(win.attachment)
                            anchors.verticalCenter: parent.verticalCenter
                            source: visible ? win.fileUrl(win.attachment) : ""
                            sourceSize.height: 56
                            height: 56
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.isImage(win.attachment)
                                  ? (win.attachment.indexOf("/goblincakes/ai/bilder/") >= 0 ? "Skärmbild" : backend.fileName(win.attachment))
                                    + " – skickas som bild"
                                  : "📎  " + (win.attachment !== "" ? backend.fileName(win.attachment) : "")
                            color: "#E6ECF5"
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 13
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
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

                    Item {
                        width: parent.width
                        height: inputFlick.height

                        Text {
                            id: promptMark
                            text: win.historySearch ? "sök ❯" : win.pictureMode ? "bild ❯" : "❯"
                            color: accent.text
                            font: input.font
                        }

                        Flickable {
                            id: inputFlick
                            FastWheel { flick: inputFlick }
                            anchors { left: promptMark.right; leftMargin: 10; right: parent.right }
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
                                selectedTextColor: accent.on
                                font.family: "IBM Plex Mono"
                                font.pixelSize: 15
                                Keys.onPressed: event => win.inputKey(event)
                                onTextChanged: {
                                    win.popupIndex = 0;
                                    win.popupClosed = false;
                                    if (!win.modelsAsked && text.startsWith("/modell ")) {
                                        win.modelsAsked = true;
                                        backend.refreshModels();
                                    }
                                }
                                // The line follows the block when the text is longer than the box
                                onCursorRectangleChanged: {
                                    if (cursorRectangle.y < inputFlick.contentY)
                                        inputFlick.contentY = cursorRectangle.y;
                                    else if (cursorRectangle.y + cursorRectangle.height > inputFlick.contentY + inputFlick.height)
                                        inputFlick.contentY = cursorRectangle.y + cursorRectangle.height - inputFlick.height;
                                }

                                cursorDelegate: BlockCaret { edit: input }

                                Text {
                                    visible: input.text === ""
                                    text: win.historySearch ? "sök i det du skrivit tidigare…"
                                        : win.pictureMode ? "beskriv bilden – t.ex. en goblin som skjuter pilbåge i solnedgången, målning"
                                        : backend.aiName ? "skriv till " + backend.aiName + "…" : "skriv din fråga…"
                                    color: "#5C6880"
                                    font: input.font
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: input.activeFocus || win.pictureMode ? accent.color : "#1E2A40"
                    }
                }
            }

            // ── The list above the input: /commands, their choices, Ctrl+R ──
            Rectangle {
                id: cmdPopup
                visible: win.popupItems.length > 0 && input.activeFocus
                z: 20
                width: Math.min(640, inputBar.width)
                height: Math.min(win.popupItems.length * 30, 360) + 2
                anchors { bottom: inputBar.top; bottomMargin: 6 }
                x: inputBar.x
                color: "#0B1018"
                border.width: 1
                border.color: "#2A3852"

                ListView {
                    id: cmdList
                    FastWheel { flick: cmdList }
                    anchors { fill: parent; margins: 1 }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.popupItems
                    currentIndex: Math.min(win.popupIndex, count - 1)
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    onModelChanged: Qt.callLater(() => positionViewAtIndex(Math.max(0, currentIndex), ListView.Contain))
                    delegate: Rectangle {
                        id: cmdRow
                        required property var modelData
                        required property int index
                        readonly property bool chosen: index === cmdList.currentIndex
                        width: cmdList.width
                        height: 30
                        color: chosen ? "#1A2438" : cmdArea.containsMouse ? "#121B2B" : "transparent"
                        Rectangle {
                            visible: cmdRow.chosen
                            width: 3
                            height: parent.height
                            color: accent.color
                        }
                        Text {
                            id: cmdLabel
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            width: cmdRow.modelData.note ? 200 : cmdRow.width - 28
                            elide: Text.ElideRight
                            text: cmdRow.modelData.label
                            color: cmdRow.chosen ? accent.text : "#E6ECF5"
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 13
                        }
                        Text {
                            anchors { left: cmdLabel.right; leftMargin: 12; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: cmdRow.modelData.note
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: cmdArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.takePopup(cmdRow.modelData, true)
                        }
                    }
                }
            }
            // ── The screenshot menu (the button by Skicka) ──
            MouseArea {
                anchors.fill: parent
                visible: shotMenu.visible
                z: 19
                onClicked: shotMenu.visible = false
            }
            Rectangle {
                id: shotMenu
                visible: false
                z: 20
                width: 240
                height: shotMenuCol.height + 2
                anchors { bottom: inputBar.top; bottomMargin: 6 }
                x: Math.max(24, Math.min(inputBar.x + shotButton.x, chatArea.width - width - 24))
                color: "#0B1018"
                border.width: 1
                border.color: "#2A3852"
                Column {
                    id: shotMenuCol
                    x: 1
                    y: 1
                    width: parent.width - 2
                    Repeater {
                        model: [
                            { scope: "screen", name: "Den här skärmen", note: "skärmen där muspekaren är" },
                            { scope: "all", name: "Båda skärmarna", note: "allt på en gång" },
                            { scope: "region", name: "Välj ett område", note: "dra en ruta – Esc avbryter" }
                        ]
                        Rectangle {
                            id: shotItem
                            required property var modelData
                            width: shotMenuCol.width
                            height: 44
                            color: shotArea.containsMouse ? "#1A2438" : "transparent"
                            Column {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Text {
                                    text: shotItem.modelData.name
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 14
                                }
                                Text {
                                    text: shotItem.modelData.note
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                }
                            }
                            MouseArea {
                                id: shotArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    shotMenu.visible = false;
                                    backend.takeScreenshot(shotItem.modelData.scope);
                                }
                            }
                        }
                    }
                }
            }

            // ── The model menu (the button by Skicka), like switching model in Claude Code ──
            MouseArea {  // a click beside the menu closes it
                anchors.fill: parent
                visible: modelMenu.visible
                z: 19
                onClicked: modelMenu.visible = false
            }
            Rectangle {
                id: modelMenu
                visible: false
                z: 20
                property var items: JSON.parse(backend.modelChoices)
                width: 380
                height: Math.min(modelList.contentHeight + 2, chatArea.height - inputBar.height - 80)
                anchors { bottom: inputBar.top; bottomMargin: 6 }
                x: Math.max(24, Math.min(inputBar.x + modelButton.x, chatArea.width - width - 24))
                color: "#0B1018"
                border.width: 1
                border.color: "#2A3852"
                Keys.onEscapePressed: visible = false

                ListView {
                    id: modelList
                    FastWheel { flick: modelList }
                    anchors { fill: parent; margins: 1 }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: modelMenu.items
                    header: Text {
                        width: modelList.width
                        visible: backend.modelsLoading
                        height: visible ? 30 : 0
                        leftPadding: 14
                        topPadding: 8
                        text: "Hämtar modellerna…"
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                    delegate: Column {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool firstInGroup: index === 0 || modelMenu.items[index - 1].group !== modelData.group
                        readonly property bool chosen: modelData.name !== "" && modelData.id === backend.model
                        width: modelList.width

                        Label {
                            visible: row.modelData.group !== "" && row.firstInGroup
                            text: row.modelData.group.toUpperCase()
                            leftPadding: 14
                            topPadding: 12
                            bottomPadding: 4
                            font.pixelSize: 11
                        }
                        Rectangle {
                            width: parent.width
                            height: row.modelData.name !== "" ? 44 : 28
                            color: pickArea.containsMouse && row.modelData.name !== "" ? "#1A2438" : "transparent"
                            Rectangle {  // the chosen one: an accent line, like the tabs
                                visible: row.chosen
                                width: 3
                                height: parent.height
                                color: accent.color
                            }
                            Column {
                                anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 30; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Row {
                                    visible: row.modelData.name !== ""
                                    spacing: 8
                                    Text {
                                        width: Math.min(implicitWidth, modelList.width - 44 - (rowTag.visible ? rowTag.width + 8 : 0))
                                        elide: Text.ElideRight
                                        text: row.modelData.name
                                        color: row.chosen ? accent.text : "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.weight: row.chosen ? Font.DemiBold : Font.Normal
                                        font.pixelSize: 14
                                    }
                                    ModelTag { id: rowTag; tag: row.modelData.tag || ""; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: row.modelData.note
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                }
                            }
                            Text {
                                visible: row.chosen
                                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                text: "✓"
                                color: accent.text
                                font.pixelSize: 15
                            }
                            MouseArea {
                                id: pickArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: row.modelData.name !== ""
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    backend.setModel(row.modelData.id);
                                    modelMenu.visible = false;
                                    input.forceActiveFocus();
                                }
                            }
                        }
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
            anchors { left: parent.left; leftMargin: win.sideSpace; right: parent.right; top: parent.top; bottom: parent.bottom }

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
                                                Keys.onTabPressed: event => { insert(cursorPosition, taskCard.modelData.file.endsWith(".gd") ? "\t" : "  "); event.accepted = true; }
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
            anchors { left: parent.left; leftMargin: win.sideSpace; right: parent.right; top: parent.top; bottom: parent.bottom }
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
            anchors { left: parent.left; leftMargin: win.sideSpace; right: parent.right; top: parent.top; bottom: parent.bottom }
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

                // ── The AI's own name (16 Oct) ──
                Rectangle {
                    width: settingsCol.width
                    height: nameCol.height + 36
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"

                    Column {
                        id: nameCol
                        x: 20
                        y: 18
                        width: parent.width - 40
                        spacing: 12
                        Text {
                            text: "Namn"
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: backend.aiName
                                  ? "Din AI heter " + backend.aiName + (backend.aiGender ? " (" + backend.aiGender + ")" : "") + " – i alla chattar och i snabbrutan (Meta+§), både lokalt och i molnet."
                                  : "Ge din AI ett eget namn, så kallar den sig det i alla chattar – t.ex. Kakan."
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                        Row {
                            spacing: 10
                            Rectangle {
                                width: 240
                                height: 30
                                color: "#07090D"
                                border.width: 1
                                border.color: nameInput.activeFocus ? accent.color : "#1E2A40"
                                TextInput {
                                    id: nameInput
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    maximumLength: 30
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 13
                                    onAccepted: { backend.setAiName(text); text = ""; }
                                    Text {
                                        visible: nameInput.text === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: backend.aiName || "Goblin AI"
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
                                enabledState: nameInput.text.trim() !== ""
                                onClicked: { backend.setAiName(nameInput.text); nameInput.text = ""; }
                            }
                            FlatButton {
                                visible: backend.aiName !== ""
                                small: true
                                text: "Heta Goblin AI igen"
                                onClicked: backend.setAiName("")
                            }
                        }
                        // Gender (20 Oct, the user's wish – cosmetic: how the AI speaks of and draws itself)
                        Row {
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 60
                                text: "Är en"
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Repeater {
                                model: [["hon", "Hon"], ["han", "Han"], ["hen", "Hen"], ["", "Inget valt"]]
                                FlatButton {
                                    required property var modelData
                                    small: true
                                    primary: backend.aiGender === modelData[0]
                                    text: modelData[1]
                                    onClicked: backend.setAiGender(modelData[0])
                                }
                            }
                        }
                    }
                }

                // ── The AI's avatar (20 Oct): own picture or one it draws ──
                Rectangle {
                    width: settingsCol.width
                    height: avatarCol.height + 36
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"

                    Column {
                        id: avatarCol
                        x: 20
                        y: 18
                        width: parent.width - 40
                        spacing: 12
                        Text {
                            text: "Avatar"
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                        }
                        Row {
                            width: parent.width
                            spacing: 16
                            Rectangle {
                                width: 72
                                height: 72
                                color: "#07090D"
                                border.width: 1
                                border.color: "#1E2A40"
                                Image {
                                    visible: backend.avatar !== ""
                                    anchors { fill: parent; margins: 1 }
                                    source: backend.avatar
                                    sourceSize: Qt.size(140, 140)
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false
                                }
                                Text {
                                    visible: backend.avatar === ""
                                    anchors.centerIn: parent
                                    text: "?"
                                    color: "#5C6880"
                                    font.family: "Chakra Petch"
                                    font.pixelSize: 28
                                }
                            }
                            Text {
                                width: parent.width - 88
                                anchors.verticalCenter: parent.verticalCenter
                                wrapMode: Text.WordWrap
                                text: (backend.avatar
                                       ? "Visas vid varje svar från " + (backend.aiName || "Goblin AI") + ". "
                                       : "Ge " + (backend.aiName || "Goblin AI") + " en bild som visas vid varje svar. ")
                                      + "Välj en egen bild, eller beskriv hur avataren ska se ut så ritar "
                                      + (backend.aiName || "Goblin AI") + " den – tryck sedan \"Använd som avatar\" under bilden."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                        }
                        Row {
                            spacing: 10
                            Rectangle {
                                width: 320
                                height: 30
                                color: "#07090D"
                                border.width: 1
                                border.color: avatarInput.activeFocus ? accent.color : "#1E2A40"
                                TextInput {
                                    id: avatarInput
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 13
                                    onAccepted: avatarDraw.clicked()
                                    Text {
                                        visible: avatarInput.text === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "T.ex. en goblin som bakar cupcakes"
                                        color: "#5C6880"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                    }
                                }
                            }
                            FlatButton {
                                id: avatarDraw
                                small: true
                                primary: true
                                text: "Rita den"
                                enabledState: avatarInput.text.trim() !== "" && !backend.busy
                                onClicked: {
                                    if (!enabledState)
                                        return;
                                    backend.askNew("Rita en avatar åt dig själv: " + avatarInput.text.trim());
                                    avatarInput.text = "";
                                    win.view = "chat";
                                }
                            }
                            FlatButton { small: true; text: "Välj bild…"; onClicked: avatarDialog.open() }
                            FlatButton {
                                visible: backend.avatar !== ""
                                small: true
                                text: "Ta bort"
                                onClicked: backend.removeAvatar()
                            }
                        }

                        // The thinking avatar (24 Oct): shown while the AI works, instead of "tänker…"
                        Row {
                            width: parent.width
                            spacing: 16
                            Rectangle {
                                width: 72
                                height: 72
                                color: "#07090D"
                                border.width: 1
                                border.color: "#1E2A40"
                                Image {
                                    visible: backend.avatarThinking !== ""
                                    anchors { fill: parent; margins: 1 }
                                    source: backend.avatarThinking
                                    sourceSize: Qt.size(140, 140)
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false
                                }
                                Text {
                                    visible: backend.avatarThinking === ""
                                    anchors.centerIn: parent
                                    text: "?"
                                    color: "#5C6880"
                                    font.family: "Chakra Petch"
                                    font.pixelSize: 28
                                }
                            }
                            Column {
                                width: parent.width - 88
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: "Tänkande avatar – visas medan " + (backend.aiName || "Goblin AI")
                                          + " arbetar, i stället för texten om vad " + (backend.aiName || "Goblin AI") + " gör."
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 13
                                }
                                Row {
                                    spacing: 10
                                    FlatButton {
                                        small: true
                                        primary: true
                                        text: "Rita den"
                                        enabledState: !backend.busy
                                        onClicked: {
                                            if (!enabledState)
                                                return;
                                            backend.askNew(backend.thinkingAvatarAsk());
                                            win.view = "chat";
                                        }
                                    }
                                    FlatButton { small: true; text: "Välj bild…"; onClicked: avatarThinkingDialog.open() }
                                    FlatButton {
                                        visible: backend.avatarThinking !== ""
                                        small: true
                                        text: "Ta bort"
                                        onClicked: backend.removeAvatarThinking()
                                    }
                                }
                            }
                        }
                    }
                }

                // ── The memory (16 Oct): what the AI always knows ──
                Rectangle {
                    id: memCard
                    property bool open: false
                    width: settingsCol.width
                    height: memCol.height + 36
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"
                    property var items: JSON.parse(backend.memory)

                    Column {
                        id: memCol
                        x: 20
                        y: 18
                        width: parent.width - 40
                        spacing: 10
                        // Folded by default (25 Oct, the user: AI-tjänster got long) – the title opens it
                        Text {
                            width: parent.width
                            text: (memCard.open ? "▾  " : "▸  ") + "Minne" + (memCard.items.length ? "   (" + memCard.items.length + ")" : "")
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: memCard.open = !memCard.open
                            }
                        }
                        Column {
                            visible: memCard.open
                            width: parent.width
                            spacing: 10
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Saker " + (backend.aiName || "Goblin AI") + " alltid vet, i alla chattar. Säg \"kom ihåg att …\" eller \"glöm att …\" i en chatt, eller skriv här. "
                                      + "Minnet skickas med varje fråga – även till tjänster på nätet när de används, så skriv inget hemligt."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Repeater {
                                model: memCard.items
                                Row {
                                    id: memRow
                                    required property var modelData
                                    required property int index
                                    width: memCol.width
                                    spacing: 10
                                    Text {
                                        width: parent.width - 30
                                        wrapMode: Text.WordWrap
                                        text: "• " + memRow.modelData.text
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        text: "×"
                                        color: memX.containsMouse ? accent.errorBright : "#8B98AD"
                                        font.pixelSize: 18
                                        MouseArea {
                                            id: memX
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: backend.removeMemory(memRow.index)
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: 10
                                Rectangle {
                                    width: Math.min(460, memCol.width - 110)
                                    height: 30
                                    color: "#07090D"
                                    border.width: 1
                                    border.color: memInput.activeFocus ? accent.color : "#1E2A40"
                                    TextInput {
                                        id: memInput
                                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                        verticalAlignment: TextInput.AlignVCenter
                                        clip: true
                                        maximumLength: 300
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                        onAccepted: if (text.trim() !== "") { backend.addMemory(text); text = ""; }
                                        Text {
                                            visible: memInput.text === ""
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "T.ex. Spelar WoW som Kaytho på Stormscale (EU)"
                                            color: "#5C6880"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 13
                                        }
                                    }
                                }
                                FlatButton {
                                    small: true
                                    primary: true
                                    text: "Lägg till"
                                    enabledState: memInput.text.trim() !== ""
                                    onClicked: { backend.addMemory(memInput.text); memInput.text = ""; }
                                }
                            }
                        }
                    }
                }

                // ── The lessons (21 Oct): what the ♥ under good answers saved ──
                Rectangle {
                    id: lessonCard
                    property bool open: false
                    width: settingsCol.width
                    height: heartCol.height + 36
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"
                    property var items: JSON.parse(backend.lessons)
                    property var categories: JSON.parse(backend.lessonCategories)
                    property string openCat: ""  // the category shown (28 Oct: one at a time, the list grows fast)
                    property string choosing: ""  // the lesson whose category choice is open
                    // The clicked category's row stays where it was when the open one above it closes (28 Oct,
                    // the user: the window jumped far down)
                    property string keepCat: ""
                    property real keepY: 0
                    Timer { id: keepTimer; interval: 400; onTriggered: lessonCard.keepCat = "" }
                    function inCat(c) { return items.filter(i => i.category === c); }

                    Column {
                        id: heartCol
                        x: 20
                        y: 18
                        width: parent.width - 40
                        spacing: 10
                        // Folded by default (25 Oct, the user: AI-tjänster got long) – the title opens it
                        Text {
                            width: parent.width
                            text: (lessonCard.open ? "▾  " : "▸  ") + "Lärdomar och lösningar  ♥ 🔧" + (lessonCard.items.length ? "   (" + lessonCard.items.length + ")" : "")
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: lessonCard.open = !lessonCard.open
                            }
                        }
                        Column {
                            visible: lessonCard.open
                            width: parent.width
                            spacing: 10
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Tryck ♥ under ett bra svar, så skriver " + (backend.aiName || "Goblin AI") + " en kort lärdom om hur det gick till – 👎 under ett dåligt, så skrivs vad som ska undvikas. "
                                      + "Vid en liknande fråga följer de 2–3 lärdomar som passar bäst med. Ett hjärta på ett svar som var fel lär in felet – "
                                      + "ändra eller ta bort sådana här. Klicka på en lärdom för att ändra den. Liknar en ny lärdom en äldre får du välja vilken som ska vara kvar. "
                                      + "🔧 = kända lösningar: problem som lösts (sparas när du sagt att det fungerar, eller av Claude) – de följer med när samma tecken kommer igen."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Row {
                                visible: lessonCard.items.length > 1
                                spacing: 12
                                FlatButton {
                                    small: true
                                    text: backend.similarBusy ? "Letar…" : "Hitta liknande"
                                    enabledState: !backend.similarBusy
                                    onClicked: if (!backend.similarBusy) backend.findSimilar()
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        const n = lessonCard.items.filter(i => i.similarItems.length > 0).length;
                                        return n ? n + " lärdomar liknar en äldre – välj under dem (▸ öppna kategorin)"
                                                 : "går igenom alla och visar lärdomar som kanske är samma sak";
                                    }
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                }
                            }
                            Text {
                                visible: lessonCard.items.length === 0
                                text: "Inga lärdomar än."
                                color: "#5C6880"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            // One row per category with lessons – only the opened one shows them
                            Repeater {
                                model: lessonCard.categories.filter(c => lessonCard.inCat(c.id).length > 0)
                                Column {
                                    id: catRow
                                    required property var modelData
                                    width: heartCol.width
                                    spacing: 10
                                    onYChanged: if (lessonCard.keepCat === modelData.id) {
                                        settings.contentY = Math.max(0, settings.contentY + y - lessonCard.keepY);
                                        lessonCard.keepY = y;
                                    }
                                    Text {
                                        text: (lessonCard.openCat === catRow.modelData.id ? "▾  " : "▸  ") + catRow.modelData.name
                                              + "   (" + lessonCard.inCat(catRow.modelData.id).length + ")"
                                              + (lessonCard.inCat(catRow.modelData.id).some(i => i.similarItems.length > 0) ? "   · att välja" : "")
                                        color: catHead.containsMouse ? accent.text : "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 14
                                        MouseArea {
                                            id: catHead
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                lessonCard.keepCat = catRow.modelData.id;
                                                lessonCard.keepY = catRow.y;
                                                keepTimer.restart();
                                                lessonCard.openCat = lessonCard.openCat === catRow.modelData.id ? "" : catRow.modelData.id;
                                            }
                                        }
                                    }
                                    Column {
                                        visible: lessonCard.openCat === catRow.modelData.id
                                        width: parent.width
                                        spacing: 10
                                        leftPadding: 16
                                        Repeater {
                                            model: lessonCard.inCat(catRow.modelData.id)
                                            Column {
                                                id: lessonRow
                                                required property var modelData
                                                width: heartCol.width - 16
                                                spacing: 4
                                                Text {
                                                    width: parent.width - 30
                                                    elide: Text.ElideRight
                                                    text: (lessonRow.modelData.kind === "avoid" ? "👎 Undvik  ·  Frågan: "
                                                       : lessonRow.modelData.kind === "solution"
                                                         ? "🔧 Lösning" + (lessonRow.modelData.confirmed ? "" : " (ej bekräftad)")
                                                           + (lessonRow.modelData.source === "claude" ? " från Claude" : lessonRow.modelData.source === "claude-fix" ? " från Claude Code" : "")
                                                           + "  ·  Tecken: "
                                                         : "♥  ·  Frågan: ") + lessonRow.modelData.question + "  ·  " + lessonRow.modelData.added
                                                      + (lessonRow.modelData.used ? "  ·  använd " + lessonRow.modelData.used + " ggr" : "")
                                                    color: "#5C6880"
                                                    font.family: "IBM Plex Sans"
                                                    font.pixelSize: 12
                                                }
                                                // Byt kategori: the choices open under the line
                                                Text {
                                                    text: lessonCard.choosing === lessonRow.modelData.id ? "▾ Byt kategori" : "▸ Byt kategori"
                                                    color: catSwitch.containsMouse ? accent.text : "#5C6880"
                                                    font.family: "IBM Plex Sans"
                                                    font.pixelSize: 12
                                                    MouseArea {
                                                        id: catSwitch
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: lessonCard.choosing = lessonCard.choosing === lessonRow.modelData.id ? "" : lessonRow.modelData.id
                                                    }
                                                }
                                                Flow {
                                                    visible: lessonCard.choosing === lessonRow.modelData.id
                                                    width: parent.width - 30
                                                    spacing: 6
                                                    Repeater {
                                                        model: lessonCard.categories
                                                        Rectangle {
                                                            id: catChoice
                                                            required property var modelData
                                                            property bool current: modelData.id === lessonRow.modelData.category
                                                            width: catChoiceText.implicitWidth + 16
                                                            height: 24
                                                            color: current ? accent.color : (catChoiceArea.containsMouse ? "#12203A" : "transparent")
                                                            border.width: 1
                                                            border.color: current ? accent.color : "#1E2A40"
                                                            Text {
                                                                id: catChoiceText
                                                                anchors.centerIn: parent
                                                                text: catChoice.modelData.name
                                                                color: catChoice.current ? accent.on : "#E6ECF5"
                                                                font.family: "IBM Plex Sans"
                                                                font.pixelSize: 12
                                                            }
                                                            MouseArea {
                                                                id: catChoiceArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    lessonCard.choosing = "";
                                                                    backend.setLessonCategory(lessonRow.modelData.id, catChoice.modelData.id);
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                Row {
                                                    width: parent.width
                                                    spacing: 10
                                                    Rectangle {
                                                        width: parent.width - 30
                                                        height: lessonEdit.contentHeight + 12
                                                        color: lessonEdit.activeFocus ? "#07090D" : "transparent"
                                                        border.width: lessonEdit.activeFocus ? 1 : 0
                                                        border.color: accent.color
                                                        TextEdit {
                                                            id: lessonEdit
                                                            anchors { fill: parent; margins: 6 }
                                                            text: lessonRow.modelData.lesson
                                                            wrapMode: TextEdit.WordWrap
                                                            selectByMouse: true
                                                            color: "#E6ECF5"
                                                            font.family: "IBM Plex Sans"
                                                            font.pixelSize: 14
                                                            Keys.onReturnPressed: event => { focus = false; event.accepted = true; }
                                                            onActiveFocusChanged: if (!activeFocus && text.trim() !== "" && text !== lessonRow.modelData.lesson)
                                                                                      backend.editLesson(lessonRow.modelData.id, text)
                                                        }
                                                    }
                                                    Text {
                                                        text: "×"
                                                        color: lessonX.containsMouse ? accent.errorBright : "#8B98AD"
                                                        font.pixelSize: 18
                                                        MouseArea {
                                                            id: lessonX
                                                            anchors.fill: parent
                                                            anchors.margins: -6
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: backend.removeLesson(lessonRow.modelData.id)
                                                        }
                                                    }
                                                }
                                                SimilarBox {
                                                    width: parent.width - 30
                                                    newId: lessonRow.modelData.id
                                                    olds: lessonRow.modelData.similarItems
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Körda kommandon (25 Oct): everything run from the chat, with Ångra; reading commands at once on/off ──
                Rectangle {
                    id: cmdLogCard
                    property bool open: false
                    width: settingsCol.width
                    height: cmdLogCol.height + 36
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"
                    property var items: JSON.parse(backend.commandLog)
                    property var undoing: JSON.parse(backend.undoing)
                    property string asking: ""  // the entry whose Ångra waits for "Ångra nu"
                    property int shown: 10

                    Column {
                        id: cmdLogCol
                        x: 20
                        y: 18
                        width: parent.width - 40
                        spacing: 10
                        // Folded by default (25 Oct, the user: AI-tjänster got long) – the title opens it
                        Text {
                            width: parent.width
                            text: (cmdLogCard.open ? "▾  " : "▸  ") + "Körda kommandon" + (cmdLogCard.items.length ? "   (" + cmdLogCard.items.length + ")" : "")
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cmdLogCard.open = !cmdLogCard.open
                            }
                        }
                        Column {
                            visible: cmdLogCard.open
                            width: parent.width
                            spacing: 10
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Kommandon som bara läser körs direkt. De som ändrar något körs först när du trycker Tillåt – före körningen sparas en kopia av filer som skrivs över "
                                      + "och gamla värden, så att de går att ångra här. Sådant som inte går att ångra (radera för gott, formatera diskar, byta system …) körs aldrig."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Item {
                                width: autorunRow.width
                                height: autorunRow.height
                                Row {
                                    id: autorunRow
                                    spacing: 10
                                    Rectangle {
                                        width: 18
                                        height: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: backend.autorun ? accent.color : "transparent"
                                        border.width: 1
                                        border.color: backend.autorun ? accent.color : "#5C6880"
                                        Text {
                                            anchors.centerIn: parent
                                            visible: backend.autorun
                                            text: "✓"
                                            color: accent.on
                                            font.pixelSize: 13
                                        }
                                    }
                                    Text {
                                        text: "Kör kommandon som bara läser direkt (av = du trycker Kör på varje)"
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.setAutorun(!backend.autorun)
                                }
                            }
                            Text {
                                visible: cmdLogCard.items.length === 0
                                text: "Inget kört än."
                                color: "#5C6880"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Repeater {
                                model: cmdLogCard.items.slice(0, cmdLogCard.shown)
                                Column {
                                    id: logRow
                                    required property var modelData
                                    readonly property var e: modelData
                                    width: cmdLogCol.width
                                    spacing: 4
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: logRow.e.t + "  ·  " + (logRow.e.by === "auto" ? "körde direkt (läser)" : logRow.e.by === "kakan" ? (backend.aiName || "Goblin AI") + " gjorde direkt" : logRow.e.by === "ångra" ? "ångring" : "du tillät")
                                              + "  ·  " + (logRow.e.exit === null || logRow.e.exit === undefined ? "i terminalen" : logRow.e.exit === 0 ? "klart" : "fel " + logRow.e.exit)
                                              + (logRow.e.undone ? "  ·  ångrat " + logRow.e.undone : "")
                                        color: logRow.e.exit && logRow.e.exit !== 0 ? "#E8A0A4" : "#5C6880"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        width: parent.width
                                        wrapMode: Text.WrapAnywhere
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        text: logRow.e.code
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Mono"
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        visible: !!logRow.e.hint && !logRow.e.undone
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        text: "Ångra: " + (logRow.e.hint || "")
                                        color: "#8B98AD"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 12
                                    }
                                    // Ångra: shows what will run first, then "Ångra nu" runs it (that click is the Tillåt)
                                    Text {
                                        visible: cmdLogCard.asking === logRow.e.id
                                        width: parent.width
                                        wrapMode: Text.WrapAnywhere
                                        text: logRow.e.undo || ""
                                        color: "#8B98AD"
                                        font.family: "IBM Plex Mono"
                                        font.pixelSize: 12
                                    }
                                    Row {
                                        visible: !!logRow.e.undo && !logRow.e.undone
                                        spacing: 10
                                        FlatButton {
                                            small: true
                                            primary: cmdLogCard.asking === logRow.e.id
                                            text: cmdLogCard.undoing.indexOf(logRow.e.id) >= 0 ? "Ångrar…"
                                                : cmdLogCard.asking === logRow.e.id ? "Ångra nu" : "Ångra"
                                            enabledState: cmdLogCard.undoing.indexOf(logRow.e.id) < 0
                                            onClicked: {
                                                if (cmdLogCard.asking === logRow.e.id) {
                                                    backend.undoCommand(logRow.e.id)
                                                    cmdLogCard.asking = ""
                                                } else {
                                                    cmdLogCard.asking = logRow.e.id
                                                }
                                            }
                                        }
                                        FlatButton {
                                            visible: cmdLogCard.asking === logRow.e.id
                                            small: true
                                            text: "Avbryt"
                                            onClicked: cmdLogCard.asking = ""
                                        }
                                    }
                                    Text {
                                        visible: !!logRow.e.undone && !!logRow.e.undo_out
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        text: logRow.e.undo_out || ""
                                        color: "#5C6880"
                                        font.family: "IBM Plex Mono"
                                        font.pixelSize: 12
                                    }
                                }
                            }
                            FlatButton {
                                visible: cmdLogCard.items.length > cmdLogCard.shown
                                small: true
                                text: "Visa fler"
                                onClicked: cmdLogCard.shown += 20
                            }
                        }
                    }
                }

                // ── MCP-servrar (punkt 8, 28 Oct): ready-made tools from outside, in podman containers ──
                Rectangle {
                    id: mcpCard
                    property bool open: false
                    property var items: JSON.parse(backend.mcpServers)
                    readonly property bool hasGithub: items.some(function (x) { return x.server === "github"; })
                    readonly property bool hasBrowser: items.some(function (x) { return x.server === "webblasare"; })
                    width: settingsCol.width
                    height: mcpCol.height + 36
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"

                    Column {
                        id: mcpCol
                        x: 20
                        y: 18
                        width: parent.width - 40
                        spacing: 10
                        Text {
                            width: parent.width
                            text: (mcpCard.open ? "▾  " : "▸  ") + "MCP-servrar" + (mcpCard.items.length ? "   (" + mcpCard.items.length + ")" : "")
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mcpCard.open = !mcpCard.open
                            }
                        }
                        Column {
                            visible: mcpCard.open
                            width: parent.width
                            spacing: 10
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Färdiga verktyg utifrån som " + (backend.aiName || "Goblin AI") + " kan använda. Servrarna körs i podman-containrar, startar när de behövs och stängs efter 5 minuter eller när ett spel startar. "
                                      + "Verktyg som bara läser körs direkt, de som ändrar något ger ett Tillåt-kort. Slå bara på de verktyg du behöver – varje verktyg tar plats i den lokala AI:ns minne."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Text {
                                visible: backend.mcpBusy
                                text: "Startar servern och hämtar verktygen …"
                                color: accent.text
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Repeater {
                                model: mcpCard.items
                                Column {
                                    id: mcpRow
                                    required property var modelData
                                    readonly property var s: modelData
                                    width: mcpCol.width
                                    spacing: 6
                                    Row {
                                        spacing: 10
                                        Item {
                                            width: mcpOnRow.width
                                            height: 30
                                            Row {
                                                id: mcpOnRow
                                                spacing: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                Rectangle {
                                                    width: 18
                                                    height: 18
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: !mcpRow.s.off ? accent.color : "transparent"
                                                    border.width: 1
                                                    border.color: !mcpRow.s.off ? accent.color : "#5C6880"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: !mcpRow.s.off
                                                        text: "✓"
                                                        color: accent.on
                                                        font.pixelSize: 13
                                                    }
                                                }
                                                Text {
                                                    text: mcpRow.s.title
                                                    color: "#E6ECF5"
                                                    font.family: "IBM Plex Sans"
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: 14
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: backend.setMcpOff(mcpRow.s.server, !mcpRow.s.off)
                                            }
                                        }
                                        FlatButton {
                                            small: true
                                            text: "Uppdatera"
                                            enabledState: !backend.mcpBusy
                                            onClicked: backend.refreshMcp(mcpRow.s.server)
                                        }
                                        FlatButton {
                                            small: true
                                            text: "Ta bort"
                                            onClicked: backend.removeMcp(mcpRow.s.server)
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: mcpRow.s.where + (mcpRow.s.when ? "  ·  verktygen hämtade " + mcpRow.s.when : mcpRow.s.error ? "  ·  gick inte: " + mcpRow.s.error : "  ·  verktygen hämtas vid nästa fråga")
                                        color: "#5C6880"
                                        font.family: "IBM Plex Mono"
                                        font.pixelSize: 12
                                    }
                                    Repeater {
                                        model: mcpRow.s.tools
                                        Item {
                                            id: mcpTool
                                            required property var modelData
                                            width: mcpRow.width
                                            height: mcpToolRow.height
                                            Row {
                                                id: mcpToolRow
                                                x: 28
                                                spacing: 10
                                                width: parent.width - 28
                                                Rectangle {
                                                    width: 16
                                                    height: 16
                                                    y: 2
                                                    color: mcpTool.modelData.on ? accent.color : "transparent"
                                                    border.width: 1
                                                    border.color: mcpTool.modelData.on ? accent.color : "#5C6880"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: mcpTool.modelData.on
                                                        text: "✓"
                                                        color: accent.on
                                                        font.pixelSize: 11
                                                    }
                                                }
                                                Text {
                                                    width: parent.width - 26
                                                    elide: Text.ElideRight
                                                    text: mcpTool.modelData.name + (mcpTool.modelData.readonly ? "" : "  (Tillåt)") + "  –  " + mcpTool.modelData.description
                                                    color: mcpTool.modelData.on ? "#E6ECF5" : "#8B98AD"
                                                    font.family: "IBM Plex Sans"
                                                    font.pixelSize: 13
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: backend.setMcpTool(mcpRow.s.server, mcpTool.modelData.name, !mcpTool.modelData.on)
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: !mcpCard.hasGithub
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "GitHub (GitHubs officiella server, bara läsning): byggen, commits, filer och issues i dina repon. Skapa en token med bara läsrätt (Fine-grained: Contents, Issues, Actions, Metadata – Read-only) och klistra in den."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Row {
                                visible: !mcpCard.hasGithub
                                spacing: 10
                                FlatButton {
                                    small: true
                                    text: "Skapa token"
                                    onClicked: Qt.openUrlExternally("https://github.com/settings/personal-access-tokens/new")
                                }
                                Rectangle {
                                    width: 300
                                    height: 30
                                    color: "#07090D"
                                    border.width: 1
                                    border.color: githubInput.activeFocus ? accent.color : "#1E2A40"
                                    TextInput {
                                        id: githubInput
                                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: TextInput.Password
                                        clip: true
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Mono"
                                        font.pixelSize: 13
                                        onAccepted: { backend.addGithub(text); text = ""; }
                                        Text {
                                            visible: githubInput.text === ""
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Klistra in GitHub-token här"
                                            color: "#5C6880"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 13
                                        }
                                    }
                                }
                                FlatButton {
                                    small: true
                                    primary: true
                                    text: "Lägg till GitHub"
                                    enabledState: githubInput.text !== "" && !backend.mcpBusy
                                    onClicked: { backend.addGithub(githubInput.text); githubInput.text = ""; }
                                }
                            }
                            Text {
                                visible: !mcpCard.hasBrowser
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Webbläsaren (Microsofts Playwright-server): en egen webbläsare i en container, utan dina inloggningar – Kakan kan öppna sidor, klicka och fylla i. Öppna och läsa går direkt, klicka och skriva kräver Tillåt. Hämtar ca 1 GB första gången."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            FlatButton {
                                visible: !mcpCard.hasBrowser
                                small: true
                                primary: true
                                text: backend.mcpBusy ? "Hämtar …" : "Lägg till webbläsaren"
                                enabledState: !backend.mcpBusy
                                onClicked: backend.addPlaywright()
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Annan server: klistra in raden ur serverns README (\"namn\": {\"command\": \"docker\", …} – docker blir podman) och tryck Lägg till, eller skriv in den i mcp.json. Den går att använda direkt. Ta bara servrar från kända avsändare."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Rectangle {
                                width: parent.width
                                height: Math.max(60, mcpPaste.contentHeight + 16)
                                color: "#07090D"
                                border.width: 1
                                border.color: mcpPaste.activeFocus ? accent.color : "#1E2A40"
                                TextEdit {
                                    id: mcpPaste
                                    anchors { fill: parent; margins: 8 }
                                    wrapMode: TextEdit.WrapAnywhere
                                    color: "#E6ECF5"
                                    selectByMouse: true
                                    font.family: "IBM Plex Mono"
                                    font.pixelSize: 12
                                    Text {
                                        visible: mcpPaste.text === ""
                                        text: "\"namn\": { \"command\": \"podman\", \"args\": [\"run\", \"-i\", \"--rm\", \"…\"] }"
                                        color: "#5C6880"
                                        font: mcpPaste.font
                                    }
                                }
                            }
                            Row {
                                spacing: 10
                                FlatButton {
                                    small: true
                                    primary: true
                                    text: "Lägg till"
                                    enabledState: mcpPaste.text.trim() !== "" && !backend.mcpBusy
                                    onClicked: { backend.addMcpText(mcpPaste.text); mcpPaste.text = ""; }
                                }
                                FlatButton {
                                    small: true
                                    text: "Öppna mcp.json"
                                    onClicked: backend.openMcpFile()
                                }
                            }
                        }
                    }
                }

                // ── Own buttons (20 Oct): above the input, a new chat with the instruction and its model ──
                Rectangle {
                    id: dailyCard
                    property bool open: false
                    width: settingsCol.width
                    height: dailyCol.height + 36
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"
                    property var items: JSON.parse(backend.daily)
                    readonly property var picks: JSON.parse(backend.modelChoices).filter(i => i.name !== "")

                    // The model list under an update (or under the field for a new one)
                    component DailyModels: Column {
                        property int target: -1
                        visible: win.dailyPick === target
                        width: parent.width
                        Text {
                            visible: backend.modelsLoading
                            text: "Hämtar modellerna…"
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: dailyCard.picks
                                FlatButton {
                                    required property var modelData
                                    small: true
                                    primary: (target === -2 ? win.dailyNewModel : (dailyCard.items[target] || {}).model || "") === modelData.id
                                    text: modelData.name
                                    onClicked: {
                                        if (target === -2)
                                            win.dailyNewModel = modelData.id;
                                        else
                                            backend.setDailyModel(target, modelData.id);
                                        win.dailyPick = -1;
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        id: dailyCol
                        x: 20
                        y: 18
                        width: parent.width - 40
                        spacing: 10
                        // Folded by default (25 Oct, the user: AI-tjänster got long) – the title opens it
                        Text {
                            width: parent.width
                            text: (dailyCard.open ? "▾  " : "▸  ") + "Egna knappar" + (dailyCard.items.length ? "   (" + dailyCard.items.length + ")" : "")
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dailyCard.open = !dailyCard.open
                            }
                        }
                        Column {
                            visible: dailyCard.open
                            width: parent.width
                            spacing: 10
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Knapparna ligger ovanför rutan där du skriver. Ett tryck = en ny chatt där modellen du valt får instruktionen – "
                                      + "t.ex. Ducks: \"Senaste om Anaheim Ducks: ställning, senaste och nästa match\". Skriv länkar i instruktionen så läses de sidorna när du trycker. Välj en modell som kan söka på nätet (en tjänst i molnet med Tavily-nyckel)."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Repeater {
                                model: dailyCard.items
                                Column {
                                    id: dailyRow
                                    required property var modelData
                                    required property int index
                                    width: dailyCol.width
                                    spacing: 6
                                    Row {
                                        width: parent.width
                                        spacing: 10
                                        Text {
                                            width: parent.width - modelChip.width - 40
                                            anchors.verticalCenter: parent.verticalCenter
                                            wrapMode: Text.WordWrap
                                            text: "<b>" + dailyRow.modelData.name + "</b>  " + dailyRow.modelData.text
                                            textFormat: Text.StyledText
                                            color: "#E6ECF5"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 14
                                        }
                                        FlatButton {
                                            id: modelChip
                                            small: true
                                            text: win.modelName(dailyRow.modelData.model || "") + "  ▾"
                                            onClicked: {
                                                win.dailyPick = win.dailyPick === dailyRow.index ? -1 : dailyRow.index;
                                                backend.refreshModels();
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "×"
                                            color: dailyX.containsMouse ? accent.errorBright : "#8B98AD"
                                            font.pixelSize: 18
                                            MouseArea {
                                                id: dailyX
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { win.dailyPick = -1; backend.removeDaily(dailyRow.index); }
                                            }
                                        }
                                    }
                                    DailyModels { target: dailyRow.index }
                                }
                            }
                            Row {
                                spacing: 10
                                Rectangle {
                                    width: 150
                                    height: 30
                                    color: "#07090D"
                                    border.width: 1
                                    border.color: dailyName.activeFocus ? accent.color : "#1E2A40"
                                    TextInput {
                                        id: dailyName
                                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                        verticalAlignment: TextInput.AlignVCenter
                                        clip: true
                                        maximumLength: 20
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                        KeyNavigation.tab: dailyInput
                                        Text {
                                            visible: dailyName.text === ""
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Namn, t.ex. Ducks"
                                            color: "#5C6880"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 13
                                        }
                                    }
                                }
                                Rectangle {
                                    width: Math.min(420, dailyCol.width - 420)
                                    height: 30
                                    color: "#07090D"
                                    border.width: 1
                                    border.color: dailyInput.activeFocus ? accent.color : "#1E2A40"
                                    TextInput {
                                        id: dailyInput
                                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                        verticalAlignment: TextInput.AlignVCenter
                                        clip: true
                                        maximumLength: 300
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                        onAccepted: dailyAdd.clicked()
                                        Text {
                                            visible: dailyInput.text === ""
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Instruktion, t.ex. Senaste om Anaheim Ducks"
                                            color: "#5C6880"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 13
                                        }
                                    }
                                }
                                FlatButton {
                                    small: true
                                    text: win.modelName(win.dailyNewModel) + "  ▾"
                                    onClicked: {
                                        win.dailyPick = win.dailyPick === -2 ? -1 : -2;
                                        backend.refreshModels();
                                    }
                                }
                                FlatButton {
                                    id: dailyAdd
                                    small: true
                                    primary: true
                                    text: "Lägg till"
                                    enabledState: dailyInput.text.trim() !== ""
                                    onClicked: {
                                        if (!enabledState)
                                            return;
                                        backend.addDaily(dailyName.text, dailyInput.text, win.dailyNewModel);
                                        dailyName.text = "";
                                        dailyInput.text = "";
                                        win.dailyNewModel = "";
                                        win.dailyPick = -1;
                                    }
                                }
                            }
                            DailyModels { target: -2 }
                        }
                    }
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
                                    : win.localStatus.paused ? "Avstängd medan ett spel kör – frågor går till molnet"
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
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Modellen märkt REKOMMENDERAS ryms i ditt grafikminne. Större svarar bättre men långsammare "
                                      + "(det som inte ryms läggs i vanliga minnet) – inget går sönder, så välj det du vill."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Repeater {
                                model: (win.local.recommend || {}).roles || []
                                Rectangle {
                                    id: roleRow
                                    required property var modelData
                                    readonly property var have: (win.localStatus.models || []).map(m => m.name.replace(/:latest$/, ""))
                                    readonly property string current: (win.localStatus.roles || {})[modelData.id] || ""
                                    // picked in the window, else the role's model, else the suggestion
                                    readonly property string picked: win.rolePick[modelData.id] || current || modelData.model
                                    readonly property bool pickedHave: have.indexOf(picked) >= 0
                                    width: localCol.width
                                    height: roleCol.height + 24
                                    color: "#0B1018"
                                    border.width: 1
                                    border.color: current && have.indexOf(current) >= 0 ? accent.color : "#1E2A40"
                                    Column {
                                        id: roleCol
                                        x: 14
                                        y: 12
                                        width: parent.width - 28
                                        spacing: 8
                                        Text {
                                            text: roleRow.modelData.name + (roleRow.current ? "  ·  använder " + roleRow.current : "")
                                            color: "#E6ECF5"
                                            font.family: "IBM Plex Sans"
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 13
                                        }
                                        Text {
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            text: roleRow.modelData.text
                                            color: "#8B98AD"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 12
                                        }
                                        Flow {
                                            width: parent.width
                                            spacing: 6
                                            Repeater {
                                                model: roleRow.modelData.options || []
                                                Rectangle {
                                                    id: optionChip
                                                    required property var modelData
                                                    readonly property bool chosen: roleRow.picked === modelData.model
                                                    width: optionText.implicitWidth + 20
                                                    height: 30
                                                    color: chosen ? "#12203A" : optionArea.containsMouse ? "#111A2A" : "transparent"
                                                    border.width: chosen ? 2 : 1
                                                    border.color: chosen ? accent.color : "#2A3852"
                                                    Text {
                                                        id: optionText
                                                        anchors.centerIn: parent
                                                        text: optionChip.modelData.model
                                                              + (optionChip.modelData.size ? " · " + win.gb(optionChip.modelData.size) : "")
                                                              + (optionChip.modelData.recommended ? " · REKOMMENDERAS"
                                                                 : optionChip.modelData.slow ? " · långsammare" : "")
                                                              + (roleRow.have.indexOf(optionChip.modelData.model) >= 0 ? " ✓" : "")
                                                        color: optionChip.modelData.recommended ? accent.text : "#E6ECF5"
                                                        font.family: "IBM Plex Sans"
                                                        font.pixelSize: 12
                                                    }
                                                    MouseArea {
                                                        id: optionArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            const p = Object.assign({}, win.rolePick);
                                                            p[roleRow.modelData.id] = optionChip.modelData.model;
                                                            win.rolePick = p;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        Text {
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            text: ((roleRow.modelData.options || []).find(o => o.model === roleRow.picked) || {}).note || ""
                                            visible: text !== ""
                                            color: "#5C6880"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 12
                                        }
                                        FlatButton {
                                            small: true
                                            visible: roleRow.picked !== roleRow.current || !roleRow.pickedHave
                                            primary: true
                                            enabledState: !backend.localBusy
                                            text: (roleRow.pickedHave ? "Använd " : "Hämta ") + roleRow.picked
                                            onClicked: {
                                                win.localError = false;
                                                if (roleRow.pickedHave)
                                                    backend.setLocalRole(roleRow.modelData.id, roleRow.picked);
                                                else
                                                    backend.pullLocal(roleRow.picked, roleRow.modelData.id);
                                            }
                                        }
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

                // ── Pictures (16 Oct): drawn on this computer, else in the cloud ──
                Rectangle {
                    width: settingsCol.width
                    height: imageCol.height + 36
                    color: "#0E1420"
                    border.width: 1
                    border.color: win.imageStatus.installed ? accent.color : "#1E2A40"

                    Column {
                        id: imageCol
                        x: 20
                        y: 18
                        width: parent.width - 40
                        spacing: 12

                        Row {
                            spacing: 12
                            Text {
                                text: "Skapa bilder"
                                color: "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.weight: Font.DemiBold
                                font.pixelSize: 16
                            }
                            Text {
                                text: win.imageStatus.installed === undefined ? "Kollar…"
                                    : !win.imageStatus.installed ? "Inte installerat på din dator"
                                    : win.imageStatus.waiting ? "Väntar på disken"
                                    : win.imageStatus.game ? "Ett spel kör – bilder ritas i molnet så länge"
                                    : win.imageStatus.model ? "Ritar på din dator" : "Ingen modell hämtad"
                                color: win.imageStatus.installed ? accent.text : "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "Be om en bild i chatten (\"gör en bild på …\") eller tryck på Skapa bild. Bilden ritas på din dator om "
                                  + "bildprogrammet är installerat – gratis och utan att något skickas iväg. Annars, eller medan ett spel kör: "
                                  + "Cloudflare (gratis, nyckel nedan), sedan Gemini (bara med Googles betalplan), OpenAI och Grok om du har nycklar. "
                                  + "Inget ligger kvar i grafikminnet mellan bilderna. Bilderna sparas i Bilder/Goblin AI (eller projektets mapp)."
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }

                        Column {
                            visible: win.imageStatus.installed === false
                            width: parent.width
                            spacing: 8
                            Label { text: "VAR SKA DET LIGGA?" }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Programmet tar 40 MB, en bildmodell 7–15 GB."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Repeater {
                                model: win.local.places || []
                                Rectangle {
                                    id: imagePlaceRow
                                    required property var modelData
                                    readonly property bool chosen: (win.imagePlace || (win.local.places || [{}])[0].path) === modelData.path
                                    width: imageCol.width
                                    height: 40
                                    color: chosen ? "#12203A" : imagePlaceArea.containsMouse ? "#111A2A" : "transparent"
                                    border.width: chosen ? 2 : 1
                                    border.color: chosen ? accent.color : "#2A3852"
                                    opacity: modelData.writable ? 1 : 0.4
                                    Text {
                                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                        text: imagePlaceRow.modelData.label + "  ·  " + win.gb(imagePlaceRow.modelData.free) + " ledigt"
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                    }
                                    MouseArea {
                                        id: imagePlaceArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (imagePlaceRow.modelData.writable) win.imagePlace = imagePlaceRow.modelData.path
                                    }
                                }
                            }
                            FlatButton {
                                primary: true
                                enabledState: !backend.imageBusy && !!win.local.places
                                text: "Installera bildprogrammet"
                                onClicked: {
                                    win.imageError = false;
                                    backend.installImage(win.imagePlace || (win.local.places || [{}])[0].path);
                                }
                            }
                        }

                        Column {
                            visible: !!win.imageStatus.installed
                            width: parent.width
                            spacing: 10
                            Label { text: "BILDMODELL" }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Storleken märkt REKOMMENDERAS ryms i ditt grafikminne. Större ger bättre bilder men tar längre tid "
                                      + "på din dator (det som inte ryms läggs i vanliga minnet) – inget går sönder, så välj det du vill."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Repeater {
                                model: win.imageStatus.models || []
                                Rectangle {
                                    id: imageModelRow
                                    required property var modelData
                                    readonly property bool used: win.imageStatus.model === modelData.id
                                    // the size picked in the window, else the downloaded one, else the suggested one
                                    readonly property string picked: win.imageVariant[modelData.id] || modelData.file
                                    readonly property var pickedVariant: modelData.variants.find(v => v.file === picked) || modelData.variants[0]
                                    readonly property bool changing: modelData.ready && picked !== modelData.file
                                    width: imageCol.width
                                    height: imageModelCol.height + 24
                                    color: "#0B1018"
                                    border.width: used ? 2 : 1
                                    border.color: used ? accent.color : modelData.ready ? "#2A3852" : "#1E2A40"
                                    Column {
                                        id: imageModelCol
                                        x: 14
                                        y: 12
                                        width: parent.width - 28
                                        spacing: 8
                                        Text {
                                            text: imageModelRow.modelData.name
                                                  + (imageModelRow.modelData.ready ? "  ·  hämtad" : "")
                                                  + (imageModelRow.used ? "  ·  används" : "")
                                            color: "#E6ECF5"
                                            font.family: "IBM Plex Sans"
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 13
                                        }
                                        Text {
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            text: imageModelRow.modelData.text
                                            color: "#8B98AD"
                                            font.family: "IBM Plex Sans"
                                            font.pixelSize: 12
                                        }
                                        Flow {
                                            width: parent.width
                                            spacing: 6
                                            Repeater {
                                                model: imageModelRow.modelData.variants
                                                Rectangle {
                                                    id: variantChip
                                                    required property var modelData
                                                    readonly property bool chosen: imageModelRow.picked === modelData.file
                                                    width: variantText.implicitWidth + 20
                                                    height: 30
                                                    color: chosen ? "#12203A" : variantArea.containsMouse ? "#111A2A" : "transparent"
                                                    border.width: chosen ? 2 : 1
                                                    border.color: chosen ? accent.color : "#2A3852"
                                                    Text {
                                                        id: variantText
                                                        anchors.centerIn: parent
                                                        text: variantChip.modelData.name + " · " + win.gb(variantChip.modelData.size)
                                                              + (variantChip.modelData.recommended ? " · REKOMMENDERAS"
                                                                 : variantChip.modelData.slow ? " · långsammare" : "")
                                                              + (variantChip.modelData.file === imageModelRow.modelData.file && imageModelRow.modelData.ready ? " ✓" : "")
                                                        color: variantChip.modelData.recommended ? accent.text : "#E6ECF5"
                                                        font.family: "IBM Plex Sans"
                                                        font.pixelSize: 12
                                                    }
                                                    MouseArea {
                                                        id: variantArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            const v = Object.assign({}, win.imageVariant);
                                                            v[imageModelRow.modelData.id] = variantChip.modelData.file;
                                                            win.imageVariant = v;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        Row {
                                            spacing: 8
                                            FlatButton {
                                                small: true
                                                visible: !imageModelRow.modelData.ready || imageModelRow.changing
                                                primary: true
                                                enabledState: !backend.imageBusy
                                                text: (imageModelRow.changing ? "Byt till " : "Hämta ") + imageModelRow.pickedVariant.name.toLowerCase()
                                                      + " (" + win.gb(imageModelRow.pickedVariant.size) + ")"
                                                onClicked: {
                                                    win.imageError = false;
                                                    backend.pullImage(imageModelRow.modelData.id, imageModelRow.picked);
                                                }
                                            }
                                            FlatButton {
                                                small: true
                                                visible: imageModelRow.modelData.ready && !imageModelRow.used
                                                text: "Använd"
                                                onClicked: backend.useImageModel(imageModelRow.modelData.id)
                                            }
                                            FlatButton {
                                                small: true
                                                visible: imageModelRow.modelData.ready
                                                enabledState: !backend.imageBusy
                                                text: "Ta bort"
                                                onClicked: backend.removeImageModel(imageModelRow.modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                            Flow {
                                width: parent.width
                                spacing: 8
                                FlatButton { small: true; text: "Uppdatera bildprogrammet"; enabledState: !backend.imageBusy; onClicked: backend.updateImage() }
                                FlatButton { small: true; text: "Ta bort bildprogrammet …"; enabledState: !backend.imageBusy; onClicked: win.imageRemoving = !win.imageRemoving }
                                FlatButton { small: true; visible: win.imageRemoving; text: "Ta bort, behåll modellerna"; onClicked: { win.imageRemoving = false; backend.uninstallImage(false); } }
                                FlatButton { small: true; visible: win.imageRemoving; text: "Ta bort allt"; onClicked: { win.imageRemoving = false; backend.uninstallImage(true); } }
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Plats: " + (win.imageStatus.dir || "") + " · stable-diffusion.cpp " + (win.imageStatus.version || "")
                                color: "#5C6880"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                            }
                        }

                        Rectangle {
                            visible: backend.imageBusy && win.imageFraction >= 0
                            width: parent.width
                            height: 4
                            color: "#1A2438"
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, win.imageFraction))
                                height: parent.height
                                color: accent.color
                            }
                        }
                        Text {
                            visible: win.imageText !== ""
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: win.imageText
                            color: win.imageError ? accent.errorBright : "#E6ECF5"
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
}
