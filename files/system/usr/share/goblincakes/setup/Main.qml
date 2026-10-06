// GOBLINCAKES setup window: pick apps, watch them install.
// Flat, square, in the GOBLINCAKES palette. Backend: /usr/bin/goblincakes-setup ("setup").
import QtQuick
import QtQuick.Window

Window {
    id: win

    width: 1180
    height: 800
    minimumWidth: 760
    minimumHeight: 560
    visible: true
    title: "GOBLINCAKES Setup"
    color: "#07090D"

    readonly property var catalog: JSON.parse(setup.catalog)
    property var chosen: ({})
    property int chosenCount: 0
    property string page: "choose" // choose → install → done
    property int failedCount: 0

    function toggle(id) {
        const c = Object.assign({}, chosen);
        if (c[id])
            delete c[id];
        else
            c[id] = true;
        chosen = c;
        chosenCount = Object.keys(c).length;
    }

    function appName(id) {
        for (const a of catalog.apps)
            if (a.id === id)
                return a.name;
        return id;
    }

    function startInstall() {
        page = "install";
        setup.install(JSON.stringify(Object.keys(chosen)));
    }

    function finish() {
        setup.markDone();
        Qt.quit();
    }

    ListModel { id: progressModel }

    Connections {
        target: setup
        function onProgress(id, state, message) {
            for (let i = 0; i < progressModel.count; i++) {
                if (progressModel.get(i).appId === id) {
                    progressModel.set(i, { "status": state, "message": message });
                    return;
                }
            }
            progressModel.append({ "appId": id, "name": win.appName(id), "status": state, "message": message });
        }
        function onAllDone(failed) {
            win.failedCount = failed;
            win.page = "done";
        }
    }

    // ── Pieces ───────────────────────────────────────────────

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

    // Initials on a square tile, instead of icons (most apps aren't installed yet)
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

    // ── Header ───────────────────────────────────────────────

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 132

        Row {
            anchors { left: parent.left; leftMargin: 48; verticalCenter: parent.verticalCenter }
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
                    text: win.page === "choose" ? "VÄLJ DINA PROGRAM"
                        : win.page === "install" ? "INSTALLERAR…" : "KLART"
                    color: "#E6ECF5"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 30
                    font.letterSpacing: 4
                }
                Text {
                    text: win.page === "choose"
                        ? "Kryssa i det du vill ha. Allt går att lägga till senare – sök på GOBLINCAKES Setup i AppGrid."
                        : win.page === "install"
                        ? "Du kan använda datorn under tiden. Stäng inte fönstret."
                        : win.failedCount === 0 ? "Allt är installerat. Programmen finns i AppGrid."
                        : win.failedCount + " program gick inte att installera – öppna GOBLINCAKES Setup igen för att försöka på nytt."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                }
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: "#1E2A40"
        }
    }

    // ── Choose ───────────────────────────────────────────────

    Flickable {
        id: chooser
        visible: win.page === "choose"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: sections.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: sections
            x: 48
            y: 32
            width: chooser.width - 96
            spacing: 34

            Repeater {
                model: win.catalog.categories

                Column {
                    id: section
                    required property var modelData
                    readonly property var apps: win.catalog.apps.filter(a => a.category === modelData.id)
                    readonly property int columns: Math.max(1, Math.floor((sections.width + 16) / 340))

                    width: sections.width
                    spacing: 14

                    Text {
                        text: section.modelData.name.toUpperCase()
                        color: "#8B98AD"
                        font.family: "Chakra Petch"
                        font.weight: Font.DemiBold
                        font.pixelSize: 14
                        font.letterSpacing: 2.5
                    }

                    Grid {
                        columns: section.columns
                        columnSpacing: 16
                        rowSpacing: 16

                        Repeater {
                            model: section.apps

                            Rectangle {
                                id: card
                                required property var modelData
                                readonly property bool installed: modelData.installed
                                readonly property bool checked: !!win.chosen[modelData.id]

                                width: (sections.width - 16 * (section.columns - 1)) / section.columns
                                height: 112
                                color: cardArea.containsMouse && !installed ? "#111A2A" : "#0E1420"
                                border.width: 1
                                border.color: checked ? "#2F6FED" : cardArea.containsMouse && !installed ? "#2A3852" : "#1E2A40"
                                opacity: installed ? 0.55 : 1

                                Monogram {
                                    id: mono
                                    name: card.modelData.name
                                    anchors { left: parent.left; leftMargin: 18; top: parent.top; topMargin: 20 }
                                }

                                Column {
                                    anchors {
                                        left: mono.right; leftMargin: 16
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
                                        text: card.installed ? "Redan installerad" : card.modelData.desc
                                        color: "#8B98AD"
                                        font.family: "IBM Plex Sans"
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        lineHeight: 1.15
                                    }
                                }

                                CheckSquare {
                                    id: check
                                    anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 20 }
                                    checked: card.checked || card.installed
                                }

                                MouseArea {
                                    id: cardArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: card.installed ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: if (!card.installed) win.toggle(card.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Install / done ───────────────────────────────────────

    Flickable {
        id: progressView
        visible: win.page !== "choose"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: rows.height + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: rows
            x: 48
            y: 32
            width: progressView.width - 96
            spacing: 10

            Repeater {
                model: progressModel

                Rectangle {
                    id: row
                    required property string name
                    required property string status
                    required property string message

                    width: rows.width
                    height: 64
                    color: "#0E1420"
                    border.width: 1
                    border.color: status === "running" ? "#2F6FED" : status === "failed" ? "#A4262C" : "#1E2A40"

                    Monogram {
                        id: rowMono
                        name: row.name
                        width: 40
                        height: 40
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        id: rowName
                        anchors { left: rowMono.right; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        width: 200
                        text: row.name
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.DemiBold
                        font.pixelSize: 16
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors {
                            left: rowName.right; leftMargin: 16
                            right: rowState.left; rightMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        text: row.message
                        color: row.status === "failed" ? "#E6ECF5" : "#8B98AD"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    // Waiting: empty square. Running: blue bar sliding. Done: check. Failed: red.
                    Item {
                        id: rowState
                        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        width: row.status === "running" ? 120 : 22
                        height: 22

                        CheckSquare {
                            anchors.right: parent.right
                            visible: row.status === "waiting" || row.status === "done"
                            checked: row.status === "done"
                        }
                        Rectangle {
                            anchors.right: parent.right
                            visible: row.status === "failed"
                            width: 22
                            height: 22
                            color: "#A4262C"
                            Text {
                                anchors.centerIn: parent
                                text: "!"
                                color: "#E6ECF5"
                                font.family: "Chakra Petch"
                                font.weight: Font.Bold
                                font.pixelSize: 15
                            }
                        }
                        Rectangle {
                            visible: row.status === "running"
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 3
                            color: "#12203A"
                            clip: true
                            Rectangle {
                                width: 40
                                height: parent.height
                                color: "#2F6FED"
                                SequentialAnimation on x {
                                    running: row.status === "running"
                                    loops: Animation.Infinite
                                    NumberAnimation { from: -40; to: 120; duration: 1100; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                    }
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
            text: win.chosenCount === 0 ? "Inget valt" : win.chosenCount === 1 ? "1 program valt" : win.chosenCount + " program valda"
            color: "#8B98AD"
            font.family: "IBM Plex Sans"
            font.pixelSize: 15
        }

        Row {
            anchors { right: parent.right; rightMargin: 48; verticalCenter: parent.verticalCenter }
            spacing: 12

            FlatButton {
                visible: win.page === "choose"
                text: "Hoppa över"
                onClicked: win.finish()
            }
            FlatButton {
                visible: win.page === "choose"
                primary: true
                enabledState: win.chosenCount > 0
                text: "Installera"
                onClicked: win.startInstall()
            }
            FlatButton {
                visible: win.page !== "choose"
                primary: true
                enabledState: win.page === "done"
                text: "Klar"
                onClicked: win.finish()
            }
        }
    }
}
