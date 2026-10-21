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

    Views { anchors.fill: parent }

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
        color: closeArea.containsMouse ? accent.error : "transparent"
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
                const c = locked ? accent.color : "#8B98AD";
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
