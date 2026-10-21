// goblin graph's four views – bars, oscilloscope, circle, explosion – drawn from the backend
// "graph" (goblin-graph's Graph). Used by goblin graph's own window and by GoblinAmp, which
// shows the graph inside its window when the user wants it there (21 Oct).
import QtQuick

Item {
    id: views
    property real barOpacity: 0.3   // see-through bars (the user's wish): the desktop shows through
    property int margin: 6
    readonly property int gap: 3
    readonly property int bars: Math.max(12, Math.min(160, Math.floor(width / 15)))
    onBarsChanged: graph.setBars(bars)
    Component.onCompleted: graph.setBars(bars)

    Row {
        id: row
        visible: graph.view === "bars"
        opacity: views.barOpacity
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: views.margin }
        height: parent.height - 2 * views.margin
        spacing: views.gap

        Repeater {
            model: views.bars
            Item {
                id: bar
                required property int index
                readonly property real level: index < graph.levels.length ? graph.levels[index] : 0
                width: (row.width - (views.bars - 1) * views.gap) / views.bars
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
                                ? graph.classColors[Math.floor(bar.index * 13 / views.bars)] : graph.classColor }
                            GradientStop { position: 1.0; color: graph.mode === "all"
                                ? graph.classColors[Math.floor(bar.index * 13 / views.bars)]
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
        anchors { fill: parent; margins: views.margin }
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
                        ctx.strokeStyle = views.rgba(views.classAt((i - 0.5) * step, width), pass[1]);
                        ctx.beginPath();
                        ctx.moveTo((i - 1) * step, y(i - 1));
                        ctx.lineTo(i * step, y(i));
                        ctx.stroke();
                    }
                }
            } else {
                for (const pass of [[8, 0.25], [2.2, 1]]) {
                    ctx.lineWidth = pass[0];
                    ctx.strokeStyle = views.rgba(graph.classColor, pass[1]);
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
        anchors { fill: parent; margins: views.margin }
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
                    ctx.strokeStyle = views.rgba(c, pass[1]);
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0);
                    ctx.lineTo(cx + Math.cos(a) * (r0 + len), cy + Math.sin(a) * (r0 + len));
                    ctx.stroke();
                }
            }
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = views.rgba(graph.mode === "all" ? "#E6ECF5" : graph.classColor, 0.45);
            ctx.beginPath();
            ctx.arc(cx, cy, r0 - 6, 0, 2 * Math.PI);
            ctx.stroke();
        }
    }

    // Explosion: every beat sends a ring and sparks outwards; the middle glows with the loudness
    Canvas {
        id: burst
        anchors { fill: parent; margins: views.margin }
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
                    ctx.strokeStyle = views.rgba(colour(r[3]), pass[1] * r[1]);
                    ctx.beginPath();
                    ctx.arc(cx, cy, rad, 0, 2 * Math.PI);
                    ctx.stroke();
                }
            }
            ctx.lineWidth = 2.2;
            ctx.lineCap = "round";
            for (const sp of graph.sparks) {
                const d = core + sp[1] * (R - core), len = R * 0.07 * (1 - sp[1] * 0.6);
                ctx.strokeStyle = views.rgba(colour(sp[3]), sp[2]);
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(sp[0]) * d, cy + Math.sin(sp[0]) * d);
                ctx.lineTo(cx + Math.cos(sp[0]) * (d + len), cy + Math.sin(sp[0]) * (d + len));
                ctx.stroke();
            }
            const g = core * (0.6 + graph.glow * 0.9);
            const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, g);
            const mid = all ? "#E6ECF5" : graph.classColor;
            grad.addColorStop(0, views.rgba(mid, 0.25 + 0.7 * graph.glow));
            grad.addColorStop(1, views.rgba(mid, 0));
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
}
