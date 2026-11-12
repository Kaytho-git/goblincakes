/*
    GOBLINCAKES Updates – a green arrow in the top bar when there is something new:
    a newer GOBLINCAKES version, one being fetched by the automatic updates, one fetched and
    waiting for a restart (however it was fetched – the arrow stays until the restart, the
    user's wish 10 Oct), or Flatpak programs. Hover = what; click = GOBLINCAKES Config →
    Uppdatera. Nothing new = no space taken.
    Waiting for a restart = /run/ostree/staged-deployment exists (gone after the restart, so a
    stale "staged" in the file never shows); fetching = rpm-ostreed-automatic/uupd is running.
    /usr/libexec/goblincakes-updates check (timer at login and every 4 hours, and after
    goblin update) writes ~/.cache/goblincakes/updates.json; this only reads it.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import QtCore
import Qt.labs.folderlistmodel

PlasmoidItem {
    id: root

    // The mark's colour says what is waiting (11 Oct, the user's wish): blue = a new GOBLINCAKES
    // version (or one being fetched), green = fetched, restart to use it, orange = programs
    // (Flatpak, VS Code, Discord, AppImages, GE-Proton, and programs added to or removed from
    // the system waiting for a restart – e.g. the calendar, 11 Oct), yellow = only firmware
    readonly property bool onlyFirmware: flatpaks.length === 0 && runtimes === 0
        && other.length > 0 && other.every(o => o.part === "firmware")
    readonly property color markColor: system === "new" || (fetching && !staged) ? "#2F6FED"
        : staged && stagedImage ? "#3FB950"
        : onlyFirmware ? "#D29922"
        : "#F0883E"
    readonly property bool editMode: Plasmoid.containment.corona?.editMode ?? false

    property string system: ""      // "new", "staged" or ""
    property var flatpaks: []
    property var news: []           // what the new version brings (goblincakes-updates)
    property int runtimes: 0        // Flatpak runtimes/extensions with updates (not named)
    property var other: []          // VS Code, Discord, AppImages, GE-Proton, firmware: [{part, name}]
    readonly property bool more: flatpaks.length > 0 || runtimes > 0 || other.length > 0
    property bool staged: false     // fetched, waiting for a restart
    property string stagedId: ""    // that deployment's checksum (/run/ostree/staged-deployment)
    property bool stagedImage: true // a new GOBLINCAKES image in it (not only programs)
    property var stagedChanges: []  // programs added/removed in it, by name
    property string stagedFor: ""   // the deployment the file describes
    property bool fetching: false   // the automatic updates are fetching right now
    property string asked: ""       // a check already started for this staged deployment
    readonly property bool available: system === "new" || staged || fetching || more

    // Line 1: the file; line 2: the staged deployment's checksum (empty = none); line 3:
    // automatic update running (1/0). Every line is always printed – without a staged deployment
    // line 2 was missing, so line 3's "0" was read as a checksum: green mark after every restart
    readonly property string readCommand: "printf '%s\\n' \"$(cat \"$HOME/.cache/goblincakes/updates.json\" 2>/dev/null)\"; "
        + "printf '%s\\n' \"$(grep -aoE '[0-9a-f]{64}\\.[0-9]+' /run/ostree/staged-deployment 2>/dev/null | head -n1 | cut -d. -f1)\"; "
        + "if systemctl is-active -q rpm-ostreed-automatic.service || systemctl is-active -q uupd.service; then echo 1; else echo 0; fi"

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.readCommand) {
                const out = (data["stdout"] || "").split("\n");
                root.stagedId = out[1] || "";
                root.staged = root.stagedId !== "";
                root.fetching = out[2] === "1";
                try {
                    const state = JSON.parse(out[0]);
                    // "staged" in the file only counts while it really waits (not after the restart)
                    root.system = state.system === "staged" && !root.staged ? "" : (state.system || "");
                    root.flatpaks = state.flatpaks || [];
                    root.news = state.news || [];
                    root.runtimes = state.flatpakRuntimes || 0;
                    root.other = state.other || [];
                    root.stagedImage = state.stagedImage !== false;
                    root.stagedChanges = state.stagedChanges || [];
                    root.stagedFor = state.stagedFor || "";
                } catch (e) {
                    root.stagedImage = true;
                    root.stagedChanges = [];
                    root.stagedFor = "";
                    root.runtimes = 0;
                    root.other = [];
                    root.system = "";
                    root.flatpaks = [];
                    root.news = [];
                }
                // Fetched in the background since the last check, or another deployment than the
                // file describes (e.g. the calendar first, a new version later): check now, once
                if (root.staged && (root.system !== "staged" || (root.stagedFor && root.stagedFor !== root.stagedId))
                        && root.asked !== root.stagedId) {
                    root.asked = root.stagedId;
                    exec.connectSource("setsid -f /usr/libexec/goblincakes-updates check >/dev/null 2>&1 < /dev/null");
                }
                if (!root.staged)
                    root.asked = "";
            }
            disconnectSource(source);
        }
    }

    // The file changes at most every few hours: every 2 minutes (P7.3, 12 Nov – was every 30 s),
    // every 30 s while the automatic update is fetching, and at once when the pointer comes over
    Timer {
        interval: root.fetching ? 30000 : 120000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource(root.readCommand)
    }

    function openUpdate() {
        exec.connectSource("setsid -f goblincakes-config --tab update >/dev/null 2>&1 < /dev/null");
    }

    preferredRepresentation: fullRepresentation
    // Drawn straight in the bar, so Plasma's own applet tooltip isn't shown: our own ToolTipArea
    toolTipMainText: ""
    toolTipSubText: ""
    readonly property string tipTitle: !available ? ""
        : (staged && !more) ? "Starta om för att uppdatera"
        : (fetching && system !== "new" && !more) ? "Uppdatering pågår"
        : "Uppdateringar finns"
    readonly property string tipText: {
        const lines = [];
        if (fetching && !staged)
            lines.push("Ny GOBLINCAKES-version hämtas i bakgrunden …");
        if (system === "new" || (staged && stagedImage)) {
            lines.push((staged && stagedImage ? "Ny GOBLINCAKES-version hämtad – starta om datorn för att använda den"
                               : "Ny GOBLINCAKES-version") + (news.length > 0 ? ":" : ""));
            for (const line of news.slice(0, 5))
                lines.push("• " + line);
            if (news.length > 5)
                lines.push("• … och " + (news.length - 5) + " till");
        }
        if (staged && stagedChanges.length > 0) {
            lines.push("Efter omstart:");
            for (const line of stagedChanges)
                lines.push("• " + line);
        }
        if (flatpaks.length > 0) {
            const shown = flatpaks.slice(0, 3).join(", ");
            lines.push(flatpaks.length === 1 ? "Program: " + shown
                       : flatpaks.length + " program: " + shown + (flatpaks.length > 3 ? " …" : ""));
        }
        if (flatpaks.length === 0 && runtimes > 0)
            lines.push("Flatpak: " + runtimes + (runtimes === 1 ? " systemdel" : " systemdelar"));
        if (other.length > 0) {
            const shown = other.slice(0, 4).map(o => o.name).join(", ");
            lines.push(shown + (other.length > 4 ? " …" : ""));
        }
        if (lines.length > 0)
            lines.push(staged && system !== "new" && !more ? "Klicka för att starta om"
                       : "Klicka för att uppdatera");
        return lines.join("\n");
    }


    // Stil (Config → Utseende → Stil, Levande utseende step 7, 11 Nov): Levande = a glow under the pointer and the mark's colour fades;
    // moving = Levande, no game running and Plasma's animations on. Read when it changes.
    readonly property string lookCommand: "cat \"$HOME/.config/goblincakes/utseende\" 2>/dev/null; "
        + "[ -e \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/goblincakes-gaming\" ] && echo spel; true"
    property bool living: false
    property bool gaming: false
    readonly property bool moving: living && !gaming && Kirigami.Units.longDuration > 1
    P5Support.DataSource {
        id: lookSource
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const lines = String(data["stdout"] || "").split("\n").map(l => l.trim());
            root.living = lines[0] === "levande";
            root.gaming = lines.indexOf("spel") >= 0;
            disconnectSource(source);
        }
    }
    // Read when the style file or the game guard's file changes (the folders are watched – no process), and every
    // 60 s in case a change was missed (12 Nov – was a process every 5 s in each widget)
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: lookSource.connectSource(root.lookCommand)
    }
    FolderListModel {
        folder: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/goblincakes"
        nameFilters: ["utseende"]
        showDirs: false
        onCountChanged: lookSource.connectSource(root.lookCommand)
        onDataChanged: lookSource.connectSource(root.lookCommand)
    }
    FolderListModel {
        folder: StandardPaths.writableLocation(StandardPaths.RuntimeLocation)
        nameFilters: ["goblincakes-gaming"]
        showDirs: false
        onCountChanged: lookSource.connectSource(root.lookCommand)
    }

    fullRepresentation: Item {
        readonly property bool shown: root.available || root.editMode
        Layout.minimumWidth: shown ? arrow.width + Kirigami.Units.smallSpacing * 2 : 0
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        visible: shown

        // Stil Levande: a glow in the accent under the pointer
        Rectangle {
            anchors.centerIn: arrow
            width: arrow.width + 8
            height: arrow.height + 8
            color: Qt.rgba(Kirigami.Theme.focusColor.r, Kirigami.Theme.focusColor.g, Kirigami.Theme.focusColor.b, 0.14)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.focusColor.r, Kirigami.Theme.focusColor.g, Kirigami.Theme.focusColor.b, 0.5)
            opacity: root.living && arrowArea.containsMouse ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { enabled: root.moving; NumberAnimation { duration: 160 } }
        }
        // A square frame with a check in it, in the colour of what is waiting – drawn, flat and
        // square like the rest of GOBLINCAKES (no icon theme needed)
        Canvas {
            id: arrow
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            opacity: root.available ? 1 : 0.4  // edit mode without updates: dimmed placeholder
            Behavior on opacity { enabled: root.moving; NumberAnimation { duration: 200 } }
            readonly property color colour: root.markColor
            onColourChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                const s = width / 16;
                ctx.reset();
                ctx.strokeStyle = colour;
                ctx.lineWidth = 1.5 * s;
                ctx.lineCap = "square";
                ctx.lineJoin = "miter";
                ctx.strokeRect(1.25 * s, 1.25 * s, 13.5 * s, 13.5 * s);  // frame
                ctx.lineWidth = 2 * s;
                ctx.beginPath();                                           // check
                ctx.moveTo(4.2 * s, 8.3 * s);
                ctx.lineTo(6.9 * s, 11 * s);
                ctx.lineTo(11.8 * s, 5.2 * s);
                ctx.stroke();
            }
        }

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: root.tipTitle
            subText: root.tipText
            active: root.available
        }

        MouseArea {
            id: arrowArea
            anchors.fill: parent
            enabled: root.available
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openUpdate()
            onContainsMouseChanged: if (containsMouse) exec.connectSource(root.readCommand)
        }
    }
}
