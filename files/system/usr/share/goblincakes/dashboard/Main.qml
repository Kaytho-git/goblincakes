// GOBLINCAKES Dashboard – step 1–3 (10 Nov): the open programs at the top, the own programs at the bottom,
// the frames of the view (SPEL, JOBB, … – chosen in Config → Dashboard) to the left and right with KVOT and
// SPELAS NU always at the bottom, and in the middle every program (type = search) or what was pressed in a
// frame. The data comes from goblin-dashboard (backend.get(key) = JSON).
import QtQuick
import QtQuick.Window
import QtQuick.Shapes

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
    property var own: []         // GOBLINCAKES' own programs, small above the bottom row (dash.own_apps)
    property var windows: []
    property var system: ({})
    property var top: []
    property var player: ({})
    property var quota: ({})
    property var projects: []
    property var project: ({})
    property var trayBox: ({})
    property var winMenu: null         // right-click on an open program: {id, name, x, y} (Växla till / Stäng)
    property var tools: ({})
    property var wow: ({})
    property var cs2: ({})
    property var builds: ({})
    property var reports: ({})
    property int boss: -1              // the chosen boss in SENASTE RAIDEN (-1 = the last one pulled)
    property string csMap: ""          // the chosen map in CS2 ("" = the most played)
    readonly property var trayIcons: JSON.parse(backend.trayIcons)
    // The views: [{name, left: [frame ids], right: [frame ids], mid}] and the one shown
    readonly property var views: JSON.parse(backend.views)
    readonly property var currentView: views[backend.view] || ({ "left": [], "right": [] })
    function frameComponent(id) {
        return ({ "projects": projectsFrame, "system": systemFrame, "wow": wowFrame, "cs2": cs2Frame,
                  "builds": buildsFrame, "reports": reportsFrame })[id] || null;
    }
    // A frame is shown only when it has something to show (projects and the system always have)
    function shows(id) {
        return id === "projects" || id === "system" ? true
             : id === "wow" ? (wow.players || []).length > 0
             : id === "cs2" ? !!cs2.count
             : id === "builds" ? !!builds.builder && (builds.rows || []).length > 0
             : id === "reports" ? (reports.rows || []).length > 0 : false;
    }
    // A sideways swipe (touchpad) changes the view – once per swipe
    property real swipe: 0
    function nudgeView(dx) {
        if (swipeLock.running) {
            swipeLock.restart();
            return;
        }
        swipe += dx;
        if (Math.abs(swipe) >= 160) {
            backend.stepView(swipe < 0 ? 1 : -1);
            swipe = 0;
            swipeLock.restart();
        }
    }
    Timer { id: swipeLock; interval: 450; onTriggered: win.swipe = 0 }

    property string group: ""          // the chosen kind of program ("" = all)
    property int sel: 0                // the marked program in the grid
    property string note: ""
    property bool dialogOpen: false
    property string box: ""            // the small box under the icons that is not the tray's: kvot (11 Nov)
    property bool adding: false        // + in PROJEKT: the folder chooser over the middle (11 Nov)
    property var browse: ({})
    property date now: new Date()
    readonly property string mid: backend.mid
    readonly property string midProject: mid.indexOf("project:") === 0 ? mid.slice(8) : ""
    readonly property string midChar: mid.indexOf("char:") === 0 ? mid.slice(5) : ""
    readonly property var classColors: ({
        DeathKnight: "#C41E3A", DemonHunter: "#A330C9", Druid: "#FF7C0A", Evoker: "#33937F",
        Hunter: "#AAD372", Mage: "#3FC7EB", Monk: "#00FF98", Paladin: "#F48CBA", Priest: "#FFFFFF",
        Rogue: "#FFF468", Shaman: "#0070DD", Warlock: "#8788EE", Warrior: "#C69B6D" })
    // Warcraft Logs' parse colours
    function parseColor(p) {
        return p === null || p === undefined ? "#8B98AD" : p >= 100 ? "#E5CC80" : p >= 99 ? "#E268A8" : p >= 95 ? "#FF8000"
             : p >= 75 ? "#A335EE" : p >= 50 ? "#0070FF" : p >= 25 ? "#1EFF00" : "#8B98AD";
    }
    function resultColor(kind) {
        return ({"ok": "#3BD16F", "win": "#3BD16F", "fail": "#F06B6B", "loss": "#F06B6B", "run": "#F0B232"})[kind] || "#8B98AD";
    }

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
        // Esc: one step at a time – the small box/menu, the search, the middle, and last the dashboard itself
        if (winMenu)
            winMenu = null;
        else if (box !== "")
            box = "";
        else if (adding)
            adding = false;
        else if (backend.tray !== "")
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
                         "trayBox", "tools", "wow", "cs2", "builds", "reports", "own", "browse"])
            load(k);
    }
    onVisibleChanged: {
        backend.setVisible(visible);
        winMenu = null;
        box = "";
        adding = false;
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

    // ── Pieces (same as GOBLINCAKES Config) ──────────────────

    component FastWheel: WheelHandler {
        required property Flickable flick
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
            const side = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x;
            if (Math.abs(side) > Math.abs(delta)) {     // sideways: changes the view (win.nudgeView)
                win.nudgeView(side);
                return;
            }
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

    // A column of frames (left or right): each frame as tall as it needs, PROJEKT takes the room that is left and
    // scrolls in itself (11 Nov – before, the whole column scrolled). The column itself scrolls only when even
    // that does not fit.
    component FrameColumn: Flickable {
        id: fc
        property var frames: []
        readonly property int gap: 16
        // the frames' own heights, PROJEKT left out
        readonly property real fixed: {
            let h = Math.max(0, fcRepeater.count - 1) * gap;
            for (let i = 0; i < fcRepeater.count; i++) {
                const l = fcRepeater.itemAt(i);
                if (l && l.item && l.modelData !== "projects")
                    h += l.item.implicitHeight;
            }
            return h;
        }
        contentHeight: fcColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 1
        Column {
            id: fcColumn
            width: fc.width
            spacing: fc.gap
            Repeater {
                id: fcRepeater
                model: fc.frames
                Loader {
                    required property string modelData
                    width: fcColumn.width
                    height: !item ? 0
                          : modelData === "projects" ? Math.max(item.minHeight, Math.min(item.implicitHeight, fc.height - fc.fixed))
                          : item.implicitHeight
                    sourceComponent: win.frameComponent(modelData)
                }
            }
        }
        FastWheel { flick: fc }
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

    // A number with its label under it
    component Tile: Frame {
        property string value
        property string label
        property color tint: "#E6ECF5"
        height: 74
        Text {
            y: 12
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.value
            color: parent.tint
            font.family: "Chakra Petch"
            font.weight: Font.Bold
            font.pixelSize: 22
        }
        Text {
            y: 46
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.label
            color: "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: 11
            font.letterSpacing: 1
        }
    }

    // A row in a side frame that shows something in the middle
    component SideCard: Rectangle {
        id: card
        property bool on: false
        property string title
        property string line
        property color titleColor: "#E6ECF5"
        property string side
        property bool big: false
        signal clicked()
        width: parent ? parent.width : 0
        height: 56
        color: on || cardArea.containsMouse ? "#12203A" : "#0E1420"
        border.width: on ? 2 : 1
        border.color: on ? accent.color : "#1E2A40"
        Column {
            anchors { left: parent.left; leftMargin: 12; right: rightText.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 2
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: card.title
                color: card.titleColor
                font.family: card.big ? "Chakra Petch" : "IBM Plex Sans"
                font.weight: card.big ? Font.Bold : Font.DemiBold
                font.pixelSize: card.big ? 17 : 15
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: text !== ""
                text: card.line
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 12
            }
        }
        Text {
            id: rightText
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: card.side
            textFormat: Text.StyledText
            color: "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: 12
        }
        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.clicked()
        }
    }

    // A table's cell text
    component Cell: Text {
        color: "#E6ECF5"
        font.family: "IBM Plex Sans"
        font.pixelSize: 14
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignRight
    }
    component HeadCell: Text {
        color: "#8B98AD"
        font.family: "IBM Plex Sans"
        font.pixelSize: 11
        font.letterSpacing: 1
        horizontalAlignment: Text.AlignRight
    }
    component BigTitle: Text {
        color: "#E6ECF5"
        font.family: "Chakra Petch"
        font.weight: Font.Bold
        font.pixelSize: 26
    }
    component SubTitle: Text {
        color: "#8B98AD"
        font.family: "IBM Plex Sans"
        font.pixelSize: 13
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

    // An icon in the row under the logo (KVOT, the power button) – like the tray's
    component TopIcon: Rectangle {
        id: topIcon
        property string path
        property bool on: false
        property bool warn: false
        signal clicked()
        width: 40
        height: 36
        color: on ? accent.dim : topArea.containsMouse ? "#1A2438" : "transparent"
        border.width: 1
        border.color: on ? accent.color : warn ? "#F06B6B" : "#1E2A40"
        Glyph {
            anchors.centerIn: parent
            scale: 0.8
            path: topIcon.path
            stroke: topIcon.warn ? "#F06B6B" : topIcon.on ? "#E6ECF5" : "#C3CCDA"
        }
        MouseArea {
            id: topArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: topIcon.clicked()
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
            width: Math.max(300, trayRow.implicitWidth)
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
            // The system tray as icons – press for more; then KVOT and the power button (11 Nov)
            Row {
                id: trayRow
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
                            onClicked: { win.box = ""; backend.openTray(parent.modelData.id); }
                        }
                    }
                }
                Item { width: 8; height: 36 }
                // KVOT (11 Nov – was a frame at the bottom left): red when a window is at 90 % or more
                TopIcon {
                    visible: (win.quota.services || []).length > 0
                    on: win.box === "kvot"
                    path: "M3 17a9 9 0 0 1 18 0M12 17l4-6M6 13l1 1M18 13l-1 1M12 8v1"
                    warn: (win.quota.services || []).some(sv => (sv.windows || []).some(w => w.percent >= 90))
                    onClicked: { backend.closeTray(); win.box = win.box === "kvot" ? "" : "kvot"; }
                }
                // The power button (11 Nov – the dashboard layout has no top bar): the logout screen
                TopIcon {
                    path: "M12 3v9M7.5 6.5a7 7 0 1 0 9 0"
                    onClicked: { win.box = ""; backend.closeTray(); backend.power(); }
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
            anchors { left: openLabel.right; leftMargin: 20; right: customizeButton.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
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
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            // the small menu under the chip (10 Nov, the user's wish: close a program from here)
                            const at = mapToItem(null, 0, height);
                            win.winMenu = {id: modelData.id, name: modelData.name,
                                           x: Math.min(at.x, win.width - 220), y: at.y + 4};
                        } else {
                            win.winMenu = null;
                            backend.activate(modelData.id);
                        }
                    }
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
        // Anpassa: Config → Dashboard (the views, what each frame shows, the programs at the bottom)
        Rectangle {
            id: customizeButton
            anchors { right: clockBox.left; rightMargin: 20; verticalCenter: parent.verticalCenter }
            width: customizeRow.implicitWidth + 28
            height: 44
            color: customizeArea.containsMouse ? "#1A2438" : "transparent"
            border.width: 1
            border.color: "#1E2A40"
            Row {
                id: customizeRow
                anchors.centerIn: parent
                spacing: 8
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    scale: 0.7
                    path: "M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M14 4h4v4h-4zM8 10h4v4H8zM16 16h4v4h-4z"
                    stroke: "#8B98AD"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Anpassa"
                    color: customizeArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 13
                }
            }
            MouseArea {
                id: customizeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: backend.customize()
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

    // KVOT: the small box behind its icon (11 Nov – was a frame at the bottom left)
    Frame {
        id: quotaPanel
        visible: win.box === "kvot"
        x: 24
        y: topBar.height - 6
        z: 5
        width: 340
        height: quotaColumn.implicitHeight + 28
        border.color: accent.color
        MouseArea { anchors.fill: parent }
        Column {
            id: quotaColumn
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 16
            Item {
                width: parent.width
                height: 20
                Heading { anchors.verticalCenter: parent.verticalCenter; text: "KVOT" }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "✕"
                    color: closeQuotaArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                    font.pixelSize: 14
                    MouseArea {
                        id: closeQuotaArea
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.box = ""
                    }
                }
            }
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
                        Heading { text: String(service.modelData.name || service.modelData.id).toUpperCase() }
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

    // ── The frames: each view (Config → Dashboard) picks which ones it shows, left and right ──
    // A frame with nothing to show is left out (win.shows), and the dashboard grows the middle instead.
    // PROJEKT (11 Nov): + next to the heading opens the dashboard's own folder chooser, every project is in the
    // list (scrolls in the frame when the column has no more room – FrameColumn), ✕ on a row takes it out
    Component {
        id: projectsFrame
        Frame {
            id: projFrame
            width: parent.width
            readonly property int rowHeight: 56
            readonly property real listHeight: win.projects.length ? win.projects.length * (rowHeight + 6) - 6 : 40
            implicitHeight: 16 + 30 + 10 + listHeight + 16
            readonly property real minHeight: 16 + 30 + 10 + Math.min(listHeight, 2 * (rowHeight + 6) - 6) + 16
            Item {
                id: projHead
                x: 16
                y: 16
                width: parent.width - 32
                height: 30
                Heading { anchors.verticalCenter: parent.verticalCenter; text: "PROJEKT" }
                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 30
                    height: 30
                    color: win.adding ? accent.dim : addArea.containsMouse ? "#1A2438" : "transparent"
                    border.width: 1
                    border.color: win.adding || addArea.containsMouse ? accent.color : "#1E2A40"
                    Glyph {
                        anchors.centerIn: parent
                        scale: 0.7
                        path: "M12 5v14M5 12h14"
                        stroke: addArea.containsMouse || win.adding ? "#E6ECF5" : "#8B98AD"
                    }
                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.adding = !win.adding;
                            if (win.adding)
                                backend.browse("");
                        }
                    }
                }
            }
            Text {
                x: 16
                y: 56
                width: parent.width - 32
                visible: win.projects.length === 0
                wrapMode: Text.WordWrap
                text: "Inga projekt ännu – tryck på + för att lägga till en mapp"
                color: "#5C6880"
                font.family: "IBM Plex Sans"
                font.pixelSize: 13
            }
            ListView {
                id: projList
                x: 16
                y: 56
                width: parent.width - 32
                height: parent.height - 56 - 16
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: win.projects
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: win.midProject === modelData.path
                    readonly property bool hovered: projArea.containsMouse || removeArea.containsMouse
                    width: projList.width - (projBar.visible ? 12 : 0)
                    height: projFrame.rowHeight
                    color: on || hovered ? "#12203A" : "#0E1420"
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
                        anchors { left: parent.left; leftMargin: 48; right: parent.right; rightMargin: 36; verticalCenter: parent.verticalCenter }
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
                        onClicked: { win.adding = false; backend.setMid("project:" + modelData.path); }
                    }
                    // ✕: out of the list (the folder and its files are not touched)
                    Text {
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        visible: parent.hovered
                        text: "✕"
                        color: removeArea.containsMouse ? accent.errorBright : "#8B98AD"
                        font.pixelSize: 14
                        MouseArea {
                            id: removeArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.removeProject(modelData.path)
                        }
                    }
                }
                FastWheel { flick: projList }
            }
            FlatScrollBar { id: projBar; flick: projList }
        }
    }
    Component {
        id: systemFrame
        Frame {
            width: parent.width
            implicitHeight: systemColumn.implicitHeight + 32
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
                    // DISK only in the middle (press SYSTEM) – 11 Nov, the user's wish
                    model: (win.system.rows || []).filter(r => r.id !== "disk")
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
    }
    Component {
        id: wowFrame
        Frame {
            width: parent.width
            implicitHeight: wowColumn.implicitHeight + 32
            Column {
                id: wowColumn
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 8
                Heading { text: "WOW STATS"; bottomPadding: 4 }
                SideCard {
                    visible: !!win.wow.raid
                    on: win.mid === "raid"
                    title: "Senaste raiden"
                    line: win.wow.raid ? win.wow.raid.short + " · " + win.wow.raid.difficulty + " · "
                                         + win.wow.raid.killed + "/" + win.wow.raid.bosses.length + " bossar" : ""
                    onClicked: backend.setMid("raid")
                }
                Text {
                    topPadding: 6
                    text: "KARAKTÄRER"
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
                Repeater {
                    model: (win.wow.players || []).slice(0, 3)
                    SideCard {
                        required property var modelData
                        big: true
                        on: win.midChar === modelData.player
                        title: modelData.name
                        titleColor: win.classColors[modelData["class"]] || "#E6ECF5"
                        line: [modelData.spec, modelData["class"], modelData.realm].filter(t => t).join(" · ")
                        side: modelData.ilvl ? "ilvl <b><font color='#E6ECF5'>" + modelData.ilvl + "</font></b>" : ""
                        onClicked: backend.setMid("char:" + modelData.player)
                    }
                }
            }
        }
    }
    Component {
        id: cs2Frame
        Frame {
            width: parent.width
            implicitHeight: csColumn.implicitHeight + 32
            Column {
                id: csColumn
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 10
                Heading { text: "CS2 STATS" }
                Rectangle {
                    width: parent.width
                    height: csInner.implicitHeight + 20
                    color: win.mid === "cs2" || csArea.containsMouse ? "#12203A" : "#0E1420"
                    border.width: win.mid === "cs2" ? 2 : 1
                    border.color: win.mid === "cs2" ? accent.color : "#1E2A40"
                    Column {
                        id: csInner
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 6
                        Text {
                            text: "Senaste " + (win.cs2.count || 0) + " matcherna"
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 15
                        }
                        Text {
                            text: win.cs2.count ? win.cs2.wins + " vinster, " + win.cs2.losses + " förluster · K/D "
                                                  + win.cs2.avg.kd + " · ADR " + win.cs2.avg.adr : ""
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                        Row {
                            spacing: 4
                            Repeater {
                                model: win.cs2.form || []
                                Rectangle { required property string modelData; width: 18; height: 8; color: win.resultColor(modelData) }
                            }
                        }
                    }
                    MouseArea {
                        id: csArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.setMid("cs2")
                    }
                }
            }
        }
    }
    Component {
        id: buildsFrame
        Frame {
            width: parent.width
            implicitHeight: buildColumn.implicitHeight + 32
            Column {
                id: buildColumn
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 10
                Heading { text: "BYGGEN" }
                Rectangle {
                    width: parent.width
                    height: buildInner.implicitHeight + 20
                    color: win.mid === "builds" || buildArea.containsMouse ? "#12203A" : "#0E1420"
                    border.width: win.mid === "builds" ? 2 : 1
                    border.color: win.mid === "builds" ? accent.color : "#1E2A40"
                    Column {
                        id: buildInner
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 6
                        Text {
                            readonly property var last: win.builds.last || ({})
                            text: "Senaste bygget " + (last.state || "")
                            color: win.resultColor(last.kind) === "#8B98AD" ? "#E6ECF5" : win.resultColor(last.kind)
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 15
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: win.builds.last ? win.builds.last.when + " · " + win.builds.last.length : ""
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                        Row {
                            spacing: 4
                            Repeater {
                                model: (win.builds.rows || []).slice().reverse()
                                Rectangle { required property var modelData; width: 18; height: 8; color: win.resultColor(modelData.kind) }
                            }
                        }
                    }
                    MouseArea {
                        id: buildArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.setMid("builds")
                    }
                }
            }
        }
    }
    Component {
        id: reportsFrame
        Frame {
            width: parent.width
            implicitHeight: kakanColumn.implicitHeight + 32
            Column {
                id: kakanColumn
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 10
                Heading { text: "KAKAN" }
                SideCard {
                    on: win.mid === "reports"
                    title: win.reports.new ? win.reports.new + (win.reports.new === 1 ? " ny rapport" : " nya rapporter") : "Rapporter"
                    line: (win.reports.rows || []).length ? "senast: " + win.reports.rows[0].title : ""
                    onClicked: backend.setMid("reports")
                }
            }
        }
    }

    // ── The middle part ───────────────────────────────────────
    Item {
        id: body
        anchors { top: topBar.bottom; bottom: bottomBar.top; left: parent.left; right: parent.right
                  topMargin: 20; bottomMargin: 16; leftMargin: 24; rightMargin: 24 }

        // Left: the view's frames (PROJEKT, SYSTEM, …) – PROJEKT takes the room that is left and scrolls in itself
        // (11 Nov); KVOT is an icon at the top now
        Item {
            id: leftCol
            readonly property var frames: win.currentView.left.filter(f => win.shows(f))
            visible: frames.length > 0
            width: visible ? 300 : 0     // nothing chosen to the left: the middle gets the room
            height: parent.height

            FrameColumn {
                id: leftFlick
                anchors.fill: parent
                frames: leftCol.frames
            }
        }

        // The middle: every program (type = search), or what was pressed in a frame
        Rectangle {
            id: middle
            anchors { left: leftCol.right; leftMargin: leftCol.visible ? 16 : 0; right: rightCol.left; rightMargin: 16
                      top: parent.top; bottom: viewStrip.visible ? viewStrip.top : parent.bottom }
            color: "#0E1420"
            border.width: 1
            border.color: "#1E2A40"
            clip: true

            // ── + in PROJEKT: the dashboard's own folder chooser (11 Nov – the system's folder dialog over the
            // full-screen dashboard added nothing). Over everything else in the middle; Esc/Avbryt closes it.
            Rectangle {
                id: addView
                visible: win.adding
                anchors.fill: parent
                anchors.margins: 1
                z: 20
                color: "#0E1420"
                readonly property var b: win.browse
                onVisibleChanged: visible ? forceActiveFocus() : search.forceActiveFocus()
                Keys.onEscapePressed: win.back()
                Keys.onReturnPressed: if (b.path && !b.added) { win.adding = false; backend.addProject(b.path); }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Backspace && b.parent) {
                        backend.browse(b.parent);
                        event.accepted = true;
                    }
                }
                MouseArea { anchors.fill: parent }   // a press here is not a press on the view under it
                Column {
                    id: addHead
                    x: 28
                    y: 22
                    width: parent.width - 56
                    spacing: 6
                    BigTitle { text: "LÄGG TILL PROJEKT" }
                    SubTitle {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Välj en mapp. Samma lista som PROJEKT → MAPPAR i Goblin AI – mappen och filerna rörs inte."
                    }
                    Item { width: 1; height: 8 }
                    // The Git folders in the home folder that are not in the list yet: one press adds
                    Heading {
                        visible: (addView.b.suggest || []).length > 0
                        text: "GIT-MAPPAR I HEMMAPPEN"
                        font.pixelSize: 12
                    }
                    Flow {
                        visible: (addView.b.suggest || []).length > 0
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: addView.b.suggest || []
                            Rectangle {
                                required property var modelData
                                width: suggestText.implicitWidth + 28
                                height: 38
                                color: suggestArea.containsMouse ? accent.dim : "#0B1018"
                                border.width: 1
                                border.color: suggestArea.containsMouse ? accent.color : "#1E2A40"
                                Text {
                                    id: suggestText
                                    anchors.centerIn: parent
                                    text: "+ " + modelData.name
                                    color: "#E6ECF5"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: suggestArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { win.adding = false; backend.addProject(modelData.path); }
                                }
                            }
                        }
                    }
                    Item { width: 1; height: 8; visible: (addView.b.suggest || []).length > 0 }
                    // Where the chooser is: up, the folder, and Lägg till
                    Item {
                        width: parent.width
                        height: 44
                        FlatButton {
                            id: upButton
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!addView.b.parent
                            width: visible ? 96 : 0
                            height: 36
                            text: "↑ Upp"
                            onClicked: backend.browse(addView.b.parent)
                        }
                        Text {
                            anchors { left: upButton.right; leftMargin: upButton.visible ? 14 : 0; right: addButtons.left
                                      rightMargin: 14; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideMiddle
                            text: addView.b.short || ""
                            color: "#E6ECF5"
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 15
                        }
                        Row {
                            id: addButtons
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            FlatButton {
                                visible: !!addView.b.path && !addView.b.added
                                primary: true
                                height: 36
                                text: "Lägg till den här mappen"
                                onClicked: { win.adding = false; backend.addProject(addView.b.path); }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !!addView.b.added
                                rightPadding: 8
                                text: "Finns redan i listan"
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                            FlatButton {
                                height: 36
                                text: "Avbryt  (Esc)"
                                onClicked: win.adding = false
                            }
                        }
                    }
                }
                // The folders in it: press = go in
                ListView {
                    id: dirList
                    anchors { top: addHead.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom
                              leftMargin: 28; rightMargin: 20; bottomMargin: 16 }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: addView.b.dirs || []
                    onModelChanged: contentY = 0
                    delegate: Rectangle {
                        required property var modelData
                        width: dirList.width - 12
                        height: 42
                        color: dirArea.containsMouse ? "#12203A" : "transparent"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
                        Glyph {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            scale: 0.8
                            path: "M3 6h7l2 3h9v10H3z"
                            stroke: modelData.git ? accent.text : "#8B98AD"
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: 44; right: gitTag.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: modelData.name
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 14
                        }
                        Text {
                            id: gitTag
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: modelData.git ? "Git" : ""
                            color: accent.text
                            font.family: "IBM Plex Mono"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: dirArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.browse(modelData.path)
                        }
                    }
                    Text {
                        visible: (addView.b.dirs || []).length === 0
                        topPadding: 8
                        text: addView.b.path ? "Inga fler mappar här" : "Läser …"
                        color: "#5C6880"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                    FastWheel { flick: dirList }
                }
                FlatScrollBar { flick: dirList }
            }

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
                    // Ctrl+← → changes the view; plain ← → too when the middle shows no program grid
                    Keys.onRightPressed: event => {
                        if (event.modifiers & Qt.ControlModifier || (text === "" && win.mid !== "apps")) backend.stepView(1);
                        else if (cursorPosition === text.length) grid.step(1);
                        else event.accepted = false;
                    }
                    Keys.onLeftPressed: event => {
                        if (event.modifiers & Qt.ControlModifier || (text === "" && win.mid !== "apps")) backend.stepView(-1);
                        else if (text === "") grid.step(-1);
                        else event.accepted = false;
                    }
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

            // ── The latest raid ──
            Flickable {
                id: raidView
                visible: win.mid === "raid" && !!win.wow.raid
                anchors { top: searchRow.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: parent.bottom
                          leftMargin: 28; rightMargin: 28; bottomMargin: 20 }
                contentHeight: raidColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                readonly property var r: win.wow.raid || ({"bosses": []})
                readonly property int at: win.boss >= 0 && win.boss < r.bosses.length ? win.boss : r.bosses.length - 1
                readonly property var b: r.bosses[at] || ({"pulls": []})
                Column {
                    id: raidColumn
                    width: raidView.width
                    spacing: 16
                    Row {
                        spacing: 14
                        BigTitle { id: raidTitle; text: "SENASTE RAIDEN" }
                        SubTitle {
                            anchors.baseline: raidTitle.baseline
                            text: [raidView.r.name, raidView.r.difficulty, raidView.r.day, raidView.r.length].filter(t => t).join(" · ")
                        }
                    }
                    Row {
                        id: raidTiles
                        width: parent.width
                        spacing: 10
                        readonly property real cell: (width - 40) / 5
                        Tile { width: raidTiles.cell; value: (raidView.r.killed || 0) + "/" + raidView.r.bosses.length; label: "BOSSAR"; tint: "#3BD16F" }
                        Tile { width: raidTiles.cell; value: String(raidView.r.pulls || 0); label: "PULLS" }
                        Tile { width: raidTiles.cell; value: raidView.r.length || ""; label: "RAIDTID" }
                        Tile { width: raidTiles.cell; value: raidView.r.bestParse === null || raidView.r.bestParse === undefined ? "–" : String(raidView.r.bestParse)
                               label: "DIN BÄSTA PARSE"; tint: win.parseColor(raidView.r.bestParse) }
                        Tile { width: raidTiles.cell; value: String(raidView.r.deaths || 0); label: "DINA DÖDSFALL" }
                    }
                    Column {
                        width: parent.width
                        Item {
                            width: parent.width
                            height: 30
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1E2A40" }
                            HeadCell { x: 10; text: "BOSS – TRYCK FÖR PULLARNA"; horizontalAlignment: Text.AlignLeft; anchors.verticalCenter: parent.verticalCenter }
                            Row {
                                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                HeadCell { width: 110; text: "PULLS" }
                                HeadCell { width: 110; text: "BÄSTA" }
                                HeadCell { width: 110; text: "DIN PARSE" }
                                HeadCell { width: 130; text: "DINA DÖDSFALL" }
                            }
                        }
                        Repeater {
                            model: raidView.r.bosses
                            Rectangle {
                                required property var modelData
                                required property int index
                                width: raidColumn.width
                                height: 44
                                color: raidView.at === index ? "#12203A" : bossArea.containsMouse ? "#101A2C" : "transparent"
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
                                Cell { x: 10; width: parent.width - 490; height: parent.height; horizontalAlignment: Text.AlignLeft; text: modelData.name }
                                Row {
                                    anchors { right: parent.right; rightMargin: 10 }
                                    height: parent.height
                                    Cell { width: 110; height: parent.height; text: String(modelData.count) }
                                    Cell { width: 110; height: parent.height; text: modelData.best; color: modelData.kill ? "#3BD16F" : "#F0B232" }
                                    Cell { width: 110; height: parent.height; text: modelData.parse === null ? "–" : String(modelData.parse); color: win.parseColor(modelData.parse) }
                                    Cell { width: 130; height: parent.height; text: String(modelData.deaths) }
                                }
                                MouseArea {
                                    id: bossArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.boss = index
                                }
                            }
                        }
                    }
                    Frame {
                        width: parent.width
                        height: pullColumn.implicitHeight + 32
                        Column {
                            id: pullColumn
                            x: 16
                            y: 16
                            width: parent.width - 32
                            spacing: 12
                            Row {
                                spacing: 12
                                Heading { id: pullHead; text: "PULLARNA · " + String(raidView.b.name || "").toUpperCase() }
                                Text {
                                    anchors.baseline: pullHead.baseline
                                    text: raidView.b.bars ? "bossens hälsa när pullen tog slut – grön = kill"
                                                          : "grön = kill · bossens hälsa visas när Warcraft Logs har svarat"
                                    color: "#8B98AD"
                                    font.family: "IBM Plex Sans"
                                    font.pixelSize: 12
                                }
                            }
                            Row {
                                width: parent.width
                                height: 64
                                spacing: 4
                                Repeater {
                                    model: raidView.b.pulls
                                    Item {
                                        required property var modelData
                                        width: Math.min(48, (pullColumn.width - (raidView.b.pulls.length - 1) * 4) / Math.max(1, raidView.b.pulls.length))
                                        height: 64
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: modelData.kill ? 64 : raidView.b.bars ? Math.max(6, 64 * modelData.pct / 100) : 20
                                            color: modelData.kill ? "#3BD16F" : accent.color
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: 8
                                FlatButton { text: "Öppna i Warcraft Logs"; visible: !!raidView.b.url; onClicked: backend.openUrl(raidView.b.url) }
                                FlatButton { text: "Hela kvällen i Warcraft Logs"; visible: !!raidView.r.url; onClicked: backend.openUrl(raidView.r.url) }
                                FlatButton {
                                    primary: true
                                    text: "Fråga Kakan om bossen"
                                    onClicked: backend.askKakan("Titta på pullarna på " + raidView.b.name + " (" + raidView.b.difficulty
                                        + ") från senaste raiden" + (raidView.b.url ? ": " + raidView.b.url : "")
                                        + ". Vad gick fel och vad kan jag göra bättre?")
                                }
                            }
                        }
                    }
                }
                FastWheel { flick: raidView }
            }
            FlatScrollBar { flick: raidView }

            // ── A character ──
            Item {
                id: charView
                readonly property var c: {
                    for (const p of win.wow.players || [])
                        if (p.player === win.midChar)
                            return p;
                    return null;
                }
                visible: win.midChar !== "" && !!c
                anchors { top: searchRow.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: parent.bottom
                          leftMargin: 28; rightMargin: 28; bottomMargin: 20 }
                Column {
                    width: parent.width
                    spacing: 16
                    visible: !!charView.c
                    Column {
                        Text {
                            text: charView.c ? charView.c.name : ""
                            color: charView.c ? win.classColors[charView.c["class"]] || "#E6ECF5" : "#E6ECF5"
                            font.family: "Chakra Petch"
                            font.weight: Font.Bold
                            font.pixelSize: 34
                        }
                        SubTitle {
                            text: charView.c ? [charView.c.spec, charView.c["class"], charView.c.realm, charView.c.region,
                                                "spelade senast " + charView.c.last].filter(t => t).join(" · ") + " · den här säsongen" : ""
                        }
                    }
                    Grid {
                        id: charTiles
                        width: parent.width
                        columns: 6
                        spacing: 10
                        readonly property real cell: (width - 50) / 6
                        readonly property var c: charView.c || ({})
                        function show(v, pre) { return v === null || v === undefined ? "–" : (pre || "") + v; }
                        Tile { width: charTiles.cell; value: charTiles.show(charTiles.c.ilvl); label: "ITEM LEVEL" }
                        Tile { width: charTiles.cell; value: charTiles.show(charTiles.c.raidParse); label: "RAID-PARSE (SNITT)"; tint: win.parseColor(charTiles.c.raidParse) }
                        Tile { width: charTiles.cell; value: charTiles.show(charTiles.c.bestParse); label: "BÄSTA PARSE"; tint: win.parseColor(charTiles.c.bestParse) }
                        Tile { width: charTiles.cell; value: (charTiles.c.kills || 0) + " / " + (charTiles.c.wipes || 0); label: "KILLS / WIPES" }
                        Tile { width: charTiles.cell; value: (charTiles.c.timed || 0) + " / " + (charTiles.c.keys || 0); label: "NYCKLAR I TID" }
                        Tile { width: charTiles.cell; value: charTiles.show(charTiles.c.topKey, "+"); label: "HÖGSTA I TID" }
                    }
                    Heading { text: "PARSE ÖVER TID"; topPadding: 6 }
                    Row {
                        width: parent.width
                        height: 80
                        spacing: 4
                        Repeater {
                            model: charView.c ? charView.c.trend : []
                            Item {
                                required property var modelData
                                width: Math.min(28, (charView.width - 39 * 4) / 40)
                                height: 80
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(3, 80 * modelData.parse / 100)
                                    color: win.parseColor(modelData.parse)
                                }
                            }
                        }
                    }
                    Text {
                        visible: charView.c && charView.c.trend.length === 0
                        text: "Inga parser den här säsongen ännu."
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                    }
                    Row {
                        spacing: 8
                        FlatButton { text: "Senaste raiden"; visible: !!win.wow.raid; onClicked: backend.setMid("raid") }
                        FlatButton { text: "Öppna på Warcraft Logs"; visible: charView.c && charView.c.wclUrl !== ""; onClicked: backend.openUrl(charView.c.wclUrl) }
                        FlatButton { text: "WoW Stats i GoblinRecorder"; onClicked: backend.launch("goblin-recorder.desktop") }
                        FlatButton {
                            primary: true
                            text: "Fråga Kakan"
                            onClicked: backend.askKakan("Hur ligger " + charView.c.name + " till den här säsongen i raid och Mythic+ – vad ska jag förbättra först?")
                        }
                    }
                }
            }

            // ── CS2 ──
            Item {
                id: csView
                visible: win.mid === "cs2" && !!win.cs2.count
                anchors { top: searchRow.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: parent.bottom
                          leftMargin: 28; rightMargin: 28; bottomMargin: 20 }
                readonly property var maps: win.cs2.maps || []
                readonly property var chosen: {
                    for (const m of maps)
                        if (m.name === win.csMap)
                            return m;
                    return maps[0] || ({"rows": [], "name": ""});
                }
                Column {
                    width: parent.width
                    spacing: 18
                    Row {
                        spacing: 14
                        BigTitle { id: csTitle; text: "COUNTER-STRIKE 2" }
                        SubTitle {
                            anchors.baseline: csTitle.baseline
                            text: "senaste " + (win.cs2.count || 0) + " matcherna · " + (win.cs2.all || 0) + " den här säsongen"
                        }
                    }
                    Row {
                        id: csTiles
                        width: parent.width
                        spacing: 10
                        readonly property real cell: (width - 50) / 6
                        readonly property var a: win.cs2.avg || ({})
                        Tile { width: csTiles.cell; value: String(win.cs2.wins || 0); label: "VINSTER"; tint: "#3BD16F" }
                        Tile { width: csTiles.cell; value: String(win.cs2.losses || 0); label: "FÖRLUSTER"; tint: "#F06B6B" }
                        Tile { width: csTiles.cell; value: csTiles.a.kd || "–"; label: "K/D" }
                        Tile { width: csTiles.cell; value: csTiles.a.adr || "–"; label: "ADR" }
                        Tile { width: csTiles.cell; value: (csTiles.a.kast || "–") + (csTiles.a.kast && csTiles.a.kast !== "–" ? " %" : ""); label: "KAST" }
                        Tile { width: csTiles.cell; value: (csTiles.a.hs || "–") + (csTiles.a.hs && csTiles.a.hs !== "–" ? " %" : ""); label: "HEADSHOTS" }
                    }
                    Row {
                        width: parent.width
                        spacing: 20
                        Column {
                            id: mapTable
                            width: parent.width - 400
                            Item {
                                width: parent.width
                                height: 30
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1E2A40" }
                                HeadCell { x: 10; text: "KARTA – TRYCK FÖR MATCHERNA"; horizontalAlignment: Text.AlignLeft; anchors.verticalCenter: parent.verticalCenter }
                                Row {
                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    HeadCell { width: 90; text: "MATCHER" }
                                    HeadCell { width: 90; text: "VINST %" }
                                    HeadCell { width: 90; text: "ADR" }
                                    HeadCell { width: 90; text: "K/D" }
                                }
                            }
                            Repeater {
                                model: csView.maps
                                Rectangle {
                                    required property var modelData
                                    width: mapTable.width
                                    height: 44
                                    color: csView.chosen.name === modelData.name ? "#12203A" : mapArea.containsMouse ? "#101A2C" : "transparent"
                                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
                                    Cell { x: 10; width: parent.width - 390; height: parent.height; horizontalAlignment: Text.AlignLeft; text: modelData.name }
                                    Row {
                                        anchors { right: parent.right; rightMargin: 10 }
                                        height: parent.height
                                        Cell { width: 90; height: parent.height; text: String(modelData.matches) }
                                        Cell { width: 90; height: parent.height; text: modelData.win }
                                        Cell { width: 90; height: parent.height; text: modelData.adr }
                                        Cell { width: 90; height: parent.height; text: modelData.kd }
                                    }
                                    MouseArea {
                                        id: mapArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.csMap = modelData.name
                                    }
                                }
                            }
                        }
                        Frame {
                            width: 380
                            height: matchColumn.implicitHeight + 32
                            Column {
                                id: matchColumn
                                x: 16
                                y: 16
                                width: parent.width - 32
                                spacing: 6
                                Heading { text: String(csView.chosen.name).toUpperCase() + " · NYAST FÖRST"; bottomPadding: 4 }
                                Repeater {
                                    model: csView.chosen.rows
                                    Item {
                                        required property var modelData
                                        width: matchColumn.width
                                        height: 44
                                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
                                        Cell { width: 70; height: parent.height; horizontalAlignment: Text.AlignLeft; text: modelData.date; color: "#8B98AD" }
                                        Cell { x: 78; width: 60; height: parent.height; horizontalAlignment: Text.AlignLeft; text: modelData.score
                                               color: win.resultColor(modelData.result); font.weight: Font.DemiBold }
                                        Cell { x: 146; width: 90; height: parent.height; text: "ADR " + modelData.adr }
                                        Cell { anchors.right: parent.right; width: 90; height: parent.height; text: "K/D " + modelData.kd }
                                    }
                                }
                                Item { width: 1; height: 6 }
                                FlatButton {
                                    primary: true
                                    width: parent.width
                                    text: "Fråga Kakan vad jag ska träna på här"
                                    onClicked: backend.askKakan("Titta på mina senaste CS2-matcher på " + csView.chosen.name + ". Vad ska jag träna på där?")
                                }
                                FlatButton { width: parent.width; text: "CS2 Stats i GoblinRecorder"; onClicked: backend.launch("goblin-recorder.desktop") }
                            }
                        }
                    }
                }
            }

            // ── The builds ──
            Item {
                id: buildView
                visible: win.mid === "builds"
                anchors { top: searchRow.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: parent.bottom
                          leftMargin: 28; rightMargin: 28; bottomMargin: 20 }
                Column {
                    id: buildHead
                    width: parent.width
                    spacing: 16
                    Row {
                        spacing: 14
                        BigTitle { id: buildTitle; text: "BYGGEN" }
                        SubTitle {
                            anchors.baseline: buildTitle.baseline
                            text: "GOBLINCAKES-imagen på GitHub · varje push + dagligen" + (win.builds.error ? " · " + win.builds.error : "")
                        }
                    }
                    Row {
                        id: buildTiles
                        width: parent.width
                        spacing: 10
                        readonly property real cell: (width - 30) / 4
                        readonly property var last: win.builds.last || ({})
                        Tile { width: buildTiles.cell; value: buildTiles.last.state || "–"; label: "SENASTE BYGGET"; tint: win.resultColor(buildTiles.last.kind) }
                        Tile { width: buildTiles.cell; value: buildTiles.last.length || "–"; label: "TOG" }
                        Tile { width: buildTiles.cell; value: String(win.builds.ok || 0); label: "LYCKADE AV DE SENASTE " + (win.builds.rows || []).length; tint: "#3BD16F" }
                        Tile { width: buildTiles.cell; value: String(win.builds.failed || 0); label: "MISSLYCKADE"; tint: win.builds.failed ? "#F06B6B" : "#E6ECF5" }
                    }
                    Item {
                        width: parent.width
                        height: 30
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1E2A40" }
                        HeadCell { text: "RESULTAT"; horizontalAlignment: Text.AlignLeft; anchors.verticalCenter: parent.verticalCenter }
                        HeadCell { x: 132; text: "COMMIT"; horizontalAlignment: Text.AlignLeft; anchors.verticalCenter: parent.verticalCenter }
                        HeadCell { x: 234; text: "VAD SOM ÄNDRADES"; horizontalAlignment: Text.AlignLeft; anchors.verticalCenter: parent.verticalCenter }
                        HeadCell { anchors { right: parent.right; rightMargin: 100; verticalCenter: parent.verticalCenter } text: "NÄR" }
                        HeadCell { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: "TID" }
                    }
                }
                ListView {
                    id: buildList
                    anchors { top: buildHead.bottom; left: parent.left; right: parent.right; bottom: buildButtons.top; bottomMargin: 12 }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.builds.rows || []
                    delegate: Rectangle {
                        required property var modelData
                        width: buildList.width
                        height: 48
                        color: rowHover.containsMouse ? "#101A2C" : "transparent"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
                        Cell { width: 124; height: parent.height; horizontalAlignment: Text.AlignLeft; text: modelData.state
                               color: win.resultColor(modelData.kind); font.weight: Font.DemiBold }
                        Cell { x: 132; width: 90; height: parent.height; horizontalAlignment: Text.AlignLeft; text: modelData.hash
                               color: accent.text; font.family: "IBM Plex Mono"; font.pixelSize: 12 }
                        Cell { x: 234; width: parent.width - 234 - 270; height: parent.height; horizontalAlignment: Text.AlignLeft; text: modelData.title }
                        Cell { anchors { right: parent.right; rightMargin: 100 } width: 160; height: parent.height; text: modelData.when; color: "#8B98AD" }
                        Cell { anchors { right: parent.right; rightMargin: 12 } width: 84; height: parent.height; text: modelData.length
                               color: "#8B98AD"; font.family: "IBM Plex Mono"; font.pixelSize: 12 }
                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.openUrl(modelData.url)
                        }
                    }
                    FastWheel { flick: buildList }
                }
                FlatScrollBar { flick: buildList }
                Row {
                    id: buildButtons
                    anchors.bottom: parent.bottom
                    spacing: 8
                    FlatButton { text: "Öppna på GitHub"; onClicked: backend.openUrl(win.builds.url || "") }
                    FlatButton {
                        visible: !!win.builds.running
                        text: "Säg till när bygget är klart"
                        onClicked: backend.watchBuild(win.builds.running.sha)
                    }
                    FlatButton {
                        primary: true
                        visible: !!win.builds.failed
                        text: "Fråga Kakan varför det misslyckades"
                        onClicked: backend.askKakan("Varför misslyckades det senaste misslyckade bygget av GOBLINCAKES?")
                    }
                }
            }

            // ── Kakan's reports ──
            Item {
                id: reportView
                visible: win.mid === "reports"
                anchors { top: searchRow.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: parent.bottom
                          leftMargin: 28; rightMargin: 28; bottomMargin: 20 }
                Row {
                    id: reportHead
                    spacing: 14
                    BigTitle { id: reportTitle; text: "KAKANS RAPPORTER" }
                    SubTitle { anchors.baseline: reportTitle.baseline; text: "det hon har lämnat till Claude · tryck för att läsa" }
                }
                ListView {
                    id: reportList
                    anchors { top: reportHead.bottom; topMargin: 16; left: parent.left; right: parent.right; bottom: parent.bottom }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.reports.rows || []
                    delegate: Rectangle {
                        required property var modelData
                        width: reportList.width
                        height: 56
                        color: reportHover.containsMouse ? "#101A2C" : "transparent"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
                        Rectangle { visible: modelData.new; width: 3; height: parent.height - 1; color: accent.color }
                        Cell { x: 14; width: 150; height: parent.height; horizontalAlignment: Text.AlignLeft; text: modelData.when; color: "#8B98AD" }
                        Cell { x: 172; width: parent.width - 184; height: parent.height; horizontalAlignment: Text.AlignLeft; text: modelData.title }
                        MouseArea {
                            id: reportHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.openFile(modelData.path)
                        }
                    }
                    FastWheel { flick: reportList }
                }
                FlatScrollBar { flick: reportList }
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

        // The views under the middle: ‹ • SPEL ◦ JOBB › – the wheel here, a sideways swipe or Ctrl+← → changes it
        Item {
            id: viewStrip
            visible: win.views.length > 1
            anchors { left: middle.left; right: middle.right; bottom: parent.bottom }
            height: 40
            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                property real sum: 0
                onWheel: event => {
                    const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    sum += d;
                    if (Math.abs(sum) >= 120) {
                        backend.stepView(sum < 0 ? 1 : -1);
                        sum = 0;
                    }
                }
            }
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                height: 32
                spacing: 14
                Repeater {
                    model: [-1].concat(win.views.map((v, i) => i)).concat([-2])
                    Rectangle {
                        required property int modelData
                        readonly property bool arrow: modelData < 0
                        readonly property bool on: modelData === backend.view
                        width: arrow ? 44 : viewName.implicitWidth + 30
                        height: 32
                        color: stripArea.containsMouse ? "#12203A" : "transparent"
                        Text {
                            visible: parent.arrow
                            anchors.centerIn: parent
                            text: parent.modelData === -1 ? "‹" : "›"
                            color: "#8B98AD"
                            font.pixelSize: 20
                        }
                        Rectangle {
                            visible: !parent.arrow
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            color: parent.on ? accent.color : "transparent"
                            border.width: parent.on ? 0 : 1
                            border.color: "#5C6880"
                        }
                        Text {
                            id: viewName
                            visible: !parent.arrow
                            x: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.arrow ? "" : (win.views[parent.modelData] || {}).name || ""
                            color: parent.on ? "#E6ECF5" : "#5C6880"
                            font.family: "Chakra Petch"
                            font.pixelSize: 12
                            font.letterSpacing: 2
                        }
                        MouseArea {
                            id: stripArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData === -1 ? backend.stepView(-1) : parent.modelData === -2
                                       ? backend.stepView(1) : backend.setView(parent.modelData)
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "bläddra med hjulet eller Ctrl+← →"
                    color: "#5C6880"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 11
                }
            }
        }

        // A sideways swipe anywhere else changes the view too (the lists leave it alone – FastWheel)
        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const side = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x;
                const down = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
                if (Math.abs(side) > Math.abs(down))
                    win.nudgeView(side);
            }
        }

        // Right: the view's frames, and SPELAS NU at the bottom
        Item {
            id: rightCol
            readonly property var frames: win.currentView.right.filter(f => win.shows(f))
            anchors.right: parent.right
            width: 340
            height: parent.height

            // The view's frames to the right (WOW STATS, CS2 STATS, BYGGEN, KAKAN …), SPELAS NU always
            FrameColumn {
                id: statsFlick
                anchors { top: parent.top; bottom: playFrame.top; bottomMargin: 16 }
                width: parent.width
                frames: rightCol.frames
            }

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

    // The menu behind a right-click on an open program: Växla till, Stäng
    MouseArea {
        anchors.fill: parent
        z: 4
        enabled: !!win.winMenu
        visible: enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: win.winMenu = null
    }
    Frame {
        id: winMenuBox
        visible: !!win.winMenu
        x: win.winMenu ? win.winMenu.x : 0
        y: win.winMenu ? win.winMenu.y : 0
        z: 5
        width: 200
        height: menuColumn.implicitHeight + 16
        border.color: accent.color
        MouseArea { anchors.fill: parent }   // a press in the menu is not a press on what lies under it
        Column {
            id: menuColumn
            x: 8
            y: 8
            width: parent.width - 16
            Text {
                width: parent.width
                height: 28
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: win.winMenu ? win.winMenu.name : ""
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 12
                font.capitalization: Font.AllUppercase
            }
            Repeater {
                model: [{text: "Växla till", act: "activate"}, {text: "Stäng", act: "close"}]
                Rectangle {
                    required property var modelData
                    width: menuColumn.width
                    height: 36
                    color: itemArea.containsMouse ? "#1A2438" : "transparent"
                    Text {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        text: modelData.text
                        color: modelData.act === "close" && itemArea.containsMouse ? "#E5534B" : "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const id = win.winMenu.id;
                            win.winMenu = null;
                            if (modelData.act === "close")
                                backend.closeWindow(id);
                            else
                                backend.activate(id);
                        }
                    }
                }
            }
        }
    }

    // ── At the bottom: the own programs ───────────────────────
    Rectangle {
        id: bottomBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 112 + (ownRow.visible ? ownRow.height : 0)
        color: "#0B1018"
        Rectangle { width: parent.width; height: 1; color: "#1A2438" }
        // GOBLINCAKES' own programs, smaller, above the programs in every view (10 Nov, the user's wish)
        Row {
            id: ownRow
            visible: win.own.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            height: 56
            spacing: 6
            Repeater {
                model: win.own
                Rectangle {
                    required property var modelData
                    width: 72
                    height: 56
                    color: ownArea.containsMouse ? "#12203A" : "transparent"
                    AppIcon {
                        y: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        side: 30
                        icon: modelData.icon
                        name: modelData.name
                    }
                    Text {
                        y: 38
                        width: parent.width - 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.name.replace(/^GOBLINCAKES /, "")
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 10
                    }
                    MouseArea {
                        id: ownArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.launch(modelData.path)
                    }
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.bottom
            anchors.verticalCenterOffset: -56
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
