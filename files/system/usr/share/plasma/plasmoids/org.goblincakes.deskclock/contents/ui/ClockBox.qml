/*
    The clock box of the desktop row, after the mockup "Skrivbordet utan docka" (9 Nov): the mouse's (keyboard's,
    controller's) battery – ethernet – the clock with the date and week under it – sound – the headset's battery –
    Kakan (13 Nov).
    Only the look; main.qml gives it the values and does what the clicks ask. Plain Qt Quick (no Plasma imports),
    so it can be tried without a desktop.
*/
import QtQuick

Rectangle {
    id: box
    property date now: new Date()
    property int week: 1
    property var net: ({ kind: "ethernet", name: "" })   // kind: ethernet / wifi / offline
    property int volume: -1                              // -1 = no sound output
    property bool muted: false
    property bool volumeShown: false                     // just changed: the % under the icon
    property var leftDevices: []                         // [{kind, name, percent, charging}]
    property var rightDevices: []
    // Kakan, farthest right (13 Nov, the user: something on the right as big as the mouse's battery – "a check for
    // Kakan, loaded or not", drawn like the mouse icon, the cupcake chosen): "" = no local AI (hidden), ready /
    // loading / idle (not in memory) / resting (a game runs) / off (Ollama not answering)
    property string kakan: ""
    property color accent: "#2F6FED"
    // The size (10 Nov, the user: the mockup's size was too big on the real desktop; 11 Nov: 20 % smaller again, both
    // looks) – every measure below is times s
    property real s: 0.6
    // Stil: Levande (Levande utseende step 6, 11 Nov – the user: "ingen ram"): tinted glass instead of the dark box –
    // #0B1018 at 62 %, no frame, a faint light line in the top edge. Platt: the dark box with its frame as before.
    property bool glass: false

    readonly property alias clockItem: clock
    readonly property alias netItem: netButton
    readonly property alias soundItem: soundButton
    readonly property alias leftItem: leftBatteries
    readonly property alias rightItem: rightBatteries
    readonly property alias kakanItem: kakanButton

    signal clockClicked()
    signal netClicked()
    signal soundClicked(int button)
    signal soundWheeled(int delta)
    signal kakanClicked()

    readonly property color frost: "#E6ECF5"
    readonly property color dimText: "#8B98AD"

    function level(percent) {
        // 24 Oct, the user's choice (the top bar): orange 11–49 %, red at 10 % and below – otherwise muted as in the mockup
        return percent <= 10 ? "#E5484D" : percent < 50 ? "#D9822B" : dimText;
    }
    function soundIcon() {
        return volume < 0 || muted || volume === 0 ? "sound-muted" : volume < 50 ? "sound-low" : "sound-high";
    }

    implicitWidth: content.implicitWidth + Math.round(44 * box.s)
    implicitHeight: content.implicitHeight + Math.round(20 * box.s)
    color: glass ? Qt.rgba(0.043, 0.063, 0.094, 0.62) : "#0B1018"
    border.width: glass ? 0 : 1
    border.color: "#1E2A40"
    Rectangle {
        visible: box.glass
        width: parent.width
        height: 1
        color: Qt.rgba(0.902, 0.925, 0.961, 0.07)
    }

    component Battery: Row {
        id: bat
        property var device
        property bool iconFirst: true
        spacing: Math.round(6 * box.s)
        layoutDirection: iconFirst ? Qt.LeftToRight : Qt.RightToLeft
        DeskIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: bat.device.kind
            size: Math.round(18 * box.s)
            color: box.level(bat.device.percent)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (bat.device.charging ? "⚡" : "") + bat.device.percent + " %"
            color: box.level(bat.device.percent)
            font.family: "IBM Plex Sans"
            font.pixelSize: Math.max(9, Math.round(12 * box.s))
        }
    }

    component IconButton: Item {
        id: button
        property string icon
        property string below: ""
        signal clicked(int button)
        signal wheeled(int delta)
        width: Math.round(44 * box.s)
        height: Math.round(44 * box.s)
        Rectangle {
            anchors.fill: parent
            color: area.containsMouse ? "#1A2438" : "transparent"
        }
        DeskIcon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: button.below ? -Math.round(5 * box.s) : 0
            size: Math.round(22 * box.s)
            name: button.icon
            color: box.frost
        }
        Text {
            visible: button.below !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: button.below
            color: box.dimText
            font.family: "IBM Plex Sans"
            font.pixelSize: Math.max(9, Math.round(10 * box.s))
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => button.clicked(mouse.button)
            onWheel: wheel => button.wheeled(wheel.angleDelta.y)
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Math.round(22 * box.s)

        // An Item around the Row: main.qml puts a ToolTipArea (anchors.fill) in leftItem – inside a Row that
        // warned "Cannot specify … anchors for items inside Row" and the tooltip didn't cover the batteries
        Item {
            id: leftBatteries
            visible: box.leftDevices.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: leftRow.implicitWidth
            height: leftRow.implicitHeight
            Row {
                id: leftRow
                spacing: Math.round(14 * box.s)
                Repeater {
                    model: box.leftDevices
                    Battery { required property var modelData; device: modelData; iconFirst: true }
                }
            }
        }

        IconButton {
            id: netButton
            anchors.verticalCenter: parent.verticalCenter
            icon: box.net.kind || "offline"
            onClicked: box.netClicked()
        }

        Item {
            id: clock
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: clockText.implicitWidth
            implicitHeight: clockText.implicitHeight
            width: implicitWidth
            height: implicitHeight
            Column {
                id: clockText
                spacing: Math.round(2 * box.s)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(box.now, "HH:mm")
                    color: box.frost
                    font.family: "Chakra Petch"
                    font.weight: Font.DemiBold
                    font.pixelSize: Math.round(34 * box.s)
                    lineHeight: 0.9
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.locale("sv_SE").toString(box.now, "dddd d MMMM") + " · v. " + box.week
                    color: box.dimText
                    font.family: "IBM Plex Sans"
                    font.pixelSize: Math.max(9, Math.round(13 * box.s))
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: box.clockClicked()
            }
        }

        IconButton {
            id: soundButton
            anchors.verticalCenter: parent.verticalCenter
            icon: box.soundIcon()
            below: box.volumeShown && box.volume >= 0 ? (box.muted ? "tyst" : box.volume + " %") : ""
            onClicked: button => box.soundClicked(button)
            onWheeled: delta => box.soundWheeled(delta)
        }

        // An Item around the Row: main.qml puts a ToolTipArea (anchors.fill) in rightItem – inside a Row that
        // warned "Cannot specify … anchors for items inside Row" and the tooltip didn't cover the batteries
        Item {
            id: rightBatteries
            visible: box.rightDevices.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: rightRow.implicitWidth
            height: rightRow.implicitHeight
            Row {
                id: rightRow
                spacing: Math.round(14 * box.s)
                Repeater {
                    model: box.rightDevices
                    Battery { required property var modelData; device: modelData; iconFirst: false }
                }
            }
        }

        Item {
            id: kakanButton
            visible: box.kakan !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: kakanRow.implicitWidth + Math.round(12 * box.s)
            height: Math.round(44 * box.s)
            readonly property color tint: box.kakan === "ready" ? box.accent
                                          : box.kakan === "resting" || box.kakan === "off" ? Qt.darker(box.dimText, 1.6) : box.dimText
            Rectangle {
                anchors.fill: parent
                color: kakanArea.containsMouse ? "#1A2438" : "transparent"
            }
            Row {
                id: kakanRow
                anchors.centerIn: parent
                spacing: Math.round(6 * box.s)
                DeskIcon {
                    id: cupcake
                    anchors.verticalCenter: parent.verticalCenter
                    name: box.kakan === "ready" ? "cupcake" : "cupcake-off"
                    size: Math.round(18 * box.s)
                    color: kakanButton.tint
                    // Loading: breathes until she is in memory
                    SequentialAnimation on opacity {
                        running: box.kakan === "loading"
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) cupcake.opacity = 1
                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // As wide as the longest word, so the clock doesn't move when her state changes
                    width: Math.ceil(longest.advanceWidth)
                    TextMetrics { id: longest; font: parent.font; text: "Ej laddad" }
                    text: ({ ready: "Redo", loading: "Laddar", idle: "Ej laddad", resting: "Vilar", off: "Av" })[box.kakan] || ""
                    color: kakanButton.tint
                    font.family: "IBM Plex Sans"
                    font.pixelSize: Math.max(9, Math.round(12 * box.s))
                }
            }
            MouseArea {
                id: kakanArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: box.kakanClicked()
            }
        }
    }
}
