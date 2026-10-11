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

PlasmoidItem {
    id: root

    readonly property color green: "#3FB950"
    readonly property bool editMode: Plasmoid.containment.corona?.editMode ?? false

    property string system: ""      // "new", "staged" or ""
    property var flatpaks: []
    property var news: []           // what the new version brings (goblincakes-updates)
    property int runtimes: 0        // Flatpak runtimes/extensions with updates (not named)
    property var other: []          // VS Code, Discord, AppImages, GE-Proton, firmware: [{part, name}]
    readonly property bool more: flatpaks.length > 0 || runtimes > 0 || other.length > 0
    property bool staged: false     // fetched, waiting for a restart
    property bool fetching: false   // the automatic updates are fetching right now
    property bool asked: false      // a check already started for a staged version the file lacks
    readonly property bool available: system === "new" || staged || fetching || more

    // Line 1: the file; line 2: staged (1/0); line 3: automatic update running (1/0)
    readonly property string readCommand: "printf '%s\\n' \"$(cat \"$HOME/.cache/goblincakes/updates.json\" 2>/dev/null)\"; "
        + "test -e /run/ostree/staged-deployment && echo 1 || echo 0; "
        + "systemctl is-active -q rpm-ostreed-automatic.service || systemctl is-active -q uupd.service && echo 1 || echo 0"

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.readCommand) {
                const out = (data["stdout"] || "").split("\n");
                root.staged = out[1] === "1";
                root.fetching = out[2] === "1";
                try {
                    const state = JSON.parse(out[0]);
                    // "staged" in the file only counts while it really waits (not after the restart)
                    root.system = state.system === "staged" && !root.staged ? "" : (state.system || "");
                    root.flatpaks = state.flatpaks || [];
                    root.news = state.news || [];
                    root.runtimes = state.flatpakRuntimes || 0;
                    root.other = state.other || [];
                } catch (e) {
                    root.runtimes = 0;
                    root.other = [];
                    root.system = "";
                    root.flatpaks = [];
                    root.news = [];
                }
                // Fetched in the background since the last check: check now (news + notice)
                if (root.staged && root.system !== "staged" && !root.asked) {
                    root.asked = true;
                    exec.connectSource("setsid -f /usr/libexec/goblincakes-updates check >/dev/null 2>&1 < /dev/null");
                }
                if (!root.staged)
                    root.asked = false;
            }
            disconnectSource(source);
        }
    }

    // The file changes at most every few hours – reading it twice a minute is plenty
    Timer {
        interval: 30000
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
        if (system === "new" || staged) {
            lines.push((staged ? "Ny GOBLINCAKES-version hämtad – starta om datorn för att använda den"
                               : "Ny GOBLINCAKES-version") + (news.length > 0 ? ":" : ""));
            for (const line of news.slice(0, 5))
                lines.push("• " + line);
            if (news.length > 5)
                lines.push("• … och " + (news.length - 5) + " till");
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

    fullRepresentation: Item {
        readonly property bool shown: root.available || root.editMode
        Layout.minimumWidth: shown ? arrow.width + Kirigami.Units.smallSpacing * 2 : 0
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        visible: shown

        // Green arrow up on a short bar ("update"), drawn – no icon theme needed
        Canvas {
            id: arrow
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            opacity: root.available ? 1 : 0.4  // edit mode without updates: dimmed placeholder
            onPaint: {
                const ctx = getContext("2d");
                const s = width / 16;
                ctx.reset();
                ctx.fillStyle = root.green;
                ctx.beginPath();          // head
                ctx.moveTo(8 * s, 1 * s);
                ctx.lineTo(14 * s, 7.5 * s);
                ctx.lineTo(2 * s, 7.5 * s);
                ctx.closePath();
                ctx.fill();
                ctx.fillRect(6 * s, 7 * s, 4 * s, 5 * s);    // shaft
                ctx.fillRect(2 * s, 13.5 * s, 12 * s, 1.5 * s); // bar
            }
        }

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: root.tipTitle
            subText: root.tipText
            active: root.available
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.available
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openUpdate()
        }
    }
}
