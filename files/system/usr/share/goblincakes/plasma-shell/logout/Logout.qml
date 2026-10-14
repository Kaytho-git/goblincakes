// GOBLINCAKES logout screen: waving goblin, goodbye bubble, log out / restart / shut down
// Copy of the look-and-feel logout screen. Plasma 6.8+ loads the logout UI from
// the shell package instead of look-and-feel, so this file replaces the default
// one shipped by plasma-desktop. Keep both copies identical.
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

    // Sizes from the 1920×1080 design, scaled to the screen
    readonly property real s: height / 1080

    // Button labels in the user's language, using Plasma's own translations
    // (Plasma 6.8+ keeps them in the shell catalog, older versions in the look-and-feel one)
    function tr(text) {
        let t = text;
        if (typeof i18nd === "function") {
            t = i18nd("plasma_shell_org.kde.plasma.desktop", text);
            if (t === text)
                t = i18nd("plasma_lookandfeel_org.kde.lookandfeel", text);
        }
        return t.replace("&", "");
    }

    focus: true
    Keys.onEscapePressed: root.cancelRequested()

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.cancelRequested()
    }

    Row {
        anchors.centerIn: parent
        spacing: Math.round(56 * root.s)

        Image {
            anchors.verticalCenter: parent.verticalCenter
            source: "images/goblin-wave.svg"
            sourceSize.width: Math.round(300 * root.s)
            sourceSize.height: Math.round(260 * root.s)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(18 * root.s)

            // Speech bubble
            Rectangle {
                width: bubble.implicitWidth + Math.round(80 * root.s)
                height: bubble.implicitHeight + Math.round(56 * root.s)
                color: "#0E1420"
                border.color: "#1E2A40"
                border.width: 1

                Column {
                    id: bubble
                    anchors.centerIn: parent
                    spacing: Math.round(14 * root.s)

                    Text {
                        text: "Goodbye!"
                        color: "#E6ECF5"
                        font.family: "Chakra Petch"
                        font.weight: Font.Bold
                        font.pixelSize: Math.round(64 * root.s)
                    }
                    Text {
                        text: "See you next raid!"
                        color: "#8B98AD"
                        font.family: "Chakra Petch"
                        font.weight: Font.DemiBold
                        font.pixelSize: Math.round(30 * root.s)
                    }
                }
            }

            Row {
                spacing: Math.round(12 * root.s)

                GoblinButton {
                    label: root.tr("&Log Out")
                    visible: typeof canLogout === "undefined" || canLogout
                    primary: true
                    onClicked: root.logoutRequested()
                }
                GoblinButton {
                    label: root.tr("&Restart")
                    visible: maysd
                    onClicked: root.rebootRequested()
                }
                GoblinButton {
                    label: root.tr("&Shut Down")
                    visible: maysd
                    onClicked: root.haltRequested()
                }
                GoblinButton {
                    label: root.tr("&Cancel")
                    onClicked: root.cancelRequested()
                }
            }
        }
    }

    // Flat, square buttons like the design's Reset / Apply
    component GoblinButton: Rectangle {
        property string label
        property bool primary: false
        signal clicked()

        width: labelText.implicitWidth + Math.round(44 * root.s)
        height: Math.max(40, Math.round(44 * root.s))
        color: primary ? (area.containsMouse ? "#4A82F0" : "#2F6FED")
                       : (area.containsMouse ? "#12203A" : "transparent")
        border.color: primary ? "transparent" : "#2A3852"
        border.width: 1

        Text {
            id: labelText
            anchors.centerIn: parent
            text: parent.label
            color: primary ? "#FFFFFF" : "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.weight: primary ? Font.Medium : Font.Normal
            font.pixelSize: Math.max(14, Math.round(17 * root.s))
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }
}
