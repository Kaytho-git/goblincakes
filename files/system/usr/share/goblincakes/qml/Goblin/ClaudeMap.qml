// CLAUDE CODE-kartan (13 Nov): what Claude Code is doing, as a map – the dashboard's middle CLAUDE CODE and the pane
// beside TERMINAL in Goblin AI. The data is claudemap.py's state (claudefeed.py → claudeFeed.state as JSON):
//   `G.ClaudeMap { info: JSON.parse(claudeFeed.state); onPicked: id => claudeFeed.pick(id) }`
// CLAUDE in the middle with the context ring around it, the stations around (you at the top): a call lights its
// station while it runs (clock arcs grow: the inner one a minute round, the outer ten), a spoke grows thicker the
// more its station is used, a thin route joins the last stations (fades after 40 s), errors leave a red dot until
// your next message. Stil: Levande (look.motion) – pulses fly out and back, the answer sends a ring out; Platt and
// during a game – the station only lights up. Under the map: what runs now and the last rows (press one = whole).
import QtQuick

Item {
    id: map
    property var info: ({})
    property bool rowsShown: true
    property int rowsMax: 16
    property string coreName: "CLAUDE"
    property bool chips: true                // the sessions to choose between, over the map
    property real mapShare: 0.58             // how much of the height the drawing may take when rows are shown
    signal picked(string id)

    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    readonly property var order: ["you", "model", "memory", "files", "shell", "net", "browser", "agents", "skills", "hooks"]
    // Kakan's stations have names of their own (claudemap.KakanSession.NAMES: KOMMANDON, NÄTET, SPEL, DATORN …)
    readonly property var names: info.names ? info.names : defaultNames
    readonly property var defaultNames: ({ you: "DU", model: "MODELL", memory: "MINNE", files: "FILER", shell: "SKAL",
                                    net: "NÄTVERK", browser: "WEBBLÄSARE", agents: "AGENTER", skills: "SKILLS",
                                    hooks: "HOOKS" })
    readonly property color memoryColor: "#A78BFA"
    readonly property color amber: "#F0B232"
    readonly property color red: typeof accent !== "undefined" ? accent.errorBright : "#F06B6B"
    readonly property var stations: info.stations || ({})
    readonly property var sessions: info.sessions || []
    readonly property int context: info.context || 0
    property real now: Date.now() / 1000
    property int openRow: -1
    readonly property bool side: rowsShown && width > height * 1.25
    readonly property real topRoom: chipFlow.visible ? chipFlow.height + 8 : 0

    // ── Pulses: events newer than the last seen (claudemap's seq) – none for what was there when it opened ──
    property int lastSeq: -1
    property string lastSession: ""
    property var pulses: []
    onInfoChanged: {
        const ev = info.events || [];
        const top = ev.length ? ev[ev.length - 1].seq : 0;
        if (info.session !== lastSession || lastSeq < 0 || top < lastSeq) {
            lastSession = info.session || "";
            lastSeq = top;
            canvas.requestPaint();
            return;
        }
        const t = Date.now();
        const add = [];
        for (const e of ev)
            if (e.seq > lastSeq)
                add.push({ st: e.st, kind: e.kind, src: e.src, t0: t + add.length * 40 });
        lastSeq = top;
        if (add.length)
            pulses = pulses.concat(add).slice(-40);
        canvas.requestPaint();
    }
    function ringColor(p) { return p >= 90 ? red : p >= 70 ? amber : accent.color; }
    function stColor(st) { return st === "memory" ? memoryColor : accent.color; }
    function length(sec) {
        if (sec === null || sec === undefined || sec < 0.05)
            return "–";
        if (sec < 10)
            return sec.toFixed(1).replace(".", ",") + " s";
        if (sec < 60)
            return Math.round(sec) + " s";
        const s = Math.round(sec);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Timer {   // the clock arcs, the route's fading and "pågår" in the rows
        interval: 1000
        running: map.visible
        repeat: true
        onTriggered: { map.now = Date.now() / 1000; canvas.requestPaint(); }
    }
    Timer {   // frames while something flies (Levande)
        interval: 33
        running: map.visible && map.moving && (map.pulses.length > 0 || !!map.info.busy)
        repeat: true
        onTriggered: {
            const t = Date.now();
            if (map.pulses.length && map.pulses.every(p => t - p.t0 > 1600))
                map.pulses = [];
            canvas.requestPaint();
        }
    }

    // ── The sessions (more than one going on, or one chosen by hand) ──
    Flow {
        id: chipFlow
        visible: map.chips && (map.sessions.length > 1 || !!map.info.picked)
        width: parent.width
        spacing: 6
        Repeater {
            model: map.sessions.concat(map.info.picked ? [{ id: "", folder: "AUTO", on: false, active: false }] : [])
            Rectangle {
                required property var modelData
                width: chipText.implicitWidth + 20
                height: 24
                color: modelData.on ? "#12203A" : chipArea.containsMouse ? "#0E1420" : "transparent"
                border.width: 1
                border.color: modelData.on ? accent.color : "#1E2A40"
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: (modelData.active ? "● " : "") + modelData.folder
                    color: modelData.on ? "#E6ECF5" : "#8B98AD"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 11
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: map.picked(parent.modelData.id)
                }
            }
        }
    }

    // ── The drawing ──
    Item {
        id: drawing
        x: 0
        y: map.topRoom
        // Wide (the dashboard's middle): the drawing to the left, the rows beside it; narrow: the rows under it
        width: map.side ? Math.min(map.height - map.topRoom, map.width * 0.55) : parent.width
        height: map.side ? map.height - map.topRoom
              : map.rowsShown ? Math.min(width * 0.9, (map.height - map.topRoom) * map.mapShare)
              : map.height - map.topRoom - nowLine.height - 8
        readonly property real size: Math.min(width, height)
        readonly property real cx: width / 2
        readonly property real cy: height / 2
        // Room for the names left and right of the ring (Kakan's SKRIVBORDET is longer than SKILLS)
        readonly property real longest: Math.max(...map.order.map(k => String(map.names[k] || "").length))
        readonly property real ring: Math.max(size * 0.22, Math.min(size * 0.36, width / 2 - dot - 22 - longest * labelChar))
        readonly property real labelChar: Math.max(9, Math.min(11, size / 44)) * 0.72
        readonly property real core: Math.max(26, size * 0.12)
        readonly property real dot: Math.max(9, size * 0.034)
        function angle(i) { return -Math.PI / 2 + i * 2 * Math.PI / map.order.length; }
        function px(st) { const i = map.order.indexOf(st); return i < 0 ? cx : cx + ring * Math.cos(angle(i)); }
        function py(st) { const i = map.order.indexOf(st); return i < 0 ? cy : cy + ring * Math.sin(angle(i)); }

        Canvas {
            id: canvas
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const d = drawing, cx = d.cx, cy = d.cy, R = d.ring, r = d.core, sr = d.dot;
                const st = map.stations, now = map.now, t = Date.now();
                const acc = Qt.color(accent.color);
                function rgba(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
                // Spokes: worn thicker and brighter by use
                for (const s of map.order) {
                    const n = (st[s] || {}).n || 0;
                    const x = d.px(s), y = d.py(s);
                    ctx.beginPath();
                    ctx.moveTo(cx, cy);
                    ctx.lineTo(x, y);
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = "#1A2438";
                    ctx.stroke();
                    if (n > 0) {
                        ctx.beginPath();
                        ctx.moveTo(cx, cy);
                        ctx.lineTo(x, y);
                        ctx.lineWidth = Math.min(6, 1 + Math.log(1 + n) / Math.log(2) * 0.8);
                        ctx.strokeStyle = rgba(s === "memory" ? Qt.color(map.memoryColor) : acc, Math.min(0.55, 0.12 + n / 60));
                        ctx.stroke();
                    }
                }
                // The route: the main loop's last stations, each leg 40 s and then fading over 20
                const route = map.info.route || [];
                for (let i = 1; i < route.length; i++) {
                    const age = now - route[i][1];
                    const a = age < 40 ? 0.75 : age < 60 ? 0.75 * (1 - (age - 40) / 20) : 0;
                    if (a <= 0)
                        continue;
                    ctx.beginPath();
                    ctx.moveTo(d.px(route[i - 1][0]), d.py(route[i - 1][0]));
                    ctx.lineTo(d.px(route[i][0]), d.py(route[i][0]));
                    ctx.lineWidth = 1.5;
                    ctx.strokeStyle = rgba(Qt.color("#C3CCDA"), a * 0.6);
                    ctx.stroke();
                }
                // Pulses (Levande): out from the centre (a subagent's from AGENTER), back, red for errors
                const live = [];
                if (map.moving) {
                    for (const p of map.pulses) {
                        const k = (t - p.t0) / (p.kind === "answer" ? 1100 : p.kind === "switch" ? 1500 : 480);
                        if (k < 0 || k > 1) {
                            if (k < 0)
                                live.push(p);
                            continue;
                        }
                        live.push(p);
                        const ox = p.src === "agents" && p.st !== "agents" ? d.px("agents") : cx;
                        const oy = p.src === "agents" && p.st !== "agents" ? d.py("agents") : cy;
                        const x = d.px(p.st), y = d.py(p.st);
                        const e = 1 - Math.pow(1 - k, 3);
                        if (p.kind === "answer" || p.kind === "switch") {
                            const rr = r + e * (p.kind === "answer" ? R * 1.25 : r * 0.8);
                            ctx.beginPath();
                            ctx.arc(cx, cy, rr, 0, 2 * Math.PI);
                            ctx.lineWidth = 2;
                            ctx.strokeStyle = rgba(p.kind === "switch" ? Qt.color(map.amber) : acc, 0.7 * (1 - k));
                            ctx.stroke();
                            if (p.kind === "switch") {
                                ctx.beginPath();
                                ctx.arc(d.px("model"), d.py("model"), sr + 4 + e * 10, 0, 2 * Math.PI);
                                ctx.stroke();
                            }
                            continue;
                        }
                        if (p.kind === "flash") {
                            ctx.beginPath();
                            ctx.arc(x, y, sr + 3 + e * 8, 0, 2 * Math.PI);
                            ctx.lineWidth = 2;
                            ctx.strokeStyle = rgba(p.st === "memory" ? Qt.color(map.memoryColor) : acc, 0.6 * (1 - k));
                            ctx.stroke();
                            continue;
                        }
                        const back = p.kind === "back" || p.kind === "err" || p.kind === "in" || p.kind === "hollow";
                        const f = back ? 1 - e : e;
                        const fx = p.kind === "in" || p.kind === "hollow" ? cx + (x - cx) * f : ox + (x - ox) * f;
                        const fy = p.kind === "in" || p.kind === "hollow" ? cy + (y - cy) * f : oy + (y - oy) * f;
                        ctx.beginPath();
                        ctx.arc(fx, fy, 3.5, 0, 2 * Math.PI);
                        const c = p.kind === "err" ? Qt.color(map.red) : p.st === "memory" ? Qt.color(map.memoryColor) : acc;
                        if (p.kind === "hollow") {
                            ctx.lineWidth = 1.5;
                            ctx.strokeStyle = rgba(c, 1);
                            ctx.stroke();
                        } else {
                            ctx.fillStyle = rgba(c, 1);
                            ctx.fill();
                        }
                    }
                }
                // The centre: the context ring around CLAUDE
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.fillStyle = "#0E1420";
                ctx.fill();
                ctx.lineWidth = 1;
                ctx.strokeStyle = map.info.busy ? acc : "#1E2A40";
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, cy, r + 5, 0, 2 * Math.PI);
                ctx.lineWidth = 3;
                ctx.strokeStyle = "#141C2C";
                ctx.stroke();
                if (map.context > 0) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r + 5, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.min(1, map.context / 100));
                    ctx.strokeStyle = Qt.color(map.ringColor(map.context));
                    ctx.stroke();
                }
                // The stations
                const lit = {};
                for (const p of live)
                    if (p.kind === "flash" || p.kind === "in")
                        lit[p.st] = true;
                for (const s of map.order) {
                    const o = st[s] || {}, x = d.px(s), y = d.py(s);
                    const c = s === "memory" ? Qt.color(map.memoryColor) : acc;
                    const on = (o.run || 0) > 0;
                    ctx.beginPath();
                    ctx.arc(x, y, sr, 0, 2 * Math.PI);
                    ctx.fillStyle = on ? rgba(c, 0.28) : lit[s] && !map.moving ? rgba(c, 0.18) : "#0E1420";
                    ctx.fill();
                    ctx.lineWidth = on ? 2 : 1;
                    ctx.strokeStyle = on || lit[s] ? rgba(c, 1) : (o.n || 0) > 0 ? "#2A3A58" : "#1E2A40";
                    ctx.stroke();
                    if (on) {   // the clock arcs: inner a minute round, outer ten minutes
                        const since = Math.min(...(map.info.running || []).filter(q => q.st === s).map(q => q.since));
                        const el = Math.max(0, now - since);
                        ctx.lineWidth = 2;
                        ctx.strokeStyle = rgba(c, 0.9);
                        ctx.beginPath();
                        ctx.arc(x, y, sr + 4, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * ((el % 60) / 60 || 0.01));
                        ctx.stroke();
                        if (el >= 5) {
                            ctx.strokeStyle = rgba(c, 0.5);
                            ctx.beginPath();
                            ctx.arc(x, y, sr + 8, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.min(1, el / 600));
                            ctx.stroke();
                        }
                    }
                    if ((o.err || 0) > 0) {
                        ctx.beginPath();
                        ctx.arc(x + sr * 0.8, y - sr * 0.8, 4, 0, 2 * Math.PI);
                        ctx.fillStyle = Qt.color(map.red);
                        ctx.fill();
                    }
                }
                // Subagents at work: small dots circling AGENTER
                const agents = map.info.agents || 0;
                for (let i = 0; i < Math.min(8, agents); i++) {
                    const a = t / 1400 * (map.moving ? 1 : 0) + i * 2 * Math.PI / agents;
                    ctx.beginPath();
                    ctx.arc(d.px("agents") + (sr + 12) * Math.cos(a), d.py("agents") + (sr + 12) * Math.sin(a), 2.5, 0, 2 * Math.PI);
                    ctx.fillStyle = acc;
                    ctx.fill();
                }
                if (live.length !== map.pulses.length && live.every(p => t - p.t0 > 1600))
                    Qt.callLater(() => map.pulses = live);
            }
        }
        // The names (Text, sharper than the canvas's): CLAUDE and the context in the middle, each station's name
        // outside its dot with what it has done (and its errors, and ×n while several run)
        Column {
            anchors.centerIn: parent
            // "KONTEXT" over the per cent (14 Nov, the user took it for the quota): how full this session is
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: map.context > 0
                text: "KONTEXT"
                color: "#8B98AD"
                font.family: "Chakra Petch"
                font.pixelSize: Math.max(8, drawing.core * 0.17)
                font.letterSpacing: 1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: map.context > 0
                text: map.context + " %"
                color: map.context >= 70 ? map.ringColor(map.context) : "#8B98AD"
                font.family: "IBM Plex Mono"
                font.pixelSize: Math.max(9, drawing.core * 0.26)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: map.info.core || map.coreName
                color: "#E6ECF5"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: Math.max(10, drawing.core * 0.34)
                font.letterSpacing: 1
            }
        }
        Repeater {
            model: map.order
            Column {
                id: label
                required property string modelData
                required property int index
                readonly property var o: map.stations[modelData] || ({})
                readonly property real a: drawing.angle(index)
                readonly property real lx: drawing.cx + (drawing.ring + drawing.dot + 12) * Math.cos(a)
                readonly property real ly: drawing.cy + (drawing.ring + drawing.dot + 12) * Math.sin(a)
                // Outside the dot: left of it on the left half, right on the right, above/below at the top/bottom
                x: Math.cos(a) > 0.3 ? lx - 4 : Math.cos(a) < -0.3 ? lx - width + 4 : lx - width / 2
                y: Math.sin(a) < -0.6 ? ly - height + 4 : Math.sin(a) > 0.6 ? ly - 4 : ly - height / 2
                Text {
                    anchors.right: Math.cos(label.a) < -0.3 ? parent.right : undefined
                    anchors.horizontalCenter: Math.abs(Math.cos(label.a)) <= 0.3 ? parent.horizontalCenter : undefined
                    text: map.names[label.modelData] + ((label.o.run || 0) > 1 ? "  ×" + label.o.run : "")
                    color: (label.o.run || 0) > 0 ? "#E6ECF5" : (label.o.n || 0) > 0 ? "#C3CCDA" : "#5C6880"
                    font.family: "IBM Plex Sans"
                    font.weight: Font.DemiBold
                    font.pixelSize: Math.max(9, Math.min(11, drawing.size / 44))
                    font.letterSpacing: 0.8
                }
                Text {
                    anchors.right: Math.cos(label.a) < -0.3 ? parent.right : undefined
                    anchors.horizontalCenter: Math.abs(Math.cos(label.a)) <= 0.3 ? parent.horizontalCenter : undefined
                    visible: (label.o.n || 0) > 0 || (label.o.err || 0) > 0 || (label.o.hook || 0) > 0
                    text: (label.o.n || 0) + ((label.o.hook || 0) > 0 ? "  ↓" + label.o.hook : "")
                          + ((label.o.err || 0) > 0 ? "  ✕" + label.o.err : "")
                    color: (label.o.err || 0) > 0 ? map.red : "#8B98AD"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: Math.max(9, Math.min(10, drawing.size / 48))
                }
            }
        }
        Text {
            visible: !!map.info.none
            anchors.centerIn: parent
            anchors.verticalCenterOffset: drawing.core + 40
            text: "Ingen Claude Code-session hittades"
            color: "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: 13
        }
    }

    // ── What runs now, and the last rows ──
    Item {
        id: nowLine
        x: map.side ? drawing.width + 28 : 0
        y: map.side ? map.topRoom : drawing.y + drawing.height + 8
        width: map.width - x
        height: 24
        Text {
            id: nowText
            anchors { left: parent.left; right: nowSide.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
            text: (map.info.busy ? "● " : "· ") + (map.info.now || "")
            color: map.info.busy ? "#E6ECF5" : "#8B98AD"
            font.family: "IBM Plex Mono"
            font.pixelSize: 12
        }
        Text {
            id: nowSide
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: [map.info.folder || "", map.info.model || ""].filter(s => s).join(" · ")
            color: "#5C6880"
            font.family: "IBM Plex Mono"
            font.pixelSize: 11
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1A2438" }
    }
    Column {
        id: rowList
        visible: map.rowsShown
        x: nowLine.x
        y: nowLine.y + nowLine.height + 4
        width: nowLine.width
        height: map.height - y
        clip: true
        Repeater {
            model: (map.info.rows || []).slice(-map.rowsMax).reverse()
            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool open: map.openRow === index
                readonly property var r: modelData
                width: rowList.width
                height: open ? rowLabel.implicitHeight + 8 : 22
                Text {
                    id: rowMark
                    x: 2
                    y: 4
                    text: ({ run: "●", ok: "·", err: "✕", "switch": "◆", answer: "○" })[row.r.state] || "·"
                    color: row.r.state === "err" ? map.red : row.r.state === "run" ? map.stColor(row.r.st)
                         : row.r.state === "switch" ? map.amber : row.r.state === "answer" ? accent.text : "#5C6880"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 12
                }
                Text {
                    id: rowStation
                    x: 18
                    y: 4
                    width: 64
                    text: map.names[row.r.st] || ""
                    color: "#5C6880"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 10
                    font.letterSpacing: 0.6
                    elide: Text.ElideRight
                }
                Text {
                    id: rowLabel
                    x: 86
                    y: 3
                    width: parent.width - x - rowTime.width - 12
                    text: row.r.label + (row.r.n > 0 ? "  +" + row.r.n : "")
                    color: row.r.state === "run" ? "#E6ECF5" : "#C3CCDA"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 11
                    elide: row.open ? Text.ElideNone : Text.ElideRight
                    wrapMode: row.open ? Text.WrapAnywhere : Text.NoWrap
                    maximumLineCount: row.open ? 12 : 1
                }
                Text {
                    id: rowTime
                    anchors.right: parent.right
                    y: 4
                    text: row.r.state === "run" ? map.length(map.now - row.r.start)
                        : row.r.state === "answer" ? map.length(row.r.took)
                        : map.length((row.r.end || row.r.start) - row.r.start)
                    color: "#5C6880"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 10
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: rowLabel.truncated || row.open
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: map.openRow = row.open ? -1 : row.index
                }
            }
        }
    }
}
