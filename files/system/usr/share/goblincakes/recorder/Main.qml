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
    property string tab: "videos" // videos | settings | wowstats | cs2stats
    property var selected: null
    // The ✕ (19 Oct, the user's wish): hide in the system tray or close – asks until remembered
    property bool closeAsk: false
    property bool closeRemember: false
    onClosing: (close) => {
        const act = hasTray ? (win.cfg.closeAction || "ask") : "quit";
        if (act === "ask") {
            close.accepted = false;
            win.closeRemember = false;
            win.closeAsk = true;
        } else if (act === "quit") {
            Qt.quit();
        } // tray: the window just hides, the program keeps running in the system tray
    }
    function closeAs(act) {
        if (win.closeRemember)
            win.set("closeAction", act);
        win.closeAsk = false;
        if (act === "quit")
            Qt.quit();
        else
            win.hide();
    }
    property bool testAsked: false  // "Testa inspelningen" pressed – open the test video when it is saved

    // To YouTube: cut, ready-made title and description, then YouTube Studio in the browser
    property bool ytOpen: false
    property real ytStart: 0
    property real ytEnd: 0          // 0 = the end of the video
    property string ytTitle: ""
    property string ytDesc: ""
    property bool ytBusy: false
    property string ytFile: ""
    property string ytError: ""
    // Straight up with YouTube's API when signed in (Inställningar → YouTube)
    readonly property var yt: JSON.parse(backend.youtubeState)
    property bool ytLoginBusy: false
    property bool ytUploading: false
    property real ytSent: 0
    property real ytTotal: 0
    property string ytUrl: ""
    property string ytPrivacy: "unlisted"
    function ytRefresh() {
        if (!selected)
            return;
        const t = JSON.parse(backend.youtubeText(selected.path, ytStart, ytEnd > 0 ? ytEnd : selected.duration));
        ytTitle = t.title;
        ytDesc = t.description;
        ytFile = "";
        ytError = "";
        if (!ytUploading)
            ytUrl = "";
    }
    function ytShow() {
        ytStart = 0;
        ytEnd = 0;
        ytOpen = true;
        ytRefresh();
    }
    property string note: ""
    property bool wclBusy: false
    property string expanded: "" // the video card that shows its players from Warcraft Logs
    property string statsBusy: ""
    property string demoBusy: "" // the CS2 match whose demo is being read
    property int overlayPick: -1 // the chosen box in "Dölj delar av bilden"
    // The explanation shown while the mouse rests on a choice (12 Oct: smaller buttons, the
    // explanations as hover instead of text under them)
    property string tipText: ""
    property Item tipItem: null
    function showTip(item, text) { tipItem = item; tipText = text || ""; }
    function hideTip(item) { if (tipItem === item) tipText = ""; }
    onTabChanged: if (tab === "settings") backend.refreshPreview()

    function set(key, value) { backend.setConfig(key, JSON.stringify(value)); }
    // A CS2 match's clips are under its card, not in the list – look there too
    function findVideo(path) {
        for (const v of videos) {
            if (v.path === path)
                return v;
            for (const c of v.clips || [])
                if (c.path === path)
                    return c;
        }
        return null;
    }
    // what to play for a card: a match whose video went after the clips → its first clip
    function playable(v) { return v && v.videoRemoved && v.clips && v.clips.length ? v.clips[0] : v; }
    readonly property var gameIcons: JSON.parse(backend.gameIcons)

    // CS2 step 2: the demo (22 Oct)
    function demoNote(v) {
        return v.demo === "waiting" ? (demoBusy === v.path ? " · läser demon …" : " · väntar på demo")
             : v.demo === "done" ? " · demo läst" : "";
    }
    function demoLeft(v) {
        const left = v.started + 3 * 86400 - Date.now() / 1000;
        return left > 86400 ? Math.round(left / 86400) + " dagar" : Math.max(1, Math.round(left / 3600)) + " h";
    }
    function num(x) { return x === undefined || x === null ? "–" : String(x).replace(".", ","); }
    // the matches with a read demo up to this one, the last 10 – how it goes over time
    function cs2Trend(v) {
        return videos.filter(o => o.kind === "cs2" && o.demoStats && o.started <= v.started)
                     .sort((a, b) => a.started - b.started).slice(-10);
    }

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
        if (v.kind === "test")
            return "TEST · " + String(v.difficulty || "").toUpperCase();  // the quality it was made with
        const r = ({ kill: "KILL", wipe: "WIPE", timed: "I TID", depleted: "FÖR SENT", win: "VINST", loss: "FÖRLUST", done: "KLAR", tie: "OAVGJORT" })[v.result] || "AVBRUTEN";
        return v.kind === "cs2" && v.score ? r + " " + v.score : r;
    }

    function resultColor(v) {
        return v.result === "kill" || v.result === "timed" || v.result === "win" ? "#3FB950"
             : v.result === "wipe" || v.result === "depleted" || v.result === "loss" ? "#E5534B" : "#8B98AD";
    }

    // WoW's class colours (as in goblin graph) by Warcraft Logs' class name
    readonly property var classColors: ({
        DeathKnight: "#C41E3A", DemonHunter: "#A330C9", Druid: "#FF7C0A", Evoker: "#33937F",
        Hunter: "#AAD372", Mage: "#3FC7EB", Monk: "#00FF98", Paladin: "#F48CBA", Priest: "#FFFFFF",
        Rogue: "#FFF468", Shaman: "#0070DD", Warlock: "#8788EE", Warrior: "#C69B6D" })

    // Warcraft Logs' parse colours
    function parseColor(p) {
        return p >= 100 ? "#E5CC80" : p >= 99 ? "#E268A8" : p >= 95 ? "#FF8000" : p >= 75 ? "#A335EE"
             : p >= 50 ? "#0070FF" : p >= 25 ? "#1EFF00" : "#8B98AD";
    }

    function amount(n) {
        return n >= 1e6 ? (n / 1e6).toFixed(2).replace(".", ",") + "M"
             : n >= 1000 ? (n / 1000).toFixed(1).replace(".", ",") + "k" : String(n);
    }

    function roleGroups(players) {
        const out = [];
        for (const p of players) {
            if (!out.length || out[out.length - 1].role !== p.role)
                out.push({ role: p.role, players: [] });
            out[out.length - 1].players.push(p);
        }
        return out;
    }

    function toggleStats(v) {
        if (expanded === v.path) {
            expanded = "";
            return;
        }
        expanded = v.path;
        backend.wclStats(v.path);
    }

    function videoTitle(v) {
        return v.kind === "mplus" ? "+" + v.level + " " + v.name : v.kind === "cs2" ? "CS2 · " + v.name
             : v.kind === "cs2clip" ? "CS2 · " + v.name + " · " + v.clip + (v.round ? " runda " + v.round : "") : v.name;
    }

    // One sentence about what is going on right now
    function stateLine() {
        if (!st.service)
            return "Inspelningstjänsten kör inte.";
        if (st.obs === "missing")
            return "OBS behövs – välj GoblinRecorder i GOBLINCAKES Config → Program → Spel.";
        if (st.obs === "connected" && st.screen === false)
            return "Välj vilken skärm OBS ska spela in – tryck Välj skärm och välj skärmen där WoW är.";
        if (st.current && st.current.kind === "test")
            return "Testinspelning (" + st.current.difficulty + ") – "
                + Math.max(0, Math.ceil(st.stopAt - Date.now() / 1000)) + " s kvar …";
        if (st.testWaiting)
            return "Testinspelningen väntar på OBS …";
        if (st.current)
            return "Spelar in " + (st.current.kind === "mplus" ? "nyckeln"
                : st.current.kind === "arena" ? st.current.difficulty + " i " + st.current.name
                : st.current.kind === "cs2" ? "CS2-matchen på " + st.current.name + (st.current.score ? " (" + st.current.score + ")" : "")
                : st.current.name + " (" + st.current.difficulty + ")") + " …";
        if (st.waiting)
            return "Sparar filmen …";
        if (st.cs2 && win.cfg.cs2 && st.cs2Gsi !== "on")
            return "CS2 körs men är inte inkopplat – tryck Koppla in CS2 under Inställningar och starta om CS2.";
        if (st.cs2 && win.cfg.cs2 && st.cs2Error)
            return "CS2: " + st.cs2Error;
        if (st.cs2 && win.cfg.cs2 && Date.now() / 1000 - (st.cs2Last || 0) > 30)
            return "CS2 körs men skickar inget – starta om CS2 (filen läses när spelet startar).";
        if (st.cs2 && win.cfg.cs2)
            return st.cs2Map ? "CS2 på " + st.cs2Map + " – matchen spelas in när uppvärmningen är slut."
                             : "CS2 körs – matchen spelas in när uppvärmningen är slut.";
        if (st.wow && !st.logging)
            return "WoW kör men skriver ingen stridslogg – skriv /combatlog i chatten.";
        if (st.wow && st.zone)
            return "I " + st.zone + " – väntar på nästa boss.";
        if (st.wow)
            return "WoW kör – inspelningen startar i raid, Mythic+ och arena.";
        return "Väntar på WoW eller CS2. Raidbossar, Mythic+-nycklar, arenamatcher och CS2-matcher spelas in av sig själva.";
    }

    Connections {
        target: backend
        function onMessage(text) {
            win.note = text;
            noteTimer.restart();
        }
        function onWclBusy(busy) { win.wclBusy = busy; }
        function onYoutubeLoginBusy(busy) { win.ytLoginBusy = busy; }
        function onYoutubeProgress(sent, total) {
            win.ytSent = sent;
            win.ytTotal = total;
        }
        function onYoutubeUploaded(json) {
            const r = JSON.parse(json);
            win.ytUploading = false;
            win.ytUrl = r.url || "";
            win.ytError = r.error || "";
            if (r.url)
                backend.copyText(r.url);
        }
        function onStatsBusy(path) { win.statsBusy = path; }
        function onDemoBusy(path) { win.demoBusy = path; }
        function onYoutubeDone(json) {
            const r = JSON.parse(json);
            win.ytBusy = false;
            win.ytFile = r.file || "";
            win.ytError = r.error || "";
            if (r.file) {
                backend.copyText(win.ytTitle);
                backend.showFile(r.file);
                backend.openYoutube();
            }
        }
        function onVideosChanged() {
            if (win.selected)
                win.selected = win.findVideo(win.selected.path);
            if (!win.selected && win.videos.length)
                win.selected = win.playable(win.videos[0]);
            // the test video just saved: straight to it
            if (win.testAsked && !win.st.current && win.videos.length && win.videos[0].kind === "test") {
                win.testAsked = false;
                win.selected = win.videos[0];
                win.tab = "videos";
            }
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
        property alias echoMode: input.echoMode
        property alias validator: input.validator
        signal edited()
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
            font.family: "IBM Plex Mono"
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            onTextEdited: parent.edited()
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

    // A setting with a switch on the right (name, explanation, key in recorder.json)
    component SettingRow: Item {
        id: row
        property string name
        property string sub
        property string key
        width: Math.min(820, settingsCol.width)
        height: Math.max(54, rowText.implicitHeight + 12)
        Column {
            id: rowText
            anchors.verticalCenter: parent.verticalCenter
            width: row.width - 80
            spacing: 3
            Text {
                text: row.name
                color: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.weight: Font.Medium
                font.pixelSize: 15
            }
            Note { width: parent.width; text: row.sub }
        }
        ToggleSwitch {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            on: !!win.cfg[row.key]
            onToggled: win.set(row.key, !win.cfg[row.key])
        }
    }

    component FlatButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        property bool danger: false
        property bool enabledState: true
        signal clicked()

        width: Math.max(96, label.implicitWidth + 32)
        height: 34
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
            font.pixelSize: 13
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

    // CS2 step 2: what the demo said about your match – the numbers, each round, the guns,
    // utility and money, and the last 10 matches (ADR) to see how it goes over time
    component DemoStats: Column {
        id: ds
        property var v
        readonly property var s: v && v.demoStats ? v.demoStats : ({})
        readonly property var trend: v ? win.cs2Trend(v) : []
        readonly property real maxAdr: Math.max(1, ...trend.map(o => o.demoStats.adr))
        readonly property var cols: [width - 4 * 56, 56, 56, 56, 56]
        spacing: 8
        topPadding: 6
        bottomPadding: 8
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: [["K–D–A", ds.s.kills + "–" + ds.s.deaths + "–" + ds.s.assists, "Kills, dödsfall och assist"],
                        ["K/D", win.num(ds.s.kd), "Kills per dödsfall"],
                        ["ADR", win.num(ds.s.adr), "Skada per runda (bara skada som tog liv, inte överskott)"],
                        ["KAST", ds.s.kast + " %", "Rundor där du fick en kill, en assist, överlevde eller blev hämnad (trade)"],
                        ["HS", ds.s.hs + " %", "Kills med huvudskott"],
                        ["ENTRY", ds.s.entryWon + "–" + ds.s.entryLost, "Rundans första kill: vunna–förlorade"],
                        ["TRADE", String(ds.s.trades), "Du dödade den som just dödat en lagkamrat (inom 5 s)"],
                        ["CLUTCH", ds.s.clutchWon + "/" + ds.s.clutches, "1vX: vunna av alla gånger du var ensam kvar"],
                        ["TTD", ds.s.ttd === undefined || ds.s.ttd === null ? "–" : ds.s.ttd + " ms",
                         "Time to damage: från att du kunde se fienden till din första skada på honom (median av "
                         + (ds.s.ttdCount || 0) + " gånger). Ungefärligt: väggar och smokes räknas, inte flashar."],
                        ["SIKTE", ds.s.cp === undefined || ds.s.cp === null ? "–" : win.num(ds.s.cp) + "°",
                         "Crosshair placement: hur långt från fiendens huvud siktet var när du kunde se honom (median av "
                         + (ds.s.cpCount || 0) + " gånger) – lägre är bättre. Ungefärligt: väggar och smokes räknas, inte flashar."]]
                Rectangle {
                    required property var modelData
                    width: 84
                    height: 46
                    color: "#0B1018"
                    border.width: 1
                    border.color: "#1E2A40"
                    HoverTip { tip: parent.modelData[2] }
                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData[1]
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 15
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData[0]
                            color: "#8B98AD"
                            font.family: "Chakra Petch"
                            font.weight: Font.DemiBold
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }
                    }
                }
            }
        }
        Text {
            text: "RUNDOR · siffran = dina kills, guldram = vunnen clutch"
            color: "#8B98AD"
            font.family: "Chakra Petch"
            font.weight: Font.DemiBold
            font.pixelSize: 11
            font.letterSpacing: 1
        }
        Flow {
            width: parent.width
            spacing: 3
            Repeater {
                model: ds.v && ds.v.demoRounds ? ds.v.demoRounds : []
                Rectangle {
                    required property var modelData
                    width: 22
                    height: 22
                    color: modelData.won ? "#16351F" : "#3A1418"
                    border.width: modelData.clutch > 0 ? 2 : 1
                    border.color: modelData.clutch > 0 ? "#E5CC80" : modelData.won ? "#2E6B3E" : "#6B2A2E"
                    HoverTip {
                        tip: "Runda " + parent.modelData.r + (parent.modelData.won ? " vunnen" : " förlorad") + " · "
                             + parent.modelData.k + " kills · " + parent.modelData.dmg + " skada"
                             + (parent.modelData.died ? "" : " · överlevde")
                             + (parent.modelData.equip !== null ? " · utrustning $" + parent.modelData.equip : "")
                             + (parent.modelData.clutch ? " · clutch 1v" + Math.abs(parent.modelData.clutch)
                                                          + (parent.modelData.clutch > 0 ? " vunnen" : " förlorad") : "")
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.k || ""
                        color: parent.modelData.k >= 2 ? "#E5CC80" : "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.DemiBold
                        font.pixelSize: 11
                    }
                }
            }
        }
        Row { // the guns
            visible: (ds.s.weapons || []).length > 0
            Repeater {
                model: ["VAPEN", "KILLS", "HS", "TRÄFF", "SKOTT"]
                Text {
                    required property string modelData
                    required property int index
                    width: ds.cols[index]
                    horizontalAlignment: index ? Text.AlignRight : Text.AlignLeft
                    text: modelData
                    color: "#8B98AD"
                    font.family: "Chakra Petch"
                    font.weight: Font.DemiBold
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
            }
        }
        Repeater {
            model: ds.s.weapons || []
            Row {
                id: wrow
                required property var modelData
                Repeater {
                    model: [wrow.modelData.name, wrow.modelData.kills, wrow.modelData.hs,
                            wrow.modelData.acc === null ? "–" : wrow.modelData.acc + " %", wrow.modelData.shots]
                    Text {
                        required property var modelData
                        required property int index
                        width: ds.cols[index]
                        horizontalAlignment: index ? Text.AlignRight : Text.AlignLeft
                        text: modelData
                        color: index ? "#8B98AD" : "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            readonly property var t: ds.s.thrown || {}
            text: "Granater: " + (t.flash || 0) + " flash (" + (ds.s.flashed || 0) + " fiender bländade"
                  + (ds.s.teamFlashed ? ", " + ds.s.teamFlashed + " lagkamrater" : "") + ", " + (ds.s.flashAssists || 0) + " flash-assist) · "
                  + (t.smoke || 0) + " smoke · " + (t.he || 0) + " HE (" + (ds.s.heDmg || 0) + " skada) · "
                  + (t.molotov || 0) + " molotov (" + (ds.s.fireDmg || 0) + " skada)"
                  + ((ds.s.wallbangs || ds.s.smokeKills || ds.s.noscopes)
                     ? "\nKills genom vägg " + (ds.s.wallbangs || 0) + " · genom rök " + (ds.s.smokeKills || 0)
                       + " · noscope " + (ds.s.noscopes || 0) : "")
            color: "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: 12
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            readonly property var b: ds.s.buys || {}
            function part(name, x) { return x && x.rounds ? name + " " + x.rounds + " (" + x.won + " vunna, " + x.kills + " kills)" : ""; }
            text: "Ekonomi: snitt $" + (ds.s.avgEquip || 0) + " · "
                  + [part("fullköp", b.full), part("halvköp", b.force), part("eco", b.eco)].filter(x => x).join(" · ")
            color: "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: 12
        }
        Column { // over time: ADR in the last matches with a read demo, this one in the accent colour
            visible: ds.trend.length > 1
            spacing: 4
            Text {
                text: "SENASTE " + ds.trend.length + " MATCHERNA · ADR"
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: 11
                font.letterSpacing: 1
            }
            Row {
                height: 40
                spacing: 3
                Repeater {
                    model: ds.trend
                    Rectangle {
                        required property var modelData
                        anchors.bottom: parent.bottom
                        width: 18
                        height: 4 + 36 * modelData.demoStats.adr / ds.maxAdr
                        color: modelData.path === ds.v.path ? accent.color : "#2A3852"
                        HoverTip {
                            tip: parent.modelData.name + " " + (parent.modelData.score || "") + " · ADR " + win.num(parent.modelData.demoStats.adr)
                                 + " · K/D " + win.num(parent.modelData.demoStats.kd) + " · HS " + parent.modelData.demoStats.hs + " %"
                                 + (parent.modelData.demoStats.ttd ? " · TTD " + parent.modelData.demoStats.ttd + " ms" : "")
                                 + (parent.modelData.demoStats.cp ? " · sikte " + win.num(parent.modelData.demoStats.cp) + "°" : "")
                        }
                    }
                }
            }
            Text {
                width: ds.width
                wrapMode: Text.WordWrap
                readonly property var avg: k => {
                    const xs = ds.trend.map(o => o.demoStats[k]).filter(x => x !== undefined && x !== null);
                    return xs.length ? xs.reduce((a, x) => a + x, 0) / xs.length : null;
                }
                text: "Snitt: ADR " + win.num(avg("adr").toFixed(1)) + " · K/D " + win.num(avg("kd").toFixed(2))
                      + " · HS " + Math.round(avg("hs")) + " % · KAST " + Math.round(avg("kast")) + " %"
                      + (avg("ttd") !== null ? " · TTD " + Math.round(avg("ttd")) + " ms" : "")
                      + (avg("cp") !== null ? " · sikte " + win.num(avg("cp").toFixed(1)) + "°" : "")
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 12
            }
        }
        FlatButton { // Goblin AI reads the numbers itself (its ```cs2 tool) and coaches
            text: "Fråga " + backend.aiName + " vad jag ska träna på"
            onClicked: backend.askAi("Hur gick min CS2-match på " + ds.v.name + " " + (ds.v.score || "") + " ("
                                     + win.when(ds.v.started) + ")? Jämför med mitt snitt för de senaste 10 matcherna "
                                     + "och säg vad jag ska arbeta på.")
            HoverTip { tip: "Öppnar Goblin AI med frågan – den läser matchen och ditt snitt själv. Du kan också fråga i chatten när som helst, t.ex. \"snitt senaste 20 CS2-matcherna\"." }
        }
    }

    // Hover explanation for any item: HoverTip { tip: "…" } inside it
    component HoverTip: HoverHandler {
        property string tip
        onHoveredChanged: hovered && tip ? win.showTip(parent, tip) : win.hideTip(parent)
    }

    // A name with a switch on the right, explanation on hover (the "Spelas in" panel)
    component PanelSwitch: Item {
        id: ps
        property string name
        property string key
        property string tip
        width: parent.width
        height: 30
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ps.name
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.weight: Font.Medium
            font.pixelSize: 15
        }
        ToggleSwitch {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            on: !!win.cfg[ps.key]
            onToggled: win.set(ps.key, !win.cfg[ps.key])
        }
        HoverTip { tip: ps.tip }
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

    // A choice among a few (fps, codec, space): small square with a blue edge when chosen;
    // "sub" is the explanation, shown on hover
    component Choice: Rectangle {
        id: ch
        property string text
        property string sub
        property bool chosen
        property bool enabledState: true
        signal picked()
        width: Math.max(88, chText.implicitWidth + 32)
        height: 34
        color: chosen ? "#12203A" : (chArea.containsMouse && enabledState ? "#0E1420" : "transparent")
        border.width: chosen ? 2 : 1
        border.color: chosen ? accent.color : "#2A3852"
        opacity: enabledState ? 1 : 0.35
        Text {
            id: chText
            anchors.centerIn: parent
            text: ch.text
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.weight: Font.Medium
            font.pixelSize: 14
        }
        MouseArea {
            id: chArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: ch.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (ch.enabledState) ch.picked()
            onContainsMouseChanged: containsMouse && ch.sub ? win.showTip(ch, ch.sub) : win.hideTip(ch)
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
                    visible: !!win.cfg.cs2
                    label: "CS2"
                    value: !win.st.cs2 ? "av" : Date.now() / 1000 - (win.st.cs2Last || 0) < 30 ? "kör" : "skickar inget"
                    tone: !win.st.cs2 ? "#2A3852" : Date.now() / 1000 - (win.st.cs2Last || 0) < 30 ? "#3FB950" : "#D29922"
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
                    visible: win.st.obs === "connected" && win.st.screen === false
                    primary: true
                    text: "Välj skärm"
                    onClicked: backend.pickScreen()
                }
                FlatButton {
                    visible: win.st.audioPlugin === false && win.st.obs !== "missing"
                    text: "Hämta ljudtillägget"
                    onClicked: backend.installAudioPlugin()
                }
                Row { // left of the OBS button (12 Oct, the user's wish)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    rightPadding: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Starta OBS när spelet startar"
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                    ToggleSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        on: !!win.cfg.autoStartObs
                        onToggled: win.set("autoStartObs", !win.cfg.autoStartObs)
                    }
                    HoverTip { tip: "OBS startas dolt i systemfältet så fort WoW eller CS2 startar – redo till första pullen eller matchen." }
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

        // WoW Stats and CS2 Stats (22 Oct, the user's wish: at the top of the window)
        Row {
            anchors { right: parent.right; rightMargin: 40; bottom: parent.bottom; bottomMargin: 5 }
            spacing: 8
            Repeater {
                model: [{ id: "wowstats", t: "WoW Stats", sub: "Dina parses per boss och dungeon, kills, item level – från dina inspelningar" },
                        { id: "cs2stats", t: "CS2 Stats", sub: "Ditt snitt, utveckling, kartor och vapen – från dina lästa demos" }]
                Choice {
                    required property var modelData
                    text: modelData.t
                    sub: modelData.sub
                    chosen: win.tab === modelData.id
                    onPicked: win.tab = win.tab === modelData.id ? "videos" : modelData.id
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
    // What gets recorded – right side of the settings tab (12 Oct, the user's wish)
    Rectangle {
        id: recordPanel
        visible: win.tab === "settings"
        anchors { right: parent.right; top: header.bottom; bottom: parent.bottom }
        width: 268
        color: "#0B1018"
        Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 1; color: "#1E2A40" }

        Flickable {
            id: recordFlick
            FastWheel { flick: recordFlick }
            anchors { fill: parent; leftMargin: 1 }
            contentHeight: recordColumn.height + 48
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        Column {
            id: recordColumn
            x: 23
            y: 24
            width: recordPanel.width - 48
            spacing: 12

            SectionTitle { text: "SPELAS IN" }

            PanelSwitch { name: "Raid"; key: "raid"; tip: "Varje bossförsök blir en egen film – kill eller wipe – för de svårighetsgrader du väljer." }
            Flow {
                width: parent.width
                spacing: 6
                opacity: win.cfg.raid ? 1 : 0.35
                Repeater {
                    model: [{ "id": "lfr", "name": "LFR" }, { "id": "normal", "name": "Normal" },
                            { "id": "heroic", "name": "Heroic" }, { "id": "mythic", "name": "Mythic" }]
                    Choice {
                        required property var modelData
                        readonly property var levels: win.cfg.raidLevels || ["lfr", "normal", "heroic", "mythic"]
                        width: (recordPanel.width - 48 - 6) / 2
                        enabledState: !!win.cfg.raid
                        text: (chosen ? "✓  " : "") + modelData.name
                        chosen: levels.indexOf(modelData.id) >= 0
                        onPicked: win.set("raidLevels", chosen ? levels.filter(l => l !== modelData.id) : levels.concat([modelData.id]))
                    }
                }
            }

            Item { width: 1; height: 6 }
            PanelSwitch { name: "Mythic+"; key: "mplus"; tip: "Hela nyckeln, från att den sätts i tills den är klar." }
            Row {
                spacing: 10
                opacity: win.cfg.mplus ? 1 : 0.35
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Från nivå  +"
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 14
                }
                FlatField {
                    id: mplusMin
                    width: 64
                    height: 32
                    enabled: !!win.cfg.mplus
                    text: String(win.cfg.mplusMin || 2)
                    validator: IntValidator { bottom: 2; top: 99 } // +2 is the lowest key
                    onEdited: {
                        const n = parseInt(text);
                        if (n >= 2 && n !== win.cfg.mplusMin)
                            win.set("mplusMin", n);
                    }
                    HoverTip { tip: "Skriver du 10 spelas bara +10 och högre in. 2 = alla nycklar." }
                }
            }

            Item { width: 1; height: 6 }
            PanelSwitch { name: "Arena"; key: "arena"; tip: "Hela matchen – 2v2, 3v3, Solo Shuffle och Skirmish. Vinst eller förlust står på filmen." }

            Item { width: 1; height: 6 }
            PanelSwitch {
                name: "Behåll wipes"
                key: "keepWipes"
                tip: "Av: bara kills, nycklar i tid och vunna arenor blir kvar när du stänger WoW, och under raiden sparas bara "
                     + "de två senaste wipes per boss. CS2-matcher blir alltid kvar. Spara för alltid skyddar en film."
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "COUNTER-STRIKE 2" }
            PanelSwitch {
                name: "CS2-matcher"
                key: "cs2"
                tip: "Varje match (alla lägen), från att uppvärmningen är slut till sista rundan. Dina kills (2K–ACE), dödsfall, "
                     + "rundor och bomben blir markeringar i filmen. Efter matchen blir varje 2K–ACE ett eget klipp, plus ett med alla kills. "
                     + "Competitive/Premier/Wingman: när du laddat ner demon (Watch → Your Matches) läses den – dina siffror, "
                     + "vapen och vunna clutchar som klipp."
            }
            PanelSwitch {
                name: "Behåll hela matchen"
                key: "cs2KeepMatch"
                tip: "Av: hela matchen (7–10 GB på Bäst) tas bort när klippen är klara och demon är läst (högst 3 dagar) – klippen och kortet blir kvar. "
                     + "Spara för alltid på en match skyddar den."
            }
            Note {
                width: parent.width
                visible: !!win.cfg.cs2
                text: win.st.cs2Gsi === "nogame" ? "Hittar inte CS2 i Steam-biblioteken."
                    : win.st.cs2Gsi === "on" ? "✓ Inkopplat. CS2 skickar matchen till GoblinRecorder."
                    : win.st.cs2Gsi === "old" ? "Filen i spelmappen är gammal – koppla in igen."
                    : "Inte inkopplat. Knappen lägger Valves fil för spelläget (gamestate_integration) i CS2:s cfg-mapp."
            }
            Row {
                visible: !!win.cfg.cs2 && win.st.cs2Gsi !== "nogame"
                spacing: 8
                FlatButton {
                    primary: win.st.cs2Gsi !== "on"
                    text: win.st.cs2Gsi === "on" ? "Koppla in igen" : "Koppla in CS2"
                    onClicked: backend.cs2Connect()
                    HoverTip { tip: "CS2 läser filen när spelet startar – starta om CS2 om det redan är igång." }
                }
                FlatButton {
                    visible: win.st.cs2Gsi === "on" || win.st.cs2Gsi === "old"
                    text: "Koppla bort"
                    onClicked: backend.cs2Disconnect()
                    HoverTip { tip: "Tar bort GoblinRecorders fil ur CS2:s cfg-mapp." }
                }
            }
        }
        }
        FlatScrollBar { flick: recordFlick }
    }


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
                      + "en Mythic+-nyckel, en arenamatch och en CS2-match en film från start till slut. De hamnar här."
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
                readonly property bool active: win.selected && (win.selected.path === modelData.path
                                                                || win.selected.parent === modelData.file)
                readonly property var clips: modelData.clips || []
                // a CS2 match folds out: its clips and its demo (waiting, or its numbers)
                readonly property bool cs2match: modelData.kind === "cs2" && (clips.length > 0 || !!modelData.demo)
                readonly property bool open: win.expanded === modelData.path && (!!modelData.wcl || cs2match)
                readonly property var stats: modelData.wclStats || null
                width: list.width - 16
                readonly property int headHeight: modelData.avgIlvl ? 100 : 84 // a 4th line: avg.ilvl
                height: headHeight + (open ? (cs2match ? clipsCol.height : statsCol.height) + 12 : 0)
                color: active ? "#12203A" : cardArea.containsMouse ? "#0E1420" : "transparent"
                border.width: active ? 2 : 1
                border.color: active ? accent.color : "#1E2A40"

                Item {
                    id: head
                    width: parent.width
                    height: card.headHeight
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
                Image { // the game, bottom right (22 Oct, the user's wish)
                    readonly property string game: card.modelData.kind === "cs2" ? "cs2" : card.modelData.kind === "test" ? "" : "wow"
                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: 8; bottomMargin: 8 }
                    width: 22
                    height: 22
                    source: game ? (win.gameIcons[game] || "") : ""
                    sourceSize: Qt.size(44, 44)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                }
                Column {
                    anchors { left: thumbBox.right; leftMargin: 12; right: parent.right; rightMargin: 36; verticalCenter: parent.verticalCenter } // the game's icon to the right
                    spacing: 4
                    Row {
                        spacing: 8
                        width: parent.width
                        Text {
                            width: Math.min(implicitWidth, parent.width - tag.width - 8)
                            text: win.videoTitle(card.modelData)
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
                        width: parent.width
                        elide: Text.ElideRight
                        text: card.clips.length
                              ? win.clock(card.modelData.fight) + " match" + win.demoNote(card.modelData) + " · " + card.clips.length + " klipp "
                                + (card.open ? "▴" : "▾") + " · " + win.size(card.modelData.size + card.clips.reduce((a, c) => a + c.size, 0))
                              : win.clock(card.modelData.fight) + (card.modelData.kind === "cs2" ? " match" + win.demoNote(card.modelData) + " · " : " strid · ") + win.size(card.modelData.size)
                              + (card.modelData.keep ? " · sparad" : "") + (card.modelData.wcl ? (card.open ? " · WCL ▴" : " · WCL ▾") : "")
                              + (card.cs2match ? (card.open ? " ▴" : " ▾") : "")
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                    Text { // the raid's average item level in the fight (Warcraft Logs), and yours
                        visible: !!card.modelData.avgIlvl
                        text: "avg.ilvl (" + win.num((card.modelData.avgIlvl || 0).toFixed(1)) + ")"
                              + (card.modelData.ilvl ? " · din " + card.modelData.ilvl : "")
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                }
                }
                MouseArea {
                    id: cardArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        win.selected = win.playable(card.modelData);
                        if (card.cs2match) // a CS2 match: its clips and demo fold out
                            win.expanded = win.expanded === card.modelData.path ? "" : card.modelData.path;
                        else if (card.modelData.wcl)
                            win.toggleStats(card.modelData); // the players from Warcraft Logs
                    }
                }

                // A CS2 match: the demo (waiting for it, or its numbers), then the clips – all
                // kills first, then 2K–ACE and clutches in the order they came
                Column {
                    id: clipsCol
                    visible: card.open && card.cs2match
                    anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: 12; rightMargin: 12 }
                    spacing: 2
                    Rectangle { width: parent.width; height: 1; color: "#1E2A40" }
                    Column {
                        visible: card.modelData.demo === "waiting"
                        width: parent.width
                        topPadding: 6
                        bottomPadding: 8
                        spacing: 8
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: win.demoBusy === card.modelData.path ? "Läser demon …"
                                  : "Hela matchen sparas tills demon är läst (" + win.demoLeft(card.modelData) + " kvar). "
                                    + "Ladda ner den i CS2: Watch → Your Matches – GoblinRecorder hittar den själv."
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 12
                        }
                        Row {
                            spacing: 8
                            FlatButton {
                                text: "Välj demo …"
                                enabledState: !win.demoBusy
                                onClicked: backend.cs2PickDemo(card.modelData.path)
                                HoverTip { tip: "En demo från FACEIT eller en egen (record i konsolen) – den läses för den här matchen." }
                            }
                            FlatButton {
                                text: "Klar utan demo"
                                enabledState: !win.demoBusy
                                onClicked: backend.cs2NoDemo(card.modelData.path)
                                HoverTip { tip: "Hela matchen tas bort nu – klippen och kortet blir kvar." }
                            }
                        }
                    }
                    DemoStats {
                        visible: !!card.modelData.demoStats
                        width: parent.width
                        v: card.modelData
                    }
                    Repeater {
                        model: card.clips
                        Rectangle {
                            id: clipRow
                            required property var modelData
                            readonly property bool chosen: win.selected && win.selected.path === modelData.path
                            width: clipsCol.width
                            height: 34
                            color: chosen ? "#1A2C4E" : clipArea.containsMouse ? "#0E1420" : "transparent"
                            Rectangle { visible: clipRow.chosen; width: 3; height: parent.height; color: accent.color }
                            Text {
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                text: (clipRow.modelData.clip === "Alla kills"
                                       ? "▶ Alla kills (" + clipRow.modelData.markers.length + ")"
                                       : clipRow.modelData.clip + "  ·  runda " + clipRow.modelData.round)
                                      + (clipRow.modelData.keep ? "  ·  sparad" : "")
                                color: clipRow.modelData.clip === "Alla kills" || clipRow.modelData.clip === "Kill" ? "#E6ECF5" : "#E5CC80"
                                font.family: "IBM Plex Sans"
                                font.weight: Font.DemiBold
                                font.pixelSize: 13
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: win.clock(clipRow.modelData.duration) + " · " + win.size(clipRow.modelData.size)
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: clipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.selected = clipRow.modelData
                            }
                        }
                    }
                }

                // The players: parse, DPS, HPS and deaths from Warcraft Logs
                Column {
                    id: statsCol
                    visible: card.open && !card.cs2match
                    anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: 12; rightMargin: 12 }
                    spacing: 4
                    readonly property var cols: [width - 44 - 44 - 58 - 58 - 38, 44, 44, 58, 58, 38]
                    Rectangle { width: parent.width; height: 1; color: "#1E2A40" }
                    Text {
                        visible: !card.stats || !card.stats.players
                        text: win.statsBusy === card.modelData.path ? "Hämtar från Warcraft Logs …" : "Inga siffror från Warcraft Logs."
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                        topPadding: 4
                        bottomPadding: 4
                    }
                    Row { // headings
                        visible: !!(card.stats && card.stats.players)
                        topPadding: 4
                        Repeater {
                            model: ["SPELARE", "PARSE", "ILVL", "DPS", "HPS", "DÖD"]
                            Text {
                                required property string modelData
                                required property int index
                                width: statsCol.cols[index]
                                horizontalAlignment: index ? Text.AlignRight : Text.AlignLeft
                                text: modelData
                                color: "#8B98AD"
                                font.family: "Chakra Petch"
                                font.weight: Font.DemiBold
                                font.pixelSize: 11
                                font.letterSpacing: 1
                            }
                        }
                    }
                    // One box per role (tanks, healers, dps) with a heading that says what the parse compares
                    Repeater {
                        model: card.stats && card.stats.players ? win.roleGroups(card.stats.players) : []
                        Rectangle {
                            id: group
                            required property var modelData
                            width: statsCol.width
                            height: groupCol.height + 12
                            color: "#0B1018"
                            border.width: 1
                            border.color: "#1E2A40"
                            Column {
                                id: groupCol
                                x: 8
                                y: 6
                                width: parent.width - 16
                                spacing: 6
                                Text {
                                    text: ({ tanks: "TANKS · parse på DPS", healers: "HEALERS · parse på HPS",
                                             dps: "DPS · parse på DPS" })[group.modelData.role] || ""
                                    color: "#8B98AD"
                                    font.family: "Chakra Petch"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 11
                                    font.letterSpacing: 1
                                }
                                Repeater {
                                    model: group.modelData.players
                                    Item {
                                        id: prow
                                        required property var modelData
                                        required property int index
                                        readonly property bool me: !!card.modelData.player
                                            && card.modelData.player.split("-")[0] === modelData.name
                                        readonly property int pad: index > 0 ? 7 : 0
                                        width: groupCol.width
                                        height: who.height + pad
                                        Rectangle { // a line between the players of a role
                                            visible: prow.index > 0
                                            width: parent.width
                                            height: 1
                                            color: "#1E2A40"
                                        }
                                        Column { // the name, the spec under it
                                            id: who
                                            y: prow.pad
                                            width: statsCol.cols[0] - 8
                                            Text {
                                                width: parent.width
                                                text: prow.modelData.name
                                                color: win.classColors[prow.modelData["class"]] || "#E6ECF5"
                                                font.family: "IBM Plex Sans"
                                                font.weight: prow.me ? Font.Bold : Font.DemiBold
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                id: specLine
                                                width: parent.width
                                                text: prow.modelData.spec
                                                color: "#8B98AD"
                                                font.family: "IBM Plex Sans"
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }
                                        }
                                        Row { // the numbers in their columns, on the line of the spec
                                            anchors.right: parent.right
                                            y: who.y + specLine.y + specLine.baselineOffset - dpsText.baselineOffset
                                            Repeater { // the parse and the item level parse
                                                model: [prow.modelData.parse, prow.modelData.ilvlParse]
                                                Text {
                                                    required property var modelData
                                                    required property int index
                                                    readonly property bool none: modelData === null || modelData === undefined
                                                    width: statsCol.cols[1 + index]
                                                    horizontalAlignment: Text.AlignRight
                                                    text: none ? "–" : modelData
                                                    color: none ? "#8B98AD" : win.parseColor(modelData)
                                                    font.family: "IBM Plex Mono"
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: 13
                                                }
                                            }
                                            Text {
                                                id: dpsText
                                                width: statsCol.cols[3]
                                                horizontalAlignment: Text.AlignRight
                                                text: win.amount(prow.modelData.dps)
                                                color: prow.modelData.role === "healers" ? "#8B98AD" : "#E6ECF5"
                                                font.family: "IBM Plex Mono"
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                width: statsCol.cols[4]
                                                horizontalAlignment: Text.AlignRight
                                                text: win.amount(prow.modelData.hps)
                                                color: prow.modelData.role === "healers" ? "#E6ECF5" : "#8B98AD"
                                                font.family: "IBM Plex Mono"
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                width: statsCol.cols[5] - 8
                                                horizontalAlignment: Text.AlignRight
                                                text: prow.modelData.deaths || ""
                                                color: "#E5534B"
                                                font.family: "IBM Plex Mono"
                                                font.pixelSize: 13
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        visible: !!(card.stats && card.stats.players)
                        width: parent.width
                        topPadding: 4
                        wrapMode: Text.WordWrap
                        text: card.stats ? (card.stats.deaths ? card.stats.deaths + " dödsfall" : "Inga dödsfall")
                              + (card.stats.ranked ? " · ILVL = parse mot samma item level" : " · parses bara för kills och nycklar i tid (kan dröja en stund efter uppladdningen)")
                              + (win.statsBusy === card.modelData.path ? " · uppdaterar …" : "") : ""
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 12
                    }
                }
            }
        }
        FlatScrollBar { flick: list }
        FlatScrollBar { flick: playerPane; anchors.rightMargin: -20 } // in the margin to the right

        // The player – scrolls when everything doesn't fit even with a small video (small window)
        Flickable {
            id: playerPane
            visible: win.videos.length > 0 && !!win.selected
            anchors { left: list.right; leftMargin: 20; right: parent.right; rightMargin: 32; top: parent.top; topMargin: 20; bottom: parent.bottom; bottomMargin: 20 }
            contentWidth: width
            contentHeight: info.y + info.height
            clip: true
            interactive: false // the timeline is dragged; the wheel and the scroll bar scroll
            boundsBehavior: Flickable.StopAtBounds
            FastWheel { flick: playerPane }

            readonly property var v: win.selected
            readonly property real dur: player.duration > 0 ? player.duration / 1000 : (v ? v.duration : 0)

            property string shownPath: ""
            onVChanged: {
                // The list is read again now and then (new object, same video): keep playing
                if (v && v.path === shownPath)
                    return;
                shownPath = v ? v.path : "";
                win.ytOpen = false;
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
                // Everything below the video must fit: it shrinks instead (13 Oct, the text at the
                // bottom was cut off – the timeline and the gaps were not counted)
                height: Math.max(200, Math.min(width * 9 / 16, playerPane.height - 14 - timeline.height - 10
                                                - controls.height - 18 - info.height))
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
                        color: accent.color
                    }
                }
                Rectangle { // the part that goes to YouTube
                    visible: win.ytOpen && playerPane.dur > 0
                    x: playerPane.dur > 0 ? timeline.width * win.ytStart / playerPane.dur : 0
                    width: playerPane.dur > 0 ? timeline.width * ((win.ytEnd > 0 ? win.ytEnd : playerPane.dur) - win.ytStart) / playerPane.dur : 0
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18
                    color: "transparent"
                    border.width: 2
                    border.color: accent.errorBright
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
                        color: modelData.kind === "death" ? "#E5534B"
                             : modelData.kind === "kill" ? (modelData.text.startsWith("Kill") ? accent.color : "#E5CC80") : "#8B98AD"
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

            Flow {
                id: controls
                anchors { left: parent.left; right: parent.right; top: timeline.bottom; topMargin: 10 }
                spacing: 10

                FlatButton {
                    width: 110
                    primary: true
                    text: player.playbackState === MediaPlayer.PlayingState ? "Pausa" : "Spela"
                    onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
                }
                Text {
                    height: 40
                    verticalAlignment: Text.AlignVCenter
                    width: 120
                    text: win.clock(player.position / 1000) + " / " + win.clock(playerPane.dur)
                    color: "#E6ECF5"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 13
                }
                Text {
                    height: 40
                    verticalAlignment: Text.AlignVCenter
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
                height: win.ytOpen ? ytPane.implicitHeight : infoCol.implicitHeight

                // The title and the line under it get the whole width, the buttons a row of their own
                Column {
                    id: infoCol
                    visible: !win.ytOpen
                    width: parent.width
                    spacing: 6
                    Text {
                        width: parent.width
                        text: playerPane.v ? win.videoTitle(playerPane.v) + " – " + playerPane.v.difficulty : ""
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
                            if (v.kind === "cs2" || v.kind === "cs2clip") {
                                const kills = v.markers.filter(m => m.kind === "kill");
                                const multi = kills.filter(m => !m.text.startsWith("Kill")).length;
                                return win.when(v.started) + " · " + win.resultText(v).toLowerCase() + " efter " + win.clock(v.fight)
                                    + " · " + kills.length + " kills" + (multi ? " (guld = 2K–ACE)" : "") + " · " + deaths.length + " dödsfall";
                            }
                            const pct = v.wcl && v.result === "wipe" && v.wcl.bossPercentage !== null && v.wcl.bossPercentage !== undefined
                                ? " på " + Math.round(v.wcl.bossPercentage) + " %" : "";
                            return win.when(v.started) + " · " + win.resultText(v).toLowerCase() + pct + " efter " + win.clock(v.fight)
                                + " · " + (deaths.length ? deaths.length + " dödsfall (röda streck – klicka för att hoppa dit)" : "inga dödsfall")
                                + "";
                        }
                    }
                    Item { width: 1; height: 6 }
                    Flow {
                        id: actions
                        width: parent.width
                        spacing: 10
                        FlatButton {
                            text: "Till YouTube …"
                            onClicked: { player.pause(); win.ytShow(); }
                        }
                        FlatButton {
                            visible: !!(playerPane.v && playerPane.v.youtube)
                            text: "Öppna på YouTube"
                            onClicked: backend.openUrl(playerPane.v.youtube.url)
                        }
                        FlatButton {
                            visible: !!(playerPane.v && !String(playerPane.v.kind).startsWith("cs2") && (playerPane.v.wcl || backend.wclConfigured))
                            primary: !!(playerPane.v && playerPane.v.wcl)
                            enabledState: !win.wclBusy
                            text: playerPane.v && playerPane.v.wcl ? "Öppna i Warcraft Logs" : win.wclBusy ? "Söker …" : "Sök i Warcraft Logs"
                            onClicked: playerPane.v.wcl ? backend.openUrl(playerPane.v.wcl.url) : backend.wclFind(playerPane.v.path)
                        }
                        FlatButton {
                            visible: !!(playerPane.v && playerPane.v.wcl)
                            text: "Fråga " + backend.aiName + " om pullen"
                            onClicked: {
                                const v = playerPane.v;
                                const what = v.wcl.kill ? "Hur gick det på " + v.name + "? Vad kan vi göra bättre?"
                                                        : "Varför wipade vi på " + v.name + "?";
                                backend.askAi(what + " " + v.wcl.url);
                            }
                        }
                        FlatButton {
                            text: playerPane.v && playerPane.v.keep ? "Sparas för alltid ✓" : "Spara för alltid"
                            onClicked: {
                                const p = playerPane.v.path, k = !playerPane.v.keep;
                                backend.setKeep(p, k);
                                win.selected = win.findVideo(p);
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

                // To YouTube: which part, title and description – then the file and YouTube Studio
                Column {
                    id: ytPane
                    visible: win.ytOpen
                    width: parent.width
                    spacing: 10
                    Flow {
                        width: parent.width
                        spacing: 10
                        Text {
                            height: 40
                            verticalAlignment: Text.AlignVCenter
                            text: "TILL YOUTUBE"
                            color: "#E6ECF5"
                            font.family: "Chakra Petch"
                            font.weight: Font.Bold
                            font.pixelSize: 15
                            font.letterSpacing: 2
                        }
                        Note {
                            height: 40
                            verticalAlignment: Text.AlignVCenter
                            text: "Från " + win.clock(win.ytStart) + " till " + win.clock(win.ytEnd > 0 ? win.ytEnd : playerPane.dur)
                                  + " (" + win.clock((win.ytEnd > 0 ? win.ytEnd : playerPane.dur) - win.ytStart) + ")"
                        }
                        FlatButton {
                            text: "Början här"
                            onClicked: { win.ytStart = Math.min(player.position / 1000, (win.ytEnd > 0 ? win.ytEnd : playerPane.dur) - 1); win.ytRefresh(); }
                        }
                        FlatButton {
                            text: "Slutet här"
                            onClicked: { win.ytEnd = Math.max(player.position / 1000, win.ytStart + 1); win.ytRefresh(); }
                        }
                        FlatButton {
                            text: "Hela filmen"
                            onClicked: { win.ytStart = 0; win.ytEnd = 0; win.ytRefresh(); }
                        }
                    }
                    FlatField {
                        width: parent.width
                        text: win.ytTitle
                        hint: "Titel"
                        onEdited: win.ytTitle = text
                    }
                    Rectangle {
                        width: parent.width
                        height: 110
                        color: "#07090D"
                        border.width: 1
                        border.color: descEdit.activeFocus ? accent.color : "#2A3852"
                        Flickable {
                            id: descFlick
                            anchors { fill: parent; margins: 10 }
                            contentHeight: descEdit.contentHeight
                            clip: true
                            FastWheel { flick: descFlick }
                            TextEdit {
                                id: descEdit
                                width: descFlick.width
                                text: win.ytDesc
                                onTextChanged: if (activeFocus) win.ytDesc = text
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                color: "#E6ECF5"
                                selectionColor: accent.color
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                            }
                        }
                    }
                    Flow { // straight up to the channel (signed in under Inställningar → YouTube)
                        visible: win.yt.signedIn
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: [{ "id": "private", "name": "Privat", "sub": "Bara du ser filmen." },
                                    { "id": "unlisted", "name": "Olistad", "sub": "Den som har länken kan se filmen – den syns inte på kanalen eller i sökningar." },
                                    { "id": "public", "name": "Offentlig", "sub": "Alla kan hitta och se filmen." }]
                            Choice {
                                text: modelData.name
                                sub: modelData.sub
                                chosen: win.ytPrivacy === modelData.id
                                enabledState: !win.ytUploading
                                onPicked: win.ytPrivacy = modelData.id
                            }
                        }
                        FlatButton {
                            primary: true
                            enabledState: !win.ytUploading && !win.ytBusy && win.ytTitle.length > 0
                            text: win.ytUploading ? (win.ytTotal > 0 ? "Laddar upp " + Math.floor(100 * win.ytSent / win.ytTotal) + " %" : "Gör filmen …")
                                                  : "Ladda upp till YouTube"
                            onClicked: {
                                win.ytUploading = true;
                                win.ytSent = 0;
                                win.ytTotal = 0;
                                win.ytUrl = "";
                                win.ytError = "";
                                backend.youtubeUpload(playerPane.v.path, win.ytStart, win.ytEnd, win.ytTitle, win.ytDesc, win.ytPrivacy);
                            }
                        }
                        FlatButton {
                            visible: win.ytUploading && win.ytTotal > 0
                            danger: true
                            text: "Avbryt"
                            onClicked: backend.youtubeCancel()
                        }
                        FlatButton {
                            visible: win.ytUrl !== ""
                            text: "Öppna på YouTube"
                            onClicked: backend.openUrl(win.ytUrl)
                        }
                    }
                    Rectangle { // how far the upload has come
                        visible: win.ytUploading && win.ytTotal > 0
                        width: parent.width
                        height: 4
                        color: "#1A2438"
                        Rectangle {
                            width: win.ytTotal > 0 ? parent.width * win.ytSent / win.ytTotal : 0
                            height: parent.height
                            color: accent.color
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 10
                        FlatButton {
                            primary: !win.yt.signedIn
                            enabledState: !win.ytBusy && !win.ytUploading && win.ytTitle.length > 0
                            text: win.ytBusy ? "Gör filmen …" : "Gör filmen och öppna YouTube"
                            onClicked: {
                                win.ytBusy = true;
                                win.ytFile = "";
                                win.ytError = "";
                                backend.youtubeMake(playerPane.v.path, win.ytStart, win.ytEnd, win.ytTitle);
                            }
                        }
                        FlatButton {
                            visible: win.ytFile !== ""
                            text: "Kopiera titeln"
                            onClicked: backend.copyText(win.ytTitle)
                        }
                        FlatButton {
                            visible: win.ytFile !== ""
                            text: "Kopiera beskrivningen"
                            onClicked: backend.copyText(win.ytDesc)
                        }
                        FlatButton {
                            visible: win.ytFile !== ""
                            text: "Visa filen"
                            onClicked: backend.showFile(win.ytFile)
                        }
                        FlatButton {
                            text: "Stäng"
                            onClicked: win.ytOpen = false
                        }
                    }
                    Note {
                        width: parent.width
                        text: win.ytError ? (win.ytError.indexOf("Det gick inte") === 0 || win.ytError.indexOf("YouTube") === 0
                                             || win.ytError === "Avbruten" ? win.ytError : "Det gick inte att göra filmen: " + win.ytError)
                            : win.ytUrl ? "Uppladdad: " + win.ytUrl + " (länken är kopierad). YouTube behöver en stund till att göra klart filmen i alla storlekar. "
                                          + "Är den låst som privat fast du valde något annat? Se Inställningar → YouTube."
                            : win.ytUploading ? (win.ytTotal > 0 ? win.size(win.ytSent) + " av " + win.size(win.ytTotal) + " – du kan titta på andra filmer under tiden, men låt fönstret vara öppet."
                                                                 : "Klipper filmen …")
                            : win.ytFile ? "Klar. Dra in filen i YouTube Studio (den är markerad i filhanteraren). Titeln är kopierad – klistra in den, "
                                           + "sedan Kopiera beskrivningen och klistra in den. Bossarnas tider blir kapitel i YouTube."
                            : "Bara filmens första ljudspår (allt) kommer med. Klipps utan omkodning – går fort, samma kvalitet."
                              + (win.yt.signedIn ? "" : " Vill du ladda upp direkt härifrån? Logga in under Inställningar → YouTube.")
                        color: win.ytError ? "#E5534B" : "#8B98AD"
                    }
                }
            }
        }
    }

    // ── WoW Stats / CS2 Stats (22 Oct, the user's wish) ─────
    // Put together from what is already here: WoW from your own history (each recorded pull with
    // your row of its Warcraft Logs numbers), CS2 from the read demos. No calls of their own.
    component StatTile: Rectangle {
        id: tile
        property string label
        property string value
        property color valueColor: "#E6ECF5"
        property string tip
        width: 112
        height: 54
        color: "#0B1018"
        border.width: 1
        border.color: "#1E2A40"
        HoverTip { tip: tile.tip }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.value
                color: tile.valueColor
                font.family: "IBM Plex Sans"
                font.weight: Font.DemiBold
                font.pixelSize: 18
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.weight: Font.DemiBold
                font.pixelSize: 10
                font.letterSpacing: 1
            }
        }
    }

    // A table row: the first column to the left, the rest to the right; colors per cell (or the default)
    component TableRow: Rectangle {
        id: trow
        property var cols: []
        property var cells: []
        property var colors: []
        property bool heading: false
        property string link
        property string tip
        width: parent ? parent.width : 0
        height: heading ? 26 : 30
        color: !heading && trowArea.containsMouse ? "#0E1420" : "transparent"
        Rectangle { visible: !trow.heading; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            Repeater {
                model: trow.cells
                Text {
                    required property var modelData
                    required property int index
                    width: trow.cols[index] || 80
                    horizontalAlignment: index ? Text.AlignRight : Text.AlignLeft
                    text: modelData === null || modelData === undefined ? "–" : String(modelData)
                    color: trow.colors[index] || (trow.heading || index ? "#8B98AD" : "#E6ECF5")
                    elide: Text.ElideRight
                    font.family: trow.heading ? "Chakra Petch" : "IBM Plex Sans"
                    font.weight: trow.heading ? Font.DemiBold : (index ? Font.Normal : Font.Medium)
                    font.pixelSize: trow.heading ? 11 : 13
                    font.letterSpacing: trow.heading ? 1 : 0
                }
            }
        }
        MouseArea {
            id: trowArea
            anchors.fill: parent
            hoverEnabled: !trow.heading
            cursorShape: trow.link ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (trow.link) backend.openUrl(trow.link)
            onContainsMouseChanged: containsMouse && trow.tip ? win.showTip(trow, trow.tip) : win.hideTip(trow)
        }
    }

    // Bars over time: values (null = gap), the colour per bar, a tip per bar
    component Bars: Column {
        id: bars
        property string title
        property var values: []
        property var barColors: []
        property var tips: []
        property real maxValue: Math.max(1, ...values.filter(x => x !== null && x !== undefined))
        spacing: 4
        Text {
            text: bars.title
            color: "#8B98AD"
            font.family: "Chakra Petch"
            font.weight: Font.DemiBold
            font.pixelSize: 11
            font.letterSpacing: 1
        }
        Row {
            height: 56
            spacing: 3
            Repeater {
                model: bars.values.length
                Rectangle {
                    required property int index
                    readonly property var v: bars.values[index]
                    anchors.bottom: parent.bottom
                    width: 12
                    height: v === null || v === undefined ? 2 : 4 + 52 * v / bars.maxValue
                    color: bars.barColors[index] || "#2A3852"
                    HoverTip { tip: bars.tips[index] || "" }
                }
            }
        }
    }

    function fmtTime(sec) { return sec ? Math.floor(sec / 60) + ":" + String(Math.round(sec % 60)).padStart(2, "0") : "–"; }
    function day(t) { return t ? new Date(t * 1000).toLocaleDateString(Qt.locale("sv_SE"), "d MMM") : ""; }

    property string wowPlayer: ""
    property int wowDays: 0
    property string wowDiff: ""
    property int cs2Count: 10
    readonly property var wowData: tab === "wowstats" ? (videos, JSON.parse(backend.wowOverview(wowPlayer, wowDays))) : ({})
    readonly property var cs2Data: tab === "cs2stats" ? (videos, JSON.parse(backend.cs2Overview(cs2Count))) : ({})
    readonly property string wowShownDiff: wowData.difficulties && wowData.difficulties.indexOf(wowDiff) >= 0
                                           ? wowDiff : (wowData.difficulties || [""])[0] || ""

    Flickable {
        id: wowPage
        FastWheel { flick: wowPage }
        visible: win.tab === "wowstats"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        contentHeight: wowCol.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property var d: win.wowData
        readonly property var r: d.raid ? d.raid[win.wowShownDiff] : null
        readonly property string metric: d.role === "healers" ? "HPS" : "DPS"

        Column {
            id: wowCol
            x: 40
            y: 28
            width: Math.min(1100, wowPage.width - 80)
            spacing: 14

            Column {
                visible: !wowPage.d.player
                width: parent.width
                spacing: 10
                SectionTitle { text: "INGA WOW-SIFFROR ÄN" }
                Note {
                    width: parent.width
                    text: "WoW Stats sammanställs av dina inspelade pulls och nycklar: när loggen hämtas från Warcraft Logs "
                          + "sparas din parse, DPS/HPS och item level. Spela in en raid eller en nyckel med Warcraft Logs inkopplat "
                          + "(Inställningar) – siffrorna kommer här."
                }
            }

            // the character: name in its class colour, spec, item level
            Item {
                visible: !!wowPage.d.player
                width: parent.width
                height: 56
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: wowPage.d.name || ""
                        color: win.classColors[wowPage.d["class"]] || "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: 26
                    }
                    Text {
                        text: [wowPage.d.spec, wowPage.d["class"], wowPage.d.realm, wowPage.d.region].filter(x => x).join(" · ")
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    FlatButton {
                        visible: !!wowPage.d.wclUrl
                        text: "Warcraft Logs"
                        onClicked: backend.openUrl(wowPage.d.wclUrl)
                    }
                    FlatButton {
                        primary: true
                        text: "Fråga " + backend.aiName + " vad jag ska förbättra"
                        onClicked: backend.askAi("Hur ser mina WoW-parses ut för " + (wowPage.d.name || "min karaktär")
                                                 + "? Vilka bossar och dungeons är svagast och vad ska jag förbättra?")
                    }
                }
            }

            Flow { // which character, which period
                visible: !!wowPage.d.player
                width: parent.width
                spacing: 8
                Repeater {
                    model: (wowPage.d.players || []).length > 1 ? wowPage.d.players : []
                    Choice {
                        required property string modelData
                        text: modelData.split("-")[0]
                        sub: modelData
                        chosen: wowPage.d.player === modelData
                        onPicked: win.wowPlayer = modelData
                    }
                }
                Item { visible: (wowPage.d.players || []).length > 1; width: 16; height: 1 }
                Repeater {
                    model: [{ d: 0, t: "Allt" }, { d: 30, t: "30 dagar" }, { d: 7, t: "7 dagar" }]
                    Choice {
                        required property var modelData
                        text: modelData.t
                        chosen: win.wowDays === modelData.d
                        onPicked: win.wowDays = modelData.d
                    }
                }
            }

            Flow {
                visible: !!wowPage.d.player
                width: parent.width
                spacing: 6
                StatTile {
                    label: "BÄSTA SNITT"
                    value: wowPage.r && wowPage.r.best !== null ? win.num(wowPage.r.best) : "–"
                    valueColor: wowPage.r && wowPage.r.best !== null ? win.parseColor(wowPage.r.best) : "#E6ECF5"
                    tip: "Snittet av din bästa parse per boss (" + win.wowShownDiff + ") – som Best Perf. Avg hos Warcraft Logs."
                }
                StatTile {
                    label: "MEDIAN SNITT"
                    value: wowPage.r && wowPage.r.median !== null ? win.num(wowPage.r.median) : "–"
                    valueColor: wowPage.r && wowPage.r.median !== null ? win.parseColor(wowPage.r.median) : "#E6ECF5"
                    tip: "Snittet av din median-parse per boss – hur du brukar prestera, inte bara din bästa."
                }
                StatTile { label: "KILLS"; value: wowPage.r ? String(wowPage.r.kills) : "–"; tip: "Inspelade kills på " + win.wowShownDiff + "." }
                StatTile { label: "PULLS"; value: wowPage.r ? String(wowPage.r.pulls) : "–"; tip: "Alla inspelade pulls, wipes också." }
                StatTile { label: "ITEM LEVEL"; value: wowPage.d.ilvl ? String(wowPage.d.ilvl) : "–"; tip: "Din item level i den senaste loggen." }
                StatTile {
                    label: "M+ I TID"
                    value: wowPage.d.mplus ? wowPage.d.mplus.timed + "/" + wowPage.d.mplus.runs : "–"
                    tip: "Inspelade nycklar i tid av alla."
                }
            }

            Note {
                visible: !!wowPage.d.missing
                width: parent.width
                font.pixelSize: 12
                text: wowPage.d.missing + " kills/nycklar saknar siffror än – tjänsten hämtar loggen själv när den finns i Warcraft Logs."
            }

            // RAID: one table per difficulty
            Item { visible: !!wowPage.r; width: 1; height: 6 }
            Row {
                visible: !!wowPage.r
                spacing: 16
                SectionTitle { text: "RAID"; anchors.verticalCenter: parent.verticalCenter }
                Repeater {
                    model: wowPage.d.difficulties || []
                    Choice {
                        required property string modelData
                        text: modelData
                        chosen: win.wowShownDiff === modelData
                        onPicked: win.wowDiff = modelData
                    }
                }
            }
            Column {
                visible: !!wowPage.r
                width: parent.width
                readonly property var cols: [width - 8 - 70 * 5 - 80 * 3 - 90 - 60, 70, 70, 70, 70, 70, 80, 90, 60, 80, 80]
                TableRow {
                    heading: true
                    cols: parent.cols
                    cells: ["BOSS", "BÄST", "MEDIAN", "ILVL %", "KILLS", "WIPES", "SNABBAST", "BÄSTA " + wowPage.metric, "ILVL", "AVG.ILVL", "SENAST"]
                }
                Repeater {
                    model: wowPage.r ? wowPage.r.bosses : []
                    TableRow {
                        required property var modelData
                        cols: parent.cols
                        link: modelData.url || ""
                        tip: modelData.url ? "Öppna din bästa kill i Warcraft Logs" : ""
                        cells: [modelData.name, modelData.best, modelData.median, modelData.ilvlParse, modelData.kills,
                                modelData.wipes, win.fmtTime(modelData.fastest), modelData.amount ? win.amount(modelData.amount) : null,
                                modelData.ilvl, modelData.avgIlvl ? win.num(modelData.avgIlvl.toFixed(1)) : null, win.day(modelData.last)]
                        colors: [null, modelData.best !== null ? win.parseColor(modelData.best) : null,
                                 modelData.median !== null ? win.parseColor(modelData.median) : null,
                                 modelData.ilvlParse !== null ? win.parseColor(modelData.ilvlParse) : null]
                    }
                }
            }

            // MYTHIC+: per dungeon
            Item { visible: !!(wowPage.d.mplus && wowPage.d.mplus.runs); width: 1; height: 6 }
            Row {
                visible: !!(wowPage.d.mplus && wowPage.d.mplus.runs)
                spacing: 16
                SectionTitle { text: "MYTHIC+" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wowPage.d.mplus && wowPage.d.mplus.best !== null ? "bästa snitt " + win.num(wowPage.d.mplus.best)
                                                                               + " · median snitt " + win.num(wowPage.d.mplus.median) : ""
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 13
                }
            }
            Column {
                visible: !!(wowPage.d.mplus && wowPage.d.mplus.runs)
                width: parent.width
                readonly property var cols: [width - 8 - 100 * 2 - 80 * 4 - 90, 100, 100, 80, 80, 80, 80, 90]
                TableRow {
                    heading: true
                    cols: parent.cols
                    cells: ["DUNGEON", "BÄSTA I TID", "HÖGSTA", "KÖRNINGAR", "I TID", "BÄST", "MEDIAN", "BÄSTA " + wowPage.metric]
                }
                Repeater {
                    model: wowPage.d.mplus ? wowPage.d.mplus.dungeons : []
                    TableRow {
                        required property var modelData
                        cols: parent.cols
                        link: modelData.url || ""
                        cells: [modelData.name, modelData.bestLevel ? "+" + modelData.bestLevel : null,
                                modelData.topLevel ? "+" + modelData.topLevel : null, modelData.pulls, modelData.kills,
                                modelData.best, modelData.median, modelData.amount ? win.amount(modelData.amount) : null]
                        colors: [null, null, null, null, null, modelData.best !== null ? win.parseColor(modelData.best) : null,
                                 modelData.median !== null ? win.parseColor(modelData.median) : null]
                    }
                }
            }

            Item { visible: (wowPage.d.trend || []).length > 1; width: 1; height: 6 }
            Bars {
                visible: (wowPage.d.trend || []).length > 1
                title: "PARSE ÖVER TID · senaste " + (wowPage.d.trend || []).length + " kills och nycklar"
                values: (wowPage.d.trend || []).map(t => t.parse)
                barColors: (wowPage.d.trend || []).map(t => win.parseColor(t.parse))
                maxValue: 100
                tips: (wowPage.d.trend || []).map(t => t.name + (t.level ? " +" + t.level : " " + (t.difficulty || "")) + " · "
                                                      + win.day(t.started) + " · parse " + t.parse + (t.ilvl ? " · ilvl " + t.ilvl : "")
                                                      + (t.avgIlvl ? " · avg.ilvl " + win.num(t.avgIlvl.toFixed(1)) : ""))
            }
            Note {
                visible: !!wowPage.d.player
                width: parent.width
                font.pixelSize: 12
                text: "Bara pulls och nycklar som GoblinRecorder spelat in. Parse = Warcraft Logs (healers på HPS, övriga på DPS); "
                      + "ILVL % = mot spelare med samma item level; ILVL = din, AVG.ILVL = gruppens snitt i den killen. "
                      + "Klicka på en rad för att öppna din bästa i Warcraft Logs."
            }
        }
    }
    FlatScrollBar { flick: wowPage }

    Flickable {
        id: cs2Page
        FastWheel { flick: cs2Page }
        visible: win.tab === "cs2stats"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        contentHeight: cs2Col.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property var d: win.cs2Data
        readonly property var ms: (d.matches || []).slice(-(win.cs2Count || 30))

        Column {
            id: cs2Col
            x: 40
            y: 28
            width: Math.min(1100, cs2Page.width - 80)
            spacing: 14

            Column {
                visible: !cs2Page.d.all
                width: parent.width
                spacing: 10
                SectionTitle { text: "INGA CS2-SIFFROR ÄN" }
                Note {
                    width: parent.width
                    text: "CS2 Stats sammanställs av dina lästa demos. Spela en Competitive/Premier/Wingman-match med CS2 inkopplat "
                          + "och ladda ner demon i CS2 (Watch → Your Matches)."
                          + (cs2Page.d.waiting ? " " + cs2Page.d.waiting + " match(er) väntar på demon nu." : "")
                }
            }

            Item {
                visible: !!cs2Page.d.all
                width: parent.width
                height: 56
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: "COUNTER-STRIKE 2"
                        color: "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: 26
                    }
                    Text {
                        text: cs2Page.d.count + " matcher · " + cs2Page.d.wins + " vinster, " + cs2Page.d.losses + " förluster"
                              + (cs2Page.d.waiting ? " · " + cs2Page.d.waiting + " väntar på demon" : "")
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                }
                FlatButton {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    primary: true
                    text: "Fråga " + backend.aiName + " vad jag ska träna på"
                    onClicked: backend.askAi("Hur ser mina CS2-siffror ut över de senaste " + (win.cs2Count || 30)
                                             + " matcherna? Vad går bra och vad ska jag träna på?")
                }
            }

            Flow {
                visible: !!cs2Page.d.all
                width: parent.width
                spacing: 8
                Repeater {
                    model: [{ n: 10, t: "Senaste 10" }, { n: 20, t: "Senaste 20" }, { n: 0, t: "Alla" }]
                    Choice {
                        required property var modelData
                        text: modelData.t
                        chosen: win.cs2Count === modelData.n
                        onPicked: win.cs2Count = modelData.n
                    }
                }
            }

            Flow {
                visible: !!cs2Page.d.all
                width: parent.width
                spacing: 6
                readonly property var a: cs2Page.d.avg || {}
                readonly property var p: cs2Page.d.per || {}
                StatTile { label: "K/D"; value: win.num(parent.a.kd); tip: "Kills per dödsfall, snitt per match." }
                StatTile { label: "ADR"; value: win.num(parent.a.adr); tip: "Skada per runda, snitt." }
                StatTile { label: "KAST"; value: parent.a.kast === null || parent.a.kast === undefined ? "–" : Math.round(parent.a.kast) + " %"; tip: "Rundor med kill, assist, överlevt eller trade." }
                StatTile { label: "HS"; value: parent.a.hs === null || parent.a.hs === undefined ? "–" : Math.round(parent.a.hs) + " %"; tip: "Kills med huvudskott." }
                StatTile { label: "TTD"; value: parent.a.ttd ? Math.round(parent.a.ttd) + " ms" : "–"; tip: "Time to damage (ungefärlig), snitt av matchernas median." }
                StatTile { label: "SIKTE"; value: parent.a.cp ? win.num(parent.a.cp.toFixed(1)) + "°" : "–"; tip: "Crosshair placement (ungefärlig) – lägre är bättre." }
                StatTile { label: "ENTRY / MATCH"; value: win.num(parent.p.entryWon) + "–" + win.num(parent.p.entryLost); tip: "Rundans första kill: vunna–förlorade per match." }
                StatTile { label: "TRADES / MATCH"; value: win.num(parent.p.trades); tip: "Du hämnades en lagkamrat inom 5 s." }
                StatTile { label: "CLUTCH / MATCH"; value: win.num(parent.p.clutchWon) + "/" + win.num(parent.p.clutches); tip: "1vX vunna av alla, per match." }
                StatTile { label: "BLÄNDADE / MATCH"; value: win.num(parent.p.flashed); tip: "Fiender du bländat minst 1 s." }
            }

            Item { visible: cs2Page.ms.length > 1; width: 1; height: 6 }
            Flow {
                visible: cs2Page.ms.length > 1
                width: parent.width
                spacing: 28
                Repeater {
                    model: [{ k: "adr", t: "ADR" }, { k: "kd", t: "K/D" }, { k: "hs", t: "HS %" },
                            { k: "ttd", t: "TTD (lägre = bättre)" }, { k: "cp", t: "SIKTE ° (lägre = bättre)" }]
                    Bars {
                        required property var modelData
                        title: modelData.t
                        values: cs2Page.ms.map(m => m[modelData.k])
                        barColors: cs2Page.ms.map((m, i) => i === cs2Page.ms.length - 1 ? accent.color
                                                           : m.result === "win" ? "#2E6B3E" : "#6B2A2E")
                        tips: cs2Page.ms.map(m => m.name + " " + m.score + " · " + win.day(m.started) + " · "
                                                  + modelData.t.split(" ")[0] + " " + win.num(m[modelData.k]))
                    }
                }
            }

            Item { visible: (cs2Page.d.maps || []).length > 0; width: 1; height: 6 }
            SectionTitle { visible: (cs2Page.d.maps || []).length > 0; text: "KARTOR" }
            Column {
                visible: (cs2Page.d.maps || []).length > 0
                width: parent.width
                readonly property var cols: [width - 8 - 90 * 4, 90, 90, 90, 90]
                TableRow { heading: true; cols: parent.cols; cells: ["KARTA", "MATCHER", "VINST %", "ADR", "K/D"] }
                Repeater {
                    model: cs2Page.d.maps || []
                    TableRow {
                        required property var modelData
                        cols: parent.cols
                        cells: [modelData.name, modelData.matches, Math.round(100 * modelData.wins / modelData.matches) + " %",
                                win.num(modelData.adr), win.num(modelData.kd)]
                    }
                }
            }

            Item { visible: (cs2Page.d.weapons || []).length > 0; width: 1; height: 6 }
            SectionTitle { visible: (cs2Page.d.weapons || []).length > 0; text: "VAPEN" }
            Column {
                visible: (cs2Page.d.weapons || []).length > 0
                width: parent.width
                readonly property var cols: [width - 8 - 90 * 4, 90, 90, 90, 90]
                TableRow { heading: true; cols: parent.cols; cells: ["VAPEN", "KILLS", "HS %", "TRÄFF %", "SKOTT"] }
                Repeater {
                    model: cs2Page.d.weapons || []
                    TableRow {
                        required property var modelData
                        cols: parent.cols
                        cells: [modelData.name, modelData.kills, modelData.hsp, modelData.acc, modelData.shots]
                    }
                }
            }

            Item { visible: cs2Page.ms.length > 0; width: 1; height: 6 }
            SectionTitle { visible: cs2Page.ms.length > 0; text: "MATCHER" }
            Column {
                visible: cs2Page.ms.length > 0
                width: parent.width
                readonly property var cols: [width - 8 - 90 * 6, 90, 90, 90, 90, 90, 90]
                TableRow { heading: true; cols: parent.cols; cells: ["MATCH", "RESULTAT", "K–D", "ADR", "HS %", "TTD", "SIKTE"] }
                Repeater {
                    model: cs2Page.ms.slice().reverse()
                    TableRow {
                        required property var modelData
                        cols: parent.cols
                        tip: "Visa matchen i Inspelningar"
                        cells: [modelData.name + " · " + modelData.mode + " · " + win.day(modelData.started), modelData.score,
                                modelData.kills + "–" + modelData.deaths, win.num(modelData.adr), modelData.hs + " %",
                                modelData.ttd ? modelData.ttd + " ms" : null, modelData.cp ? win.num(modelData.cp) + "°" : null]
                        colors: [null, modelData.result === "win" ? "#3FB950" : modelData.result === "loss" ? "#E5534B" : null]
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.tab = "videos";
                                win.expanded = parent.modelData.path;
                                const v = win.videos.find(x => x.path === parent.modelData.path);
                                if (v)
                                    win.selected = win.playable(v);
                            }
                        }
                    }
                }
            }
        }
    }
    FlatScrollBar { flick: cs2Page }

    // ── Settings ─────────────────────────────────────────────

    Flickable {
        id: settingsView
        FastWheel { flick: settingsView }
        visible: win.tab === "settings"
        anchors { left: parent.left; right: recordPanel.left; top: header.bottom; bottom: parent.bottom }
        contentHeight: settingsCol.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: settingsCol
            x: 40
            y: 30
            width: settingsView.width - 80
            spacing: 14

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
            SectionTitle { text: "YOUTUBE" }
            Note {
                width: Math.min(820, parent.width)
                text: win.yt.signedIn
                    ? "Inloggad" + (win.yt.email ? " som " + win.yt.email : "") + ". Till YouTube … i spelaren får knappen Ladda upp till YouTube. "
                      + "Obs: Google låser filmer från ett eget API-projekt som privata tills projektet granskats – ansök en gång med "
                      + "YouTubes formulär (gratis, kan ta några veckor). Tills dess: välj Privat och byt i YouTube Studio när låset är borta, "
                      + "eller använd Gör filmen och öppna YouTube."
                    : win.yt.client
                    ? "Klienten är sparad. Logga in med det Google-konto som har din YouTube-kanal."
                    : "Ladda upp filmerna direkt till din kanal. Gör en gång i Google Cloud (gratis): skapa ett projekt, slå på "
                      + "YouTube Data API v3 (APIs & Services → Library), ställ in OAuth consent screen (External, lägg till din "
                      + "e-postadress som testanvändare – eller Publish app, annars måste du logga in igen var 7:e dag), skapa sedan "
                      + "Credentials → OAuth client ID av typen Desktop app och klistra in Client ID och Client Secret här."
            }
            Row {
                visible: !win.yt.client
                spacing: 12
                FlatButton { text: "Öppna Google Cloud …"; onClicked: backend.openYoutubeConsole() }
                FlatField { id: ytId; width: 260; hint: "Client ID" }
                FlatField { id: ytSecret; width: 260; hint: "Client Secret"; echoMode: TextInput.Password }
                FlatButton {
                    primary: true
                    enabledState: ytId.text.length > 20 && ytSecret.text.length > 10 && !win.ytLoginBusy
                    text: "Spara och logga in"
                    onClicked: backend.setYoutubeClient(ytId.text, ytSecret.text)
                }
            }
            Row {
                visible: win.yt.client
                spacing: 12
                FlatButton {
                    visible: !win.yt.signedIn
                    primary: true
                    enabledState: !win.ytLoginBusy
                    text: win.ytLoginBusy ? "Väntar på webbläsaren …" : "Logga in på YouTube"
                    onClicked: backend.youtubeLogin()
                }
                FlatButton {
                    visible: win.yt.signedIn
                    text: "Ansök om granskning …"
                    onClicked: backend.openYoutubeAudit()
                }
                FlatButton {
                    visible: win.yt.signedIn
                    text: "Logga ut"
                    onClicked: backend.youtubeLogout(false)
                }
                FlatButton {
                    text: "Ta bort klienten"
                    onClicked: backend.youtubeLogout(true)
                }
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "KODARE" }
            Flow {
                width: settingsCol.width
                spacing: 12
                Repeater {
                    // Nvidia = NVENC, AMD/Intel = VAAPI (the same choices, the right encoder behind them)
                    readonly property string hw: win.enc.family === "vaapi" ? "VAAPI " : "NVENC "
                    model: [{ "id": "h264", "name": hw + "H.264", "sub": "Grafikkortet · spelas upp överallt" },
                            { "id": "hevc", "name": hw + "HEVC", "sub": "Grafikkortet · mindre filer" },
                            { "id": "av1", "name": hw + "AV1", "sub": "Grafikkortet · minst filer, Nvidia RTX 40xx, AMD RX 7000 eller Intel Arc" },
                            { "id": "x264", "name": "x264", "sub": "Processorn · tar kraft från spelet" }]
                    Choice {
                        required property var modelData
                        readonly property bool works: !win.enc.known || !!win.enc.codecs[modelData.id]
                        text: modelData.name
                        sub: (works ? modelData.sub : (win.enc.hardware ? "Grafikkortet klarar inte " + modelData.name.split(" ")[1] : "OBS hittade ingen kodare på grafikkortet (NVENC för Nvidia, VAAPI för AMD och Intel)"))
                             + ". Byter du kodare startas OBS om (dolt) före nästa inspelning."
                        enabledState: works
                        chosen: win.cfg.codec === modelData.id
                        onPicked: win.set("codec", modelData.id)
                    }
                }
            }
            Note {
                visible: !win.enc.hardware
                width: Math.min(820, parent.width)
                text: "OBS hittade ingen kodare på grafikkortet (NVENC för Nvidia, VAAPI för AMD och Intel) – OBS spelar in med processorn (x264). "
                      + "Har du startat OBS en gång? GoblinRecorder läser vad som finns ur OBS logg."
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
            SectionTitle { text: "KVALITET" }
            Row {
                spacing: 12
                Repeater {
                    model: [{ "id": "best", "name": "Bäst" }, { "id": "high", "name": "Hög" },
                            { "id": "normal", "name": "Normal" }, { "id": "small", "name": "Liten" }]
                    Choice {
                        required property var modelData
                        // MB per minute, as recorder.encoder_settings counts it (video + 1 or 3 audio tracks);
                        // Bäst has no bitrate (measured 15 Oct: a raid minute at CQP 18 = 326 MB, Hög 199)
                        readonly property real mb: ({ best: 0, high: 25, normal: 10, small: 5 })[modelData.id]
                            * (win.cfg.codec === "h264" || win.cfg.codec === "x264" ? 1.5 : 1)
                            * (win.cfg.fps <= 30 ? 0.7 : 1) * 7.5 + (win.cfg.capture === "wow" ? 1.2 : 3.6)
                        text: modelData.name
                        sub: modelData.id === "best"
                             ? "Riktigt fin bild – grafikkortet ger varje bild så mycket som behövs, så storleken följer vad som händer: "
                               + "ungefär 200–300 MB per minut, mest i stora raidstrider och M+-pulls. Håll koll på platsgränsen."
                             : "≈ " + Math.round(mb / 5) * 5 + " MB per minut. "
                             + ({ high: "Om du vill klippa ihop filmer i efterhand.", normal: "Räcker gott för WoW.",
                                  small: "När disken är liten." })[modelData.id] + " En lugn stund blir mindre."
                        chosen: (win.cfg.quality || "normal") === modelData.id
                        onPicked: win.set("quality", modelData.id)
                    }
                }
            }
            Item { width: 1; height: 4 }
            Row {
                spacing: 12
                FlatButton {
                    readonly property bool busy: !!(win.st.testWaiting || (win.st.current && win.st.current.kind === "test"))
                    enabledState: !!win.st.service && !win.st.recording && !busy && win.st.obs !== "missing"
                    text: busy ? "Testar …" : "Testa inspelningen (30 s)"
                    onClicked: {
                        win.testAsked = true;
                        backend.testRecording();
                    }
                }
                Note {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 420
                    text: "Spelar in 30 sekunder av skärmen med inställningarna här – kör WoW samtidigt för att se hur "
                        + "spelet blir. Filmen läggs överst i Inspelningar och tas bort när WoW stängs (om du inte sparar den)."
                }
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "LJUD" }
            Text {
                text: "Filmen fångar"
                color: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.weight: Font.Medium
                font.pixelSize: 15
            }
            Row {
                spacing: 12
                Repeater {
                    model: [{ "id": "all", "name": "Allt", "sub": "WoW, Discord och din röst – på tre ljudspår (Allt, WoW, Discord) som du väljer mellan under filmen." },
                            { "id": "wow", "name": "Bara WoW", "sub": "Bara spelets ljud – Discord och din mikrofon spelas inte in. Gäller filmer som spelas in efter bytet." }]
                    Choice {
                        required property var modelData
                        text: modelData.name
                        sub: modelData.sub
                        chosen: (win.cfg.capture || "all") === modelData.id
                        onPicked: win.set("capture", modelData.id)
                    }
                }
            }
            Column { // the switch under the text (12 Oct, the user's wish)
                topPadding: 8
                spacing: 8
                Text {
                    text: "Min mikrofon"
                    opacity: win.cfg.capture === "wow" ? 0.35 : 1
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.weight: Font.Medium
                    font.pixelSize: 15
                }
                ToggleSwitch {
                    on: win.cfg.mic !== false
                    enabledState: win.cfg.capture !== "wow"
                    onToggled: win.set("mic", win.cfg.mic === false)
                }
                HoverTip { tip: "Din röst på spåren Allt och Discord – med brusreducering, så att tangentbordet hörs mindre." }
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
                        text: modelData.name
                        sub: "WoW spelar ofta svagt bredvid Discord. Förstärkningen gäller bara filmen – en spärr ser till att det aldrig skär sig."
                        chosen: (win.cfg.gameBoost === undefined ? 12 : win.cfg.gameBoost) === modelData.db
                        onPicked: win.set("gameBoost", modelData.db)
                    }
                }
            }

            Text {
                topPadding: 8
                text: "Andning och småljud i mikrofonen"
                opacity: win.cfg.capture === "wow" ? 0.35 : 1
                color: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.weight: Font.Medium
                font.pixelSize: 15
            }
            Row {
                spacing: 12
                opacity: win.cfg.mic !== false && win.cfg.capture !== "wow" ? 1 : 0.35
                Repeater {
                    model: [{ "id": "off", "name": "Släpp igenom", "sub": "Allt som mikrofonen hör kommer med (brusreduceringen tar fortfarande bort jämnt brus som fläktar)." },
                            { "id": "normal", "name": "Stäng mellan orden", "sub": "Mikrofonen stängs när du inte pratar – andning och små ljud kommer inte med." },
                            { "id": "strong", "name": "Stäng mer", "sub": "För en känslig mikrofon: stängs även vid starkare andning. Hörs början av ord försvinna – välj Stäng mellan orden." },
                            { "id": "keys", "name": "Stäng mot tangentbordet", "sub": "Som Stäng mellan orden, men lyssnar på hur länge ljudet håller i sig: tal släpps igenom, korta klick från tangentbordet och musen gör det inte." }]
                    Choice {
                        required property var modelData
                        enabledState: win.cfg.mic !== false && win.cfg.capture !== "wow"
                        text: modelData.name
                        sub: modelData.sub
                        chosen: (win.cfg.micGate || "normal") === modelData.id
                        onPicked: win.set("micGate", modelData.id)
                    }
                }
            }
            Item { width: 1; height: 14 }
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
            SectionTitle { text: "HUR MYCKET PLATS FILMERNA FÅR TA" }
            Row {
                spacing: 12
                Repeater {
                    model: [50, 100, 200, 500]
                    Choice {
                        required property var modelData
                        text: modelData + " GB"
                        sub: "När gränsen nås tas de äldsta filmerna bort – inte de du sparat för alltid."
                        chosen: win.cfg.maxGB === modelData
                        onPicked: win.set("maxGB", modelData)
                    }
                }
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "NÄR FÖNSTRET STÄNGS"; visible: hasTray }
            Row {
                visible: hasTray
                spacing: 12
                Repeater {
                    model: [
                        { id: "ask", name: "Fråga", sub: "Krysset frågar varje gång om fönstret ska gömmas i systemfältet eller stängas." },
                        { id: "tray", name: "Göm i systemfältet", sub: "Krysset gömmer fönstret – ikonen i systemfältet visar om något spelas in, klick tar fram fönstret igen." },
                        { id: "quit", name: "Stäng", sub: "Krysset stänger fönstret. Inspelningen fortsätter ändå – den sköts av en egen tjänst." }
                    ]
                    Choice {
                        required property var modelData
                        text: modelData.name
                        sub: modelData.sub
                        chosen: (win.cfg.closeAction || "ask") === modelData.id
                        onPicked: win.set("closeAction", modelData.id)
                    }
                }
            }

            Item { width: 1; height: 14 }
            SectionTitle { text: "DÖLJ DELAR AV BILDEN" }
            Note {
                width: Math.min(820, parent.width)
                text: "Lägg en bild eller en svart ruta över det som inte ska synas i filmerna – chatten, namn, Discord. "
                      + "Dra rutan dit du vill och ändra storleken i hörnet. Den syns bara i filmerna, aldrig på din skärm."
            }
            Item {
                id: editor
                width: Math.min(820, settingsCol.width)
                height: width * 9 / 16

                Rectangle {
                    anchors.fill: parent
                    color: "#0E1420"
                    border.width: 1
                    border.color: "#1E2A40"
                }
                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: backend.preview
                    fillMode: Image.Stretch
                    asynchronous: true
                }
                Note {
                    anchors.centerIn: parent
                    visible: !backend.preview
                    text: "Starta OBS för att se skärmen här"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: win.overlayPick = -1
                }

                Repeater {
                    model: win.cfg.overlays || []
                    Rectangle {
                        id: box
                        required property var modelData
                        required property int index
                        readonly property bool picked: win.overlayPick === index
                        x: modelData.x * editor.width
                        y: modelData.y * editor.height
                        width: modelData.w * editor.width
                        height: modelData.h * editor.height
                        color: modelData.file ? "transparent" : "#000000"
                        border.width: 2
                        border.color: picked ? accent.color : "#8B98AD"

                        function save() {
                            backend.moveOverlay(index, x / editor.width, y / editor.height, width / editor.width, height / editor.height);
                        }

                        Image {
                            anchors.fill: parent
                            visible: !!box.modelData.file
                            source: box.modelData.file ? backend.fileUrl(box.modelData.file) : ""
                            fillMode: Image.Stretch
                        }
                        Text { // as in the video: centred, as large as fits
                            anchors.fill: parent
                            anchors.margins: Math.min(parent.width, parent.height) * 0.12
                            visible: !!box.modelData.text
                            text: box.modelData.text || ""
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 200
                            minimumPixelSize: 6
                            fontSizeMode: Text.Fit
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            drag.target: box
                            drag.minimumX: 0
                            drag.minimumY: 0
                            drag.maximumX: editor.width - box.width
                            drag.maximumY: editor.height - box.height
                            onPressed: win.overlayPick = box.index
                            onReleased: box.save()
                        }
                        Rectangle { // resize handle
                            anchors { right: parent.right; bottom: parent.bottom }
                            width: 14
                            height: 14
                            color: box.picked ? accent.color : "#8B98AD"
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.SizeFDiagCursor
                                property real sx
                                property real sy
                                property real sw
                                property real sh
                                onPressed: mouse => {
                                    win.overlayPick = box.index;
                                    const p = mapToItem(editor, mouse.x, mouse.y);
                                    sx = p.x; sy = p.y; sw = box.width; sh = box.height;
                                }
                                onPositionChanged: mouse => {
                                    const p = mapToItem(editor, mouse.x, mouse.y);
                                    box.width = Math.max(16, Math.min(editor.width - box.x, sw + p.x - sx));
                                    box.height = Math.max(16, Math.min(editor.height - box.y, sh + p.y - sy));
                                }
                                onReleased: box.save()
                            }
                        }
                    }
                }
            }
            Row {
                visible: win.overlayPick >= 0 && win.overlayPick < (win.cfg.overlays || []).length
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Text i rutan"
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                }
                FlatField {
                    id: overlayText
                    width: Math.min(560, settingsCol.width - 140)
                    hint: "t.ex. GOBLINCAKES eller Chatten är dold"
                    text: parent.visible ? ((win.cfg.overlays[win.overlayPick] || {}).text || "") : ""
                    onEdited: textSave.restart()
                }
                Timer { // save when you stop typing for a moment
                    id: textSave
                    interval: 600
                    onTriggered: backend.setOverlayText(win.overlayPick, overlayText.text)
                }
            }
            Row { // the picked box: in which games it covers the picture (22 Oct, the user's wish)
                visible: win.overlayPick >= 0 && win.overlayPick < (win.cfg.overlays || []).length
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 4
                    text: "Döljer i"
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                }
                Repeater {
                    model: [{ "id": "wow", "name": "WoW" }, { "id": "cs2", "name": "CS2" }]
                    Choice {
                        required property var modelData
                        readonly property var games: ((win.cfg.overlays || [])[win.overlayPick] || {}).games || ["wow", "cs2"]
                        text: (chosen ? "✓  " : "") + modelData.name
                        sub: "Av: rutan syns inte i filmerna från " + modelData.name + "."
                        chosen: games.indexOf(modelData.id) >= 0
                        onPicked: backend.setOverlayGames(win.overlayPick, JSON.stringify(
                            chosen ? games.filter(g => g !== modelData.id) : games.concat([modelData.id])))
                    }
                }
            }
            Flow {
                width: Math.min(820, settingsCol.width)
                spacing: 10
                FlatButton { text: "Lägg till bild …"; onClicked: backend.addOverlay(true) }
                FlatButton { text: "Lägg till svart ruta"; onClicked: backend.addOverlay(false) }
                FlatButton {
                    visible: win.overlayPick >= 0
                    text: "Byt bild …"
                    onClicked: backend.changeOverlayImage(win.overlayPick)
                }
                FlatButton {
                    visible: win.overlayPick >= 0
                    danger: true
                    text: "Ta bort rutan"
                    onClicked: { backend.removeOverlay(win.overlayPick); win.overlayPick = -1; }
                }
                FlatButton { text: "Uppdatera skärmbilden"; onClicked: backend.refreshPreview() }
            }

        }
    }
    FlatScrollBar { flick: settingsView }

    // The hover explanation (win.showTip), below the item – above it near the bottom edge
    Rectangle {
        id: tipBox
        visible: win.tipText !== "" && !!win.tipItem && win.tipItem.visible
        readonly property point at: win.tipItem ? win.tipItem.mapToItem(win.contentItem, 0, 0) : Qt.point(0, 0)
        width: Math.min(360, tipLabel.implicitWidth + 24)
        height: tipLabel.implicitHeight + 16
        x: Math.max(8, Math.min(win.width - width - 8, at.x))
        y: win.tipItem && at.y + win.tipItem.height + 6 + height > win.height - 8
           ? at.y - height - 6 : at.y + (win.tipItem ? win.tipItem.height : 0) + 6
        z: 100
        color: "#0E1420"
        border.width: 1
        border.color: accent.color
        Text {
            id: tipLabel
            x: 12
            y: 8
            width: Math.min(336, implicitWidth)
            text: win.tipText
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            lineHeight: 1.15
        }
    }

    // The ✕ asks: hide in the system tray or close
    Rectangle {
        visible: win.closeAsk
        anchors.fill: parent
        z: 50
        color: "#B307090D"
        MouseArea { anchors.fill: parent; onClicked: win.closeAsk = false }
        Rectangle {
            anchors.centerIn: parent
            width: 460
            height: askCol.implicitHeight + 48
            color: "#0E1420"
            border.width: 1
            border.color: accent.color
            MouseArea { anchors.fill: parent } // clicks inside don't close it
            Column {
                id: askCol
                x: 24
                y: 24
                width: parent.width - 48
                spacing: 14
                Text {
                    text: "STÄNGA GOBLINRECORDER?"
                    color: "#E6ECF5"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 16
                    font.letterSpacing: 2
                }
                Note {
                    width: parent.width
                    text: "Inspelningen fortsätter i båda fallen – den sköts av en egen tjänst. I systemfältet syns ikonen med en röd prick när något spelas in."
                }
                Row {
                    spacing: 10
                    ToggleSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        on: win.closeRemember
                        onToggled: win.closeRemember = !win.closeRemember
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Kom ihåg mitt val (ändras i Inställningar)"
                        color: "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                }
                Row {
                    spacing: 10
                    FlatButton { primary: true; text: "Göm i systemfältet"; onClicked: win.closeAs("tray") }
                    FlatButton { text: "Stäng"; onClicked: win.closeAs("quit") }
                    FlatButton { text: "Avbryt"; onClicked: win.closeAsk = false }
                }
            }
        }
    }

    // Short messages at the bottom
    Rectangle {
        visible: win.note !== ""
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 24 }
        width: noteText.implicitWidth + 40
        height: 42
        color: "#12203A"
        border.width: 1
        border.color: accent.color
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
