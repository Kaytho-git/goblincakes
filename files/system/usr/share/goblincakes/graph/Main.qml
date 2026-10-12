// goblin graph – bars, oscilloscope or rolling wave. A window without frame or background
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

    function remember() { graph.saveGeometry(x, y, width, height); }
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
        opacity: hover.hovered ? 0.55 : 0
        border.color: "#1E2A40"
        border.width: 1
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Row {
        id: row
        visible: graph.view === "bars"
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

    // Rolling wave: how loud it is, scrolling from right (now) to left, mirrored round the middle
    Canvas {
        id: roll
        anchors { fill: parent; margins: 6 }
        visible: graph.view === "scroll"
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const col = 4, count = Math.floor(width / col);
            const h = graph.history, start = Math.max(0, h.length - count);
            const mid = height / 2, amp = height / 2 - 4;
            let grad = null;
            if (graph.mode !== "all") {
                grad = ctx.createLinearGradient(0, mid - amp, 0, mid + amp);
                grad.addColorStop(0, graph.classColor);
                grad.addColorStop(0.5, win.rgba(graph.classColor, 0.15));
                grad.addColorStop(1, graph.classColor);
            }
            for (let i = start; i < h.length; i++) {
                const x = width - (h.length - i) * col;
                const v = Math.max(1.5, h[i] * amp);
                ctx.fillStyle = grad ? grad : win.classAt(x, width);
                ctx.fillRect(x, mid - v, col - 1, v * 2);
            }
        }
    }

    Connections {
        target: graph
        function onLevelsChanged() {
            if (graph.view === "scope") scope.requestPaint();
            else if (graph.view === "scroll") roll.requestPaint();
        }
        function onStyleChanged() { scope.requestPaint(); roll.requestPaint(); }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton)
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
        visible: hover.hovered
        text: ({ bars: "Staplar", scope: "Oscilloskop", scroll: "Rullande" })[graph.view] + "  ·  "
              + (graph.mode === "all" ? "Alla klasser" : graph.className)
        color: graph.mode === "all" ? "#E6ECF5" : graph.classColor
        font.family: "Chakra Petch"
        font.weight: Font.DemiBold
        font.pixelSize: 14
        font.letterSpacing: 1.5
    }

    // Close, top right (hover only)
    Rectangle {
        anchors { right: parent.right; top: parent.top; margins: 6 }
        width: 26
        height: 22
        visible: hover.hovered
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

    // Resize, bottom right (hover only)
    Item {
        anchors { right: parent.right; bottom: parent.bottom }
        width: 18
        height: 18
        visible: hover.hovered
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

    Shortcut { sequence: "Esc"; onActivated: Qt.quit() }
}
