// GOBLINCAKES Config: install apps (Program), gaming optimisations (Optimering), graphics drivers (Grafik).
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

    readonly property var catalog: JSON.parse(backend.catalog)
    property var chosen: ({})
    property int chosenCount: 0
    property string page: "choose" // choose → install → done
    property int failedCount: 0
    property string tab: startTab // apps | tweaks | graphics
    readonly property var gpu: JSON.parse(backend.gpu)
    property string gpuMessage: ""
    readonly property string mainBrowser: backend.mainBrowser // app id, "" = Firefox

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

    ListModel {
        id: tweakModel
        Component.onCompleted: {
            for (const t of JSON.parse(backend.tweaks).tweaks)
                append({ "tweakId": t.id, "name": t.name, "desc": t.desc, "status": t.state, "message": "", "note": t.note || "" });
        }
    }

    Connections {
        target: backend
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
        }
        function onGpuProgress(text) {
            win.gpuMessage = text;
        }
        function onGpuDone(ok) {
            if (ok)
                win.gpuMessage = "";
        }
        function onTweakChanged(id, state, message) {
            for (let i = 0; i < tweakModel.count; i++)
                if (tweakModel.get(i).tweakId === id)
                    tweakModel.set(i, { "status": state, "message": message });
        }
    }

    // ── Pieces ───────────────────────────────────────────────

    component FlatButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        property bool enabledState: true
        signal clicked()

        width: Math.max(150, label.implicitWidth + 48)
        height: 44
        opacity: enabledState ? 1 : 0.4
        color: primary ? (area.containsMouse && enabledState ? "#4A82F0" : "#2F6FED")
                       : (area.containsMouse && enabledState ? "#1A2438" : "transparent")
        border.width: primary ? 0 : 1
        border.color: "#2A3852"

        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: "#E6ECF5"
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
        color: checked ? "#2F6FED" : "transparent"
        border.width: checked ? 0 : 1
        border.color: "#2A3852"
        Canvas {
            anchors.fill: parent
            visible: parent.checked
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = "#E6ECF5";
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                ctx.moveTo(5.5, 11.5);
                ctx.lineTo(9.5, 15.5);
                ctx.lineTo(16.5, 7);
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
        height: 176

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
                    text: win.tab === "graphics" ? "GRAFIK"
                        : win.tab === "tweaks" ? "OPTIMERING"
                        : win.page === "choose" ? "VÄLJ DINA PROGRAM"
                        : win.page === "install" ? "INSTALLERAR…" : "KLART"
                    color: "#E6ECF5"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 30
                    font.letterSpacing: 4
                }
                Text {
                    text: win.tab === "graphics"
                        ? "Drivrutiner för ditt grafikkort. Den gamla varianten finns kvar i startmenyn om något går fel."
                        : win.tab === "tweaks"
                        ? "Inställningar för spel. Slå på det du vill ha – allt går att slå av igen."
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
                model: [{ "id": "apps", "label": "PROGRAM" }, { "id": "tweaks", "label": "OPTIMERING" }, { "id": "graphics", "label": "GRAFIK" }]

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

    // ── Choose ───────────────────────────────────────────────

    Flickable {
        id: chooser
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
            spacing: 34

            Repeater {
                model: win.catalog.categories

                Column {
                    id: section
                    required property var modelData
                    readonly property var apps: win.catalog.apps.filter(a => a.category === modelData.id)
                    readonly property int columns: Math.max(1, Math.floor((sections.width + 16) / 340))

                    width: sections.width
                    spacing: 14

                    Text {
                        text: section.modelData.name.toUpperCase()
                        color: "#8B98AD"
                        font.family: "Chakra Petch"
                        font.weight: Font.DemiBold
                        font.pixelSize: 14
                        font.letterSpacing: 2.5
                    }
                    Text {
                        visible: !!section.modelData.note
                        width: section.width
                        text: section.modelData.note || ""
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                    }

                    Grid {
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

                                width: (sections.width - 16 * (section.columns - 1)) / section.columns
                                height: browser ? 160 : 112
                                color: cardArea.containsMouse && !installed ? "#111A2A" : "#0E1420"
                                border.width: 1
                                border.color: checked ? "#2F6FED" : cardArea.containsMouse && !installed ? "#2A3852" : "#1E2A40"
                                // Browsers stay bright when installed: their switch is still in use
                                opacity: installed && !browser ? 0.55 : 1

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

                                // Browsers: "Huvudwebbläsare" switch – installs it and makes it the main browser
                                Rectangle {
                                    visible: card.browser
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    anchors { leftMargin: 18; rightMargin: 18; bottomMargin: 14 }
                                    height: 30
                                    color: "transparent"
                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; top: parent.top }
                                        anchors.topMargin: -8
                                        height: 1
                                        color: "#1E2A40"
                                    }
                                    Text {
                                        anchors { left: parent.left; verticalCenter: browserSwitch.verticalCenter }
                                        text: "Huvudwebbläsare"
                                        color: browserSwitch.on ? "#E6ECF5" : "#8B98AD"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                    }
                                    ToggleSwitch {
                                        id: browserSwitch
                                        anchors { right: parent.right; bottom: parent.bottom }
                                        on: win.mainBrowser === card.modelData.id
                                        onToggled: win.setMainBrowser(card.modelData.id, !on)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Install / done ───────────────────────────────────────

    Flickable {
        id: progressView
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
                    border.color: status === "running" ? "#2F6FED" : status === "failed" ? "#A4262C" : "#1E2A40"

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

                    // Waiting: empty square. Running: blue bar sliding. Done: check. Failed: red.
                    Item {
                        id: rowState
                        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        width: row.status === "running" ? 120 : 22
                        height: 22

                        CheckSquare {
                            anchors.right: parent.right
                            visible: row.status === "waiting" || row.status === "done"
                            checked: row.status === "done"
                        }
                        Rectangle {
                            anchors.right: parent.right
                            visible: row.status === "failed"
                            width: 22
                            height: 22
                            color: "#A4262C"
                            Text {
                                anchors.centerIn: parent
                                text: "!"
                                color: "#E6ECF5"
                                font.family: "Chakra Petch"
                                font.weight: Font.Bold
                                font.pixelSize: 15
                            }
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
                                color: "#2F6FED"
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

    Flickable {
        id: tweaksView
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

                Rectangle {
                    id: tweakRow
                    required property string tweakId
                    required property string name
                    required property string desc
                    required property string status
                    required property string message
                    required property string note
                    readonly property bool available: status !== "unavailable"

                    // Settings that don't fit this computer (no Nvidia card, one graphics card…) aren't shown
                    visible: available
                    width: tweakRows.width
                    height: available ? Math.max(92, tweakText.height + 36) : 0
                    color: "#0E1420"
                    border.width: 1
                    border.color: status === "on" ? "#2F6FED" : "#1E2A40"
                    opacity: available ? 1 : 0.55

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
    }

    // ── Graphics drivers ─────────────────────────────────────

    Flickable {
        id: graphicsView
        visible: win.tab === "graphics"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: gfxCol.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        readonly property bool switching: backend.gpuBusy
        readonly property bool pendingChange: !!win.gpu.pending && win.gpu.pending !== win.gpu.variant
        readonly property string after: win.gpu.pending || win.gpu.variant || "base"

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
                        + " (Optimering → Spel på det kraftfulla grafikkortet). Andra program: högerklicka → Kör med dedikerat grafikkort."
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
                border.color: graphicsView.pendingChange || graphicsView.switching ? "#2F6FED" : "#1E2A40"

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
                        text: graphicsView.pendingChange
                            ? (win.gpu.pending === "nvidia" ? "Nvidia-drivrutinerna är nedladdade – starta om för att använda dem."
                                                            : "Nvidia-drivrutinerna tas bort när du startar om.")
                            : win.gpu.variant === "nvidia"
                            ? (win.gpu.hasNvidia ? "Nvidia-drivrutinerna är installerade." : "Nvidia-drivrutinerna är installerade, men datorn har inget Nvidia-kort.")
                            : (win.gpu.hasNvidia ? "Nvidia-kortet kör med den öppna grunddrivrutinen." : "Du har redan rätt drivrutiner.")
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        lineHeight: 1.15
                        text: graphicsView.pendingChange
                            ? "Vill du inte byta ändå: tryck Ångra. Den nuvarande varianten finns kvar i startmenyn."
                            : win.gpu.variant === "nvidia"
                            ? (win.gpu.hasNvidia ? "Allt är klart för spel." : "De tar plats och lägger till Nvidia-inställningar vid start. Ta bort dem för ett renare system (ungefär 1 GB).")
                            : (win.gpu.hasNvidia ? "Skrivbordet fungerar, men spel går mycket bättre med Nvidias egna drivrutiner. De laddas ner (bara skillnaden, ungefär 1 GB) och används efter en omstart."
                                                 : "AMD och Intel använder de öppna drivrutinerna (Mesa), som redan finns i GOBLINCAKES. Inget behöver laddas ner.")
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
                                color: "#2F6FED"
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
                            visible: !graphicsView.pendingChange && win.gpu.variant === "base" && !!win.gpu.hasNvidia
                            primary: true
                            text: "Installera Nvidia-drivrutiner"
                            onClicked: { win.gpuMessage = ""; backend.switchVariant("nvidia"); }
                        }
                        FlatButton {
                            visible: !graphicsView.pendingChange && win.gpu.variant === "nvidia"
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

    // Scroll bars for the lists above (shown only when a list is longer than the window)
    FlatScrollBar { flick: chooser }
    FlatScrollBar { flick: progressView }
    FlatScrollBar { flick: tweaksView }
    FlatScrollBar { flick: graphicsView }

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
            text: win.tab === "graphics" ? "Bytet frågar efter ditt lösenord."
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
                visible: win.tab !== "apps"
                primary: true
                // Not while apps are still installing
                enabledState: win.page !== "install"
                text: "Stäng"
                onClicked: win.finish()
            }
        }
    }
}
