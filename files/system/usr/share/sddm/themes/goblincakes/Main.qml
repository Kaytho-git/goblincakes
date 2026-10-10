// GOBLINCAKES login screen (SDDM): the background as is, date, time, user and password,
// and a choice under the password: Skrivbord (always preselected) or TV-läge.
// No dimming, no blur, no other buttons.
import QtQuick

Item {
    id: root

    // Sizes from a 1920×1080 screen, scaled to the real one
    readonly property real s: height / 1080

    Image {
        anchors.fill: parent
        source: (typeof config !== "undefined" && config && config.background) || "/usr/share/wallpapers/goblincakes/goblincakes-login.svg"
        sourceSize.width: root.width
        sourceSize.height: root.height
        fillMode: Image.PreserveAspectCrop
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

    // An input field: flat, square, dark with a thin frame that turns blue when active
    component Field: Rectangle {
        id: field
        property alias input: input
        property string placeholder
        property Item next: null
        property var keyHandler: null

        width: Math.round(360 * root.s)
        height: Math.round(44 * root.s)
        color: "#0E1420"
        border.width: 1
        border.color: input.activeFocus ? "#2F6FED" : "#1E2A40"

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * root.s)
            anchors.rightMargin: Math.round(14 * root.s)
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: "#E6ECF5"
            selectionColor: "#2F6FED"
            selectedTextColor: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: Math.round(17 * root.s)
            passwordCharacter: "•"
            KeyNavigation.tab: field.next
            Keys.onPressed: event => { if (field.keyHandler) field.keyHandler(event); }
            onTextChanged: root.notice = ""
        }

        Text {
            anchors.fill: input
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0
            text: field.placeholder
            color: "#8B98AD"
            font: input.font
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onPressed: mouse => { input.forceActiveFocus(); mouse.accepted = false; }
        }
    }

    // Error from the last attempt; cleared when typing
    property string notice

    // The session to start: the Plasma desktop unless TV-läge is chosen under the password
    // (never SDDM's lastIndex – a new user has no last session, and SDDM's first one in the
    // list is GOBLINCAKES TV, which put people straight into Steam Big Picture, 10 Oct).
    property int desktopSession: sessionModel.lastIndex
    property int tvSession: -1
    property bool tvMode: false
    Repeater {
        model: sessionModel
        delegate: Item {
            Component.onCompleted: {
                const file = String(model.file || ""), exec = String(model.exec || "");
                if (/(^|\/)plasma\.desktop$/.test(file) || /startplasma-wayland/.test(exec))
                    root.desktopSession = index;
                if (/(^|\/)goblincakes-tv\.desktop$/.test(file) || /goblincakes-tv-session/.test(exec))
                    root.tvSession = index;
            }
        }
    }

    // One half of the session choice: flat, square; the chosen one dark blue with a blue frame
    component Choice: Rectangle {
        id: choice
        property string text
        property bool chosen
        signal picked()
        width: Math.round(180 * root.s)
        height: Math.round(36 * root.s)
        color: chosen ? "#1B3A78" : area.containsMouse ? "#111A2A" : "#0E1420"
        border.width: 1
        border.color: chosen ? "#2F6FED" : "#1E2A40"
        Text {
            anchors.centerIn: parent
            text: choice.text
            color: choice.chosen ? "#E6ECF5" : "#8B98AD"
            font.family: "IBM Plex Sans"
            font.weight: choice.chosen ? Font.DemiBold : Font.Normal
            font.pixelSize: Math.round(15 * root.s)
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { choice.picked(); passwordField.input.forceActiveFocus(); }
        }
    }

    function login() {
        if (userField.input.text.length === 0) {
            userField.input.forceActiveFocus();
            return;
        }
        root.notice = "";
        sddm.login(userField.input.text, passwordField.input.text,
                   root.tvMode && root.tvSession >= 0 ? root.tvSession : root.desktopSession);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordField.input.text = "";
            root.notice = "Fel lösenord";
            passwordField.input.forceActiveFocus();
            shake.restart();
        }
        function onInformationMessage(msg) {
            root.notice = msg;
        }
    }

    // Login block, left of the goblin in the background. Only on the main screen.
    Column {
        id: block
        visible: typeof primaryScreen === "undefined" || primaryScreen
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

        Field {
            id: userField
            placeholder: "Användare"
            input.text: userModel.lastUser
            next: passwordField.input
            input.onAccepted: passwordField.input.forceActiveFocus()
        }

        Field {
            id: passwordField
            placeholder: "Lösenord"
            input.echoMode: TextInput.Password
            next: userField.input
            input.onAccepted: root.login()
            // Left/right arrows in an empty password field switch Skrivbord ↔ TV-läge
            keyHandler: event => {
                if (passwordField.input.text.length === 0 && root.tvSession >= 0
                        && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                    root.tvMode = event.key === Qt.Key_Right;
                    event.accepted = true;
                }
            }
        }

        // What to log in to: the desktop (always preselected) or TV mode (Steam Big Picture)
        Row {
            visible: root.tvSession >= 0
            Choice { text: "Skrivbord"; chosen: !root.tvMode; onPicked: root.tvMode = false }
            Choice { text: "TV-läge"; chosen: root.tvMode; onPicked: root.tvMode = true }
        }

        Text {
            id: message
            // Full width so the block does not jump when a message appears
            width: Math.round(360 * root.s)
            height: Math.round(24 * root.s)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.notice || (typeof keyboard !== "undefined" && keyboard.capsLock ? "Caps Lock är på" : "")
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

    Component.onCompleted: {
        if (userField.input.text.length > 0)
            passwordField.input.forceActiveFocus();
        else
            userField.input.forceActiveFocus();
    }
}
