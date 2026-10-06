// GOBLINCAKES lock screen: the wallpaper as is, date, time, user name and password.
// No dimming, no blur, no extra buttons. The wallpaper itself is drawn by kscreenlocker
// behind this item (from kscreenlockerrc).
import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

Item {
    id: root

    // Magic properties and signals kscreenlocker looks for
    property bool debug: false
    property string notification
    property bool viewVisible: false
    signal clearPassword()
    signal notificationRepeated()

    implicitWidth: 800
    implicitHeight: 600

    // Sizes from a 1920×1080 screen, scaled to the real one
    readonly property real s: height / 1080

    // Set when PAM let us in without asking for a password; Enter then unlocks
    property bool unlockReady: false

    function unlock() {
        if (root.unlockReady) {
            Qt.quit();
            return;
        }
        if (password.text.length === 0)
            return;
        authenticator.respond(password.text);
    }

    onClearPassword: password.text = ""

    Connections {
        target: authenticator
        function onFailed(kind) {
            // A fingerprint or smartcard reader, not the password (older Plasma sends no kind)
            if (kind !== undefined && kind != 0)
                return;
            password.text = "";
            root.notification = "Fel lösenord";
            authenticator.startAuthenticating();
            shake.restart();
        }
        function onSucceeded() {
            if (authenticator.hadPrompt)
                Qt.quit();
            else
                root.unlockReady = true;
        }
        function onErrorMessageChanged() {
            if (authenticator.errorMessage)
                root.notification = authenticator.errorMessage;
        }
        function onPromptForSecretChanged() {
            password.forceActiveFocus();
        }
    }

    // Keeps PAM ready to receive the password
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: authenticator.startAuthenticating()
    }

    // Updates the clock
    Timer {
        id: clock
        property date now: new Date()
        interval: 1000
        repeat: true
        running: true
        onTriggered: now = new Date()
    }

    KeyboardIndicator.KeyState {
        id: capsLock
        key: Qt.Key_CapsLock
    }

    MouseArea {
        anchors.fill: parent
        onPressed: password.forceActiveFocus()
    }

    // Block left of the goblin in the wallpaper
    Column {
        id: block
        x: Math.round(root.width * 0.3 - width / 2)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(12 * root.s)
        transform: Translate { id: shakeOffset }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.now, "HH:mm")
            color: "#E6ECF5"
            font.family: "Chakra Petch"
            font.weight: Font.Bold
            font.pixelSize: Math.round(112 * root.s)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const d = Qt.locale().toString(clock.now, "dddd d MMMM");
                return d.charAt(0).toUpperCase() + d.slice(1);
            }
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: Math.round(24 * root.s)
        }

        Item { width: 1; height: Math.round(40 * root.s) }

        // User name: flat, square, same look as the field but not editable
        Rectangle {
            width: Math.round(360 * root.s)
            height: Math.round(44 * root.s)
            color: "#0E1420"
            border.width: 1
            border.color: "#1E2A40"

            Text {
                anchors.fill: parent
                anchors.leftMargin: Math.round(14 * root.s)
                anchors.rightMargin: Math.round(14 * root.s)
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: kscreenlocker_userName
                color: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.pixelSize: Math.round(17 * root.s)
            }
        }

        // Password: border turns blue when active
        Rectangle {
            width: Math.round(360 * root.s)
            height: Math.round(44 * root.s)
            color: "#0E1420"
            border.width: 1
            border.color: password.activeFocus ? "#2F6FED" : "#1E2A40"

            TextInput {
                id: password
                anchors.fill: parent
                anchors.leftMargin: Math.round(14 * root.s)
                anchors.rightMargin: Math.round(14 * root.s)
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                focus: true
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: "#E6ECF5"
                selectionColor: "#2F6FED"
                selectedTextColor: "#E6ECF5"
                font.family: "IBM Plex Sans"
                font.pixelSize: Math.round(17 * root.s)
                onTextChanged: if (text.length > 0) root.notification = ""
                onAccepted: root.unlock()
                Keys.onEscapePressed: text = ""
            }

            Text {
                anchors.fill: password
                verticalAlignment: Text.AlignVCenter
                visible: password.text.length === 0
                text: "Lösenord"
                color: "#8B98AD"
                font: password.font
            }
        }

        Text {
            // Full width so the block does not jump when a message appears
            width: Math.round(360 * root.s)
            height: Math.round(24 * root.s)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.notification || (capsLock.locked ? "Caps Lock är på" : "")
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: Math.round(15 * root.s)
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeOffset; property: "x"; to: -12 * root.s; duration: 50 }
        NumberAnimation { target: shakeOffset; property: "x"; to: 12 * root.s; duration: 80 }
        NumberAnimation { target: shakeOffset; property: "x"; to: -6 * root.s; duration: 70 }
        NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 50 }
    }

    Component.onCompleted: password.forceActiveFocus()
}
