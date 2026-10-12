// goblin graph – the bars. A window without frame or background (flags + transparent colour),
// among the other windows. Drag = move, bottom-right corner = resize, right-click = all
// classes ↔ one class, wheel = another class, Esc = close. Hovering shows a faint backdrop,
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
        onWheel: wheel => graph.stepClass(wheel.angleDelta.y > 0 ? -1 : 1)
    }

    // What is shown, top left (hover only)
    Text {
        anchors { left: parent.left; top: parent.top; margins: 10 }
        visible: hover.hovered
        text: graph.mode === "all" ? "Alla klasser" : graph.className
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
