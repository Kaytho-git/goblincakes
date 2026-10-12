// goblin graph – bars, oscilloscope, circle or explosion. A window without frame or background
// (flags + transparent colour), among the other windows. Drag = move, bottom-right corner =
// resize, double-click = next view, right-click = all classes ↔ one class, wheel = another
// class, Esc = close. Hovering shows a faint backdrop,
// the class name and a close button, so the window can be found while it is quiet.
import QtQuick

Window {
    id: win
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: "goblin graph"
    visible: true
    width: saved.w || 720
    height: saved.h || 220
    x: saved.x !== undefined ? saved.x : (Screen.width - width) / 2
    y: saved.y !== undefined ? saved.y : Screen.height - height - 140
    minimumWidth: 160
    minimumHeight: 60

    readonly property int gap: 3
    readonly property int bars: Math.max(12, Math.min(160, Math.floor(width / 15)))
    onBarsChanged: graph.setBars(bars)
    Component.onCompleted: graph.setBars(bars)

    function remember() { graph.saveGeometry(graph.shape, x, y, width, height); }

    // The circle and the explosion want a square window: each shape keeps its own size/place
    property string shape: graph.shape
    property string lastShape: graph.shape
    onShapeChanged: {
        if (shape === lastShape)
            return;
        graph.saveGeometry(lastShape, x, y, width, height);
        lastShape = shape;
        const g = graph.geometryFor(shape);
        const cx = x + width / 2, cy = y + height / 2;
        if (g.length) {
            width = g[2]; height = g[3]; x = g[0]; y = g[1];
        } else if (shape === "round") {
            const s = Math.max(320, Math.min(width, height));
            width = s; height = s; x = cx - s / 2; y = cy - s / 2;
        } else {
            width = 720; height = 220; x = cx - 360; y = cy - 110;
        }
        saveLater.stop();
    }
    Timer { id: saveLater; interval: 600; onTriggered: win.remember() }
    onXChanged: saveLater.restart()
    onYChanged: saveLater.restart()
    onWidthChanged: saveLater.restart()
    onHeightChanged: saveLater.restart()

    Connections {
        target: graph
        function onRaiseWindow() { win.show(); win.raise(); win.requestActivate(); }
    }

    // Only while the pointer is over the window: where it is, what it shows, how to close
    Rectangle {
        anchors.fill: parent
        color: "#0B1018"
        opacity: hover.hovered && !graph.locked ? 0.55 : 0   // locked: no box round it
        border.color: "#1E2A40"
        border.width: 1
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Row {
        id: row
        visible: graph.view === "bars"
        opacity: 0.3   // see-through bars (the user's wish): the desktop shows through
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
        height: parent.height - 12
        spacing: win.gap

        Repeater {
            model: win.bars
            Item {
                id: bar
                required property int index
                readonly property real level: index < graph.levels.length ? graph.levels[index] : 0
                width: (row.width - (win.bars - 1) * win.gap) / win.bars
                height: row.height
                // At least a thin line, so the bars show where the window is when it's quiet
                Item {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: Math.max(3, bar.level * bar.height)
                    clip: true
                    // The colour depends on the height (the gradient spans the whole window):
                    // one class = the class colour at the top, fading out towards the bottom
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: bar.height
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: graph.mode === "all"
                                ? graph.classColors[Math.floor(bar.index * 13 / win.bars)] : graph.classColor }
                            GradientStop { position: 1.0; color: graph.mode === "all"
                                ? graph.classColors[Math.floor(bar.index * 13 / win.bars)]
                                : Qt.rgba(Qt.color(graph.classColor).r, Qt.color(graph.classColor).g,
                                          Qt.color(graph.classColor).b, 0.12) }  // fades into whatever is behind
                        }
                    }
                }
            }
        }
    }

    function rgba(c, a) { const q = Qt.color(c); return Qt.rgba(q.r, q.g, q.b, a); }
    function classAt(x, w) { return graph.classColors[Math.min(12, Math.floor(x * 13 / Math.max(1, w)))]; }

    // Oscilloscope: the sound wave itself, held still by triggering on a rising zero crossing
    Canvas {
        id: scope
        anchors { fill: parent; margins: 6 }
        visible: graph.view === "scope"
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = graph.wave, n = w.length;
            if (n < 2) return;
            const mid = height / 2, amp = height / 2 - 4, step = width / (n - 1);
            const y = i => mid - w[i] * amp;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            if (graph.mode === "all") {
                // Segment by segment, coloured by where on the width it is (13 classes side by side)
                for (const pass of [[7, 0.22], [2.2, 1]]) {
                    ctx.lineWidth = pass[0];
                    for (let i = 1; i < n; i++) {
                        ctx.strokeStyle = win.rgba(win.classAt((i - 0.5) * step, width), pass[1]);
                        ctx.beginPath();
                        ctx.moveTo((i - 1) * step, y(i - 1));
                        ctx.lineTo(i * step, y(i));
                        ctx.stroke();
                    }
                }
            } else {
                for (const pass of [[8, 0.25], [2.2, 1]]) {
                    ctx.lineWidth = pass[0];
                    ctx.strokeStyle = win.rgba(graph.classColor, pass[1]);
                    ctx.beginPath();
                    ctx.moveTo(0, y(0));
                    for (let i = 1; i < n; i++) ctx.lineTo(i * step, y(i));
                    ctx.stroke();
                }
            }
        }
    }

    // Circle: bars around a ring, growing outwards – bass at the top and bottom, treble at the sides
    Canvas {
        id: circle
        anchors { fill: parent; margins: 6 }
        visible: graph.view === "circle"
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const lv = graph.levels, half = lv.length;
            if (half < 2) return;
            const spokes = half * 4, cx = width / 2, cy = height / 2;
            const R = Math.min(width, height) / 2 - 4, r0 = R * 0.42;
            const thick = Math.max(2, 2 * Math.PI * r0 / spokes * 0.55);
            ctx.lineCap = "butt";
            for (const pass of [[2.4, 0.18], [1, 1]]) {
                ctx.lineWidth = thick * pass[0];
                for (let i = 0; i < spokes; i++) {
                    const j = i % (half * 2), k = j < half ? j : half * 2 - 1 - j;
                    const a = -Math.PI / 2 + (i + 0.5) * 2 * Math.PI / spokes;
                    const len = 3 + lv[k] * (R - r0 - 3);
                    const c = graph.mode === "all" ? graph.classColors[Math.floor(i * 13 / spokes)] : graph.classColor;
                    ctx.strokeStyle = win.rgba(c, pass[1]);
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0);
                    ctx.lineTo(cx + Math.cos(a) * (r0 + len), cy + Math.sin(a) * (r0 + len));
                    ctx.stroke();
                }
            }
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = win.rgba(graph.mode === "all" ? "#E6ECF5" : graph.classColor, 0.45);
            ctx.beginPath();
            ctx.arc(cx, cy, r0 - 6, 0, 2 * Math.PI);
            ctx.stroke();
        }
    }

    // Explosion: every beat sends a ring and sparks outwards; the middle glows with the loudness
    Canvas {
        id: burst
        anchors { fill: parent; margins: 6 }
        visible: graph.view === "burst"
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height / 2, R = Math.min(width, height) / 2 - 4;
            const core = R * 0.12, all = graph.mode === "all";
            const colour = i => all ? graph.classColors[i] : graph.classColor;
            for (const r of graph.rings) {
                const rad = core + r[0] * (R - core);
                for (const pass of [[10, 0.18], [2.5, 1]]) {
                    ctx.lineWidth = pass[0] * r[2];
                    ctx.strokeStyle = win.rgba(colour(r[3]), pass[1] * r[1]);
                    ctx.beginPath();
                    ctx.arc(cx, cy, rad, 0, 2 * Math.PI);
                    ctx.stroke();
                }
            }
            ctx.lineWidth = 2.2;
            ctx.lineCap = "round";
            for (const sp of graph.sparks) {
                const d = core + sp[1] * (R - core), len = R * 0.07 * (1 - sp[1] * 0.6);
                ctx.strokeStyle = win.rgba(colour(sp[3]), sp[2]);
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(sp[0]) * d, cy + Math.sin(sp[0]) * d);
                ctx.lineTo(cx + Math.cos(sp[0]) * (d + len), cy + Math.sin(sp[0]) * (d + len));
                ctx.stroke();
            }
            const g = core * (0.6 + graph.glow * 0.9);
            const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, g);
            const mid = all ? "#E6ECF5" : graph.classColor;
            grad.addColorStop(0, win.rgba(mid, 0.25 + 0.7 * graph.glow));
            grad.addColorStop(1, win.rgba(mid, 0));
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(cx, cy, g, 0, 2 * Math.PI);
            ctx.fill();
        }
    }

    Connections {
        target: graph
        function onLevelsChanged() {
            const c = ({ scope: scope, circle: circle, burst: burst })[graph.view];
            if (c) c.requestPaint();
        }
        function onStyleChanged() {
            for (const c of [scope, circle, burst]) c.requestPaint();
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        enabled: !graph.locked
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton && !graph.locked)
                win.startSystemMove();
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                graph.toggleMode();
        }
        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                graph.cycleView();
        }
        onWheel: wheel => graph.stepClass(wheel.angleDelta.y > 0 ? -1 : 1)
    }

    // What is shown, top left (hover only)
    Text {
        anchors { left: parent.left; top: parent.top; margins: 10 }
        visible: hover.hovered && !graph.locked
        text: ({ bars: "Staplar", scope: "Oscilloskop", circle: "Cirkel", burst: "Explosion" })[graph.view] + "  ·  "
              + (graph.mode === "all" ? "Alla klasser" : graph.className)
        color: graph.mode === "all" ? "#E6ECF5" : graph.classColor
        font.family: "Chakra Petch"
        font.weight: Font.DemiBold
        font.pixelSize: 14
        font.letterSpacing: 1.5
    }
    // What is playing, in the middle (12 Oct, the user's wish) – also when locked, then it is
    // the only thing that shows. A dark outline keeps it readable over the bars.
    Text {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 40)
        visible: hover.hovered && graph.nowPlaying !== ""
        text: "♪  " + graph.nowPlaying
        color: "#E6ECF5"
        style: Text.Outline
        styleColor: "#07090D"
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font.family: "IBM Plex Sans"
        font.weight: Font.Medium
        font.pixelSize: 15
    }

    // Close, top right (hover only; locked = can't be closed by accident)
    Rectangle {
        anchors { right: parent.right; top: parent.top; margins: 6 }
        width: 26
        height: 22
        visible: hover.hovered && !graph.locked
        color: closeArea.containsMouse ? "#A4262C" : "transparent"
        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "#E6ECF5"
            font.pixelSize: 13
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.quit()
        }
    }

    // Lock, left of the close button (hover only). Locked (the user's wish) = nothing to see or
    // click in the window – no box, buttons, moving, resizing, closing or switching; only
    // goblin graph lås upp in the terminal unlocks
    Rectangle {
        anchors { right: parent.right; top: parent.top; topMargin: 6; rightMargin: 36 }
        width: 26
        height: 22
        visible: hover.hovered && !graph.locked
        color: lockArea.containsMouse ? "#1A2438" : "transparent"
        Canvas {
            id: padlock
            anchors.centerIn: parent
            width: 14
            height: 16
            property bool locked: graph.locked
            onLockedChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = locked ? "#2F6FED" : "#8B98AD";
                ctx.fillStyle = c;
                ctx.fillRect(1, 7, 12, 9);                    // body
                ctx.strokeStyle = c;
                ctx.lineWidth = 2;
                ctx.beginPath();                             // shackle, open to the right when unlocked
                ctx.moveTo(3.5, 7);
                ctx.lineTo(3.5, 4);
                ctx.arc(7, 4, 3.5, Math.PI, 0, false);
                ctx.lineTo(10.5, locked ? 7 : 5);
                ctx.stroke();
            }
        }
        MouseArea {
            id: lockArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: graph.toggleLock()
        }
    }

    // Resize, bottom right (hover only, not when locked)
    Item {
        anchors { right: parent.right; bottom: parent.bottom }
        width: 18
        height: 18
        visible: hover.hovered && !graph.locked
        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.strokeStyle = "#8B98AD";
                ctx.lineWidth = 1.5;
                for (const d of [6, 11, 16]) {
                    ctx.beginPath();
                    ctx.moveTo(width - d, height - 2);
                    ctx.lineTo(width - 2, height - d);
                    ctx.stroke();
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeFDiagCursor
            onPressed: win.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
        }
    }

    Shortcut { sequence: "Esc"; enabled: !graph.locked; onActivated: Qt.quit() }
}
