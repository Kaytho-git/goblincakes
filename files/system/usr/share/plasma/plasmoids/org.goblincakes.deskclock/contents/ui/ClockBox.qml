/*
    The clock box of the desktop row, after the mockup "Skrivbordet utan docka" (9 Nov): the mouse's (keyboard's,
    controller's) battery – ethernet – the clock with the date and week under it – sound – the headset's battery.
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

    readonly property alias clockItem: clock
    readonly property alias netItem: netButton
    readonly property alias soundItem: soundButton
    readonly property alias leftItem: leftBatteries
    readonly property alias rightItem: rightBatteries

    signal clockClicked()
    signal netClicked()
    signal soundClicked(int button)
    signal soundWheeled(int delta)

    readonly property color frost: "#E6ECF5"
    readonly property color dimText: "#8B98AD"

    function level(percent) {
        // 24 Oct, the user's choice (the top bar): orange 11–49 %, red at 10 % and below – otherwise muted as in the mockup
        return percent <= 10 ? "#E5484D" : percent < 50 ? "#D9822B" : dimText;
    }
    function soundIcon() {
        return volume < 0 || muted || volume === 0 ? "sound-muted" : volume < 50 ? "sound-low" : "sound-high";
    }

    implicitWidth: content.implicitWidth + 44
    implicitHeight: content.implicitHeight + 20
    color: "#0B1018"
    border.width: 1
    border.color: "#1E2A40"

    component Battery: Row {
        id: bat
        property var device
        property bool iconFirst: true
        spacing: 6
        layoutDirection: iconFirst ? Qt.LeftToRight : Qt.RightToLeft
        DeskIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: bat.device.kind
            size: 18
            color: box.level(bat.device.percent)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (bat.device.charging ? "⚡" : "") + bat.device.percent + " %"
            color: box.level(bat.device.percent)
            font.family: "IBM Plex Sans"
            font.pixelSize: 12
        }
    }

    component IconButton: Item {
        id: button
        property string icon
        property string below: ""
        signal clicked(int button)
        signal wheeled(int delta)
        width: 44
        height: 44
        Rectangle {
            anchors.fill: parent
            color: area.containsMouse ? "#1A2438" : "transparent"
        }
        DeskIcon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: button.below ? -5 : 0
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
            font.pixelSize: 10
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
        spacing: 22

        Row {
            id: leftBatteries
            visible: box.leftDevices.length > 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Repeater {
                model: box.leftDevices
                Battery { required property var modelData; device: modelData; iconFirst: true }
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
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(box.now, "HH:mm")
                    color: box.frost
                    font.family: "Chakra Petch"
                    font.weight: Font.DemiBold
                    font.pixelSize: 34
                    lineHeight: 0.9
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.locale("sv_SE").toString(box.now, "dddd d MMMM") + " · v. " + box.week
                    color: box.dimText
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 13
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

        Row {
            id: rightBatteries
            visible: box.rightDevices.length > 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Repeater {
                model: box.rightDevices
                Battery { required property var modelData; device: modelData; iconFirst: false }
            }
        }
    }
}
