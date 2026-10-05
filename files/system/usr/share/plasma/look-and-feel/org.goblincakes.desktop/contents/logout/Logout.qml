// GOBLINCAKES logout screen: waving goblin + log out / restart / shut down
import QtQuick

Item {
    id: root

    // The logout greeter connects to these signals by name
    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    focus: true
    Keys.onEscapePressed: root.cancelRequested()

    Rectangle {
        anchors.fill: parent
        color: "#0c1a3a"
        opacity: 0.96
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.cancelRequested()
    }

    Column {
        anchors.centerIn: parent
        spacing: 24

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "images/goblin-wave.svg"
            sourceSize.width: Math.round(root.height / 3)
            sourceSize.height: Math.round(root.height / 3)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Hejdå! Vi syns nästa raid!"
            color: "#e6e9f0"
            font.pixelSize: Math.round(root.height / 28)
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            GoblinButton {
                label: "Logga ut"
                visible: typeof canLogout === "undefined" || canLogout
                primary: true
                onClicked: root.logoutRequested()
            }
            GoblinButton {
                label: "Starta om"
                visible: maysd
                onClicked: root.rebootRequested()
            }
            GoblinButton {
                label: "Stäng av"
                visible: maysd
                onClicked: root.haltRequested()
            }
            GoblinButton {
                label: "Avbryt"
                onClicked: root.cancelRequested()
            }
        }
    }

    component GoblinButton: Rectangle {
        property string label
        property bool primary: false
        signal clicked()

        width: Math.max(140, labelText.implicitWidth + 40)
        height: 44
        radius: 6
        color: primary ? (area.containsMouse ? "#3b82f6" : "#1d4ed8")
                       : (area.containsMouse ? "#1c2334" : "#161c2a")
        border.color: "#1c2334"

        Text {
            id: labelText
            anchors.centerIn: parent
            text: parent.label
            color: primary ? "#ffffff" : "#e6e9f0"
            font.pixelSize: 16
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }
}
