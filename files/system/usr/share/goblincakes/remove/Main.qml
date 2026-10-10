// GOBLINCAKES – uninstall Fedora programs ("goblin remove apps"), in the style of GOBLINCAKES Config.
// Backend: /usr/libexec/goblincakes-remove-apps ("backend"). Pieces (buttons, check boxes …)
// are copies of the ones in config/Main.qml – change both.
import QtQuick
import QtQuick.Window

Window {
    id: win

    width: 1180
    height: 800
    minimumWidth: 760
    minimumHeight: 560
    visible: true
    title: "Avinstallera program – GOBLINCAKES"
    color: "#07090D"

    readonly property var lists: JSON.parse(backend.programs)
    readonly property var apps: lists.apps
    readonly property var removed: lists.removed
    property string tab: startTab // apps | removed
    property string page: "choose" // choose → working → done
    property var toRemove: ({})
    property var toRestore: ({})
    readonly property int removeCount: Object.keys(toRemove).length
    readonly property int restoreCount: Object.keys(toRestore).length
    property bool ok: true
    property string lastLine: ""
    property string summary: "" // what happens at the restart, in names

    function flip(map, key) {
        const m = Object.assign({}, map);
        if (m[key])
            delete m[key];
        else
            m[key] = true;
        return m;
    }

    function names(list, chosen) {
        return list.filter(a => chosen[a.package]).map(a => a.name).join(", ");
    }

    function apply() {
        const gone = names(apps, toRemove), back = names(removed, toRestore);
        summary = (gone ? "Avinstalleras: " + gone : "") + (gone && back ? "\n" : "") + (back ? "Kommer tillbaka: " + back : "");
        page = "working";
        lastLine = "";
        backend.apply(JSON.stringify(Object.keys(toRemove)), JSON.stringify(Object.keys(toRestore)));
    }

    function back() {
        toRemove = {};
        toRestore = {};
        page = "choose";
    }

    Connections {
        target: backend
        function onProgress(line) { win.lastLine = line; }
        function onDone(ok) {
            win.ok = ok;
            win.page = "done";
        }
    }

    // ── Pieces (same as GOBLINCAKES Config) ──────────────────

    // Mouse wheel: each notch moves the list a fixed step at once (Flickable's own wheel
    // handling only gives it a small push that slows down – sluggish on a real computer)
    component FastWheel: WheelHandler {
        required property Flickable flick
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
            const top = flick.originY, bottom = top + Math.max(0, flick.contentHeight - flick.height);
            flick.cancelFlick();
            flick.contentY = Math.max(top, Math.min(bottom, flick.contentY - delta));
            event.accepted = true;
        }
    }

    component FlatButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        property bool enabledState: true
        signal clicked()

        width: Math.max(150, label.implicitWidth + 48)
        height: 44
        opacity: enabledState ? 1 : 0.4
        color: primary ? (area.containsMouse && enabledState ? "#4A82F0" : "#2F6FED")
                       : (area.containsMouse && enabledState ? "#1A2438" : "transparent")
        border.width: primary ? 0 : 1
        border.color: "#2A3852"

        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.weight: Font.Medium
            font.pixelSize: 15
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.enabledState) btn.clicked()
        }
    }

    // Square check box, filled blue with a check mark when on
    component CheckSquare: Rectangle {
        property bool checked
        width: 22
        height: 22
        color: checked ? "#2F6FED" : "transparent"
        border.width: checked ? 0 : 1
        border.color: "#2A3852"
        Canvas {
            anchors.fill: parent
            visible: parent.checked
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = "#E6ECF5";
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                ctx.moveTo(5.5, 11.5);
                ctx.lineTo(9.5, 15.5);
                ctx.lineTo(16.5, 7);
                ctx.stroke();
            }
        }
    }

    component Monogram: Rectangle {
        property string name
        width: 48
        height: 48
        color: "#12203A"
        border.width: 1
        border.color: "#1E2A40"
        Text {
            anchors.centerIn: parent
            text: {
                const words = parent.name.replace(/[^A-Za-z0-9 .-]/g, "").split(/[ .-]+/).filter(w => w.length);
                return (words.length > 1 ? words[0][0] + words[1][0] : parent.name.slice(0, 2)).toUpperCase();
            }
            color: "#E6ECF5"
            font.family: "Chakra Petch"
            font.weight: Font.Bold
            font.pixelSize: 18
        }
    }

    // Flat, square scroll bar along the right edge of a list – only when it doesn't fit
    component FlatScrollBar: Item {
        id: bar
        required property Flickable flick
        readonly property bool needed: flick.visible && flick.contentHeight > flick.height + 1
        anchors { right: flick.right; rightMargin: 6; top: flick.top; topMargin: 6; bottom: flick.bottom; bottomMargin: 6 }
        width: 8
        visible: needed
        z: 2

        Rectangle {
            anchors.fill: parent
            color: "#0E1420"
        }

        MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
                const ratio = Math.max(0, Math.min(1, (mouse.y - handle.height / 2) / (bar.height - handle.height)));
                bar.flick.contentY = ratio * (bar.flick.contentHeight - bar.flick.height);
            }
        }

        Rectangle {
            id: handle
            width: parent.width
            height: Math.max(32, bar.flick.visibleArea.heightRatio * bar.height)
            y: bar.flick.visibleArea.yPosition / Math.max(0.0001, 1 - bar.flick.visibleArea.heightRatio)
               * (bar.height - height)
            color: handleArea.pressed ? "#2F6FED" : handleArea.containsMouse ? "#8B98AD" : "#2A3852"

            MouseArea {
                id: handleArea
                anchors.fill: parent
                hoverEnabled: true
                property real startY
                property real startContentY
                onPressed: mouse => {
                    startY = mapToItem(bar, 0, mouse.y).y;
                    startContentY = bar.flick.contentY;
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const dy = mapToItem(bar, 0, mouse.y).y - startY;
                    const span = bar.flick.contentHeight - bar.flick.height;
                    const y = startContentY + dy * span / Math.max(1, bar.height - handle.height);
                    bar.flick.contentY = Math.max(0, Math.min(span, y));
                }
            }
        }
    }

    // The program's own icon, or its initials when the icon theme doesn't have one
    component AppIcon: Item {
        property string icon
        property string name
        property bool hasIcon
        width: 48
        height: 48
        Image {
            anchors.fill: parent
            visible: parent.hasIcon
            source: parent.hasIcon ? "image://icon/" + parent.icon : ""
            sourceSize.width: 96
            sourceSize.height: 96
            smooth: true
        }
        Monogram {
            visible: !parent.hasIcon
            name: parent.name
        }
    }

    component SectionTitle: Text {
        color: "#8B98AD"
        font.family: "Chakra Petch"
        font.weight: Font.DemiBold
        font.pixelSize: 14
        font.letterSpacing: 2.5
    }

    component Note: Text {
        color: "#8B98AD"
        font.family: "IBM Plex Sans"
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        lineHeight: 1.15
    }

    // ── Header ───────────────────────────────────────────────

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 176

        Row {
            anchors { left: parent.left; leftMargin: 48; top: parent.top; topMargin: 30 }
            spacing: 22

            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: logoUrl
                sourceSize.width: 64
                sourceSize.height: 64
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    text: win.page === "working" ? "ARBETAR…"
                        : win.page === "done" ? (win.ok ? "KLART" : "NÅGOT GICK FEL")
                        : win.tab === "removed" ? "AVINSTALLERADE" : "AVINSTALLERA PROGRAM"
                    color: "#E6ECF5"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 30
                    font.letterSpacing: 4
                }
                Text {
                    text: win.page === "working" ? "Stäng inte fönstret. Systemet frågar kanske efter ditt lösenord."
                        : win.page === "done" ? (win.ok ? "Ändringarna gäller efter en omstart – fram till dess ser allt ut som förut."
                                                       : "Allt gick inte igenom – se meddelandet nedan. Det som gick bra gäller efter en omstart.")
                        : win.tab === "removed" ? "Kryssa i det du vill ha tillbaka. Det kommer tillbaka efter en omstart."
                        : "Kryssa i det du inte vill ha. Det försvinner efter en omstart och går att få tillbaka."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                }
            }
        }

        // Tabs
        Row {
            anchors { left: parent.left; leftMargin: 48; bottom: parent.bottom }
            spacing: 32
            visible: win.page === "choose"

            Repeater {
                model: [{ "id": "apps", "label": "PROGRAM" },
                        { "id": "removed", "label": "AVINSTALLERADE" + (win.removed.length ? " (" + win.removed.length + ")" : "") }]

                Item {
                    id: tabItem
                    required property var modelData
                    readonly property bool active: win.tab === modelData.id
                    width: tabLabel.implicitWidth
                    height: 44

                    Text {
                        id: tabLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: tabItem.modelData.label
                        color: tabItem.active || tabArea.containsMouse ? "#E6ECF5" : "#8B98AD"
                        font.family: "Chakra Petch"
                        font.weight: Font.DemiBold
                        font.pixelSize: 15
                        font.letterSpacing: 2.5
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 2
                        color: "#2F6FED"
                        visible: tabItem.active
                    }
                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.tab = tabItem.modelData.id
                    }
                }
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: "#1E2A40"
            z: -1
        }
    }

    // ── Programs that can be uninstalled ─────────────────────

    Flickable {
        id: appsView
        FastWheel { flick: appsView }
        visible: win.page === "choose" && win.tab === "apps"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: appsColumn.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: appsColumn
            x: 48
            y: 32
            width: appsView.width - 96
            spacing: 14
            readonly property int columns: Math.max(1, Math.floor((width + 16) / 340))

            Note {
                width: parent.width
                text: "Programmen som följer med Fedora och GOBLINCAKES. Det som skrivbordet behöver finns inte med. "
                      + "Vill du bara slippa se ett program räcker det att dölja det: goblin apps i terminalen."
            }

            Grid {
                columns: appsColumn.columns
                columnSpacing: 16
                rowSpacing: 16

                Repeater {
                    model: win.apps

                    Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool checked: !!win.toRemove[modelData.package]

                        width: (appsColumn.width - 16 * (appsColumn.columns - 1)) / appsColumn.columns
                        height: 112
                        color: cardArea.containsMouse ? "#111A2A" : "#0E1420"
                        border.width: 1
                        border.color: checked ? "#A4262C" : cardArea.containsMouse ? "#2A3852" : "#1E2A40"

                        AppIcon {
                            id: icon
                            icon: card.modelData.icon
                            name: card.modelData.name
                            hasIcon: card.modelData.hasIcon
                            anchors { left: parent.left; leftMargin: 18; top: parent.top; topMargin: 20 }
                        }

                        Column {
                            anchors {
                                left: icon.right; leftMargin: 16
                                right: check.left; rightMargin: 14
                                top: parent.top; topMargin: 18
                            }
                            spacing: 5

                            Text {
                                width: parent.width
                                text: card.modelData.name
                                color: "#E6ECF5"
                                font.family: "IBM Plex Sans"
                                font.weight: Font.DemiBold
                                font.pixelSize: 16
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: (card.modelData.hidden ? "Dold i appmenyn · " : "")
                                      + (card.modelData.comment || card.modelData.package)
                                      + (card.modelData.others.length ? " (även " + card.modelData.others.join(", ") + ")" : "")
                                color: "#8B98AD"
                                font.family: "IBM Plex Sans"
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                lineHeight: 1.15
                            }
                        }

                        // Red when ticked: this one goes
                        CheckSquare {
                            id: check
                            anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 20 }
                            checked: card.checked
                            color: checked ? "#A4262C" : "transparent"
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.toRemove = win.flip(win.toRemove, card.modelData.package)
                        }
                    }
                }
            }
        }
    }
    FlatScrollBar { flick: appsView }

    // ── Uninstalled programs: tick to bring back ─────────────

    Flickable {
        id: removedView
        FastWheel { flick: removedView }
        visible: win.page === "choose" && win.tab === "removed"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: removedColumn.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: removedColumn
            x: 48
            y: 32
            width: removedView.width - 96
            spacing: 12

            Note {
                visible: win.removed.length === 0
                width: parent.width
                text: "Inget är avinstallerat – allt från GOBLINCAKES finns kvar."
            }

            Repeater {
                model: win.removed

                Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool restoring: modelData.state === "restoring"
                    readonly property bool checked: !!win.toRestore[modelData.package]

                    width: removedColumn.width
                    height: 76
                    color: rowArea.containsMouse && !restoring ? "#111A2A" : "#0E1420"
                    border.width: 1
                    border.color: checked ? "#2F6FED" : rowArea.containsMouse && !restoring ? "#2A3852" : "#1E2A40"
                    opacity: restoring ? 0.6 : 1

                    AppIcon {
                        id: rowIcon
                        icon: row.modelData.icon
                        name: row.modelData.name
                        hasIcon: row.modelData.hasIcon
                        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                    }
                    Column {
                        anchors { left: rowIcon.right; leftMargin: 16; right: rowCheck.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Text {
                            width: parent.width
                            text: row.modelData.name
                            color: "#E6ECF5"
                            font.family: "IBM Plex Sans"
                            font.weight: Font.DemiBold
                            font.pixelSize: 16
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: row.restoring ? "Kommer tillbaka vid nästa omstart"
                                : row.modelData.state === "removing" ? "Försvinner vid nästa omstart · paket " + row.modelData.package
                                : "Avinstallerat · paket " + row.modelData.package
                            color: "#8B98AD"
                            font.family: "IBM Plex Sans"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        anchors { right: rowCheck.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        visible: !row.restoring
                        text: "Återställ"
                        color: row.checked ? "#E6ECF5" : "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 13
                    }
                    CheckSquare {
                        id: rowCheck
                        visible: !row.restoring
                        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        checked: row.checked
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: row.restoring ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: if (!row.restoring) win.toRestore = win.flip(win.toRestore, row.modelData.package)
                    }
                }
            }
        }
    }
    FlatScrollBar { flick: removedView }

    // ── Working / done ───────────────────────────────────────

    Column {
        visible: win.page !== "choose"
        anchors { left: parent.left; leftMargin: 48; right: parent.right; rightMargin: 48; top: header.bottom; topMargin: 40 }
        spacing: 16

        Text {
            width: parent.width
            visible: win.page === "done" && win.ok
            text: win.summary
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: 16
            wrapMode: Text.WordWrap
            lineHeight: 1.3
        }
        Text {
            width: parent.width
            visible: !(win.page === "done" && win.ok)
            text: win.lastLine
            color: win.page === "done" && !win.ok ? "#DC464C" : "#8B98AD"
            font.family: "IBM Plex Mono"
            font.pixelSize: 13
            wrapMode: Text.WrapAnywhere
        }
        // A thin running line while rpm-ostree works
        Rectangle {
            visible: win.page === "working"
            width: parent.width
            height: 3
            color: "#12203A"
            Rectangle {
                id: runner
                width: parent.width / 4
                height: parent.height
                color: "#2F6FED"
                SequentialAnimation on x {
                    running: win.page === "working"
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: runner.parent.width - runner.width; duration: 1100; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: runner.parent.width - runner.width; to: 0; duration: 1100; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    // ── Footer ───────────────────────────────────────────────

    Rectangle {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 84
        color: "#0B1018"

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1
            color: "#1E2A40"
        }

        Text {
            anchors { left: parent.left; leftMargin: 48; verticalCenter: parent.verticalCenter }
            visible: win.page === "choose"
            text: {
                const parts = [];
                if (win.removeCount)
                    parts.push(win.removeCount + " att avinstallera");
                if (win.restoreCount)
                    parts.push(win.restoreCount + " att återställa");
                return parts.length ? parts.join(" · ") : "Inget valt";
            }
            color: "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: 15
        }

        Row {
            anchors { right: parent.right; rightMargin: 48; verticalCenter: parent.verticalCenter }
            spacing: 12

            FlatButton {
                visible: win.page === "done"
                text: "Tillbaka"
                onClicked: win.back()
            }
            FlatButton {
                visible: win.page !== "working"
                text: "Stäng"
                onClicked: Qt.quit()
            }
            FlatButton {
                visible: win.page === "choose"
                primary: true
                enabledState: win.removeCount + win.restoreCount > 0
                text: "Verkställ"
                onClicked: win.apply()
            }
            FlatButton {
                visible: win.page === "done"
                primary: true
                text: "Starta om nu"
                onClicked: backend.reboot()
            }
        }
    }
}
