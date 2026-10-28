// GOBLINCAKES lagmätare: live graphs while it measures (28 Oct, the user's wish) – on the screen the
// game isn't on (KWin's goblincakes-windows script), never on top of the game.
import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 470
    height: 690
    minimumWidth: 380
    minimumHeight: 520
    visible: true
    title: "Lagmätning"
    color: "#07090D"

    readonly property var d: JSON.parse(meter.data || "{}")
    readonly property var rows: d.rows || []
    readonly property var marks: d.marks || []
    readonly property real tEnd: rows.length ? rows[rows.length - 1].t : 0
    readonly property int span: 120  // seconds shown

    function num(v, unit) {
        if (v === undefined || v === null) return "–"
        return (v < 10 && v % 1 ? v.toFixed(1).replace(".", ",") : Math.round(v)) + (unit ? " " + unit : "")
    }
    function last(key) {
        for (var i = rows.length - 1; i >= 0; i--)
            if (rows[i][key] !== undefined) return rows[i][key]
        return undefined
    }

    Shortcut { sequence: "Esc"; onActivated: root.close() }
    Connections {
        target: meter
        function onRaiseWindow() { root.show(); root.raise(); root.requestActivate() }
    }

    component FlatButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        signal clicked()
        width: Math.max(130, label.implicitWidth + 40)
        height: 40
        color: primary ? (area.containsMouse ? accent.hover : accent.color)
                       : (area.containsMouse ? "#1A2438" : "transparent")
        border.width: primary ? 0 : 1
        border.color: "#2A3852"
        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: btn.primary ? accent.on : "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.weight: Font.Medium
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

    // One graph: up to two lines (main in the accent, the other muted) over the last `span` seconds,
    // red ticks at the top where `bad` is true, a red line at every "laggar nu"
    component Graph: Rectangle {
        id: g
        property string name
        property string value
        property string key
        property string key2: ""
        property real floor: 100
        property bool fixed: false   // 0–floor always (percent)
        property var bad: null       // function(row) → true = red tick
        height: 112
        color: "#0B1018"
        border.width: 1
        border.color: "#1E2A40"

        Text {
            x: 12; y: 8
            text: g.name
            color: "#8B98AD"
            font.family: "Chakra Petch"
            font.pixelSize: 13
            font.letterSpacing: 1
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 12; y: 7
            text: g.value
            color: "#E6ECF5"
            font.family: "IBM Plex Mono"
            font.pixelSize: 13
        }
        Canvas {
            id: canvas
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: parent.top
                      leftMargin: 10; rightMargin: 10; topMargin: 30; bottomMargin: 8 }
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "#1A2438"
                ctx.lineWidth = 1
                for (var q = 0; q <= 2; q++) {
                    var gy = Math.round(height * q / 2) + 0.5
                    ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
                }
                var rows = root.rows
                if (!rows.length) return
                var top = g.floor
                if (!g.fixed)
                    for (var i = 0; i < rows.length; i++) {
                        if (rows[i][g.key] > top) top = rows[i][g.key]
                        if (g.key2 && rows[i][g.key2] > top) top = rows[i][g.key2]
                    }
                var t0 = root.tEnd - root.span
                function xOf(t) { return (t - t0) / root.span * width }
                function yOf(v) { return height - Math.min(v / top, 1) * (height - 2) - 1 }
                ctx.strokeStyle = accent.errorBright
                ctx.lineWidth = 2
                for (var m = 0; m < root.marks.length; m++) {
                    var mx = Math.round(xOf(root.marks[m])) + 0.5
                    if (mx < 0) continue
                    ctx.beginPath(); ctx.moveTo(mx, 0); ctx.lineTo(mx, height); ctx.stroke()
                }
                if (g.bad) {
                    ctx.fillStyle = accent.errorBright
                    for (var b = 0; b < rows.length; b++)
                        if (g.bad(rows[b])) ctx.fillRect(xOf(rows[b].t) - 2, 0, 4, 6)
                }
                function line(key, colour, w) {
                    ctx.strokeStyle = colour
                    ctx.lineWidth = w
                    ctx.beginPath()
                    var started = false
                    for (var k = 0; k < rows.length; k++) {
                        var v = rows[k][key]
                        if (v === undefined) { started = false; continue }
                        var x = xOf(rows[k].t), y = yOf(v)
                        if (started) ctx.lineTo(x, y); else { ctx.moveTo(x, y); started = true }
                    }
                    ctx.stroke()
                }
                if (g.key2) line(g.key2, "#8B98AD", 1)
                line(g.key, accent.color, 2)
                ctx.fillStyle = "#5A6A85"
                ctx.font = "11px 'IBM Plex Mono'"
                ctx.fillText(Math.round(top), 2, 11)
            }
            Connections { target: meter; function onDataChanged() { canvas.requestPaint() } }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Row {
            width: parent.width
            spacing: 10
            Rectangle {
                width: 10; height: 10
                anchors.verticalCenter: parent.verticalCenter
                color: root.d.running ? accent.errorBright : "#5A6A85"
                SequentialAnimation on opacity {
                    running: !!root.d.running
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700 }
                    NumberAnimation { to: 1; duration: 700 }
                }
            }
            Text {
                text: root.d.running ? "MÄTER" : "MÄTNINGEN STOPPAD"
                color: "#E6ECF5"
                font.family: "Chakra Petch"
                font.weight: Font.Bold
                font.pixelSize: 20
                font.letterSpacing: 1.5
            }
        }
        Text {
            width: parent.width
            text: (root.d.game ? root.d.game : "inget spel") + "  ·  ping mot " + (root.d.server || "–")
                  + (root.d.started ? "  ·  sedan " + root.d.started : "")
            color: "#8B98AD"
            elide: Text.ElideRight
            font.family: "IBM Plex Sans"
            font.pixelSize: 13
        }

        Graph {
            width: parent.width
            name: "PING"
            key: "ping"; key2: "ping_home"
            value: root.num(root.last("ping"), "ms") + "  ·  router " + root.num(root.last("ping_home"), "ms")
            bad: function (r) { return (r.ping_lost || 0) + (r.ping_home_lost || 0) > 0 }
        }
        Graph {
            width: parent.width
            name: "PROCESSOR"
            key: "cpu"; key2: "cpu_max"; fixed: true
            value: root.num(root.last("cpu"), "%") + "  ·  kärna " + root.num(root.last("cpu_max"), "%")
                   + "  ·  " + root.num(root.last("cpu_temp"), "°C")
        }
        Graph {
            width: parent.width
            name: "GRAFIKKORT"
            key: "gpu"; fixed: true
            value: root.num(root.last("gpu"), "%") + "  ·  " + root.num(root.last("gpu_mhz"), "MHz")
                   + "  ·  " + root.num(root.last("gpu_temp"), "°C")
            bad: function (r) { return ((r.gpu_why || 0) & 0xE8) !== 0 }  // slows down: heat, power brake
        }
        Graph {
            width: parent.width
            name: "DISK"
            key: "disk_read_mb"; key2: "disk_write_mb"; floor: 50
            value: "läser " + root.num(root.last("disk_read_mb"), "") + "  ·  skriver "
                   + root.num(root.last("disk_write_mb"), "MB/s") + "  ·  swap "
                   + root.num((root.last("swap_mb") || 0) / 1024, "GB")
        }
        Text {
            width: parent.width
            text: "Mest processor: " + ((root.last("top") || []).map(function (p) { return p[0] + " " + p[1] + " %" })
                                        .join(", ") || "–")
            color: "#8B98AD"
            elide: Text.ElideRight
            font.family: "IBM Plex Sans"
            font.pixelSize: 13
        }
        Row {
            spacing: 10
            FlatButton { text: "Laggar nu"; primary: true; onClicked: meter.mark() }
            FlatButton {
                text: root.d.running ? "Stoppa" : "Stäng"
                onClicked: root.d.running ? meter.stop() : root.close()
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Röd linje = laggar nu (Meta+Shift+L). Fråga sedan Goblin AI: \"varför laggade det?\""
            color: "#5A6A85"
            font.family: "IBM Plex Sans"
            font.pixelSize: 12
        }
    }
}
