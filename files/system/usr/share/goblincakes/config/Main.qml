// GOBLINCAKES Config: install apps (Program), settings (Inställningar), graphics drivers (Grafik).
// Flat, square, in the GOBLINCAKES palette. Backend: /usr/bin/goblincakes-config ("backend").
import QtQuick
import QtQuick.Window

Window {
    id: win

    width: 1180
    height: 800
    minimumWidth: 760
    minimumHeight: 560
    visible: true
    title: "GOBLINCAKES Config"
    color: "#07090D"

    // Closed while installing or updating: hide and carry on, notify when finished, then quit
    onClosing: close => {
        if (page === "install" || updateState === "running") {
            close.accepted = false;
            hide();
        } else {
            Qt.quit();
        }
    }

    readonly property var catalog: JSON.parse(backend.catalog)
    property var chosen: ({})
    property int chosenCount: 0
    property string page: "choose" // choose → install → done
    property int failedCount: 0
    property string tab: startTab // apps | system | tweaks | graphics | update
    readonly property var gpu: JSON.parse(backend.gpu)
    property string gpuMessage: ""
    readonly property string mainBrowser: backend.mainBrowser // app id, "" = Firefox
    readonly property var autostart: JSON.parse(backend.autostart) // installed app id → starts at login
    readonly property var fullscreen: JSON.parse(backend.fullscreen) // web app id → opens in fullscreen
    readonly property var webapps: JSON.parse(backend.webapps)
    property string webappStatus: ""
    property bool webappBusy: false
    property var expanded: ({}) // category id → open
    // Uppdatera tab
    property string updateState: "idle" // idle → running → done
    // "Kolla efter uppdateringar" (quick check, nothing downloaded): "" → checking → done
    property string checkState: ""
    property string checkText: ""
    property bool checkFound: false
    property bool checkStaged: false  // already fetched: offer "Starta om nu" right away
    property real updateFrac: 0
    property string updateTitle: ""
    property string updateStatus: ""
    property bool updateOk: true
    property bool updateReboot: false
    // Förinstallerat tab
    readonly property var systemApps: JSON.parse(backend.systemApps)
    property string appFilter: ""
    onTabChanged: if (tab === "system") backend.refreshSystemApps()
    Component.onCompleted: {
        if (tab === "system")
            backend.refreshSystemApps();
        showCheck(backend.knownUpdates(), true);
    }

    function toggleCategory(id) {
        const e = Object.assign({}, expanded);
        e[id] = !e[id];
        expanded = e;
    }

    function isInstalled(id) {
        for (const a of catalog.apps)
            if (a.id === id)
                return a.installed;
        return false;
    }

    // Switch under a browser: on = install it if needed and make it the main browser
    function setMainBrowser(id, on) {
        if (on && !isInstalled(id) && !chosen[id])
            toggle(id);
        backend.setMainBrowser(on ? id : "");
    }

    function toggle(id) {
        const c = Object.assign({}, chosen);
        if (c[id]) {
            delete c[id];
            // Not installing it after all: it can't be the main browser either
            if (id === mainBrowser && !isInstalled(id))
                backend.setMainBrowser("");
        } else
            c[id] = true;
        chosen = c;
        chosenCount = Object.keys(c).length;
    }

    function appName(id) {
        for (const a of catalog.apps)
            if (a.id === id)
                return a.name;
        return id;
    }

    function startInstall() {
        page = "install";
        backend.install(JSON.stringify(Object.keys(chosen)));
    }

    function finish() {
        backend.markDone();
        Qt.quit();
    }

    // After installing: back to choosing apps (failed ones can be picked again)
    function goBack() {
        progressModel.clear();
        chosen = {};
        chosenCount = 0;
        failedCount = 0;
        backend.refreshCatalog();
        page = "choose";
    }

    ListModel { id: progressModel }
    ListModel { id: updateResults }
    ListModel { id: updateNews }

    // parts: "" = everything (Uppdatera allt), else goblin update --only (one row's Uppdatera)
    function startUpdate(parts) {
        updateResults.clear();
        updateNews.clear();
        updateFrac = 0;
        updateTitle = "Förbereder…";
        updateStatus = "";
        updateReboot = false;
        updateState = "running";
        backend.startUpdate(parts || "");
    }

    ListModel {
        id: tweakModel
        Component.onCompleted: {
            for (const t of JSON.parse(backend.tweaks).tweaks)
                append({ "tweakId": t.id, "section": t.section || "", "name": t.name, "desc": t.desc,
                         "status": t.state, "message": "", "note": t.note || "" });
            win.tweakRev++;
        }
    }
    // INSTÄLLNINGAR: a section heading above the first setting of each section that is shown
    // (settings that don't fit this computer are hidden, so whole sections can be empty)
    property int tweakRev: 0
    function sectionShown(name) {
        for (let i = 0; i < tweakModel.count; i++) {
            const item = tweakModel.get(i);
            if (item.section === name && item.status !== "unavailable")
                return true;
        }
        return false;
    }
    function tweakSectionStart(index) {
        const item = tweakModel.get(index);
        if (!item || item.status === "unavailable")
            return false;
        for (let i = index - 1; i >= 0; i--) {
            const prev = tweakModel.get(i);
            if (prev.section !== item.section)
                break;
            if (prev.status !== "unavailable")
                return false;
        }
        return true;
    }

    // Result of a check: the "Kolla efter uppdateringar" button, or (fromCache) what the update
    // arrow's automatic check found last, read when the window opens. "Uppdatera allt" is only
    // offered when something was found (the user's choice, 10 Oct).
    // What a check found, one row per part with its own Uppdatera (11 Oct, the user's wish)
    ListModel { id: checkParts }
    function showCheck(json, fromCache) {
        let st;
        try { st = JSON.parse(json); } catch (e) { st = null; }
        if (!st) {
            if (fromCache)
                return;  // never checked: just the button
            win.checkState = "done";
            win.checkFound = false;
            win.checkStaged = false;
            win.checkText = "Det gick inte att kolla just nu – är datorn ansluten till internet?";
            return;
        }
        const apps = st.flatpaks || [];
        const runtimes = st.flatpakRuntimes || 0;
        const other = st.other || [];
        const lines = [];
        const news = (st.news || []).map(line => "  • " + line);
        if (st.system === "new")
            lines.push("Ny GOBLINCAKES-version finns" + (news.length > 0 ? ":" : "."), ...news);
        else if (st.system === "staged" && st.stagedImage !== false)
            lines.push("En ny GOBLINCAKES-version är redan hämtad – den används efter en omstart"
                       + (news.length > 0 ? ":" : "."), ...news);
        // Programs added to or removed from the system (the calendar, goblin remove), 11 Oct
        const changes = st.system === "staged" ? (st.stagedChanges || []) : [];
        if (changes.length > 0)
            lines.push((st.stagedImage === false ? "Väntar på en omstart:" : "Efter omstarten också:"),
                       ...changes.map(line => "  • " + line));
        else if (st.system === "staged" && st.stagedImage === false)
            lines.push("Ändringar i systemet väntar på en omstart.");
        const parts = [];
        if (st.system === "new")
            parts.push({ "part": "system", "title": "GOBLINCAKES", "detail": "Ny version – används efter en omstart" });
        if (apps.length > 0 || runtimes > 0)
            parts.push({ "part": "flatpak", "title": "Flatpak-program",
                         "detail": apps.length > 0 ? apps.join(", ") + (runtimes > 0 ? " + " + runtimes + " systemdelar" : "")
                                                   : runtimes + (runtimes === 1 ? " systemdel" : " systemdelar") + " för programmen" });
        const groups = [["appimages", "AppImage-program"], ["vscode", "VS Code"], ["discord", "Discord"],
                        ["proton", "GE-Proton"], ["firmware", "Firmware"]];
        for (const [id, title] of groups) {
            const names = other.filter(o => o.part === id).map(o => o.name);
            if (names.length > 0)
                parts.push({ "part": id, "title": title, "detail": names.join(", ") });
        }
        checkParts.clear();
        for (const p of parts)
            checkParts.append(p);
        const found = parts.length > 0;
        if (fromCache && !found && st.system !== "staged")
            return;  // nothing known: just the button
        win.checkFound = found;
        win.checkStaged = st.system === "staged";
        win.checkText = lines.length > 0 ? lines.join("\n")
                      : found ? "Det här kan uppdateras – en del i taget eller allt på en gång:"
                      : "Allt är redan uppdaterat.";
        win.checkState = "done";
    }

    Connections {
        target: backend
        // Config started again while open (the update arrow, AppGrid, Meta+C): this window, on that tab
        function onCheckDone(json) { win.showCheck(json, false); }
        function onShowTab(tab) {
            if (tab !== "")
                win.tab = tab;
            if (tab === "update" && win.updateState === "idle")
                win.showCheck(backend.knownUpdates(), true);  // e.g. the arrow: what it found
            win.show();
            win.raise();
            win.requestActivate();
        }
        function onWebappProgress(text) { win.webappStatus = text; }
        function onWebappDone(ok) {
            win.webappBusy = false;
            if (ok) {
                win.webappStatus = "Klar – finns nu i AppGrid";
                webUrl.text = "";
                webName.text = "";
            } else if (!win.webappStatus.startsWith("Det där"))
                win.webappStatus = "Det gick inte – kolla adressen och nätverket";
        }
        function onProgress(id, state, message) {
            for (let i = 0; i < progressModel.count; i++) {
                if (progressModel.get(i).appId === id) {
                    progressModel.set(i, { "status": state, "message": message });
                    return;
                }
            }
            progressModel.append({ "appId": id, "name": win.appName(id), "status": state, "message": message });
        }
        function onAllDone(failed) {
            win.failedCount = failed;
            win.page = "done";
            if (!win.visible) {
                backend.notifyHidden("Programmen är installerade",
                                     failed ? failed + " gick inte att installera – öppna GOBLINCAKES Config igen" : "", false);
                if (win.updateState !== "running")
                    Qt.quit();
            }
        }
        function onGpuProgress(text) {
            win.gpuMessage = text;
        }
        function onUpdateProgress(frac, title, status) {
            win.updateFrac = frac;
            win.updateTitle = title;
            win.updateStatus = status;
        }
        function onUpdateResult(name, ok, summary) {
            updateResults.append({ "name": name, "ok": ok, "summary": summary });
        }
        function onUpdateNews(text) {
            updateNews.append({ "text": text });
        }
        function onUpdateDone(ok, reboot) {
            win.updateOk = ok;
            win.updateReboot = reboot;
            win.updateState = "done";
            if (!win.visible) {
                backend.notifyHidden(ok ? "GOBLINCAKES är uppdaterat" : "Uppdateringen är klar – något gick inte",
                                     reboot ? "Den nya versionen används efter en omstart" : "", reboot);
                if (win.page !== "install")
                    Qt.quit();
            }
        }
        function onGpuDone(ok) {
            if (ok)
                win.gpuMessage = "";
        }
        function onTweakChanged(id, state, message) {
            for (let i = 0; i < tweakModel.count; i++)
                if (tweakModel.get(i).tweakId === id)
                    tweakModel.set(i, { "status": state, "message": message });
            win.tweakRev++;
        }
    }

    // ── Pieces ───────────────────────────────────────────────

    // Flat text field with a grey hint while empty
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

    component FlatField: Rectangle {
        property alias text: input.text
        property string hint
        signal accepted()
        height: 44
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
            font.pixelSize: 15
            clip: true
            selectByMouse: true
            onAccepted: parent.accepted()
        }
        Text {
            anchors { fill: input }
            verticalAlignment: Text.AlignVCenter
            visible: !input.text && !input.activeFocus
            text: parent.hint
            color: "#5C6880"
            font: input.font
            elide: Text.ElideRight
        }
    }

    component FlatButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        property bool enabledState: true
        signal clicked()

        width: Math.max(150, label.implicitWidth + 48)
        height: 44
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
            font.pixelSize: 15
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.enabledState) btn.clicked()
        }
    }

    // Square check box, filled blue with a check mark when on
    component CheckSquare: Rectangle {
        property bool checked
        width: 22
        height: 22
        color: checked ? accent.color : "transparent"
        border.width: checked ? 0 : 1
        border.color: "#2A3852"
        property color mark: accent.on // the tick: dark on light accent colours
        Canvas {
            anchors.fill: parent
            visible: parent.checked
            property color mark: parent.mark
            onMarkChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = mark;
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                ctx.moveTo(5.5, 11.5);
                ctx.lineTo(9.5, 15.5);
                ctx.lineTo(16.5, 7);
                ctx.stroke();
            }
        }
    }

    // Result of a step: green square with a check (done) or red square with a cross (failed),
    // drawn like the check box (no font glyphs – "✓" looked like a V)
    component ResultMark: Rectangle {
        property bool ok: true
        property int size: 22
        width: size
        height: size
        color: ok ? "#0F2418" : accent.error
        border.width: 1
        border.color: ok ? "#3FB950" : accent.error
        Canvas {
            anchors.fill: parent
            property bool ok: parent.ok
            onOkChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                const s = width / 22;
                ctx.reset();
                ctx.lineWidth = 2.5 * s;
                ctx.beginPath();
                if (ok) {
                    ctx.strokeStyle = "#3FB950";
                    ctx.moveTo(5.5 * s, 11.5 * s);
                    ctx.lineTo(9.5 * s, 15.5 * s);
                    ctx.lineTo(16.5 * s, 7 * s);
                } else {
                    ctx.strokeStyle = "#E6ECF5";
                    ctx.moveTo(7 * s, 7 * s);
                    ctx.lineTo(15 * s, 15 * s);
                    ctx.moveTo(15 * s, 7 * s);
                    ctx.lineTo(7 * s, 15 * s);
                }
                ctx.stroke();
            }
        }
    }

    // Initials on a square tile, instead of icons (most apps aren't installed yet)
    component Monogram: Rectangle {
        property string name
        width: 48
        height: 48
        color: "#12203A"
        border.width: 1
        border.color: "#1E2A40"
        Text {
            anchors.centerIn: parent
            text: {
                const words = parent.name.replace(/[^A-Za-z0-9 .-]/g, "").split(/[ .-]+/).filter(w => w.length);
                return (words.length > 1 ? words[0][0] + words[1][0] : parent.name.slice(0, 2)).toUpperCase();
            }
            color: "#E6ECF5"
            font.family: "Chakra Petch"
            font.weight: Font.Bold
            font.pixelSize: 18
        }
    }

    // Flat, square scroll bar along the right edge of a list – only when it doesn't fit.
    // Drag the handle, or click the track to jump there (the mouse wheel works as well).
    component FlatScrollBar: Item {
        id: bar
        required property Flickable flick
        readonly property bool needed: flick.visible && flick.contentHeight > flick.height + 1
        anchors { right: flick.right; rightMargin: 6; top: flick.top; topMargin: 6; bottom: flick.bottom; bottomMargin: 6 }
        width: 8
        visible: needed
        z: 2

        Rectangle {
            anchors.fill: parent
            color: "#0E1420"
        }

        MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
                const ratio = Math.max(0, Math.min(1, (mouse.y - handle.height / 2) / (bar.height - handle.height)));
                bar.flick.contentY = ratio * (bar.flick.contentHeight - bar.flick.height);
            }
        }

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
                    const y = startContentY + dy * span / Math.max(1, bar.height - handle.height);
                    bar.flick.contentY = Math.max(0, Math.min(span, y));
                }
            }
        }
    }

    // ── Header ───────────────────────────────────────────────

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 176 + (backend.live ? 52 : 0)

        // From the USB stick (live): what differs from the installed GOBLINCAKES
        Rectangle {
            visible: backend.live
            anchors { left: parent.left; right: parent.right; leftMargin: 48; rightMargin: 48
                      bottom: parent.bottom; bottomMargin: 56 }
            height: liveNote.implicitHeight + 20
            color: "#0E1420"
            border.color: accent.color
            border.width: 1
            Text {
                id: liveNote
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                          leftMargin: 14; rightMargin: 14 }
                text: "Du provar GOBLINCAKES från USB-minnet. Steam och TV-läget finns inte här, men installeras direkt i systemet när du installerar GOBLINCAKES. Det du väljer här försvinner när datorn startas om."
                color: "#E6ECF5"
                wrapMode: Text.WordWrap
                font.family: "IBM Plex Sans"
                font.pixelSize: 13
            }
        }

        Row {
            anchors { left: parent.left; leftMargin: 48; top: parent.top; topMargin: 30 }
            spacing: 22

            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: logoUrl
                sourceSize.width: 64
                sourceSize.height: 64
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    text: win.tab === "system" ? "FÖRINSTALLERAT"
                        : win.tab === "update"
                          ? (win.updateState === "running" ? "UPPDATERAR…" : win.updateState === "done" ? "UPPDATERAT" : "UPPDATERA")
                        : win.tab === "graphics" ? "GRAFIK"
                        : win.tab === "windows" ? "FÖNSTER"
                        : win.tab === "tweaks" ? "INSTÄLLNINGAR"
                        : win.page === "choose" ? "VÄLJ DINA PROGRAM"
                        : win.page === "install" ? "INSTALLERAR…" : "KLART"
                    color: "#E6ECF5"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 30
                    font.letterSpacing: 4
                }
                Text {
                    text: win.tab === "system"
                        ? "Programmen som följer med GOBLINCAKES. Dölj det du inte använder – det finns kvar och fungerar, men syns inte i AppGrid."
                        : win.tab === "update"
                        ? (win.updateState === "running" ? "Du kan använda datorn under tiden. Stäng inte fönstret."
                           : win.updateState === "done" ? (win.updateOk ? "Allt är uppdaterat." : "Klart, men något gick inte – se listan nedan.")
                           : "Systemet, program, VS Code, Discord, AppImages, GE-Proton och firmware – samma som goblin update.")
                        : win.tab === "windows"
                        ? "Hur fönstren ligger på skärmarna – egna rutor och vilket program som öppnas var. Byt layout med Meta+Ctrl+1–9."
                        : win.tab === "graphics"
                        ? "Drivrutiner för ditt grafikkort. Den gamla varianten finns kvar i startmenyn om något går fel."
                        : win.tab === "tweaks"
                        ? "Prestanda, spel, ljud, system och utseende. Slå på det du vill ha – allt går att slå av igen."
                        : win.page === "choose"
                        ? "Kryssa i det du vill ha. Allt går att lägga till senare – sök på GOBLINCAKES Config i AppGrid."
                        : win.page === "install"
                        ? "Du kan använda datorn under tiden. Stäng inte fönstret."
                        : win.failedCount === 0 ? "Allt är installerat. Programmen finns i AppGrid."
                        : win.failedCount + " program gick inte att installera – tryck Tillbaka för att försöka igen."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                }
            }
        }

        // Which GOBLINCAKES is running
        Text {
            anchors { right: parent.right; rightMargin: 48; top: parent.top; topMargin: 30 }
            text: backend.version
            color: "#8B98AD"
            font.family: "IBM Plex Mono"
            font.pixelSize: 13
        }

        // Tabs
        Row {
            anchors { left: parent.left; leftMargin: 48; bottom: parent.bottom }
            spacing: 32

            Repeater {
                model: [{ "id": "apps", "label": "PROGRAM" }, { "id": "system", "label": "FÖRINSTALLERAT" }, { "id": "tweaks", "label": "INSTÄLLNINGAR" }, { "id": "windows", "label": "FÖNSTER" }, { "id": "graphics", "label": "GRAFIK" }, { "id": "update", "label": "UPPDATERA" }]

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
                        color: accent.color
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

    // ── Choose ───────────────────────────────────────────────

    Flickable {
        id: chooser
        FastWheel { flick: chooser }
        visible: win.tab === "apps" && win.page === "choose"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: sections.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: sections
            x: 48
            y: 32
            width: chooser.width - 96
            spacing: 12

            // ── Terminal: Ghostty (standard) or Konsole, same GOBLINCAKES look ──
            Column {
                width: sections.width
                spacing: 14
                bottomPadding: 22

                Text {
                    text: "TERMINAL"
                    color: "#8B98AD"
                    font.family: "Chakra Petch"
                    font.weight: Font.DemiBold
                    font.pixelSize: 14
                    font.letterSpacing: 2.5
                }
                Text {
                    width: parent.width
                    text: "Vilken terminal vill du använda? Båda har GOBLINCAKES färger och typsnitt. Den du väljer ligger i dockan och öppnas när GOBLINCAKES behöver en terminal. Du kan byta här när du vill."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                }
                Row {
                    spacing: 16
                    Repeater {
                        model: [
                            {id: "ghostty", name: "Ghostty", desc: "Snabb och enkel. GOBLINCAKES standard."},
                            {id: "konsole", name: "Konsole", desc: "KDE:s egen terminal, med flikar, delad vy och inställningar i menyerna."}
                        ]
                        Rectangle {
                            id: termCard
                            required property var modelData
                            readonly property bool chosen: backend.terminal === modelData.id
                            width: Math.min(420, (sections.width - 16) / 2)
                            height: 92
                            color: termArea.containsMouse && !chosen ? "#111A2A" : "#0E1420"
                            border.width: 1
                            border.color: chosen ? accent.color : termArea.containsMouse ? "#2A3852" : "#1E2A40"

                            Monogram {
                                id: termMono
                                name: termCard.modelData.name
                                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                            }
                            Column {
                                anchors {
                                    left: termMono.right; leftMargin: 16
                                    right: termCheck.left; rightMargin: 14
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 5
                                Text {
                                    text: termCard.modelData.name
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 16
                                }
                                Text {
                                    width: parent.width
                                    text: termCard.modelData.desc
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                            CheckSquare {
                                id: termCheck
                                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                                checked: termCard.chosen
                            }
                            MouseArea {
                                id: termArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: termCard.chosen ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: backend.setTerminal(termCard.modelData.id)
                            }
                        }
                    }
                }
            }

            // ── Egen webbapp: any link as its own app ──
            Column {
                width: sections.width
                spacing: 14
                bottomPadding: 22

                function create() {
                    if (win.webappBusy || !webUrl.text.trim())
                        return;
                    win.webappBusy = true;
                    win.webappStatus = "Skapar…";
                    backend.createWebapp(webUrl.text, webName.text);
                }

                Text {
                    text: "EGEN WEBBAPP"
                    color: "#8B98AD"
                    font.family: "Chakra Petch"
                    font.weight: Font.DemiBold
                    font.pixelSize: 14
                    font.letterSpacing: 2.5
                }
                Text {
                    width: parent.width
                    text: "Klistra in länken till en webbsida, så blir den en egen app med ikon i AppGrid – i ett eget fönster utan adressfält (Google Chrome om den är installerad, annars Chromium). Namnet tas från sidan om du inte skriver ett eget."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                }
                Row {
                    id: webRow
                    spacing: 12
                    readonly property real buttonWidth: 150
                    FlatField {
                        id: webUrl
                        width: (sections.width - webRow.buttonWidth - 24) * 0.62
                        hint: "Länk, t.ex. https://mail.proton.me"
                        onAccepted: parent.parent.create()
                    }
                    FlatField {
                        id: webName
                        width: (sections.width - webRow.buttonWidth - 24) * 0.38
                        hint: "Namn (valfritt)"
                        onAccepted: parent.parent.create()
                    }
                    FlatButton {
                        width: webRow.buttonWidth
                        text: "Skapa app"
                        primary: true
                        enabledState: !win.webappBusy && webUrl.text.trim().length > 0
                        onClicked: parent.parent.create()
                    }
                }
                Text {
                    visible: win.webappStatus !== ""
                    text: win.webappStatus
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 13
                }

            }

            Repeater {
                model: win.catalog.categories

                Column {
                    id: section
                    required property var modelData
                    readonly property var apps: win.catalog.apps.filter(a => a.category === modelData.id)
                    readonly property int columns: Math.max(1, Math.floor((sections.width + 16) / 340))

                    readonly property bool open: !!win.expanded[modelData.id]
                    readonly property int chosenHere: apps.filter(a => !!win.chosen[a.id]).length
                    readonly property int installedHere: apps.filter(a => a.installed).length

                    width: sections.width
                    spacing: 14

                    // Category header: click to open/close (closed from the start)
                    Rectangle {
                        width: section.width
                        height: 52
                        color: headerArea.containsMouse ? "#111A2A" : "#0E1420"
                        border.width: 1
                        border.color: section.open ? "#2A3852" : "#1E2A40"

                        Text {
                            id: arrow
                            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                            text: "\u203A"
                            rotation: section.open ? 90 : 0
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 22
                            Behavior on rotation { NumberAnimation { duration: 120 } }
                        }
                        Text {
                            anchors { left: arrow.right; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            text: section.modelData.name.toUpperCase()
                            color: "#E6ECF5"
                            font.family: "Chakra Petch"
                            font.weight: Font.DemiBold
                            font.pixelSize: 14
                            font.letterSpacing: 2.5
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                            text: (section.chosenHere ? section.chosenHere + (section.chosenHere === 1 ? " vald · " : " valda · ") : "")
                                  + (section.installedHere ? section.installedHere + (section.installedHere === 1 ? " installerad · " : " installerade · ") : "")
                                  + section.apps.length + " program"
                            color: section.chosenHere ? accent.text : "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: headerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.toggleCategory(section.modelData.id)
                        }
                    }
                    Text {
                        visible: section.open && !!section.modelData.note
                        width: section.width
                        text: section.modelData.note || ""
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                    }

                    Grid {
                        visible: section.open
                        columns: section.columns
                        columnSpacing: 16
                        rowSpacing: 16

                        Repeater {
                            model: section.apps

                            Rectangle {
                                id: card
                                required property var modelData
                                readonly property bool installed: modelData.installed
                                readonly property bool checked: !!win.chosen[modelData.id]
                                readonly property bool browser: !!modelData.browser
                                // Installed and has something to start: "Starta vid inloggning"
                                readonly property bool canAutostart: installed && win.autostart[modelData.id] !== undefined
                                // Installed web apps (streaming services, Claude): "Helskärm"
                                readonly property string webapp: modelData.check[0] === "webapp" ? modelData.check[1] : ""
                                readonly property bool canFullscreen: installed && webapp !== "" && win.fullscreen[webapp] !== undefined

                                width: (sections.width - 16 * (section.columns - 1)) / section.columns
                                height: 112 + 48 * ((browser ? 1 : 0) + (canAutostart ? 1 : 0) + (canFullscreen ? 1 : 0))
                                color: cardArea.containsMouse && !installed ? "#111A2A" : "#0E1420"
                                border.width: 1
                                border.color: checked ? accent.color : cardArea.containsMouse && !installed ? "#2A3852" : "#1E2A40"
                                // Stays bright when installed if a switch is still in use
                                opacity: installed && !browser && !canAutostart && !canFullscreen ? 0.55 : 1

                                Monogram {
                                    id: mono
                                    name: card.modelData.name
                                    anchors { left: parent.left; leftMargin: 18; top: parent.top; topMargin: 20 }
                                }

                                Column {
                                    anchors {
                                        left: mono.right; leftMargin: 16
                                        right: check.left; rightMargin: 14
                                        top: parent.top; topMargin: 18
                                    }
                                    spacing: 5

                                    Text {
                                        width: parent.width
                                        text: card.modelData.name
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 16
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: card.installed ? "Redan installerad" : card.modelData.desc
                                        color: "#8B98AD"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        lineHeight: 1.15
                                    }
                                }

                                CheckSquare {
                                    id: check
                                    anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 20 }
                                    checked: card.checked || card.installed
                                }

                                MouseArea {
                                    id: cardArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: card.installed ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: if (!card.installed) win.toggle(card.modelData.id)
                                }

                                // Switches at the bottom of the card, each on its own row
                                Column {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    anchors { leftMargin: 18; rightMargin: 18; bottomMargin: 14 }
                                    spacing: 18

                                    // Browsers: installs it and makes it the main browser
                                    CardSwitch {
                                        visible: card.browser
                                        text: "Huvudwebbläsare"
                                        on: win.mainBrowser === card.modelData.id
                                        onToggled: win.setMainBrowser(card.modelData.id, !on)
                                    }
                                    // Installed apps: start it at every login (~/.config/autostart)
                                    CardSwitch {
                                        visible: card.canAutostart
                                        text: "Starta vid inloggning"
                                        on: !!win.autostart[card.modelData.id]
                                        onToggled: backend.setAutostart(card.modelData.id, !on)
                                    }
                                    // Web apps: open in fullscreen (F11 leaves it)
                                    CardSwitch {
                                        visible: card.canFullscreen
                                        text: "Helskärm"
                                        on: !!win.fullscreen[card.webapp]
                                        onToggled: backend.setFullscreen(card.webapp, !on)
                                    }
                                }
                            }
                        }
                    }
                }
            }


            // ── The user's own web apps, at the bottom ──
            Column {
                visible: win.webapps.length > 0
                width: sections.width
                spacing: 14
                topPadding: 22

                Text {
                    text: "DINA WEBBAPPAR"
                    color: "#8B98AD"
                    font.family: "Chakra Petch"
                    font.weight: Font.DemiBold
                    font.pixelSize: 14
                    font.letterSpacing: 2.5
                }

                // The ones made so far, with a button to remove each
                Repeater {
                    model: win.webapps
                    Rectangle {
                        required property var modelData
                        width: sections.width
                        height: 52
                        color: "#0E1420"
                        border.width: 1
                        border.color: "#1E2A40"
                        Monogram {
                            id: webMono
                            name: parent.modelData.name
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            scale: 0.7
                        }
                        Column {
                            anchors { left: webMono.right; leftMargin: 10; right: fullLabel.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            Text {
                                width: parent.width
                                text: parent.parent.modelData.name
                                color: "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.weight: Font.DemiBold
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: parent.parent.modelData.url
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                                elide: Text.ElideMiddle
                            }
                        }
                        // Open in fullscreen (F11 leaves it)
                        Text {
                            id: fullLabel
                            anchors { right: fullSwitch.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "Helskärm"
                            color: fullSwitch.on ? "#E6ECF5" : "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                        ToggleSwitch {
                            id: fullSwitch
                            anchors { right: removeBtn.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            on: !!win.fullscreen[parent.modelData.id]
                            onToggled: backend.setFullscreen(parent.modelData.id, !on)
                        }
                        FlatButton {
                            id: removeBtn
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            height: 36
                            width: 110
                            text: "Ta bort"
                            onClicked: backend.removeWebapp(parent.modelData.id)
                        }
                    }
                }
            }
        }
    }

    // ── Install / done ───────────────────────────────────────

    Flickable {
        id: progressView
        FastWheel { flick: progressView }
        visible: win.tab === "apps" && win.page !== "choose"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: rows.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: rows
            x: 48
            y: 32
            width: progressView.width - 96
            spacing: 10

            Repeater {
                model: progressModel

                Rectangle {
                    id: row
                    required property string name
                    required property string status
                    required property string message

                    width: rows.width
                    height: 64
                    color: "#0E1420"
                    border.width: 1
                    border.color: status === "running" ? accent.color : status === "failed" ? accent.error : "#1E2A40"

                    Monogram {
                        id: rowMono
                        name: row.name
                        width: 40
                        height: 40
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        id: rowName
                        anchors { left: rowMono.right; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        width: 200
                        text: row.name
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.DemiBold
                        font.pixelSize: 16
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors {
                            left: rowName.right; leftMargin: 16
                            right: rowState.left; rightMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        text: row.message
                        color: row.status === "failed" ? "#E6ECF5" : "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    // Waiting: empty square. Running: blue bar sliding. Done: green check. Failed: red cross.
                    Item {
                        id: rowState
                        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        width: row.status === "running" ? 120 : 22
                        height: 22

                        CheckSquare {
                            anchors.right: parent.right
                            visible: row.status === "waiting"
                            checked: false
                        }
                        ResultMark {
                            anchors.right: parent.right
                            visible: row.status === "done" || row.status === "failed"
                            ok: row.status === "done"
                            size: 22
                        }
                        Rectangle {
                            visible: row.status === "running"
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 3
                            color: "#12203A"
                            clip: true
                            Rectangle {
                                width: 40
                                height: parent.height
                                color: accent.color
                                SequentialAnimation on x {
                                    running: row.status === "running"
                                    loops: Animation.Infinite
                                    NumberAnimation { from: -40; to: 120; duration: 1100; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Optimisations ────────────────────────────────────────

    // Square on/off switch: blue with the knob to the right when on
    // A row at the bottom of an app card: line above, label left, switch right
    component CardSwitch: Item {
        id: row
        property string text
        property bool on
        signal toggled()
        width: parent ? parent.width : 0
        height: 30
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.topMargin: -8
            height: 1
            color: "#1E2A40"
        }
        Text {
            anchors { left: parent.left; verticalCenter: rowSwitch.verticalCenter }
            text: row.text
            color: row.on ? "#E6ECF5" : "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: 13
        }
        ToggleSwitch {
            id: rowSwitch
            anchors { right: parent.right; bottom: parent.bottom }
            on: row.on
            onToggled: row.toggled()
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

    Flickable {
        id: tweaksView
        FastWheel { flick: tweaksView }
        visible: win.tab === "tweaks"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: tweakRows.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: tweakRows
            x: 48
            y: 32
            width: tweaksView.width - 96
            spacing: 12

            Repeater {
                model: tweakModel

                Column {
                    id: tweakRow
                    required property int index
                    required property string tweakId
                    required property string section
                    required property string name
                    required property string desc
                    required property string status
                    required property string message
                    required property string note
                    readonly property bool available: status !== "unavailable"
                    readonly property bool sectionStart: { win.tweakRev; return win.tweakSectionStart(index); }

                    // Settings that don't fit this computer (no Nvidia card, one graphics card…) aren't shown
                    visible: available
                    width: tweakRows.width
                    spacing: 12

                    Text {
                        visible: tweakRow.sectionStart
                        topPadding: tweakRow.index > 0 ? 20 : 0
                        text: tweakRow.section.toUpperCase()
                        color: "#8B98AD"
                        font.family: "Chakra Petch"
                        font.weight: Font.DemiBold
                        font.pixelSize: 14
                        font.letterSpacing: 2.5
                    }

                Rectangle {
                    width: parent.width
                    height: Math.max(92, tweakText.height + 36)
                    color: "#0E1420"
                    border.width: 1
                    border.color: tweakRow.status === "on" ? accent.color : "#1E2A40"

                    Column {
                        id: tweakText
                        anchors {
                            left: parent.left; leftMargin: 22
                            right: tweakSwitch.left; rightMargin: 24
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 5
                        Text {
                            width: parent.width
                            text: tweakRow.name
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                        }
                        Text {
                            width: parent.width
                            text: tweakRow.available ? tweakRow.desc : tweakRow.desc + " (Finns inte på den här datorn.)"
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            lineHeight: 1.15
                        }
                        Text {
                            visible: tweakRow.note !== ""
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: tweakRow.note
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                        Text {
                            visible: tweakRow.message !== ""
                            text: tweakRow.message
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                    }

                    ToggleSwitch {
                        id: tweakSwitch
                        anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                        on: tweakRow.status === "on"
                        enabledState: tweakRow.available && tweakRow.status !== "busy"
                        onToggled: backend.setTweak(tweakRow.tweakId, !on)
                    }
                }
                }
            }

            Text {
                topPadding: 20
                visible: { win.tweakRev; return !win.sectionShown("Utseende"); } // else drawn above the season switch
                text: "UTSEENDE"
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: 14
                font.letterSpacing: 2.5
            }

            // The accent colour: buttons, frames, switches, ticks, scroll bars and highlights in
            // Plasma, KDE programs, these windows, Firefox and the login screen (goblincakes-accent).
            Rectangle {
                id: colourRow
                readonly property var list: JSON.parse(backend.accents)
                readonly property var chosen: list.find(a => a.chosen) || ({ "name": "GOBLINCAKES blå" })
                property string hovered: ""
                width: tweakRows.width
                height: colourCol.height + 40
                color: "#0E1420"
                border.width: 1
                border.color: "#1E2A40"

                Column {
                    id: colourCol
                    anchors { left: parent.left; leftMargin: 22; right: parent.right; rightMargin: 22; top: parent.top; topMargin: 20 }
                    spacing: 14
                    Column {
                        width: parent.width
                        spacing: 5
                        Text {
                            text: "Färg"
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                        }
                        Text {
                            width: parent.width
                            text: "Knappar, ramar, reglage, kryssrutor, rullningslister och markeringar – i Plasma, KDE-program, GOBLINCAKES-fönstren, Firefox och inloggningen. Ändras direkt; vissa program och Firefox får färgen när de startas om."
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            lineHeight: 1.15
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: colourRow.list
                            Rectangle {
                                id: swatch
                                required property var modelData
                                readonly property bool busy: backend.accentBusy === modelData.id
                                width: 40
                                height: 40
                                color: "transparent"
                                border.width: modelData.chosen ? 2 : (swatchArea.containsMouse ? 1 : 0)
                                border.color: modelData.chosen ? "#E6ECF5" : "#8B98AD"
                                Rectangle {
                                    anchors { fill: parent; margins: 4 }
                                    color: swatch.modelData.color
                                    opacity: swatch.busy ? 0.5 : 1
                                    Canvas {
                                        anchors.fill: parent
                                        visible: swatch.modelData.chosen
                                        property color mark: swatch.modelData.on
                                        onMarkChanged: requestPaint()
                                        onPaint: {
                                            const ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = mark;
                                            ctx.lineWidth = 2.5;
                                            ctx.beginPath();
                                            ctx.moveTo(width / 2 - 7, height / 2);
                                            ctx.lineTo(width / 2 - 2.5, height / 2 + 4.5);
                                            ctx.lineTo(width / 2 + 6.5, height / 2 - 5);
                                            ctx.stroke();
                                        }
                                    }
                                }
                                MouseArea {
                                    id: swatchArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: colourRow.hovered = containsMouse ? swatch.modelData.name : ""
                                    onClicked: if (!swatch.modelData.chosen) backend.setAccent(swatch.modelData.id)
                                }
                            }
                        }
                    }
                    Text {
                        text: backend.accentBusy ? "Byter färg…"
                            : colourRow.hovered ? colourRow.hovered
                            : "Vald: " + colourRow.chosen.name
                        color: colourRow.hovered || backend.accentBusy ? "#E6ECF5" : "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                }
            }

            // The whole GOBLINCAKES look back (goblincakes-firstlogin --reset = `goblin dock reset`).
            // Other themes are fine – this is only the way back. Asks once before doing anything.
            Rectangle {
                id: lookRow
                property string state_: "idle"  // idle | confirm | done
                width: tweakRows.width
                height: Math.max(92, lookText.height + 36)
                color: "#0E1420"
                border.width: 1
                border.color: state_ === "confirm" ? accent.error : "#1E2A40"

                Column {
                    id: lookText
                    anchors {
                        left: parent.left; leftMargin: 22
                        right: lookButtons.left; rightMargin: 24
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 5
                    Text {
                        width: parent.width
                        text: "Återställ GOBLINCAKES-utseendet"
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.DemiBold
                        font.pixelSize: 16
                    }
                    Text {
                        width: parent.width
                        text: lookRow.state_ === "confirm"
                            ? "Tema, färger, typsnitt, terminalen, toppfältet och dockan blir som från början. Egna paneler och fästa program i dockan försvinner. Din terminalinställning sparas som config.ghostty.bak."
                            : lookRow.state_ === "done"
                            ? "Klart. Logga ut och in igen så att alla program får det."
                            : "Har du bytt tema i Systeminställningar och vill tillbaka? Det här ställer tillbaka allt till GOBLINCAKES."
                        color: lookRow.state_ === "done" ? "#E6ECF5" : "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                    }
                }

                Row {
                    id: lookButtons
                    anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    FlatButton {
                        visible: lookRow.state_ === "idle"
                        text: "Återställ…"
                        onClicked: lookRow.state_ = "confirm"
                    }
                    FlatButton {
                        visible: lookRow.state_ === "confirm"
                        text: "Avbryt"
                        onClicked: lookRow.state_ = "idle"
                    }
                    FlatButton {
                        visible: lookRow.state_ === "confirm"
                        primary: true
                        text: "Återställ"
                        onClicked: { backend.resetLook(); lookRow.state_ = "done"; }
                    }
                }
            }
        }
    }

    // ── Fönster: window layouts (goblincakes-tile, Meta+Ctrl+1–9) ─────────
    // KDE's own tiles per screen, drawn here: split, drag the borders, templates, and which
    // program opens in which tile. Several named layouts (Raid, Jobb …), each on Meta+Ctrl+N.
    // The tree: {dir: "h"|"v", children: [{size, …}]} or a tile {apps: [desktop ids]}.

    // A small flat button (templates, tile tools)
    component SmallButton: Rectangle {
        id: sb
        property string text
        property bool on: false
        property bool enabledState: true
        signal clicked()
        width: sbLabel.implicitWidth + 24
        height: 30
        opacity: enabledState ? 1 : 0.35
        color: on ? accent.dim : sbArea.containsMouse && enabledState ? "#12203A" : "transparent"
        border.width: 1
        border.color: on ? accent.color : "#2A3852"
        Text {
            id: sbLabel
            anchors.centerIn: parent
            text: sb.text
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: 13
        }
        MouseArea {
            id: sbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: sb.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (sb.enabledState) sb.clicked()
        }
    }

    Item {
        id: windowsView
        visible: win.tab === "windows"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }

        property var info: ({ "screens": [], "layouts": [], "apps": [], "current": {}, "active": "",
                              "suggest": { "main": [], "others": [], "from": "open", "second": true } })
        property bool suggesting: false
        property bool loaded: false
        property int sel: 0                 // the layout being edited
        property string selScreen: ""
        property var selPath: null          // the chosen tile (path in its screen's tree)
        property string pendingApp: ""      // clicked in the list: the next tile clicked gets it
        property string status: ""
        property string filter: ""
        readonly property var layout: info.layouts.length ? info.layouts[Math.min(sel, info.layouts.length - 1)] : null
        readonly property var appsById: {
            const m = {};
            for (const a of info.apps) m[a.id] = a;
            return m;
        }

        onVisibleChanged: if (visible && !loaded) backend.loadTiles()

        Connections {
            target: backend
            function onTilesLoaded(json) {
                if (!json) {
                    windowsView.status = "Kunde inte läsa skärmarna.";
                    return;
                }
                windowsView.info = JSON.parse(json);
                windowsView.loaded = true;
                const i = windowsView.info.layouts.findIndex(l => l.name === windowsView.info.active);
                windowsView.sel = Math.max(0, i);
            }
            function onTilesCaptured(json) {
                if (!json || !windowsView.layout)
                    return;
                const got = JSON.parse(json).screens || {};
                windowsView.edit(d => { Object.assign(d.layouts[windowsView.sel].screens, got); });
                windowsView.status = "Sparat som det ser ut nu.";
            }
            function onTilesSuggested(json) {
                windowsView.suggesting = false;
                const got = json ? JSON.parse(json) : null;
                if (!got || !Object.keys(got.screens || {}).length) {
                    windowsView.status = "Inget förslag – välj huvudfönster (★) eller program att ha med.";
                    return;
                }
                let at = windowsView.info.layouts.findIndex(l => l.name === got.name);
                if (at < 0 && windowsView.info.layouts.length >= 9) {
                    windowsView.status = "Du har redan 9 layouter – ta bort en först.";
                    return;
                }
                windowsView.edit(d => {
                    const screens = {};
                    for (const s of d.screens)  // screens the suggestion leaves out keep KDE's tiles as they are
                        screens[s.name] = JSON.parse(JSON.stringify(d.current[s.name] || {}));
                    Object.assign(screens, got.screens);
                    if (at < 0)
                        d.layouts.push({ "name": got.name, "screens": screens });
                    else
                        d.layouts[at].screens = screens;
                });
                windowsView.sel = at < 0 ? windowsView.info.layouts.length - 1 : at;
                windowsView.selPath = null;
                windowsView.status = "Förslaget är klart. Dra i kanterna eller flytta program om du vill – tryck sedan Använd.";
            }
            function onTileDone(message) {
                windowsView.status = message || "Klart.";
                windowsView.info = Object.assign({}, windowsView.info, { "active": windowsView.layout ? windowsView.layout.name : "" });
            }
        }

        Timer {
            id: saveTimer
            interval: 500
            onTriggered: backend.saveLayouts(JSON.stringify({ "active": windowsView.info.active, "layouts": windowsView.info.layouts,
                                                              "suggest": windowsView.info.suggest }))
        }

        // ── Changing the layouts (a copy, then saved half a second later) ──
        function edit(fn) {
            const d = JSON.parse(JSON.stringify(info));
            fn(d);
            info = d;
            saveTimer.restart();
        }
        function treeOf(d, conn) {
            const L = d.layouts[sel];
            if (!L.screens[conn])
                L.screens[conn] = {};
            return L.screens[conn];
        }
        function nodeAt(tree, path) {
            let n = tree;
            for (const i of path)
                n = n.children[i];
            return n;
        }
        function leavesOf(tree) {
            const kids = tree && tree.children ? tree.children : [];
            if (kids.length < 2)
                return [tree || {}];
            let out = [];
            for (const c of kids)
                out = out.concat(leavesOf(c));
            return out;
        }
        function flatten(node, x, y, w, h, path, out) {
            const kids = node && node.children ? node.children : [];
            if (kids.length >= 2) {
                const horiz = node.dir !== "v";
                let pos = 0;
                for (let i = 0; i < kids.length; i++) {
                    const s = kids[i].size;
                    const cx = horiz ? x + pos * w : x, cy = horiz ? y : y + pos * h;
                    const cw = horiz ? s * w : w, ch = horiz ? h : s * h;
                    flatten(kids[i], cx, cy, cw, ch, path.concat([i]), out);
                    if (i < kids.length - 1)
                        out.seps.push({ "horiz": horiz, "x": horiz ? cx + cw : x, "y": horiz ? y : cy + ch,
                                        "len": horiz ? h : w, "path": path, "index": i,
                                        "start": horiz ? cx : cy, "extent": horiz ? w : h, "pair": s + kids[i + 1].size });
                    pos += s;
                }
            } else {
                out.leaves.push({ "x": x, "y": y, "w": w, "h": h, "path": path,
                                  "apps": (node && node.apps) || [], "n": out.leaves.length + 1 });
            }
        }
        function samePath(a, b) {
            return !!a && !!b && a.length === b.length && a.every((v, i) => v === b[i]);
        }
        function toggleMain(app) {
            edit(d => {
                const m = d.suggest.main, i = m.indexOf(app);
                if (i >= 0) m.splice(i, 1); else m.push(app);
                d.suggest.others = d.suggest.others.filter(a => a !== app);
            });
        }
        function toggleOther(app) {
            edit(d => {
                const o = d.suggest.others, i = o.indexOf(app);
                if (i >= 0) o.splice(i, 1); else o.push(app);
                d.suggest.main = d.suggest.main.filter(a => a !== app);
            });
        }
        function setAuto(on) {
            info = Object.assign({}, info, { "auto": on });
            backend.tileAuto(on);
        }
        function setOwnDesktop(on) {
            const i = sel;
            edit(d => { d.layouts[i].desktop = on ? i + 1 : 0; });
            status = on ? "Layouten får skrivbord " + (i + 1) + " – Använd eller Meta+Ctrl+" + (i + 1) + " byter dit."
                        : "Layouten använder skrivbordet som visas.";
        }
        function setSuggest(key, value) {
            edit(d => { d.suggest[key] = value; });
        }
        function suggestNow() {
            suggesting = true;
            status = info.suggest.from === "open" ? "Tittar vilka program som är öppna…" : "Gör ett förslag…";
            backend.suggestTiles(JSON.stringify(info.suggest));
        }
        function newLayout() {
            const names = info.layouts.map(l => l.name);
            let n = info.layouts.length + 1, name = "Layout " + n;
            while (names.indexOf(name) >= 0)
                name = "Layout " + (++n);
            edit(d => {
                const screens = {};
                for (const s of d.screens)
                    screens[s.name] = JSON.parse(JSON.stringify(d.current[s.name] || {}));
                d.layouts.push({ "name": name, "screens": screens });
            });
            sel = info.layouts.length - 1;
            selPath = null;
            status = "Ny layout med KDE:s rutor som de är nu. Ändra, dra in program och tryck Använd.";
        }
        function removeLayout() {
            const i = sel;
            edit(d => { d.layouts.splice(i, 1); if (d.active === (info.layouts[i] || {}).name) d.active = ""; });
            sel = Math.max(0, i - 1);
            selPath = null;
        }
        function rename(name) {
            name = name.trim();
            if (!name || !layout || name === layout.name || info.layouts.some(l => l.name === name))
                return;
            const old = layout.name;
            edit(d => { d.layouts[sel].name = name; if (d.active === old) d.active = name; });
        }
        function split(dir) {
            const conn = selScreen, path = selPath;
            if (!conn || !path)
                return;
            let next = path;
            edit(d => {
                const tree = treeOf(d, conn);
                if (!path.length) {
                    d.layouts[sel].screens[conn] = { "dir": dir, "children": [{ "size": 0.5, "apps": tree.apps || [] }, { "size": 0.5 }] };
                    next = [0];
                    return;
                }
                const parent = nodeAt(tree, path.slice(0, -1)), i = path[path.length - 1], node = parent.children[i];
                if (parent.dir === dir) {
                    node.size /= 2;
                    parent.children.splice(i + 1, 0, { "size": node.size });
                } else {
                    parent.children[i] = { "dir": dir, "size": node.size, "children": [{ "size": 0.5, "apps": node.apps || [] }, { "size": 0.5 }] };
                    next = path.concat([0]);
                }
            });
            selPath = next;
        }
        function removeTile() {
            const conn = selScreen, path = selPath;
            if (!conn || !path || !path.length)
                return;
            edit(d => {
                const tree = treeOf(d, conn);
                const parent = nodeAt(tree, path.slice(0, -1)), i = path[path.length - 1];
                const gone = parent.children.splice(i, 1)[0];
                const neighbour = parent.children[Math.max(0, i - 1)];
                neighbour.size += gone.size;
                if (!neighbour.children && gone.apps)
                    neighbour.apps = (neighbour.apps || []).concat(gone.apps);
                if (parent.children.length === 1) {
                    const only = parent.children[0];
                    if (path.length === 1) {
                        delete only.size;
                        d.layouts[sel].screens[conn] = only;
                    } else {
                        only.size = parent.size;
                        nodeAt(tree, path.slice(0, -2)).children[path[path.length - 2]] = only;
                    }
                }
            });
            selPath = null;
        }
        function template(kind) {
            const conn = selScreen || (info.screens[0] || {}).name;
            if (!conn)
                return;
            const half = (a, b) => ({ "dir": "h", "children": [{ "size": a }, { "size": b }] });
            const trees = {
                "full": {},
                "half": half(0.5, 0.5),
                "twothirds": half(0.667, 0.333),
                "three": { "dir": "h", "children": [{ "size": 0.334 }, { "size": 0.333 }, { "size": 0.333 }] },
                "grid": { "dir": "h", "children": [
                    { "size": 0.5, "dir": "v", "children": [{ "size": 0.5 }, { "size": 0.5 }] },
                    { "size": 0.5, "dir": "v", "children": [{ "size": 0.5 }, { "size": 0.5 }] }] },
                "bigtwo": { "dir": "h", "children": [{ "size": 0.6 },
                    { "size": 0.4, "dir": "v", "children": [{ "size": 0.5 }, { "size": 0.5 }] }] }
            };
            edit(d => {
                const old = leavesOf(treeOf(d, conn)).map(l => l.apps || []);
                const tree = JSON.parse(JSON.stringify(trees[kind]));
                const fresh = leavesOf(tree);
                old.forEach((apps, i) => {
                    if (!apps.length) return;
                    const leaf = fresh[Math.min(i, fresh.length - 1)];
                    leaf.apps = (leaf.apps || []).concat(apps);
                });
                d.layouts[sel].screens[conn] = tree;
            });
            selScreen = conn;
            selPath = null;
        }
        function assign(conn, path, app) {
            if (!app)
                return;
            edit(d => {
                const L = d.layouts[sel];
                for (const c in L.screens)
                    for (const leaf of leavesOf(L.screens[c]))
                        if (leaf.apps)
                            leaf.apps = leaf.apps.filter(a => a !== app);
                const leaf = path.length ? nodeAt(treeOf(d, conn), path) : treeOf(d, conn);
                leaf.apps = (leaf.apps || []).concat([app]);
            });
            pendingApp = "";
            selScreen = conn;
            selPath = path;
        }
        function unassign(conn, path, app) {
            edit(d => {
                const leaf = path.length ? nodeAt(treeOf(d, conn), path) : treeOf(d, conn);
                leaf.apps = (leaf.apps || []).filter(a => a !== app);
            });
        }
        function resize(conn, sep, size) {
            edit(d => {
                const parent = nodeAt(treeOf(d, conn), sep.path);
                parent.children[sep.index].size = size;
                parent.children[sep.index + 1].size = sep.pair - size;
            });
        }

        // ── Left: the layouts and the screens ──
        Flickable {
            id: windowsFlick
            FastWheel { flick: windowsFlick }
            anchors { left: parent.left; right: appPane.left; rightMargin: 24; top: parent.top; bottom: parent.bottom }
            contentHeight: winCol.height + 56
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: winCol
                x: 48
                y: 28
                width: windowsFlick.width - 48
                spacing: 16

                Text {
                    width: parent.width
                    visible: !windowsView.loaded
                    text: windowsView.status || "Läser skärmarna…"
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                }

                // The layouts: 1 Raid, 2 Jobb … (Meta+Ctrl+number)
                Flow {
                    width: parent.width
                    spacing: 8
                    visible: windowsView.loaded
                    Repeater {
                        model: windowsView.info.layouts
                        Rectangle {
                            id: chip
                            required property var modelData
                            required property int index
                            readonly property bool chosen: index === windowsView.sel
                            width: chipRow.implicitWidth + 28
                            height: 36
                            color: chosen ? accent.dim : chipArea.containsMouse ? "#111A2A" : "#0E1420"
                            border.width: 1
                            border.color: chosen ? accent.color : "#1E2A40"
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: chip.index + 1
                                    color: chip.chosen ? "#E6ECF5" : "#8B98AD"
                                    font.family: "IBM Plex Mono"
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: chip.modelData.name
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.weight: chip.chosen ? Font.DemiBold : Font.Normal
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    visible: chip.modelData.name === windowsView.info.active
                                    width: 7
                                    height: 7
                                    color: "#3FB950"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { windowsView.sel = chip.index; windowsView.selPath = null; }
                            }
                        }
                    }
                    SmallButton {
                        height: 36
                        visible: windowsView.info.layouts.length < 9
                        text: "+ Ny layout"
                        onClicked: windowsView.newLayout()
                    }
                }

                // Automatic tiles (15 Oct): new windows fill free tiles, drag = swap
                Row {
                    visible: windowsView.loaded
                    width: parent.width
                    spacing: 12
                    SmallButton {
                        anchors.verticalCenter: parent.verticalCenter
                        on: !!windowsView.info.auto
                        text: windowsView.info.auto ? "Automatiska rutor: på" : "Automatiska rutor: av"
                        onClicked: windowsView.setAuto(!windowsView.info.auto)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 220
                        text: "Nya fönster läggs i nästa lediga ruta, och drar du ett fönster till en annan ruta byter de två plats. "
                              + "Meta+Shift+T tar ut ett fönster ur rutorna (eller tillbaka)."
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                // Main windows → a suggested layout (15 Oct, the user's idea)
                Rectangle {
                    visible: windowsView.loaded
                    width: parent.width
                    height: suggestCol.implicitHeight + 28
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"
                    Column {
                        id: suggestCol
                        x: 16
                        y: 14
                        width: parent.width - 32
                        spacing: 10
                        Flow {
                            width: parent.width
                            spacing: 8
                            Text {
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                                text: "HUVUDFÖNSTER"
                                color: "#8B98AD"
                                font.family: "Chakra Petch"
                                font.weight: Font.DemiBold
                                font.pixelSize: 13
                                font.letterSpacing: 2
                            }
                            Repeater {
                                model: windowsView.info.suggest.main
                                SmallButton {
                                    required property string modelData
                                    on: true
                                    text: "★ " + (windowsView.appsById[modelData] || { "name": modelData }).name + "  ✕"
                                    onClicked: windowsView.toggleMain(modelData)
                                }
                            }
                            Text {
                                visible: !windowsView.info.suggest.main.length
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                                text: "Markera dina viktigaste program med ★ i listan till höger."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                        }
                        Flow {
                            width: parent.width
                            spacing: 8
                            Text {
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                                text: "De andra:"
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            SmallButton {
                                text: "Programmen som är öppna nu"
                                on: windowsView.info.suggest.from === "open"
                                onClicked: windowsView.setSuggest("from", "open")
                            }
                            SmallButton {
                                text: "Valda i listan (✓)" + (windowsView.info.suggest.others.length ? " · " + windowsView.info.suggest.others.length : "")
                                on: windowsView.info.suggest.from === "chosen"
                                onClicked: windowsView.setSuggest("from", "chosen")
                            }
                            Item { width: 8; height: 1 }
                            SmallButton {
                                visible: windowsView.info.screens.length > 1
                                text: "På skärm 2"
                                on: windowsView.info.suggest.second
                                onClicked: windowsView.setSuggest("second", true)
                            }
                            SmallButton {
                                visible: windowsView.info.screens.length > 1
                                text: "Allt på huvudskärmen"
                                on: !windowsView.info.suggest.second
                                onClicked: windowsView.setSuggest("second", false)
                            }
                        }
                        Row {
                            spacing: 12
                            FlatButton {
                                primary: true
                                enabledState: !windowsView.suggesting && (windowsView.info.suggest.main.length > 0
                                              || (windowsView.info.suggest.from === "chosen" && windowsView.info.suggest.others.length > 0)
                                              || windowsView.info.suggest.from === "open")
                                text: windowsView.suggesting ? "Gör förslag…" : "Föreslå layout"
                                onClicked: windowsView.suggestNow()
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: suggestCol.width - 200
                                text: windowsView.info.suggest.main.length === 1
                                    ? "Huvudfönstret i mitten, de andra på sidorna."
                                    : windowsView.info.suggest.main.length > 1
                                    ? "Huvudfönstren stora bredvid varandra (⅔ av höjden), de andra i en rad under."
                                    : "Utan huvudfönster delas skärmen lika."
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: windowsView.loaded && !windowsView.layout
                    text: "Gör en layout: hur rutorna ligger på varje skärm och vilket program som öppnas i vilken ruta. Spara flera – till exempel Raid, Jobb och Ianseo – och byt med Meta+Ctrl+1, 2, 3 …"
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                }

                // Name, shortcut, save as it is now, remove
                Row {
                    visible: !!windowsView.layout
                    spacing: 10
                    FlatField {
                        id: layoutName
                        width: 220
                        height: 36
                        hint: "Namn"
                        text: windowsView.layout ? windowsView.layout.name : ""
                        onAccepted: windowsView.rename(text)
                        onActiveFocusChanged: if (!activeFocus) windowsView.rename(text)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Meta+Ctrl+" + (windowsView.sel + 1)
                        color: accent.text
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 13
                    }
                    SmallButton {
                        height: 36
                        text: "Spara som det ser ut nu"
                        onClicked: { windowsView.status = "Läser KDE:s rutor…"; backend.captureTiles(); }
                    }
                    SmallButton {
                        height: 36
                        on: !!(windowsView.layout && windowsView.layout.desktop)
                        text: windowsView.layout && windowsView.layout.desktop
                              ? "Eget skrivbord (" + windowsView.layout.desktop + ")" : "Eget skrivbord"
                        onClicked: windowsView.setOwnDesktop(!(windowsView.layout && windowsView.layout.desktop))
                    }
                    SmallButton {
                        height: 36
                        text: "Ta bort layouten"
                        onClicked: windowsView.removeLayout()
                    }
                }

                // The screens side by side, as in System Settings → Display
                Item {
                    id: screensArea
                    visible: !!windowsView.layout
                    width: parent.width
                    readonly property var box: {
                        const s = windowsView.info.screens;
                        if (!s.length) return { "x": 0, "y": 0, "w": 1, "h": 1 };
                        const x0 = Math.min(...s.map(o => o.x)), y0 = Math.min(...s.map(o => o.y));
                        const x1 = Math.max(...s.map(o => o.x + o.w)), y1 = Math.max(...s.map(o => o.y + o.h));
                        return { "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0 };
                    }
                    readonly property real scale: Math.min((width - 12) / box.w, 330 / box.h)
                    height: box.h * scale + 30

                    Repeater {
                        model: windowsView.info.screens
                        Item {
                            id: scr
                            required property var modelData
                            readonly property string conn: modelData.name
                            readonly property var tree: windowsView.layout ? (windowsView.layout.screens[conn] || {}) : {}
                            readonly property var flat: {
                                const out = { "leaves": [], "seps": [] };
                                windowsView.flatten(tree, 0, 0, screenBox.width, screenBox.height, [], out);
                                return out;
                            }
                            x: (modelData.x - screensArea.box.x) * screensArea.scale + 4
                            y: (modelData.y - screensArea.box.y) * screensArea.scale
                            width: modelData.w * screensArea.scale - 8
                            height: modelData.h * screensArea.scale + 26

                            Text {
                                text: "Skärm " + scr.modelData.n + " · " + scr.conn + (scr.modelData.n === 1 ? " · huvudskärm" : "")
                                color: windowsView.selScreen === scr.conn ? "#E6ECF5" : "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                            }
                            Rectangle {
                                id: screenBox
                                y: 22
                                width: parent.width
                                height: scr.modelData.h * screensArea.scale
                                color: "#07090D"
                                border.width: 1
                                border.color: "#2A3852"

                                Repeater {
                                    model: scr.flat.leaves
                                    Rectangle {
                                        id: leaf
                                        required property var modelData
                                        readonly property bool chosen: windowsView.selScreen === scr.conn && windowsView.samePath(windowsView.selPath, modelData.path)
                                        x: modelData.x + 3
                                        y: modelData.y + 3
                                        width: modelData.w - 6
                                        height: modelData.h - 6
                                        color: drop.containsDrag ? accent.dim : leafArea.containsMouse ? "#111A2A" : "#0B1018"
                                        border.width: chosen || drop.containsDrag ? 2 : 1
                                        border.color: chosen || drop.containsDrag ? accent.color : "#1E2A40"
                                        Text {
                                            x: 8
                                            y: 6
                                            text: leaf.modelData.n
                                            color: leaf.chosen ? accent.text : "#5C6880"
                                            font.family: "Chakra Petch"
                                            font.weight: Font.Bold
                                            font.pixelSize: 15
                                        }
                                        MouseArea {
                                            id: leafArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (windowsView.pendingApp)
                                                    windowsView.assign(scr.conn, leaf.modelData.path, windowsView.pendingApp);
                                                windowsView.selScreen = scr.conn;
                                                windowsView.selPath = leaf.modelData.path;
                                            }
                                        }
                                        Column {
                                            anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; top: parent.top; topMargin: 28 }
                                            spacing: 4
                                            clip: true
                                            Repeater {
                                                model: leaf.modelData.apps
                                                Rectangle {
                                                    id: appChip
                                                    required property string modelData
                                                    readonly property var app: windowsView.appsById[modelData] || { "name": modelData, "icon": "" }
                                                    width: parent.width
                                                    height: 24
                                                    color: "#12203A"
                                                    border.width: 1
                                                    border.color: "#2A3852"
                                                    Image {
                                                        id: chipIcon
                                                        x: 4
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 16
                                                        height: 16
                                                        sourceSize.width: 32
                                                        sourceSize.height: 32
                                                        source: appChip.app.icon ? "image://icon/" + appChip.app.icon : ""
                                                    }
                                                    Text {
                                                        anchors { left: chipIcon.right; leftMargin: 6; right: chipX.left; verticalCenter: parent.verticalCenter }
                                                        text: appChip.app.name
                                                        color: "#E6ECF5"
                                                        font.family: "IBM Plex Sans"
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        id: chipX
                                                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                                        text: "✕"
                                                        color: chipXArea.containsMouse ? accent.errorBright : "#8B98AD"
                                                        font.pixelSize: 11
                                                        MouseArea {
                                                            id: chipXArea
                                                            anchors { fill: parent; margins: -5 }
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: windowsView.unassign(scr.conn, leaf.modelData.path, appChip.modelData)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        DropArea {
                                            id: drop
                                            anchors.fill: parent
                                            keys: ["goblincakes-app"]
                                            onDropped: drop => windowsView.assign(scr.conn, leaf.modelData.path, drop.source.appId)
                                        }
                                    }
                                }

                                // The borders between tiles: drag to make one bigger (shown while dragging,
                                // set when let go – the tiles are drawn again from the new sizes)
                                Repeater {
                                    model: scr.flat.seps
                                    Item {
                                        id: sep
                                        required property var modelData
                                        property real offset: 0
                                        x: modelData.horiz ? modelData.x - 5 + offset : modelData.x
                                        y: modelData.horiz ? modelData.y : modelData.y - 5 + offset
                                        width: modelData.horiz ? 10 : modelData.len
                                        height: modelData.horiz ? modelData.len : 10
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: sep.modelData.horiz ? 2 : parent.width
                                            height: sep.modelData.horiz ? parent.height : 2
                                            color: sepArea.pressed || sepArea.containsMouse ? accent.color : "transparent"
                                        }
                                        MouseArea {
                                            id: sepArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: sep.modelData.horiz ? Qt.SplitHCursor : Qt.SplitVCursor
                                            property real pressAt: 0
                                            onPressed: mouse => { pressAt = sep.modelData.horiz ? mapToItem(screenBox, mouse.x, 0).x : mapToItem(screenBox, 0, mouse.y).y; }
                                            onPositionChanged: mouse => {
                                                if (!pressed) return;
                                                const at = sep.modelData.horiz ? mapToItem(screenBox, mouse.x, 0).x : mapToItem(screenBox, 0, mouse.y).y;
                                                sep.offset = at - pressAt;
                                            }
                                            onReleased: {
                                                const m = sep.modelData;
                                                const edge = (m.horiz ? m.x : m.y) + sep.offset;
                                                const size = Math.max(0.08, Math.min(m.pair - 0.08, (edge - m.start) / m.extent));
                                                sep.offset = 0;
                                                windowsView.resize(scr.conn, m, size);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Tools for the chosen tile and templates for its screen
                Flow {
                    visible: !!windowsView.layout
                    width: parent.width
                    spacing: 8
                    SmallButton {
                        text: "Dela sida vid sida"
                        enabledState: !!windowsView.selPath
                        onClicked: windowsView.split("h")
                    }
                    SmallButton {
                        text: "Dela uppe/nere"
                        enabledState: !!windowsView.selPath
                        onClicked: windowsView.split("v")
                    }
                    SmallButton {
                        text: "Ta bort rutan"
                        enabledState: !!windowsView.selPath && windowsView.selPath.length > 0
                        onClicked: windowsView.removeTile()
                    }
                }
                Flow {
                    visible: !!windowsView.layout
                    width: parent.width
                    spacing: 8
                    Text {
                        height: 30
                        verticalAlignment: Text.AlignVCenter
                        text: "Mall för " + (windowsView.selScreen || "skärm 1") + ":"
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                    Repeater {
                        model: [["full", "Hel"], ["half", "50/50"], ["twothirds", "⅔ + ⅓"], ["three", "Tre kolumner"],
                                ["grid", "2 × 2"], ["bigtwo", "Stor + två små"]]
                        SmallButton {
                            required property var modelData
                            text: modelData[1]
                            onClicked: windowsView.template(modelData[0])
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: !!windowsView.layout
                    text: windowsView.status || "Klicka på en ruta för att dela den, dra i kanterna mellan rutorna, och dra ett program från listan till en ruta. Spel och dialogrutor lämnas i fred."
                    color: windowsView.status ? "#E6ECF5" : "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                }
            }
        }
        FlatScrollBar { flick: windowsFlick }

        // ── Right: the programs to drag into the tiles ──
        Rectangle {
            id: appPane
            visible: windowsView.loaded
            anchors { right: parent.right; rightMargin: 48; top: parent.top; topMargin: 28; bottom: parent.bottom; bottomMargin: 20 }
            width: 270
            color: "#0E1420"
            border.width: 1
            border.color: "#1E2A40"

            FlatField {
                id: appSearch
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                height: 36
                hint: "Sök program"
                onTextChanged: windowsView.filter = text.toLowerCase()
            }
            Text {
                id: appHint
                anchors { left: parent.left; right: parent.right; top: appSearch.bottom; margins: 10; topMargin: 8 }
                text: windowsView.pendingApp ? "Klicka på rutan där " + (windowsView.appsById[windowsView.pendingApp] || {}).name + " ska öppnas."
                                             : "Dra till en ruta – eller klicka här och sedan på rutan. ★ = huvudfönster"
                                               + (windowsView.info.suggest.from === "chosen" ? ", ✓ = med i förslaget." : ".")
                color: windowsView.pendingApp ? accent.text : "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
            ListView {
                id: appList
                FastWheel { flick: appList }
                anchors { left: parent.left; right: parent.right; top: appHint.bottom; bottom: parent.bottom; topMargin: 8; bottomMargin: 6 }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: windowsView.info.apps.filter(a => !windowsView.filter || a.name.toLowerCase().indexOf(windowsView.filter) >= 0 || a.word.indexOf(windowsView.filter) >= 0)
                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    width: appList.width
                    height: 34
                    color: windowsView.pendingApp === modelData.id ? accent.dim : rowArea.containsMouse ? "#111A2A" : "transparent"
                    Image {
                        id: rowIcon
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        sourceSize.width: 40
                        sourceSize.height: 40
                        source: appRow.modelData.icon ? "image://icon/" + appRow.modelData.icon : ""
                    }
                    readonly property bool isMain: windowsView.info.suggest.main.indexOf(modelData.id) >= 0
                    readonly property bool isOther: windowsView.info.suggest.others.indexOf(modelData.id) >= 0
                    Text {
                        anchors { left: rowIcon.right; leftMargin: 10; right: rowMarks.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        text: appRow.modelData.name
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                    Row { // ★ = main window, ✓ = one of the others (when "Valda i listan")
                        id: rowMarks
                        z: 2
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text {
                            visible: windowsView.info.suggest.from === "chosen" && !appRow.isMain
                            width: 24
                            height: 26
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "✓"
                            color: appRow.isOther ? accent.text : (checkArea.containsMouse ? "#8B98AD" : "#2A3852")
                            font.pixelSize: 15
                            MouseArea {
                                id: checkArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: windowsView.toggleOther(appRow.modelData.id)
                            }
                        }
                        Text {
                            width: 24
                            height: 26
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: appRow.isMain ? "★" : "☆"
                            color: appRow.isMain ? accent.text : (starArea.containsMouse ? "#8B98AD" : "#2A3852")
                            font.pixelSize: 16
                            MouseArea {
                                id: starArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: windowsView.toggleMain(appRow.modelData.id)
                            }
                        }
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.OpenHandCursor
                        drag.target: appGhost
                        drag.threshold: 6
                        onPressed: mouse => {
                            const p = mapToItem(appGhost.parent, mouse.x, mouse.y);
                            appGhost.appId = appRow.modelData.id;
                            appGhost.label = appRow.modelData.name;
                            appGhost.x = p.x - 16;
                            appGhost.y = p.y - 14;
                        }
                        onPositionChanged: if (drag.active) appGhost.dragging = true
                        onReleased: {
                            if (appGhost.dragging) {
                                appGhost.Drag.drop();
                                appGhost.dragging = false;
                            } else {
                                windowsView.pendingApp = windowsView.pendingApp === appRow.modelData.id ? "" : appRow.modelData.id;
                            }
                        }
                    }
                }
            }
            FlatScrollBar { flick: appList }
        }
    }

    // A program being dragged from the list to a tile
    Rectangle {
        id: appGhost
        property string appId
        property string label
        property bool dragging: false
        parent: win.contentItem
        z: 100
        visible: dragging
        width: ghostText.implicitWidth + 24
        height: 28
        color: accent.color
        opacity: 0.92
        Drag.active: dragging
        Drag.keys: ["goblincakes-app"]
        Drag.hotSpot.x: 16
        Drag.hotSpot.y: 14
        Text {
            id: ghostText
            anchors.centerIn: parent
            text: appGhost.label
            color: accent.on
            font.family: "IBM Plex Sans"
            font.pixelSize: 13
        }
    }

    // ── Graphics drivers ─────────────────────────────────────

    Flickable {
        id: graphicsView
        FastWheel { flick: graphicsView }
        visible: win.tab === "graphics"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: gfxCol.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        readonly property bool switching: backend.gpuBusy
        readonly property bool pendingChange: !!win.gpu.pending && win.gpu.pending !== win.gpu.variant
        // Installed from the ISO with the Nvidia variant chosen: fetched after the first start
        readonly property bool fetching: !!win.gpu.origin && win.gpu.origin !== win.gpu.variant && !win.gpu.pending
        readonly property string after: win.gpu.pending || win.gpu.variant || "base"
        // The Nvidia variants: nvidia (current driver, RTX 20/GTX 16 and newer) and
        // nvidia-legacy (Nvidia's 580 driver for GTX 750/900/10, which 590+ dropped)
        readonly property bool onNvidia: win.gpu.variant === "nvidia" || win.gpu.variant === "nvidia-legacy"
        readonly property string legacyCard: ((win.gpu.cards || []).find(c => c.legacy) || {}).name || "Nvidia-kortet"
        function driverName(v) {
            return v === "nvidia-legacy" ? "Nvidias legacy-drivrutin" : v === "nvidia" ? "Nvidia-drivrutinerna" : "Grundvarianten";
        }
        function headline() {
            const g = win.gpu;
            if (fetching)
                return driverName(g.origin) + (g.origin === "nvidia" ? " hämtas" : " hämtas") + " i bakgrunden.";
            if (pendingChange)
                return g.pending === "base" ? "Nvidia-drivrutinerna tas bort när du startar om."
                    : driverName(g.pending) + (g.pending === "nvidia" ? " är nedladdade" : " är nedladdad") + " – starta om för att använda " + (g.pending === "nvidia" ? "dem." : "den.");
            if (g.variant === "nvidia-legacy")
                return g.nvidiaLegacy ? "Nvidias legacy-drivrutin (580) är installerad." : "Nvidias legacy-drivrutin är installerad, men den passar inte det här grafikkortet.";
            if (g.variant === "nvidia")
                return g.nvidiaSupported ? "Nvidia-drivrutinerna är installerade."
                    : g.nvidiaLegacy ? "Nvidia-drivrutinerna är installerade, men " + legacyCard + " behöver legacy-drivrutinen."
                    : g.hasNvidia ? "Nvidia-drivrutinerna är installerade, men de stöder inte det här kortet."
                    : "Nvidia-drivrutinerna är installerade, men datorn har inget Nvidia-kort.";
            if (g.nvidiaLegacy && !g.nvidiaSupported)
                return legacyCard + " behöver Nvidias legacy-drivrutin.";
            return g.hasNvidia ? "Nvidia-kortet kör med den öppna grunddrivrutinen." : "Du har redan rätt drivrutiner.";
        }
        function detail() {
            const g = win.gpu;
            if (fetching)
                return "Installationen valde dem efter ditt grafikkort. Du får en notis när de är klara – sedan räcker en omstart.";
            if (pendingChange)
                return "Vill du inte byta ändå: tryck Ångra. Den nuvarande varianten finns kvar i startmenyn.";
            if (g.variant === "nvidia-legacy")
                return g.nvidiaLegacy
                    ? "Allt är klart för spel. Drivrutinen uppdateras med goblin update. Nvidia ger 580-serien bara säkerhetsuppdateringar (till oktober 2028), inga förbättringar för nya spel."
                    : g.nvidiaSupported ? "Kortet klarar Nvidias nya drivrutin – byt till den för bäst stöd."
                    : "Ta bort den för ett renare system.";
            if (g.variant === "nvidia")
                return g.nvidiaSupported ? "Allt är klart för spel."
                    : g.nvidiaLegacy ? "Nvidias nya drivrutin stöder inte GTX 750/900/10 – byt till legacy-drivrutinen (580)."
                    : "De tar plats och lägger till Nvidia-inställningar vid start. Ta bort dem för ett renare system (ungefär 1 GB).";
            if (g.nvidiaLegacy && !g.nvidiaSupported)
                return "GTX 750/900/10-kort fungerar bara med Nvidias äldre 580-drivrutin – Nvidias nya stöder dem inte längre. Utan den kör kortet med den öppna drivrutinen: skrivbordet fungerar, men spel går mycket långsamt. Den laddas ner (bara skillnaden, ungefär 1 GB), används efter en omstart och uppdateras sedan med goblin update.";
            if (g.hasNvidia && !g.nvidiaSupported)
                return "Kortet är för gammalt för Nvidias drivrutiner för dagens Linux. Den öppna drivrutinen fungerar för skrivbordet, men ger lägre prestanda i spel.";
            if (g.hasNvidia)
                return "Skrivbordet fungerar, men spel går mycket bättre med Nvidias egna drivrutiner. De laddas ner (bara skillnaden, ungefär 1 GB) och används efter en omstart.";
            return "AMD och Intel använder de öppna drivrutinerna (Mesa), som redan finns i GOBLINCAKES. Inget behöver laddas ner.";
        }

        Column {
            id: gfxCol
            x: 48
            y: 32
            width: graphicsView.width - 96
            spacing: 14

            Text {
                text: "DITT GRAFIKKORT"
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: 14
                font.letterSpacing: 2.5
            }

            Repeater {
                model: win.gpu.cards || []
                Rectangle {
                    required property var modelData
                    width: gfxCol.width
                    height: 72
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"
                    Monogram {
                        id: cardMono
                        name: modelData.vendor === "nvidia" ? "Nvidia" : modelData.vendor === "amd" ? "AMD" : modelData.vendor === "intel" ? "Intel" : "?"
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        anchors { left: cardMono.right; leftMargin: 16; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        text: modelData.name
                        elide: Text.ElideRight
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.DemiBold
                        font.pixelSize: 16
                    }
                }
            }

            // Laptop with two cards: which one does what
            Rectangle {
                visible: !!win.gpu.hybrid
                width: gfxCol.width
                height: hybridText.height + 36
                color: "#0E1420"
                border.width: 1
                border.color: "#1E2A40"
                Text {
                    id: hybridText
                    x: 22
                    y: 18
                    width: parent.width - 44
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                    textFormat: Text.StyledText
                    text: "<font color='#E6ECF5'><b>" + (win.gpu.laptop ? "Laptop" : "Dator") + " med två grafikkort.</b></font> "
                        + "Skrivbordet körs på det inbyggda kortet, som sparar ström. Spel från Steam, Lutris och Heroic startar på det kraftfulla "
                        + (win.gpu.dgpu === "nvidia" ? "Nvidia-kortet" : win.gpu.dgpu === "amd" ? "AMD-kortet" : "kortet")
                        + " (Inställningar → Spel på det kraftfulla grafikkortet). Andra program: högerklicka → Kör med dedikerat grafikkort."
                }
            }

            Item { width: 1; height: 10 }

            Text {
                text: "DRIVRUTINER"
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: 14
                font.letterSpacing: 2.5
            }

            Rectangle {
                width: gfxCol.width
                height: driverCol.height + 40
                color: "#0E1420"
                border.width: 1
                border.color: graphicsView.pendingChange || graphicsView.switching ? accent.color : "#1E2A40"

                Column {
                    id: driverCol
                    x: 22
                    y: 20
                    width: parent.width - 44
                    spacing: 14

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.DemiBold
                        font.pixelSize: 16
                        text: graphicsView.headline()
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        lineHeight: 1.15
                        text: graphicsView.detail()
                    }

                    // While switching: status + sliding bar
                    Column {
                        visible: graphicsView.switching
                        spacing: 8
                        Text {
                            text: win.gpuMessage || "Startar…"
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 14
                        }
                        Rectangle {
                            width: 200
                            height: 3
                            color: "#12203A"
                            clip: true
                            Rectangle {
                                width: 48
                                height: parent.height
                                color: accent.color
                                SequentialAnimation on x {
                                    running: graphicsView.switching
                                    loops: Animation.Infinite
                                    NumberAnimation { from: -48; to: 200; duration: 1100; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                    }
                    Text {
                        visible: !graphicsView.switching && win.gpuMessage !== ""
                        text: win.gpuMessage
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                    }

                    Row {
                        visible: !graphicsView.switching
                        spacing: 12
                        FlatButton {
                            visible: !graphicsView.pendingChange && !graphicsView.fetching && win.gpu.variant === "base" && !!win.gpu.nvidiaSupported
                            primary: true
                            text: "Installera Nvidia-drivrutiner"
                            onClicked: { win.gpuMessage = ""; backend.switchVariant("nvidia"); }
                        }
                        FlatButton {
                            // GTX 750/900/10: Nvidia's 580 driver (goblincakes-nvidia-legacy)
                            visible: !graphicsView.pendingChange && !graphicsView.fetching && win.gpu.variant !== "nvidia-legacy"
                                     && !!win.gpu.nvidiaLegacy && !win.gpu.nvidiaSupported
                            primary: true
                            text: win.gpu.variant === "nvidia" ? "Byt till legacy-drivrutinen" : "Installera Nvidias legacy-drivrutin"
                            onClicked: { win.gpuMessage = ""; backend.switchVariant("nvidia-legacy"); }
                        }
                        FlatButton {
                            visible: !graphicsView.pendingChange && !graphicsView.fetching && win.gpu.variant === "nvidia-legacy" && !!win.gpu.nvidiaSupported
                            primary: true
                            text: "Byt till Nvidias nya drivrutin"
                            onClicked: { win.gpuMessage = ""; backend.switchVariant("nvidia"); }
                        }
                        FlatButton {
                            visible: !graphicsView.pendingChange && !graphicsView.fetching && graphicsView.onNvidia
                            primary: !win.gpu.hasNvidia
                            text: "Ta bort Nvidia-drivrutinerna"
                            onClicked: { win.gpuMessage = ""; backend.switchVariant("base"); }
                        }
                        FlatButton {
                            visible: graphicsView.pendingChange
                            primary: true
                            text: "Starta om nu"
                            onClicked: backend.reboot()
                        }
                        FlatButton {
                            visible: graphicsView.pendingChange
                            text: "Ångra"
                            onClicked: { win.gpuMessage = ""; backend.undoSwitch(); }
                        }
                    }
                }
            }

            // Secure Boot: Nvidia's and the Xbox controllers' drivers need Universal Blue's key, confirmed once
            Rectangle {
                visible: !!win.gpu.secureBoot && !win.gpu.keyEnrolled
                width: gfxCol.width
                height: sbCol.height + 40
                color: "#0E1420"
                border.width: 1
                border.color: "#1E2A40"
                Column {
                    id: sbCol
                    x: 22
                    y: 20
                    width: parent.width - 44
                    spacing: 12
                    Text {
                        text: "Secure Boot är påslaget"
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.DemiBold
                        font.pixelSize: 16
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        text: win.gpu.keyFile
                            ? "Drivrutinerna för Nvidia och Xbox-handkontroller är signerade med Universal Blues nyckel, som datorn behöver godkänna en gång. Tryck på knappen, välj ett lösenord, och skriv det i den blå skärmen vid nästa start (Enroll MOK → Continue → Yes → lösenordet → Reboot)."
                            : "Drivrutinerna för Nvidia och Xbox-handkontroller är signerade med Universal Blues nyckel, som datorn behöver godkänna en gång. Öppna Grafik igen efter omstarten, så finns knappen här."
                    }
                    FlatButton {
                        visible: !!win.gpu.keyFile
                        text: "Godkänn nyckeln"
                        onClicked: backend.enrollKey()
                    }
                }
            }
        }
    }

    // ── Förinstallerat: show/hide the programs that come with GOBLINCAKES ──

    Flickable {
        id: systemView
        FastWheel { flick: systemView }
        visible: win.tab === "system"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: sysCol.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: sysCol
            x: 48
            y: 32
            width: systemView.width - 96
            spacing: 10

            FlatField {
                width: sysCol.width
                hint: "Sök bland programmen"
                onTextChanged: win.appFilter = text
            }

            Text {
                visible: win.systemApps.length === 0
                text: "Läser in programmen…"
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 15
            }

            Repeater {
                model: win.systemApps.filter(a => !win.appFilter
                    || (a.name + " " + a.comment + " " + a.source).toLowerCase().includes(win.appFilter.toLowerCase()))
                Rectangle {
                    id: appRow
                    required property var modelData
                    property bool shown: modelData.visible
                    width: sysCol.width
                    height: 64
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"
                    opacity: shown ? 1 : 0.6

                    Image {
                        id: appIcon
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        width: 32
                        height: 32
                        sourceSize.width: 64
                        sourceSize.height: 64
                        source: modelData.icon ? "image://icon/" + modelData.icon : ""
                        asynchronous: true
                    }
                    Column {
                        anchors { left: appIcon.right; leftMargin: 14; right: appSource.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: modelData.name + (modelData.default ? "" : "  · dold från start")
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 15
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            visible: text !== ""
                            text: modelData.comment
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                    }
                    Text {
                        id: appSource
                        anchors { right: appSwitch.left; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        text: modelData.source
                        color: "#5C6880"
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 12
                    }
                    ToggleSwitch {
                        id: appSwitch
                        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        on: appRow.shown
                        onToggled: {
                            appRow.shown = !appRow.shown;
                            backend.setAppVisible(appRow.modelData.id, appRow.shown);
                        }
                    }
                }
            }
        }
    }

    // ── Uppdatera: goblin update in a window ─────────────────

    Flickable {
        id: updateView
        FastWheel { flick: updateView }
        visible: win.tab === "update"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: updCol.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: updCol
            x: 48
            y: 32
            width: updateView.width - 96
            spacing: 14

            // Before the first run: what it does
            Text {
                visible: win.updateState === "idle"
                width: updCol.width
                wrapMode: Text.WordWrap
                lineHeight: 1.2
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 15
                textFormat: Text.StyledText
                text: "Hämtar den senaste GOBLINCAKES-versionen och uppdaterar dina program (Flatpak), VS Code, Discord, AppImages som WowUp och Raider.IO, "
                    + "GE-Proton och firmware. Den nya GOBLINCAKES-versionen används efter en omstart – den förra finns kvar i startmenyn.<br><br>"
                    + "<font color='#E6ECF5'>Tryck Kolla efter uppdateringar</font> för att se vad som är nytt – det kollas också av sig själv när du loggar in. Inget hämtas förrän du trycker Uppdatera på en del eller Uppdatera allt. Systemet kan fråga efter ditt lösenord."
            }

            // Result of "Kolla efter uppdateringar"
            Rectangle {
                visible: win.updateState === "idle" && win.checkState !== ""
                width: updCol.width
                height: checkLabel.height + 28
                color: "#0E1420"
                border.width: 1
                border.color: win.checkFound ? "#3FB950" : "#1E2A40"
                Text {
                    id: checkLabel
                    anchors { left: parent.left; right: parent.right; margins: 16; verticalCenter: parent.verticalCenter }
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                    text: win.checkState === "checking" ? "Kollar efter uppdateringar…" : win.checkText
                }
            }

            // One row per part with something new, each updated on its own
            Repeater {
                model: win.updateState === "idle" && win.checkState === "done" ? checkParts : null
                Rectangle {
                    required property string part
                    required property string title
                    required property string detail
                    width: updCol.width
                    height: Math.max(64, partText.height + 24)
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"
                    Column {
                        id: partText
                        anchors { left: parent.left; leftMargin: 16; right: partButton.left; rightMargin: 16
                                  verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text {
                            text: title
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 15
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: detail
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                    }
                    FlatButton {
                        id: partButton
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "Uppdatera"
                        onClicked: win.startUpdate(part)
                    }
                }
            }

            // Progress
            Text {
                visible: win.updateState !== "idle"
                text: win.updateState === "done" ? "KLART" : win.updateTitle.toUpperCase()
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: 14
                font.letterSpacing: 2.5
            }
            Rectangle {
                visible: win.updateState !== "idle"
                width: updCol.width
                height: 12
                color: "#0E1420"
                border.width: 1
                border.color: "#1E2A40"
                Rectangle {
                    x: 1
                    y: 1
                    height: parent.height - 2
                    width: Math.max(0, (parent.width - 2) * (win.updateState === "done" ? 1 : win.updateFrac))
                    color: win.updateState === "done" && !win.updateOk ? accent.error : accent.color
                    Behavior on width { NumberAnimation { duration: 250 } }
                }
            }
            Text {
                visible: win.updateState === "running"
                width: updCol.width
                elide: Text.ElideRight
                text: win.updateStatus || "…"
                color: "#8B98AD"
                font.family: "IBM Plex Mono"
                font.pixelSize: 13
            }

            Item { width: 1; height: 8; visible: updateResults.count > 0 }

            // What was updated
            Text {
                visible: updateResults.count > 0
                text: "UPPDATERAT"
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: 14
                font.letterSpacing: 2.5
            }
            Repeater {
                model: updateResults
                Rectangle {
                    required property string name
                    required property bool ok
                    required property string summary
                    width: updCol.width
                    height: Math.max(56, resultText.height + 28)
                    color: "#0E1420"
                    border.width: 1
                    border.color: ok ? "#1E2A40" : accent.error
                    ResultMark {
                        id: resultMark
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        ok: parent.ok
                        size: 24
                    }
                    Text {
                        id: resultName
                        anchors { left: resultMark.right; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        width: 190
                        elide: Text.ElideRight
                        text: name
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.DemiBold
                        font.pixelSize: 15
                    }
                    Text {
                        id: resultText
                        anchors { left: resultName.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        wrapMode: Text.WordWrap
                        text: summary
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                    }
                }
            }

            Item { width: 1; height: 8; visible: updateNews.count > 0 }

            // What's new in the downloaded GOBLINCAKES version
            Text {
                visible: updateNews.count > 0
                text: "NYTT I GOBLINCAKES"
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: 14
                font.letterSpacing: 2.5
            }
            Rectangle {
                visible: updateNews.count > 0
                width: updCol.width
                height: newsCol.height + 32
                color: "#0E1420"
                border.width: 1
                border.color: "#1E2A40"
                Column {
                    id: newsCol
                    x: 20
                    y: 16
                    width: parent.width - 40
                    spacing: 8
                    Repeater {
                        model: updateNews
                        Row {
                            required property string text
                            width: newsCol.width
                            spacing: 10
                            Text {
                                text: parent.text.startsWith("Fedora:") ? " " : "•"
                                color: accent.text
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 14
                            }
                            Text {
                                width: newsCol.width - 20
                                wrapMode: Text.WordWrap
                                text: parent.text
                                color: parent.text.startsWith("Fedora:") ? "#8B98AD" : "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }
    }

    // Scroll bars for the lists above (shown only when a list is longer than the window)
    FlatScrollBar { flick: chooser }
    FlatScrollBar { flick: progressView }
    FlatScrollBar { flick: tweaksView }
    FlatScrollBar { flick: graphicsView }
    FlatScrollBar { flick: updateView }
    FlatScrollBar { flick: systemView }

    // ── Footer ───────────────────────────────────────────────

    Rectangle {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 84
        color: "#0B1018"

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1
            color: "#1E2A40"
        }

        Text {
            anchors { left: parent.left; leftMargin: 48; verticalCenter: parent.verticalCenter }
            visible: win.tab !== "apps" || win.page === "choose"
            text: win.tab === "system" ? "Gäller direkt och bara för dig. Avinstallera helt med knappen till höger."
                : win.tab === "update"
                    ? (win.updateState === "done" && win.updateReboot ? "Den nya versionen används efter en omstart."
                       : win.updateState === "running" ? "Uppdaterar…" : "Samma sak som goblin update i terminalen.")
                : win.tab === "graphics" ? "Bytet frågar efter ditt lösenord."
                : win.tab === "windows" ? "Sparas av sig själv. Använd = rutorna och fönstren på plats nu."
                : win.tab === "tweaks" ? "Ändringar gäller direkt. Systeminställningar frågar efter ditt lösenord."
                : win.chosenCount === 0 ? "Inget valt" : win.chosenCount === 1 ? "1 program valt" : win.chosenCount + " program valda"
            color: "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: 15
        }

        Row {
            anchors { right: parent.right; rightMargin: 48; verticalCenter: parent.verticalCenter }
            spacing: 12

            FlatButton {
                visible: win.tab === "apps" && win.page === "choose"
                text: "Hoppa över"
                onClicked: win.finish()
            }
            FlatButton {
                visible: win.tab === "apps" && win.page === "choose"
                primary: true
                enabledState: win.chosenCount > 0
                text: "Installera"
                onClicked: win.startInstall()
            }
            FlatButton {
                visible: win.tab === "apps" && win.page === "done"
                text: "Tillbaka"
                onClicked: win.goBack()
            }
            FlatButton {
                visible: win.tab === "apps" && win.page !== "choose"
                primary: true
                enabledState: win.page === "done"
                text: "Klar"
                onClicked: win.finish()
            }
            FlatButton {
                visible: win.tab === "windows" && !!windowsView.layout
                text: "Använd"
                onClicked: { windowsView.status = "Ordnar fönstren…"; backend.useLayout(windowsView.layout.name, false); }
            }
            FlatButton {
                visible: win.tab === "windows" && !!windowsView.layout
                primary: true
                text: "Öppna hela layouten"
                onClicked: { windowsView.status = "Ordnar fönstren och startar programmen…"; backend.useLayout(windowsView.layout.name, true); }
            }
            FlatButton {
                visible: win.tab === "system"
                text: "Avinstallera program…"
                onClicked: backend.openRemover()
            }
            FlatButton {
                visible: win.tab === "update" && win.updateState === "idle"
                primary: !win.checkFound && !win.checkStaged
                enabledState: win.checkState !== "checking"
                text: win.checkState === "checking" ? "Kollar…" : "Kolla efter uppdateringar"
                onClicked: { win.checkState = "checking"; backend.checkUpdates(); }
            }
            FlatButton {
                // Only when there is something to update (a check found it), or again after a run
                visible: win.tab === "update" && (win.updateState === "done" || (win.updateState === "idle" && win.checkFound))
                primary: !(win.updateState === "done" && win.updateReboot)
                text: win.updateState === "done" ? "Uppdatera igen" : "Uppdatera allt"
                onClicked: win.startUpdate("")
            }
            FlatButton {
                visible: win.tab === "update" && ((win.updateState === "done" && win.updateReboot)
                                                   || (win.updateState === "idle" && win.checkStaged))
                primary: true
                text: "Starta om nu"
                onClicked: backend.reboot()
            }
            FlatButton {
                visible: win.tab !== "apps"
                primary: win.tab !== "update"
                // Not while apps are installing or the system is updating
                enabledState: win.page !== "install" && win.updateState !== "running"
                text: "Stäng"
                onClicked: win.finish()
            }
        }
    }
}
