// GOBLINCAKES Dashboard – step 1 (10 Nov): the open programs at the top, the own programs at the bottom,
// PROJEKT / SYSTEM / KVOT to the left, SPELAS NU to the right, and in the middle every program (type =
// search) or what was pressed in a frame. The data comes from goblin-dashboard (backend.get(key) = JSON).
import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Dialogs

Window {
    id: win
    title: "GOBLINCAKES Dashboard"
    color: "#07090D"
    flags: Qt.Window | Qt.FramelessWindowHint
    width: 1920
    height: 1080

    // ── What is shown (read from the backend as JSON) ─────────
    property var apps: []
    property var bottom: []
    property var windows: []
    property var system: ({})
    property var top: []
    property var player: ({})
    property var quota: ({})
    property var projects: []
    property var project: ({})
    property var trayBox: ({})
    property var tools: ({})
    readonly property var trayIcons: JSON.parse(backend.trayIcons)

    property string group: ""          // the chosen kind of program ("" = all)
    property int sel: 0                // the marked program in the grid
    property string note: ""
    property bool dialogOpen: false
    property date now: new Date()
    readonly property string mid: backend.mid
    readonly property string midProject: mid.indexOf("project:") === 0 ? mid.slice(8) : ""

    readonly property var groups: {
        const seen = [];
        for (const a of apps)
            if (seen.indexOf(a.group) < 0)
                seen.push(a.group);
        const order = ["Spel", "Internet", "Ljud och video", "Bild", "Kontor", "Utveckling", "Verktyg", "System",
                       "Inställningar", "Övrigt"];
        return order.filter(g => seen.indexOf(g) >= 0);
    }
    readonly property var shown: {
        const words = search.text.toLowerCase().split(/\s+/).filter(w => w);
        return apps.filter(a => {
            if (words.length === 0)
                return group === "" || a.group === group;
            const hay = a.name.toLowerCase() + " " + a.words;
            return words.every(w => hay.indexOf(w) >= 0);
        }).sort((a, b) => words.length === 0 ? 0 : rank(a, words[0]) - rank(b, words[0]));
    }
    // What was typed at the start of the name first, then at the start of a word in it, then anywhere in it
    function rank(app, word) {
        const name = app.name.toLowerCase();
        const at = name.indexOf(word);
        return at === 0 ? 0 : at > 0 && " -(".indexOf(name.charAt(at - 1)) >= 0 ? 1 : at > 0 ? 2 : 3;
    }
    onShownChanged: sel = 0

    function load(key) {
        try {
            win[key] = JSON.parse(backend.get(key));
        } catch (e) {
        }
    }
    function say(text) { note = text; noteTimer.restart(); }
    function showApps() { backend.setMid("apps"); search.forceActiveFocus(); }
    function back() {
        // Esc: one step at a time – the small box, the search, the middle, and last the dashboard itself
        if (backend.tray !== "")
            backend.closeTray();
        else if (search.text !== "")
            search.text = "";
        else if (mid !== "apps")
            showApps();
        else
            win.hide();
    }
    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    function resetText(epoch) {
        if (!epoch)
            return "";
        const d = new Date(epoch * 1000);
        const same = d.toDateString() === now.toDateString();
        return d.toLocaleString(Qt.locale("sv_SE"), same ? "HH:mm" : "ddd HH:mm");
    }

    Component.onCompleted: {
        for (const k of ["apps", "bottom", "windows", "system", "top", "player", "quota", "projects", "project",
                         "trayBox", "tools"])
            load(k);
    }
    onVisibleChanged: {
        backend.setVisible(visible);
        if (visible) {
            search.text = "";
            group = "";
            search.forceActiveFocus();
        }
    }
    // Like Plasma's "Instrumentpanel för program": another window in front = the dashboard steps aside
    onActiveChanged: if (!active && visible && !backend.stays && !dialogOpen) hideTimer.restart()
    Timer { id: hideTimer; interval: 250; onTriggered: if (!win.active && !win.dialogOpen) win.hide() }
    Timer { id: noteTimer; interval: 5000; onTriggered: win.note = "" }
    Timer { interval: 1000; running: win.visible; repeat: true; onTriggered: win.now = new Date() }

    Connections {
        target: backend
        function onChanged(key) { win.load(key); }
        function onSaid(text) { win.say(text); }
    }

    FolderDialog {
        id: addProjectDialog
        title: "Lägg till en projektmapp"
        onVisibleChanged: { backend.sharpText(); win.dialogOpen = visible; }
        onAccepted: backend.addProject(selectedFolder.toString())
    }

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

    component FlatScrollBar: Item {
        id: bar
        required property Flickable flick
        readonly property bool needed: flick.visible && flick.contentHeight > flick.height + 1
        anchors { right: flick.right; rightMargin: 2; top: flick.top; bottom: flick.bottom }
        width: 8
        visible: needed
        z: 2
        Rectangle { anchors.fill: parent; color: "#0B1018" }
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

    component FlatButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        property bool danger: false
        signal clicked()

        width: Math.max(96, label.implicitWidth + 32)
        height: 40
        color: primary ? (area.containsMouse ? accent.hover : accent.color)
                       : (area.containsMouse ? (danger ? "#3A1418" : "#1A2438") : "transparent")
        border.width: primary ? 0 : 1
        border.color: danger && area.containsMouse ? accent.error : "#1E2A40"
        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: btn.primary ? accent.on : "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: 14
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // A frame's heading
    component Heading: Text {
        color: "#8B98AD"
        font.family: "Chakra Petch"
        font.pixelSize: 13
        font.letterSpacing: 2
    }

    component Frame: Rectangle {
        color: "#0B1018"
        border.width: 1
        border.color: "#1E2A40"
    }

    // A program's own icon; without one (or without an icon theme) its first letter on a tile
    component AppIcon: Item {
        id: appIcon
        property string icon
        property string name
        property int side: 52
        width: side
        height: side
        Image {
            id: img
            anchors.fill: parent
            readonly property bool has: backend.hasIcon(appIcon.icon)
            source: has ? "image://icon/" + appIcon.icon : ""
            sourceSize: Qt.size(appIcon.side * 2, appIcon.side * 2)
            smooth: true
            visible: has && status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            visible: !img.visible
            color: "#12203A"
            border.width: 1
            border.color: "#1E2A40"
            Text {
                anchors.centerIn: parent
                text: appIcon.name.charAt(0).toUpperCase()
                color: "#E6ECF5"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: Math.round(appIcon.side * 0.42)
            }
        }
    }

    // A thin bar: how much of something is used
    component Meter: Rectangle {
        property real percent: 0
        property bool warn: false
        height: 6
        color: "#1A2438"
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, parent.percent)) / 100
            height: parent.height
            color: parent.warn ? "#F06B6B" : accent.color
        }
    }

    // The history as small bars (0–100), the newest to the right
    component Bars: Item {
        id: bars
        property var values: []
        property int count: 40
        Row {
            anchors.fill: parent
            spacing: 3
            Repeater {
                model: bars.count
                Item {
                    required property int index
                    readonly property int at: index - (bars.count - bars.values.length)
                    width: (bars.width - (bars.count - 1) * 3) / bars.count
                    height: bars.height
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.at < 0 ? 2 : Math.max(2, bars.height * bars.values[parent.at] / 100)
                        color: parent.at < 0 ? "#1A2438" : accent.color
                    }
                }
            }
        }
    }

    // A line-drawn symbol (24 × 24 SVG path)
    component Glyph: Shape {
        id: glyph
        property string path
        property color stroke: "#C3CCDA"
        property bool filled: false
        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: glyph.filled ? "transparent" : glyph.stroke
            strokeWidth: 1.6
            fillColor: glyph.filled ? glyph.stroke : "transparent"
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: glyph.path }
        }
    }

    readonly property var trayPaths: ({
        "nätverk": "M3 14h18v7H3zM7 14V9h10v5M12 9V3",
        "ljud": "M4 9h4l5-4v14l-5-4H4zM16 9c1.5 1.5 1.5 4.5 0 6M19 6c3 3 3 9 0 12",
        "bluetooth": "M7 7l10 10-5 5V2l5 5L7 17",
        "urklipp": "M8 3h8v4H8zM8 5H4v16h16V5h-4M8 12h8M8 16h5",
        "enheter": "M10 2h4v6h-4zM7 8h10v6l-3 4v4h-4v-4l-3-4z"
    })

    // ── At the top: the open programs ─────────────────────────
    Rectangle {
        id: topBar
        width: parent.width
        height: 112
        color: "#05070A"
        z: 3
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }

        Column {
            id: brand
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 300
            spacing: 8
            Row {
                spacing: 10
                Image { source: logoUrl; width: 32; height: 32; sourceSize: Qt.size(64, 64) }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "GOBLINCAKES"
                    color: "#E6ECF5"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 20
                    font.letterSpacing: 3
                }
            }
            // The system tray as icons – press for more
            Row {
                spacing: 4
                Repeater {
                    model: win.trayIcons
                    Rectangle {
                        required property var modelData
                        readonly property bool on: backend.tray === modelData.id
                        width: 40
                        height: 36
                        color: on ? accent.dim : trayArea.containsMouse ? "#1A2438" : "transparent"
                        border.width: 1
                        border.color: on ? accent.color : "#1E2A40"
                        Glyph {
                            anchors.centerIn: parent
                            scale: 0.8
                            path: win.trayPaths[parent.modelData.id] || ""
                            stroke: parent.on ? "#E6ECF5" : "#C3CCDA"
                        }
                        MouseArea {
                            id: trayArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.openTray(parent.modelData.id)
                        }
                    }
                }
            }
        }

        Heading {
            id: openLabel
            anchors { left: brand.right; leftMargin: 20; verticalCenter: parent.verticalCenter }
            text: "ÖPPNA PROGRAM"
            font.pixelSize: 12
        }
        ListView {
            id: openList
            anchors { left: openLabel.right; leftMargin: 20; right: clockBox.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
            height: 44
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: win.windows
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: Math.min(260, chipRow.implicitWidth + 24)
                height: 44
                color: chipArea.containsMouse ? accent.dim : "#0E1420"
                border.width: 1
                border.color: index === 0 || chipArea.containsMouse ? accent.color : "#1E2A40"
                opacity: modelData.min ? 0.6 : 1
                Row {
                    id: chipRow
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    AppIcon { side: 24; icon: modelData.icon; name: modelData.name; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 200)
                        elide: Text.ElideRight
                        text: modelData.name
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                    }
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.activate(modelData.id)
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: win.windows.length === 0
                text: "Inga program är öppna"
                color: "#5C6880"
                font.family: "IBM Plex Sans"
                font.pixelSize: 14
            }
        }
        Column {
            id: clockBox
            anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
            Text {
                anchors.right: parent.right
                text: Qt.formatTime(win.now, "HH:mm")
                color: "#E6ECF5"
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: 22
            }
            Text {
                anchors.right: parent.right
                text: win.now.toLocaleDateString(Qt.locale("sv_SE"), "dddd d MMMM")
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 12
            }
        }
    }

    // The small box behind a system tray icon
    Frame {
        id: trayPanel
        visible: backend.tray !== ""
        x: 24
        y: topBar.height - 6
        z: 5
        width: 340
        height: trayColumn.implicitHeight + 28
        border.color: accent.color
        MouseArea { anchors.fill: parent }   // a press in the box is not a press on what lies under it
        Column {
            id: trayColumn
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 6
            Item {
                width: parent.width
                height: 28
                Heading { anchors.verticalCenter: parent.verticalCenter; text: win.trayBox.title || "" }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "✕"
                    color: closeTrayArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                    font.pixelSize: 14
                    MouseArea {
                        id: closeTrayArea
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.closeTray()
                    }
                }
            }
            Repeater {
                model: win.trayBox.rows || []
                Rectangle {
                    required property var modelData
                    width: trayColumn.width
                    height: 40
                    color: rowArea.containsMouse && modelData.act ? "#1A2438" : "transparent"
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
                    Text {
                        anchors { left: parent.left; right: rowRight.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        text: modelData.a
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                    }
                    Text {
                        id: rowRight
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: modelData.b
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !!modelData.act
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.copyClip(modelData.text)
                    }
                }
            }
            // Ljud: the volume (press or drag) and Tyst
            Row {
                visible: !!win.trayBox.volume
                width: parent.width
                height: 44
                spacing: 12
                Item {
                    width: parent.width - muteButton.width - 12
                    height: parent.height
                    Meter {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 8
                        percent: win.trayBox.volume ? win.trayBox.volume.percent : 0
                        opacity: win.trayBox.volume && win.trayBox.volume.muted ? 0.4 : 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function set(x) { backend.setVolume(Math.round(Math.max(0, Math.min(1, x / width)) * 100)); }
                        onPressed: mouse => set(mouse.x)
                        onPositionChanged: mouse => { if (pressed) set(mouse.x); }
                    }
                }
                FlatButton {
                    id: muteButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: 96
                    height: 34
                    text: win.trayBox.volume && win.trayBox.volume.muted ? "Ljud på" : "Tyst"
                    onClicked: backend.toggleMute()
                }
            }
            Text {
                visible: (win.trayBox.rows || []).length === 0
                text: "Läser …"
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 13
            }
        }
    }

    // ── The middle part ───────────────────────────────────────
    Item {
        id: body
        anchors { top: topBar.bottom; bottom: bottomBar.top; left: parent.left; right: parent.right
                  topMargin: 20; bottomMargin: 16; leftMargin: 24; rightMargin: 24 }

        // Left: PROJEKT, SYSTEM, and KVOT at the bottom
        Item {
            id: leftCol
            width: 300
            height: parent.height

            Frame {
                id: projectFrame
                width: parent.width
                height: projectColumn.implicitHeight + 32
                Column {
                    id: projectColumn
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 6
                    Heading { text: "PROJEKT"; bottomPadding: 6 }
                    Repeater {
                        model: win.projects.slice(0, 5)
                        Rectangle {
                            required property var modelData
                            readonly property bool on: win.midProject === modelData.path
                            width: projectColumn.width
                            height: 56
                            color: on ? "#12203A" : projArea.containsMouse ? "#12203A" : "#0E1420"
                            border.width: on ? 2 : 1
                            border.color: on ? accent.color : "#1E2A40"
                            opacity: modelData.exists ? 1 : 0.5
                            Glyph {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                path: "M3 6h7l2 3h9v10H3z"
                                stroke: "#8B98AD"
                            }
                            Column {
                                anchors { left: parent.left; leftMargin: 48; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: modelData.name
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 15
                                }
                                Text {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: !modelData.exists ? "mappen finns inte längre"
                                          : modelData.short + (modelData.changed ? " · " + modelData.changed + " ändrade" : "")
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Mono"
                                    font.pixelSize: 11
                                }
                            }
                            MouseArea {
                                id: projArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.setMid("project:" + modelData.path)
                            }
                        }
                    }
                    Rectangle {
                        width: projectColumn.width
                        height: 44
                        color: addArea.containsMouse ? "#12203A" : "transparent"
                        border.width: 1
                        border.color: "#1E2A40"
                        Text {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "+ Lägg till projekt"
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: addArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { win.dialogOpen = true; addProjectDialog.open(); }
                        }
                    }
                }
            }

            Frame {
                id: systemFrame
                anchors { top: projectFrame.bottom; topMargin: 16 }
                width: parent.width
                height: systemColumn.implicitHeight + 32
                color: win.mid === "system" ? "#0E1420" : "#0B1018"
                border.color: win.mid === "system" ? accent.color : "#1E2A40"
                Column {
                    id: systemColumn
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 2
                    Heading { text: "SYSTEM"; bottomPadding: 8 }
                    Repeater {
                        model: win.system.rows || []
                        Item {
                            required property var modelData
                            width: systemColumn.width
                            height: 40
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.k
                                color: "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Meter {
                                x: 56
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 56 - 84
                                percent: modelData.p
                                warn: modelData.warn
                            }
                            Text {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: modelData.v
                                color: "#C3CCDA"
                                font.family: "IBM Plex Mono"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.setMid(win.mid === "system" ? "apps" : "system")
                }
            }

            Frame {
                id: quotaFrame
                anchors.bottom: parent.bottom
                width: parent.width
                height: quotaColumn.implicitHeight + 28
                visible: (win.quota.services || []).length > 0
                Column {
                    id: quotaColumn
                    x: 16
                    y: 14
                    width: parent.width - 32
                    spacing: 16
                    Repeater {
                        model: win.quota.services || []
                        Column {
                            id: service
                            required property var modelData
                            width: quotaColumn.width
                            spacing: 8
                            Item {
                                width: parent.width
                                height: 18
                                Heading { text: "KVOT · " + String(service.modelData.name || service.modelData.id).toUpperCase() }
                                Text {
                                    anchors { right: parent.right; baseline: parent.children[0].baseline }
                                    readonly property var first: (service.modelData.windows || [])[0]
                                    text: service.modelData.error ? "" : first && first.resets ? "nollställs " + win.resetText(first.resets) : ""
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 11
                                }
                            }
                            Repeater {
                                model: service.modelData.windows || []
                                Item {
                                    required property var modelData
                                    width: service.width
                                    height: 18
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        color: "#E6ECF5"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                    }
                                    Meter {
                                        x: 64
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 64 - 50
                                        percent: modelData.percent
                                        warn: modelData.percent >= 90
                                    }
                                    Text {
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                        text: modelData.percent + " %"
                                        color: "#C3CCDA"
                                        font.family: "IBM Plex Mono"
                                        font.pixelSize: 12
                                    }
                                }
                            }
                            Text {
                                visible: !!service.modelData.error
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: service.modelData.error || ""
                                color: "#F0B232"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }

        // The middle: every program (type = search), or what was pressed in a frame
        Rectangle {
            id: middle
            anchors { left: leftCol.right; leftMargin: 16; right: rightCol.left; rightMargin: 16; top: parent.top; bottom: parent.bottom }
            color: "#0E1420"
            border.width: 1
            border.color: "#1E2A40"
            clip: true

            // The search line is always there: typing anywhere searches the programs
            Item {
                id: searchRow
                x: 28
                y: 20
                width: parent.width - 56
                height: 44
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: search.text !== "" ? accent.color : "#1E2A40" }
                Text {
                    id: prompt
                    anchors.verticalCenter: parent.verticalCenter
                    text: "❯"
                    color: accent.text
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 18
                }
                TextInput {
                    id: search
                    anchors { left: prompt.right; leftMargin: 12; right: backButton.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    focus: true
                    clip: true
                    color: "#E6ECF5"
                    selectionColor: accent.color
                    selectedTextColor: accent.on
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 18
                    onTextChanged: if (text !== "" && win.mid !== "apps") backend.setMid("apps")
                    Keys.onEscapePressed: win.back()
                    Keys.onReturnPressed: if (win.mid === "apps" && win.shown.length > 0) backend.launch(win.shown[win.sel].path)
                    Keys.onEnterPressed: if (win.mid === "apps" && win.shown.length > 0) backend.launch(win.shown[win.sel].path)
                    Keys.onDownPressed: grid.step(grid.columns)
                    Keys.onUpPressed: grid.step(-grid.columns)
                    Keys.onRightPressed: event => { if (cursorPosition === text.length) grid.step(1); else event.accepted = false; }
                    Keys.onLeftPressed: event => { if (text === "") grid.step(-1); else event.accepted = false; }
                    Text {
                        visible: search.text === ""
                        text: "Skriv för att söka bland programmen"
                        color: "#5C6880"
                        font: search.font
                    }
                }
                FlatButton {
                    id: backButton
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: win.mid !== "apps"
                    width: visible ? 150 : 0
                    height: 34
                    text: "Alla program  (Esc)"
                    onClicked: win.showApps()
                }
            }

            // ── Every program ──
            Item {
                id: appsView
                visible: win.mid === "apps"
                anchors { top: searchRow.bottom; topMargin: 14; left: parent.left; right: parent.right; bottom: parent.bottom
                          leftMargin: 28; rightMargin: 20; bottomMargin: 16 }
                Flow {
                    id: chips
                    width: parent.width
                    spacing: 6
                    visible: search.text === ""
                    Repeater {
                        model: [""].concat(win.groups)
                        Rectangle {
                            required property string modelData
                            readonly property bool on: win.group === modelData
                            width: chipText.implicitWidth + 24
                            height: 32
                            color: on ? accent.dim : groupArea.containsMouse ? "#1A2438" : "transparent"
                            border.width: 1
                            border.color: on ? accent.color : "#1E2A40"
                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: parent.modelData === "" ? "Alla" : parent.modelData
                                color: parent.on ? "#E6ECF5" : "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            MouseArea {
                                id: groupArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.group = parent.modelData
                            }
                        }
                    }
                }
                GridView {
                    id: grid
                    anchors { top: chips.visible ? chips.bottom : parent.top; topMargin: chips.visible ? 14 : 0
                              left: parent.left; right: parent.right; bottom: parent.bottom }
                    readonly property int columns: Math.max(1, Math.floor((width - 12) / 132))
                    cellWidth: Math.floor((width - 12) / columns)
                    cellHeight: 122
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.shown
                    currentIndex: win.sel
                    function step(by) {
                        if (win.mid !== "apps" || count === 0)
                            return;
                        win.sel = Math.max(0, Math.min(count - 1, win.sel + by));
                        positionViewAtIndex(win.sel, GridView.Contain);
                    }
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            readonly property bool marked: cell.index === win.sel && search.text !== ""
                            color: cellArea.containsMouse || marked ? "#12203A" : "transparent"
                            border.width: marked ? 1 : 0
                            border.color: accent.color
                        }
                        AppIcon {
                            y: 14
                            anchors.horizontalCenter: parent.horizontalCenter
                            side: 52
                            icon: cell.modelData.icon
                            name: cell.modelData.name
                        }
                        Text {
                            y: 74
                            x: 8
                            width: parent.width - 16
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: cell.modelData.name
                            color: "#C3CCDA"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: cellArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.launch(cell.modelData.path)
                        }
                    }
                    FastWheel { flick: grid }
                }
                FlatScrollBar { flick: grid }
                Text {
                    anchors.centerIn: grid
                    visible: win.shown.length === 0 && win.apps.length > 0
                    text: "Inget program heter så"
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                }
            }

            // ── The system ──
            Flickable {
                id: sysView
                visible: win.mid === "system"
                anchors { top: searchRow.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: parent.bottom
                          leftMargin: 28; rightMargin: 28; bottomMargin: 20 }
                contentHeight: sysColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: sysColumn
                    width: sysView.width
                    spacing: 18
                    Row {
                        spacing: 14
                        Text {
                            id: sysTitle
                            text: "SYSTEMET"
                            color: "#E6ECF5"
                            font.family: "Chakra Petch"
                            font.weight: Font.Bold
                            font.pixelSize: 26
                        }
                        Text {
                            anchors.baseline: sysTitle.baseline
                            text: "sedan dashboarden öppnades · en stapel = 2 sekunder"
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                        }
                    }
                    Grid {
                        id: sysGrid
                        width: parent.width
                        columns: width >= 780 ? 3 : 2
                        spacing: 12
                        Repeater {
                            model: win.system.rows || []
                            Frame {
                                required property var modelData
                                width: (sysGrid.width - (sysGrid.columns - 1) * 12) / sysGrid.columns
                                height: 150
                                Text {
                                    x: 16
                                    y: 18
                                    text: ({"cpu": "PROCESSOR", "gpu": "GRAFIKKORT", "temp": "TEMPERATUR", "ram": "MINNE", "disk": "DISK – LEDIGT"})[modelData.id] || modelData.k
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                    font.letterSpacing: 1
                                }
                                Text {
                                    anchors { right: parent.right; rightMargin: 16 }
                                    y: 10
                                    text: modelData.v
                                    color: modelData.warn ? "#F06B6B" : "#E6ECF5"
                                    font.family: "Chakra Petch"
                                    font.weight: Font.Bold
                                    font.pixelSize: 22
                                }
                                Bars {
                                    x: 16
                                    y: 50
                                    width: parent.width - 32
                                    height: 56
                                    values: modelData.bars || []
                                }
                                Text {
                                    x: 16
                                    y: 118
                                    width: parent.width - 32
                                    elide: Text.ElideRight
                                    text: modelData.note
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                    Heading { text: "TAR MEST PROCESSOR JUST NU"; topPadding: 6 }
                    Column {
                        width: Math.min(parent.width, 560)
                        Repeater {
                            model: win.top
                            Item {
                                required property var modelData
                                width: parent.width
                                height: 40
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 14
                                }
                                Text {
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    text: String(Math.round(modelData.cpu)) + " %"
                                    color: "#C3CCDA"
                                    font.family: "IBM Plex Mono"
                                    font.pixelSize: 12
                                }
                            }
                        }
                        Text {
                            topPadding: 8
                            text: "100 % = en hel processorkärna"
                            color: "#5C6880"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                    }
                }
                FastWheel { flick: sysView }
            }
            FlatScrollBar { flick: sysView }

            // ── A project ──
            Item {
                id: projectView
                visible: win.midProject !== ""
                anchors { top: searchRow.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: parent.bottom
                          leftMargin: 28; rightMargin: 28; bottomMargin: 20 }
                readonly property var p: win.project
                Column {
                    id: projectHead
                    anchors { left: parent.left; right: openCol.left; rightMargin: 24 }
                    spacing: 8
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: String(projectView.p.name || "").toUpperCase()
                        color: "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: 34
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideMiddle
                        text: [projectView.p.short, projectView.p.remote, projectView.p.branch ? "grenen " + projectView.p.branch : ""].filter(t => t).join(" · ")
                        color: "#8B98AD"
                        font.family: "IBM Plex Mono"
                        font.pixelSize: 12
                    }
                    Text {
                        visible: !!projectView.p.git
                        text: (projectView.p.changed ? projectView.p.changed + " ändrade filer som inte är sparade i Git" : "Inga osparade ändringar")
                              + (projectView.p.waiting ? " · " + projectView.p.waiting + " commits väntar på push" : "")
                        color: projectView.p.changed || projectView.p.waiting ? "#F0B232" : "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                    Heading { text: "SENASTE COMMITS"; topPadding: 14; visible: !!projectView.p.git }
                }
                ListView {
                    id: commitList
                    anchors { top: projectHead.bottom; topMargin: 8; left: parent.left; right: openCol.left; rightMargin: 24; bottom: parent.bottom }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: projectView.p.commits || []
                    delegate: Item {
                        required property var modelData
                        width: commitList.width
                        height: 48
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
                        Text {
                            id: hashText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 70
                            text: modelData.hash
                            color: accent.text
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 12
                        }
                        Text {
                            anchors { left: hashText.right; leftMargin: 14; right: whenText.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: modelData.msg
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 14
                        }
                        Text {
                            id: whenText
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: modelData.when
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                    }
                    FastWheel { flick: commitList }
                }
                FlatScrollBar { flick: commitList }
                Text {
                    anchors { top: projectHead.bottom; topMargin: 16 }
                    visible: !projectView.p.git && !projectView.p.loading
                    text: "Mappen är inget Git-projekt – inga commits att visa."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                }
                Column {
                    id: openCol
                    anchors.right: parent.right
                    width: Math.min(380, parent.width * 0.4)
                    Heading { text: "ÖPPNA"; topPadding: 12; bottomPadding: 12 }
                    Rectangle { width: parent.width; height: 1; color: "#1E2A40" }
                    Repeater {
                        model: [
                            {"how": "code", "name": "VS Code", "note": win.tools.code ? "" : "inte installerat", "ok": true},
                            {"how": "claude", "name": "Claude Code", "note": win.tools.claude ? "i eget terminalfönster" : "inte installerat", "ok": true},
                            {"how": "codex", "name": "Codex", "note": "i eget terminalfönster", "ok": !!win.tools.codex},
                            {"how": "folder", "name": "Öppna mappen", "note": "filhanteraren", "ok": true}
                        ].filter(o => o.ok)
                        Rectangle {
                            required property var modelData
                            width: openCol.width
                            height: 52
                            color: openArea.containsMouse ? "#12203A" : "transparent"
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1E2A40" }
                            Text {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 15
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: modelData.note
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: openArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.openProject(win.midProject, modelData.how)
                            }
                        }
                    }
                    Item { width: 1; height: 16 }
                    FlatButton {
                        danger: true
                        height: 34
                        text: "Ta bort ur listan"
                        onClicked: backend.removeProject(win.midProject)
                    }
                    Text {
                        topPadding: 10
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Samma lista som PROJEKT → MAPPAR i Goblin AI. Mappen och filerna rörs inte."
                        color: "#5C6880"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                        lineHeight: 1.3
                    }
                }
            }

            // A line for a moment (why something could not be started)
            Rectangle {
                visible: win.note !== ""
                anchors { bottom: parent.bottom; bottomMargin: 16; horizontalCenter: parent.horizontalCenter }
                width: noteText.implicitWidth + 32
                height: 40
                color: "#0B1018"
                border.width: 1
                border.color: accent.color
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

        // Right: SPELAS NU at the bottom (WoW Stats and CS2 Stats come above it in step 2)
        Item {
            id: rightCol
            anchors.right: parent.right
            width: 340
            height: parent.height

            Frame {
                id: playFrame
                anchors.bottom: parent.bottom
                width: parent.width
                height: playColumn.implicitHeight + 32
                readonly property bool has: !!win.player.name
                readonly property bool playing: win.player.status === "Playing"
                // The time runs on between the readings
                property real position: 0
                property real readAt: 0
                Connections {
                    target: win
                    function onPlayerChanged() { playFrame.position = win.player.position || 0; playFrame.readAt = Date.now(); }
                }
                readonly property real shownPosition: {
                    const tick = win.now;   // worked out again once a second
                    const p = position + (playing ? (Date.now() - readAt) / 1000 : 0);
                    return win.player.length ? Math.min(p, win.player.length) : p;
                }
                Column {
                    id: playColumn
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 12
                    Heading { text: "SPELAS NU" }
                    Row {
                        width: parent.width
                        spacing: 14
                        Rectangle {
                            width: 84
                            height: 84
                            color: "#12203A"
                            border.width: 1
                            border.color: "#1E2A40"
                            Glyph {
                                anchors.centerIn: parent
                                visible: cover.status !== Image.Ready
                                path: "M9 18V5l10-2v13M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0zM19 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0z"
                                stroke: "#8B98AD"
                            }
                            Image {
                                id: cover
                                anchors.fill: parent
                                anchors.margins: 1
                                source: win.player.art || ""
                                sourceSize: Qt.size(168, 168)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                        Column {
                            width: parent.width - 98
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: playFrame.has ? (win.player.title || "Okänd titel") : "Inget spelas"
                                color: "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.weight: Font.DemiBold
                                font.pixelSize: 16
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                visible: playFrame.has
                                text: win.player.artist || ""
                                color: "#C3CCDA"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: playFrame.has ? [win.player.album, win.player.app ? win.player.app.charAt(0).toUpperCase() + win.player.app.slice(1) : ""].filter(t => t).join(" · ")
                                                    : "Starta musik i t.ex. GoblinAmp"
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                            }
                        }
                    }
                    Item {
                        width: parent.width
                        height: 14
                        visible: playFrame.has && win.player.length > 0
                        Text {
                            id: posText
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.clock(playFrame.shownPosition)
                            color: "#8B98AD"
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 11
                        }
                        Rectangle {
                            anchors { left: posText.right; leftMargin: 8; right: lenText.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            height: 4
                            color: "#1A2438"
                            Rectangle {
                                width: parent.width * (win.player.length ? playFrame.shownPosition / win.player.length : 0)
                                height: parent.height
                                color: "#E6ECF5"
                            }
                        }
                        Text {
                            id: lenText
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: win.clock(win.player.length || 0)
                            color: "#8B98AD"
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 11
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        visible: playFrame.has
                        Repeater {
                            model: [
                                {"what": "Previous", "path": "M5 5h2v14H5zM19 5L9 12l10 7z", "main": false},
                                {"what": "PlayPause", "path": playFrame.playing ? "M7 5h4v14H7zM13 5h4v14h-4z" : "M7 4l13 8-13 8z", "main": true},
                                {"what": "Next", "path": "M17 5h2v14h-2zM5 5l10 7-10 7z", "main": false}
                            ]
                            Rectangle {
                                required property var modelData
                                width: modelData.main ? 64 : 52
                                height: 44
                                color: modelData.main ? (mediaArea.containsMouse ? accent.hover : accent.color)
                                                      : (mediaArea.containsMouse ? "#1A2438" : "transparent")
                                border.width: modelData.main ? 0 : 1
                                border.color: "#1E2A40"
                                Glyph {
                                    anchors.centerIn: parent
                                    scale: 0.8
                                    filled: true
                                    path: parent.modelData.path
                                    stroke: parent.modelData.main ? accent.on : "#E6ECF5"
                                }
                                MouseArea {
                                    id: mediaArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.media(parent.modelData.what)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // A press beside the small box closes it
    MouseArea {
        anchors.fill: parent
        z: 4
        enabled: backend.tray !== ""
        visible: enabled
        onClicked: backend.closeTray()
    }

    // ── At the bottom: the own programs ───────────────────────
    Rectangle {
        id: bottomBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 112
        color: "#0B1018"
        Rectangle { width: parent.width; height: 1; color: "#1A2438" }
        Row {
            anchors.centerIn: parent
            spacing: 14
            Repeater {
                model: win.bottom
                Rectangle {
                    required property var modelData
                    width: 84
                    height: 88
                    color: dockArea.containsMouse ? "#12203A" : "transparent"
                    AppIcon {
                        y: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        side: 52
                        icon: modelData.icon
                        name: modelData.name
                    }
                    Text {
                        y: 66
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.name
                        color: "#C3CCDA"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: dockArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.launch(modelData.path)
                    }
                }
            }
            Rectangle {
                width: 84
                height: 88
                color: allArea.containsMouse ? "#12203A" : "transparent"
                Rectangle {
                    y: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 52
                    height: 52
                    color: "transparent"
                    border.width: 1
                    border.color: win.mid === "apps" ? accent.color : "#1E2A40"
                    Grid {
                        anchors.centerIn: parent
                        columns: 3
                        spacing: 6
                        Repeater { model: 9; Rectangle { width: 8; height: 8; color: "#8B98AD" } }
                    }
                }
                Text {
                    y: 66
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Alla program"
                    color: "#C3CCDA"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 12
                }
                MouseArea {
                    id: allArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { search.text = ""; win.group = ""; win.showApps(); }
                }
            }
        }
    }
}
