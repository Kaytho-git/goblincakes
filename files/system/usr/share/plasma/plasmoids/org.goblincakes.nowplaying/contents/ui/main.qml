/*
    GOBLINCAKES Now Playing – the middle of the top bar.

    Music: what Spotify or the music player (Quod Libet …) is playing, read over
    MPRIS with the same model as Plasma's media controller. Browsers are left out
    so a YouTube tab doesn't take over the bar.
    Discord: the server and channel you are in, read from the Discord window's
    title ("#channel | Server - Discord") through the task manager model.
    Nothing to show = the widget takes no space.
*/
import QtQuick
import QtQuick.Layouts
import QtQml.Models
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Palette (same as the rest of GOBLINCAKES)
    readonly property color frost: "#E6ECF5"
    readonly property color muted: "#8B98AD"
    readonly property color accent: "#2F6FED"
    readonly property color line: "#2A3852"

    readonly property bool editMode: Plasmoid.containment.corona?.editMode ?? false

    // ---- Music ----
    // Music players only (desktop entry or name contains one of these)
    readonly property var musicPlayers: ["spotify", "quodlibet", "quod libet", "elisa", "strawberry",
        "audacious", "rhythmbox", "lollypop", "amberol", "clementine", "deadbeef", "tauon",
        "cmus", "g4music", "gapless", "harmonoid", "cider", "tidal", "deezer", "youtube-music",
        "youtubemusic", "nuclear", "museeks", "sayonara", "juk", "qmmp", "mpd", "mpv"]

    property int playerRevision: 0

    function isMusicPlayer(entry, identity) {
        const name = (entry + " " + identity).toLowerCase();
        return musicPlayers.some(p => name.indexOf(p) !== -1);
    }

    // Playing beats paused; stopped players are not shown
    readonly property var player: {
        playerRevision;
        let paused = null;
        for (let i = 0; i < players.count; i++) {
            const p = players.objectAt(i);
            if (!p || p.multiplexer || !p.container || !isMusicPlayer(p.entry, p.identity)) {
                continue;
            }
            if (p.status === Mpris.PlaybackStatus.Playing) {
                return p.container;
            }
            if (p.status === Mpris.PlaybackStatus.Paused && !paused) {
                paused = p.container;
            }
        }
        return paused;
    }
    readonly property bool playing: player?.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string songText: {
        if (!player || !player.track) {
            return "";
        }
        return player.artist ? player.artist + "  —  " + player.track : player.track;
    }

    Mpris.Mpris2Model {
        id: mpris2Model
    }

    Instantiator {
        id: players
        model: mpris2Model
        delegate: QtObject {
            required property var model
            readonly property var container: model.container
            readonly property bool multiplexer: model.isMultiplexer ?? false
            readonly property string entry: model.desktopEntry ?? ""
            readonly property string identity: model.identity ?? ""
            readonly property int status: model.playbackStatus ?? 0
            onStatusChanged: root.playerRevision++
            onEntryChanged: root.playerRevision++
            onIdentityChanged: root.playerRevision++
        }
        onObjectAdded: root.playerRevision++
        onObjectRemoved: root.playerRevision++
    }

    // ---- Discord ----
    property int windowRevision: 0

    // "(2) #general | Raid Night - Discord", "Discord | #general | Raid Night" →
    // "Raid Night  ›  #general". Empty outside a server channel (DMs, friends list).
    function discordPlace(title) {
        let t = title.replace(/^\(\d+\)\s*/, "").replace(/^[•●]\s*/, "");
        t = t.replace(/\s+[-–—]\s+(Discord|Vesktop)$/i, "");
        const parts = t.split(" | ").map(p => p.trim())
            .filter(p => p.length > 0 && !/^(discord|vesktop)$/i.test(p));
        const channel = parts.find(p => p.startsWith("#"));
        if (!channel) {
            return "";
        }
        const server = parts.filter(p => p !== channel).join(" · ");
        return server ? server + "  ›  " + channel : channel;
    }

    readonly property var discord: {
        windowRevision;
        for (let i = 0; i < windows.count; i++) {
            const w = windows.objectAt(i);
            if (!w || !/discord|vesktop|vencord|webcord|armcord|legcord/i.test(w.appId)) {
                continue;
            }
            const place = discordPlace(w.title);
            if (place) {
                return { place: place, row: w.row, icon: w.appId };
            }
        }
        return null;
    }

    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        filterMinimized: false
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    Instantiator {
        id: windows
        model: tasksModel
        delegate: QtObject {
            required property var model
            required property int index
            readonly property int row: index
            readonly property string appId: model.AppId ?? ""
            readonly property string title: model.display ?? ""
            onAppIdChanged: root.windowRevision++
            onTitleChanged: root.windowRevision++
            onRowChanged: root.windowRevision++
        }
        onObjectAdded: root.windowRevision++
        onObjectRemoved: root.windowRevision++
    }

    // ---- Look ----
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    fullRepresentation: Item {
        id: full
        readonly property bool empty: !music.visible && !chat.visible

        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        Layout.maximumWidth: row.implicitWidth
        Layout.fillHeight: true

        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: Kirigami.Units.gridUnit

            // In edit mode the widget would otherwise be invisible and impossible to find
            Text {
                visible: root.editMode && full.empty
                text: "Spelas nu"
                color: root.muted
                font: Kirigami.Theme.defaultFont
            }

            // Music: click = play/pause, wheel = next/previous
            Item {
                id: music
                visible: root.songText !== ""
                implicitWidth: musicRow.implicitWidth
                implicitHeight: musicRow.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: musicRow
                    anchors.fill: parent
                    spacing: Math.round(Kirigami.Units.smallSpacing * 1.5)

                    Text {
                        text: root.playing ? "♪" : "❚❚"
                        color: root.playing ? root.accent : root.muted
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pixelSize: root.playing ? Kirigami.Theme.defaultFont.pixelSize * 1.15 : Kirigami.Theme.defaultFont.pixelSize * 0.7
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: root.songText
                        color: root.playing ? root.frost : root.muted
                        font: Kirigami.Theme.defaultFont
                        elide: Text.ElideRight
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Kirigami.Units.smallSpacing
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (!root.player) {
                            return;
                        }
                        if (mouse.button === Qt.MiddleButton) {
                            root.player.Raise();
                        } else {
                            root.player.PlayPause();
                        }
                    }
                    onWheel: wheel => {
                        if (!root.player) {
                            return;
                        }
                        if (wheel.angleDelta.y < 0) {
                            root.player.Next();
                        } else if (wheel.angleDelta.y > 0) {
                            root.player.Previous();
                        }
                    }
                }
            }

            Rectangle {
                visible: music.visible && chat.visible
                color: root.line
                implicitWidth: 1
                implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.1)
                Layout.alignment: Qt.AlignVCenter
            }

            // Discord: click = show the Discord window
            Item {
                id: chat
                visible: root.discord !== null
                implicitWidth: chatRow.implicitWidth
                implicitHeight: chatRow.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: chatRow
                    anchors.fill: parent
                    spacing: Math.round(Kirigami.Units.smallSpacing * 1.5)

                    Kirigami.Icon {
                        source: root.discord ? root.discord.icon : ""
                        fallback: "discord"
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: root.discord ? root.discord.place : ""
                        color: root.frost
                        font: Kirigami.Theme.defaultFont
                        elide: Text.ElideRight
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Kirigami.Units.smallSpacing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.discord) {
                            tasksModel.requestActivate(tasksModel.index(root.discord.row, 0));
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Plasmoid.removeInternalAction("configure");
    }
}

