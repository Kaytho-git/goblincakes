// FILER beside TERMINAL (18 Nov, the user: "look at files while you work – what we have done"): the folder of
// the tab shown as a tree with git's marks (like VS Code), a file with colours and line numbers or its change.
// Only reads (fileview.py), nothing updates by itself – ↻ reads again (the user's choice). No key here takes
// the keyboard: what is typed still goes to the terminal (Esc there would stop Claude Code – so ← closes a file).
import QtQuick
import "../qml/Goblin" as G

Item {
    id: pane
    property string folder: ""            // the tab's folder (Main.qml: terminals.folderOf)
    readonly property bool fileOpen: current !== ""
    property string current: ""           // the file shown (relative to fileView.root)
    property bool diff: false             // ÄNDRINGEN: git diff HEAD instead of the file
    property bool onlyChanged: false      // ÄNDRADE: the changed files as a list
    property var expanded: []
    property var rowsList: []
    property var file: ({})
    property string shownRoot: ""

    component FastWheel: G.FastWheel {}
    // the strip's small text buttons (as KARTA/FILER above)
    component Tool: Item {
        id: tool
        property string text
        property bool on: false
        property bool dim: false
        signal clicked
        width: toolText.implicitWidth + 18
        height: 26
        Rectangle {
            anchors.fill: parent
            color: tool.on ? "#12203A" : toolArea.containsMouse ? "#0E1420" : "transparent"
        }
        Text {
            id: toolText
            anchors.centerIn: parent
            text: tool.text
            color: tool.on ? "#E6ECF5" : toolArea.containsMouse ? accent.text : tool.dim ? "#5C6880" : "#8B98AD"
            font.family: "IBM Plex Sans"
            font.weight: Font.DemiBold
            font.pixelSize: 10
            font.letterSpacing: 1
        }
        MouseArea {
            id: toolArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tool.clicked()
        }
    }

    function load(f) {             // FILER opened, ↻, another tab chosen
        folder = f;
        fileView.open(f);          // → onChanged → the rows
    }
    function reload() {
        if (fileView.root !== shownRoot) {   // another folder: start from the top
            shownRoot = fileView.root;
            expanded = [];
            current = "";
            diff = false;
        }
        const y = tree.contentY;
        rowsList = JSON.parse(fileView.rows(JSON.stringify(expanded), onlyChanged));
        tree.contentY = Math.min(y, Math.max(0, tree.contentHeight - tree.height));
        if (current)
            showFile(current, true);
    }
    function toggle(rel) {
        const at = expanded.indexOf(rel);
        const next = expanded.slice();
        if (at >= 0)
            next.splice(at, 1);
        else
            next.push(rel);
        expanded = next;
        reload();
    }
    function showFile(rel, keepPlace) {
        const y = keepPlace && rel === current ? code.contentY : 0;
        if (rel !== current)
            diff = false;
        current = rel;
        file = JSON.parse(fileView.show(rel, diff, mono.advanceWidth("0")));
        if (diff && !file.canDiff) {
            diff = false;
            file = JSON.parse(fileView.show(rel, false, mono.advanceWidth("0")));
        }
        codeText.deselect();
        code.contentY = 0;
        Qt.callLater(() => code.contentY = Math.min(y, Math.max(0, code.contentHeight - code.height)));
    }
    function markColour(m) { return fileView.markColour(m); }

    FontMetrics {   // the code's character width – wrapped rows start after the line numbers
        id: mono
        font.family: "IBM Plex Mono"
        font.pixelSize: 12
    }
    Connections {
        target: fileView
        function onChanged() { pane.reload(); }
    }

    // ── the strip on top: the folder + ALLA/ÄNDRADE/↻, or the file + ← ÄNDRINGEN KOPIERA ↻ ──
    Item {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 34
        Row {   // the tree's
            visible: !pane.fileOpen
            anchors { left: parent.left; leftMargin: 12; right: treeTools.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text {
                text: fileView.root ? fileView.name : "Ingen mapp"
                color: "#E6ECF5"
                font.family: "IBM Plex Mono"
                font.pixelSize: 11
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, parent.width - branchText.width - 8)
            }
            Text {
                id: branchText
                text: fileView.isGit ? (fileView.branch || "git") + (fileView.changedCount ? " · " + fileView.changedCount + " ändrade" : "") : ""
                color: "#5C6880"
                font.family: "IBM Plex Mono"
                font.pixelSize: 10
                anchors.baseline: parent.children[0].baseline
            }
        }
        Row {
            id: treeTools
            visible: !pane.fileOpen
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 2
            Tool {
                text: "ALLA"
                on: !pane.onlyChanged
                onClicked: { pane.onlyChanged = false; pane.reload(); }
            }
            Tool {
                text: "ÄNDRADE"
                visible: fileView.isGit
                on: pane.onlyChanged
                onClicked: { pane.onlyChanged = true; pane.reload(); }
            }
            Tool {
                text: "↻"
                onClicked: pane.load(pane.folder)
            }
        }
        // a file's
        Tool {
            id: backTool
            visible: pane.fileOpen
            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
            text: "←"
            onClicked: { pane.current = ""; pane.diff = false; }
        }
        Text {
            visible: pane.fileOpen
            anchors { left: backTool.right; leftMargin: 6; right: fileTools.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: pane.current
            color: pane.file.mark ? pane.markColour(pane.file.mark) : "#E6ECF5"
            font.family: "IBM Plex Mono"
            font.pixelSize: 11
            elide: Text.ElideLeft
        }
        Row {
            id: fileTools
            visible: pane.fileOpen
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 2
            Tool {
                text: "ÄNDRINGEN"
                visible: !!pane.file.canDiff
                on: pane.diff
                onClicked: { pane.diff = !pane.diff; pane.showFile(pane.current, false); }
            }
            Tool {
                id: copyTool
                text: copied.running ? "KOPIERAT" : "KOPIERA"
                visible: pane.file.kind === "text"
                onClicked: {
                    fileView.copy(codeText.selectedText, pane.diff ? "" : pane.current, !pane.diff);
                    copied.restart();
                }
                Timer { id: copied; interval: 1500 }
            }
            Tool {
                text: "↻"
                onClicked: { fileView.refresh(); }   // marks + the file again (onChanged → reload → showFile)
            }
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: "#1A2438"
        }
    }

    // ── the tree ──
    ListView {
        id: tree
        visible: !pane.fileOpen
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: 4 }
        clip: true
        model: pane.rowsList
        boundsBehavior: Flickable.StopAtBounds
        FastWheel { flick: tree }
        delegate: Item {
            id: row
            required property var modelData
            width: tree.width
            height: 22
            Rectangle {
                anchors.fill: parent
                color: rowArea.containsMouse ? "#0E1420" : "transparent"
            }
            Text {
                id: arrow
                x: 10 + row.modelData.depth * 14
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                text: row.modelData.dir ? "▶" : ""
                rotation: row.modelData.open ? 90 : 0
                horizontalAlignment: Text.AlignHCenter
                color: "#8B98AD"
                font.family: "DejaVu Sans"
                font.pixelSize: 8
            }
            Text {
                anchors { left: arrow.right; leftMargin: 4; right: markText.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: row.modelData.name + (row.modelData.dir ? "/" : "")
                elide: pane.onlyChanged ? Text.ElideLeft : Text.ElideRight
                color: row.modelData.ignored ? "#5C6880"
                     : row.modelData.mark && row.modelData.mark !== "•" ? pane.markColour(row.modelData.mark)
                     : row.modelData.dir ? "#C7D0DD" : "#E6ECF5"
                font.family: "IBM Plex Mono"
                font.pixelSize: 11
                font.strikeout: row.modelData.mark === "D"
            }
            Text {
                id: markText
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                text: row.modelData.mark
                color: row.modelData.mark === "•" ? "#E2C04A" : pane.markColour(row.modelData.mark)
                font.family: "IBM Plex Mono"
                font.weight: Font.DemiBold
                font.pixelSize: 11
            }
            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.modelData.dir ? pane.toggle(row.modelData.rel) : pane.showFile(row.modelData.rel, false)
            }
        }
    }
    G.FlatScrollBar { flick: tree; margin: 2 }
    Text {
        visible: !pane.fileOpen && pane.rowsList.length === 0
        anchors { left: parent.left; right: parent.right; top: head.bottom; margins: 16 }
        wrapMode: Text.WordWrap
        text: !fileView.root ? "Ingen mapp – öppna en terminal i mappen du vill se."
              : pane.onlyChanged ? "Inget ändrat sedan senaste commit." : "Mappen är tom."
        color: "#8B98AD"
        font.family: "IBM Plex Sans"
        font.pixelSize: 12
    }

    // ── a file ──
    Text {
        id: fileNote
        visible: pane.fileOpen && !!pane.file.note
        anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: 14; rightMargin: 14; topMargin: 8 }
        wrapMode: Text.WordWrap
        text: pane.file.note || ""
        color: "#8B98AD"
        font.family: "IBM Plex Sans"
        font.pixelSize: 11
    }
    Flickable {
        id: code
        visible: pane.fileOpen && pane.file.kind === "text"
        anchors { left: parent.left; right: parent.right; top: fileNote.visible ? fileNote.bottom : head.bottom; bottom: parent.bottom; topMargin: 6 }
        clip: true
        contentWidth: width
        contentHeight: codeText.height + 16
        boundsBehavior: Flickable.StopAtBounds
        FastWheel { flick: code }
        TextEdit {
            id: codeText
            x: 6
            width: code.width - 20
            readOnly: true
            selectByMouse: true
            activeFocusOnPress: false     // the keyboard stays in the terminal
            persistentSelection: true
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.Wrap
            text: pane.fileOpen && pane.file.kind === "text" ? pane.file.html : ""
            color: "#E6ECF5"
            selectionColor: Qt.rgba(accent.color.r, accent.color.g, accent.color.b, 0.4)
            selectedTextColor: "#FFFFFF"
            font.family: "IBM Plex Mono"
            font.pixelSize: 12
        }
    }
    G.FlatScrollBar { flick: code; margin: 2 }
    Flickable {
        id: picture
        visible: pane.fileOpen && pane.file.kind === "image"
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; margins: 12 }
        clip: true
        contentHeight: Math.max(height, img.paintedHeight)
        FastWheel { flick: picture }
        Image {
            id: img
            width: picture.width
            // small pictures (the children's game's pixel art, icons) at least 256 px high – sharp, not blurred
            height: Math.min(Math.max(sourceSize.height, 256), picture.height)
            source: picture.visible ? pane.file.url : ""
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignTop
            asynchronous: true
            cache: false
            smooth: sourceSize.height > height
        }
    }
}
