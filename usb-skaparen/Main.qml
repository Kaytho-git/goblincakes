// GOBLINCAKES USB – makes an install USB stick (Windows and Linux), in the style of GOBLINCAKES Config.
// Backend: goblincakes_usb.py next to this file ("backend"). FlatButton, CheckSquare and
// FlatScrollBar are copies of the ones in /usr/share/goblincakes/config/Main.qml – change both.
import QtQuick
import QtQuick.Window

Window {
    id: win

    width: 980
    height: 720
    minimumWidth: 720
    minimumHeight: 600
    visible: true
    title: "GOBLINCAKES USB"
    color: "#07090D"

    readonly property var manifest: JSON.parse(backend.manifest)
    readonly property var variants: manifest.variants || []
    readonly property var drives: JSON.parse(backend.drives)
    readonly property var gpu: JSON.parse(backend.gpu)
    property string variantId: ""
    property string device: ""
    property bool understood: false
    property string page: "choose" // choose → working → done | failed
    property real progressValue: 0
    property string progressText: ""
    property string retryText: ""
    property string errorText: ""

    readonly property var variant: variants.find(v => v.id === variantId) || null
    readonly property bool hasNvidiaIso: variants.some(v => v.id === "live-nvidia")
    readonly property string suggestedId: suggest(variants)
    // The graphics card in this computer decides the suggestion (the stick may be for another one)
    function suggest(list) {
        if (gpu.nvidiaSupported && list.some(v => v.id === "live-nvidia")) return "live-nvidia";
        return list.some(v => v.id === "live-base") ? "live-base" : "";
    }
    readonly property var drive: drives.find(d => d.device === device) || null

    function gb(bytes) { return (bytes / 1e9).toFixed(1).replace(".", ",") + " GB"; }
    function bigEnough(d) { return !!variant && d.size >= variant.size; }

    Component.onCompleted: {
        backend.loadManifest();
        backend.refreshDrives();
    }
    onVariantsChanged: if (!variantId && variants.length) variantId = suggest(variants) || variants[0].id

    Timer { interval: 3000; running: win.page === "choose"; repeat: true; onTriggered: backend.refreshDrives() }

    Connections {
        target: backend
        function onProgress(stage, value, text) {
            if (stage === "retry") { win.retryText = text; return; }
            win.retryText = "";
            win.progressValue = value;
            win.progressText = text;
        }
        function onFinished(ok, message) {
            win.errorText = message;
            win.page = ok ? "done" : "failed";
        }
    }

    // ── Pieces (same as GOBLINCAKES Config) ──────────────────

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

    component Label: Text {
        color: "#8B98AD"
        font.family: "IBM Plex Sans"
        font.pixelSize: 14
        wrapMode: Text.WordWrap
        lineHeight: 1.15
    }

    component SectionTitle: Text {
        color: "#8B98AD"
        font.family: "Chakra Petch"
        font.weight: Font.DemiBold
        font.pixelSize: 14
        font.letterSpacing: 2.5
    }

    // Card you pick one of (ISO kind, USB stick)
    component Choice: Rectangle {
        id: choice
        property string title
        property string detail
        property bool selected
        property bool usable: true
        property bool suggested: false
        signal picked()
        height: choiceColumn.height + 30
        color: area.containsMouse && usable ? "#111A2A" : "#0E1420"
        border.width: selected ? 2 : 1
        border.color: selected ? "#2F6FED" : area.containsMouse && usable ? "#2A3852" : "#1E2A40"
        opacity: usable ? 1 : 0.45
        Column {
            id: choiceColumn
            anchors { left: parent.left; leftMargin: 20; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 5
            Row {
                width: parent.width
                spacing: 10
                Text {
                    width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 10 : 0))
                    text: choice.title
                    color: "#E6ECF5"
                    font.family: "IBM Plex Sans"
                    font.weight: Font.DemiBold
                    font.pixelSize: 16
                    elide: Text.ElideRight
                }
                Rectangle {
                    id: badge
                    visible: choice.suggested
                    anchors.verticalCenter: parent.verticalCenter
                    width: badgeText.implicitWidth + 14
                    height: 20
                    color: "#1B3A78"
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: "FÖRESLÅS FÖR DEN HÄR DATORN"
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.weight: Font.DemiBold
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }
                }
            }
            Text {
                width: parent.width
                text: choice.detail
                color: "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: choice.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (choice.usable) choice.picked()
        }
    }

    // ── Header ───────────────────────────────────────────────

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 132
        Row {
            anchors { left: parent.left; leftMargin: 40; verticalCenter: parent.verticalCenter }
            spacing: 20
            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: logoUrl
                sourceSize.width: 56
                sourceSize.height: 56
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    text: win.page === "working" ? "SKAPAR USB-MINNET…" : win.page === "done" ? "KLART" : win.page === "failed" ? "DET GICK INTE" : "GOBLINCAKES USB"
                    color: "#E6ECF5"
                    font.family: "Chakra Petch"
                    font.weight: Font.Bold
                    font.pixelSize: 28
                    font.letterSpacing: 4
                }
                Text {
                    text: win.page === "working" ? "Låt USB-minnet sitta kvar och datorn vara på."
                        : win.page === "done" ? "USB-minnet är redo att installera GOBLINCAKES."
                        : win.page === "failed" ? "Inget är förstört – du kan försöka igen."
                        : "Gör ett USB-minne som installerar GOBLINCAKES."
                    color: "#8B98AD"
                    font.family: "IBM Plex Sans"
                    font.pixelSize: 15
                }
            }
        }
        Text {
            anchors { right: parent.right; rightMargin: 40; top: parent.top; topMargin: 28 }
            visible: !!win.manifest.version
            text: "ISO " + (win.manifest.version || "")
            color: "#8B98AD"
            font.family: "IBM Plex Mono"
            font.pixelSize: 13
        }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: "#1E2A40" }
    }

    // ── Choose ───────────────────────────────────────────────

    Flickable {
        id: chooser
        visible: win.page === "choose"
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top }
        contentHeight: chooseColumn.height + 56
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: chooseColumn
            x: 40
            y: 28
            width: chooser.width - 80
            spacing: 14

            SectionTitle { text: "1. VAD SKA USB-MINNET GÖRA?" }
            Label {
                visible: !!win.manifest.error
                width: parent.width
                color: "#DC464C"
                text: win.manifest.error || ""
            }
            Label {
                visible: !win.manifest.error && win.variants.length === 0
                width: parent.width
                text: win.manifest.variants ? "Ingen ISO finns att hämta just nu." : "Hämtar listan över ISO:er…"
            }
            Repeater {
                model: win.variants
                Choice {
                    required property var modelData
                    width: chooseColumn.width
                    title: modelData.name + "  ·  " + win.gb(modelData.size)
                    detail: modelData.description + " Kräver ett USB-minne på minst " + modelData.minUsb + " GB."
                    selected: win.variantId === modelData.id
                    suggested: modelData.id === win.suggestedId && win.variants.length > 1
                    onPicked: win.variantId = modelData.id
                }
            }

            // Graphics card: only a suggestion – the stick may be for another computer
            Rectangle {
                width: chooseColumn.width
                height: gpuColumn.height + 28
                color: "#0B1018"
                border.width: 1
                border.color: "#1E2A40"
                Column {
                    id: gpuColumn
                    x: 18
                    y: 14
                    width: parent.width - 36
                    spacing: 4
                    Text {
                        width: parent.width
                        text: "Grafikkort i den här datorn: " + (win.gpu.cards && win.gpu.cards.length ? win.gpu.cards.join(", ") : "okänt")
                        color: "#E6ECF5"
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        width: parent.width
                        font.pixelSize: 13
                        text: (win.gpu.nvidiaSupported
                            ? (win.hasNvidiaIso
                               ? "Nvidia GTX 16xx/RTX 20xx eller nyare: Nvidia-ISO:n föreslås – drivrutinerna finns med från start."
                               : "Nvidia GTX 16xx/RTX 20xx eller nyare: Nvidia-drivrutinerna hämtas automatiskt efter första starten.")
                            : win.gpu.hasNvidia
                            ? "Nvidia-kortet är äldre än GTX 16xx/RTX 20xx, som Nvidias drivrutiner kräver – den vanliga ISO:n föreslås (öppna drivrutinen)."
                            : "Den vanliga ISO:n föreslås – drivrutinerna för AMD och Intel finns redan med.")
                            + (win.hasNvidiaIso
                               ? "\n\nSka USB-minnet till en annan dator? Välj efter den datorns grafikkort. Fel val gör ingen skada: GOBLINCAKES byter själv till rätt version efter första starten (behöver internet)."
                               : "")
                    }
                }
            }

            Item { width: 1; height: 10 }
            Row {
                width: parent.width
                SectionTitle { text: "2. VÄLJ USB-MINNE"; anchors.verticalCenter: parent.verticalCenter }
            }
            Label {
                visible: win.drives.length === 0
                width: parent.width
                text: "Inget USB-minne hittat. Sätt i ett – listan uppdateras av sig själv."
            }
            Repeater {
                model: win.drives
                Choice {
                    required property var modelData
                    width: chooseColumn.width
                    title: modelData.name + "  ·  " + modelData.sizeText
                    detail: win.bigEnough(modelData) ? (isWindows ? "Disk " + modelData.device : modelData.device)
                                                     : "För litet för den här ISO:n (" + (win.variant ? win.gb(win.variant.size) : "") + ")"
                    usable: win.bigEnough(modelData)
                    selected: win.device === modelData.device
                    onPicked: { win.device = modelData.device; win.understood = false; }
                }
            }
        }
    }
    FlatScrollBar { flick: chooser }

    // ── Working / done / failed ──────────────────────────────

    Column {
        visible: win.page !== "choose"
        anchors { left: parent.left; leftMargin: 40; right: parent.right; rightMargin: 40; top: header.bottom; topMargin: 36 }
        spacing: 16

        // Progress
        Rectangle {
            visible: win.page === "working"
            width: parent.width
            height: 6
            color: "#12203A"
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, win.progressValue))
                height: parent.height
                color: "#2F6FED"
            }
        }
        Text {
            visible: win.page === "working"
            width: parent.width
            text: win.progressText || "Startar…"
            color: "#E6ECF5"
            font.family: "IBM Plex Sans"
            font.pixelSize: 15
            wrapMode: Text.WordWrap
        }
        Label { visible: win.page === "working" && win.retryText !== ""; width: parent.width; text: win.retryText }
        Label {
            visible: win.page === "working"
            width: parent.width
            text: "Delarna hämtas från GitHub och skrivs direkt till USB-minnet – inget sparas på datorn. Efteråt läses hela USB-minnet tillbaka och kontrolleras."
        }

        // Done
        Label {
            visible: win.page === "done"
            width: parent.width
            color: "#E6ECF5"
            font.pixelSize: 15
            text: "Så här installerar du:\n\n"
                + "1. Sätt USB-minnet i datorn som ska få GOBLINCAKES.\n"
                + "2. Starta datorn och tryck på startmenyknappen direkt – oftast F12, F11, F8 eller Esc (står ofta på skärmen).\n"
                + "3. Välj USB-minnet (det som heter UEFI). Startar datorn Windows i stället: kolla att USB-start är på i BIOS/UEFI.\n"
                + "4. Välj \"Starta GOBLINCAKES\" och sedan Installera GOBLINCAKES.\n\n"
                + "Secure Boot kan vara påslaget. Vid första omstarten efter installationen kan en blå skärm visas: "
                + "Enroll MOK → Continue → Yes → lösenordet universalblue → Reboot."
        }

        // Failed
        Label {
            visible: win.page === "failed"
            width: parent.width
            color: "#DC464C"
            font.pixelSize: 15
            text: win.errorText
        }
    }

    // ── Footer ───────────────────────────────────────────────

    Rectangle {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 88
        color: "#0B1018"
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: "#1E2A40" }

        // The one warning that matters
        Row {
            visible: win.page === "choose" && !!win.drive
            anchors { left: parent.left; leftMargin: 40; verticalCenter: parent.verticalCenter }
            spacing: 12
            CheckSquare {
                anchors.verticalCenter: parent.verticalCenter
                checked: win.understood
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.understood = !win.understood }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: footer.width - 380
                text: "Allt på " + (win.drive ? win.drive.name + " (" + win.drive.sizeText + ")" : "") + " raderas – jag förstår."
                color: win.understood ? "#E6ECF5" : "#8B98AD"
                font.family: "IBM Plex Sans"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.understood = !win.understood }
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: 40; verticalCenter: parent.verticalCenter }
            spacing: 12
            FlatButton {
                visible: win.page === "failed"
                text: "Tillbaka"
                onClicked: { win.page = "choose"; win.understood = false; }
            }
            FlatButton {
                visible: win.page !== "working"
                text: "Stäng"
                onClicked: Qt.quit()
            }
            FlatButton {
                visible: win.page === "choose"
                primary: true
                enabledState: !!win.variant && !!win.drive && win.bigEnough(win.drive) && win.understood
                text: "Skapa USB-minne"
                onClicked: {
                    win.progressValue = 0;
                    win.progressText = "";
                    win.page = "working";
                    backend.write(win.device, win.variantId);
                }
            }
        }
    }
}
