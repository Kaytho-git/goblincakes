/*
    GOBLINCAKES Dock – the bottom dock as a launcher only (plan 29 Oct, the user's wish):
    pinned apps and nothing else; a pinned app that is open gets a marker in the accent colour.
    Open apps that aren't pinned show only in the top bar. Plasma's icontasks can't filter
    "pinned only", so this is our own widget on the same TasksModel.

    - TasksModel with launchInPlace: an open pinned app takes its launcher's place, so every
      pinned app is one row; rows whose launcher position is -1 (not pinned) are hidden.
    - The wave (like macOS, the user's wish): the icon under the pointer grows the most, its
      neighbours less, out to `zoomRange` icons each way (cosine falloff). The icons grow away
      from the panel's edge; the dock's drawn background keeps its height and widens with them.
      The panel is thicker than the drawn dock – the strip above is transparent room for the
      grown icons (the panel window would clip them otherwise).
    - Size: everything comes from the panel's thickness – base icon = thickness / (zoom + 0.24),
      so dragging the panel's edge (or Config later) resizes the dock and the icons follow.
    - Click: launcher → start; one window → show / minimise; several → bring them all up, or
      the next one if one is already active. Middle click = new window. Right click = menu
      (new window, close, unpin). Drag an icon = move it; drop an app (.desktop) = pin it there.
    - The widget's width is fixed (the row + room for the widest wave), so the panel doesn't
      resize while the pointer moves.
    Not yet: previews on hover, Meta+1–9 (still icontasks'), vertical panels.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Palette (same as the rest of GOBLINCAKES)
    readonly property color accent: Kirigami.Theme.focusColor // the accent chosen in Config → Utseende
    readonly property color night: "#0B1018"

    readonly property bool editMode: Plasmoid.containment.corona?.editMode ?? false
    readonly property bool growDown: Plasmoid.location === PlasmaCore.Types.TopEdge
    readonly property real zoomMax: Plasmoid.configuration.zoom ? Math.max(1, Plasmoid.configuration.zoomFactor) : 1
    readonly property real zoomRange: Math.max(0.5, Plasmoid.configuration.zoomRange)

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        filterMinimized: false
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: false
        launchInPlace: true
        // Two-way like icontasks: dock-add.js / Config write the config, a pin from the menu
        // or a drop changes the model and is written back
        launcherList: Plasmoid.configuration.launchers
        onLauncherListChanged: Plasmoid.configuration.launchers = launcherList
    }

    // Moves the pinned app at `from` to `to` (both launcher positions)
    function moveLauncher(from, to) {
        const list = Array.from(tasksModel.launcherList);
        if (from < 0 || from >= list.length || to < 0 || to >= list.length || from === to) return;
        const item = list.splice(from, 1)[0];
        list.splice(to, 0, item);
        Plasmoid.configuration.launchers = list;
    }

    function activate(task) {
        const idx = tasksModel.makeModelIndex(task.index);
        if (task.isStartup) return;
        if (task.isLauncher) {
            tasksModel.requestActivate(idx); // starts it
            return;
        }
        const kids = task.model.ChildCount ?? 0;
        if (kids > 1) {
            let active = -1;
            for (let i = 0; i < kids; i++) {
                if (tasksModel.data(tasksModel.makeModelIndex(task.index, i), TaskManager.AbstractTasksModel.IsActive))
                    active = i;
            }
            if (active >= 0) {
                tasksModel.requestActivate(tasksModel.makeModelIndex(task.index, (active + 1) % kids));
            } else {
                for (let i = kids - 1; i >= 0; i--)
                    tasksModel.requestActivate(tasksModel.makeModelIndex(task.index, i));
            }
        } else if (task.active) {
            tasksModel.requestToggleMinimized(idx);
        } else {
            tasksModel.requestActivate(idx);
        }
    }

    fullRepresentation: Item {
        id: dock

        readonly property int count: tasksModel.launcherList.length
        // Sizes: all from the panel's thickness
        readonly property real thickness: Math.max(16, height)
        readonly property real base: Math.max(8, Math.floor(thickness / (root.zoomMax + 0.24)))
        readonly property real spacing: Math.round(base * 0.12)
        readonly property real pad: Math.round(base * 0.12)
        readonly property real step: base + spacing
        readonly property real bandHeight: base + 2 * pad

        // The wave's widest reach on one side (computed once per size/setting) → fixed width
        readonly property real reserve: {
            let most = 0;
            for (let t = 0; t <= count; t += 0.05) {
                const g = layout(t, 1);
                most = Math.max(most, g.left, g.right);
            }
            return Math.ceil(most);
        }
        readonly property real rowWidth: count * step
        readonly property real totalWidth: rowWidth + 2 * reserve + 2 * pad
        readonly property real rowLeft: (width - rowWidth) / 2

        Layout.minimumWidth: totalWidth
        Layout.preferredWidth: totalWidth
        Layout.maximumWidth: totalWidth
        Layout.fillHeight: true

        // Where the pointer is along the row, in icons (0 … count); kept when it leaves so the
        // wave sinks where it was
        property real pointer: 0
        property bool engaged: false
        // Dragging an icon: shown at dragTo while held, moved for real on release (a launcher
        // reorder can recreate the rows, which would drop the held one mid-drag)
        property int dragFrom: -1
        property int dragTo: -1
        readonly property bool dragging: dragFrom >= 0
        function place(slot) {
            if (dragFrom < 0 || dragTo < 0 || slot < 0) return slot;
            if (slot === dragFrom) return dragTo;
            if (dragFrom < dragTo && slot > dragFrom && slot <= dragTo) return slot - 1;
            if (dragFrom > dragTo && slot >= dragTo && slot < dragFrom) return slot + 1;
            return slot;
        }
        property real amount: engaged && !dragging && !root.editMode && root.zoomMax > 1 ? 1 : 0
        Behavior on amount { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        function falloff(d) {
            return d >= root.zoomRange ? 0 : (Math.cos(Math.PI * d / root.zoomRange) + 1) / 2;
        }

        // Sizes and places for pointer position t (icons) at wave strength a.
        // x[i] = left edge of slot i (slot = icon + spacing), relative to the row's own left;
        // left/right = how far the grown row reaches past the unzoomed row on each side.
        function layout(t, a) {
            const xs = [], sizes = [], widths = [];
            let total = 0;
            for (let i = 0; i < count; i++) {
                const s = 1 + (root.zoomMax - 1) * a * falloff(Math.abs(i + 0.5 - t));
                sizes.push(base * s);
                widths.push(base * s + spacing);
                xs.push(total);
                total += base * s + spacing;
            }
            // Keep the point under the pointer still: zoomed position of t = unzoomed position of t
            const k = Math.min(Math.max(Math.floor(t), 0), Math.max(count - 1, 0));
            const at = count === 0 ? 0 : xs[k] + (t - k) * widths[k];
            const shift = t * step - at;
            for (let i = 0; i < count; i++) xs[i] += shift;
            return { x: xs, size: sizes, width: widths, left: -shift, right: total + shift - count * step };
        }

        readonly property var geo: layout(pointer, amount)

        HoverHandler {
            id: hover
            onPointChanged: {
                if (!hovered) return;
                const p = point.position;
                dock.pointer = Math.min(Math.max((p.x - dock.rowLeft) / dock.step, 0), dock.count);
                // Starts in the drawn band, then stays on over the grown icons above it
                const inBand = root.growDown ? p.y <= dock.bandHeight : p.y >= dock.height - dock.bandHeight;
                if (inBand) dock.engaged = true;
            }
            onHoveredChanged: if (!hovered) dock.engaged = false
        }

        // The dock's own background + frame in the accent colour (the panel's own is hidden)
        Rectangle {
            readonly property real first: dock.count ? dock.geo.x[0] : 0
            readonly property real last: dock.count ? dock.geo.x[dock.count - 1] + dock.geo.width[dock.count - 1] : 0
            x: dock.rowLeft + first - dock.pad + dock.spacing / 2
            width: last - first - dock.spacing + 2 * dock.pad
            y: root.growDown ? 0 : dock.height - dock.bandHeight
            height: dock.bandHeight
            color: Qt.rgba(root.night.r, root.night.g, root.night.b, 0.6)
            border.color: root.accent
            border.width: 1
            visible: dock.count > 0
        }

        Repeater {
            model: tasksModel
            delegate: Item {
                id: task
                required property var model
                required property int index

                readonly property int slot: (tasksModel.launcherList, tasksModel.launcherPosition(model.LauncherUrlWithoutIcon))
                readonly property bool shown: slot >= 0 && slot < dock.count
                readonly property int place: dock.place(slot)
                readonly property bool isLauncher: model.IsLauncher === true
                readonly property bool isStartup: model.IsStartup === true
                readonly property bool active: model.IsActive === true
                readonly property int windows: isLauncher || isStartup ? 0 : Math.max(1, model.ChildCount ?? 0)
                readonly property real size: shown ? dock.geo.size[place] : 0

                visible: shown
                z: mouse.moved ? 2 : isStartup ? 1 : 0
                x: shown ? dock.rowLeft + dock.geo.x[place] : 0
                width: shown ? dock.geo.width[place] : 0
                Behavior on x { enabled: dock.dragging; NumberAnimation { duration: 120 } }
                height: dock.height

                Kirigami.Icon {
                    id: icon
                    width: task.size
                    height: task.size
                    x: dock.spacing / 2
                    y: root.growDown ? dock.pad : dock.height - dock.pad - task.size
                    source: task.model.decoration
                    active: mouse.containsMouse
                    SequentialAnimation on opacity {
                        running: task.isStartup
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.35; duration: 400 }
                        NumberAnimation { to: 1; duration: 400 }
                    }
                }

                // Open marker: one square per window (at most 3), the active app's first one wide
                Row {
                    spacing: Math.max(2, Math.round(dock.pad * 0.3))
                    anchors.horizontalCenter: icon.horizontalCenter
                    y: root.growDown ? Math.round(dock.pad * 0.25) : dock.height - height - Math.round(dock.pad * 0.25)
                    Repeater {
                        model: Math.min(task.windows, 3)
                        Rectangle {
                            required property int index
                            readonly property real dot: Math.max(3, Math.round(dock.pad * 0.45))
                            width: task.active && index === 0 ? Math.round(dock.base * 0.35) : dot
                            height: dot
                            color: root.accent
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }
                    }
                }

                PlasmaCore.ToolTipArea {
                    id: tip
                    x: 0
                    y: root.growDown ? 0 : icon.y
                    width: parent.width
                    height: root.growDown ? icon.y + icon.height : dock.height - icon.y
                    mainText: task.model.AppName || task.model.display || ""
                    subText: task.windows > 1 ? task.windows + " fönster"
                            : task.windows === 1 && task.model.display !== task.model.AppName ? (task.model.display ?? "") : ""
                    active: !dock.dragging && !menu.opened

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        property real pressX: 0
                        property bool moved: false

                        onPressed: mouse => { pressX = mouse.x; moved = false; }
                        onPositionChanged: mouse => {
                            if (!(mouse.buttons & Qt.LeftButton)) return;
                            if (!moved && Math.abs(mouse.x - pressX) < Qt.styleHints.startDragDistance) return;
                            if (!moved) dock.dragFrom = task.slot;
                            moved = true;
                            const px = mapToItem(dock, mouse.x, mouse.y).x;
                            dock.dragTo = Math.min(Math.max(Math.floor((px - dock.rowLeft) / dock.step), 0), dock.count - 1);
                        }
                        onReleased: {
                            if (!dock.dragging) return;
                            const from = dock.dragFrom, to = dock.dragTo;
                            dock.dragFrom = dock.dragTo = -1;
                            root.moveLauncher(from, to);
                        }
                        onCanceled: dock.dragFrom = dock.dragTo = -1
                        onClicked: mouse => {
                            if (moved) return;
                            if (mouse.button === Qt.MiddleButton) {
                                tasksModel.requestNewInstance(tasksModel.makeModelIndex(task.index));
                            } else if (mouse.button === Qt.RightButton) {
                                menu.task = task;
                                menu.visualParent = icon;
                                menu.openRelative();
                            } else {
                                root.activate(task);
                            }
                        }
                    }
                }
            }
        }

        // Drop an app from the AppGrid/menu → pinned where it was dropped
        DropArea {
            anchors.fill: parent
            onEntered: drag => drag.accepted = drag.hasUrls
            onDropped: drop => {
                const target = Math.min(Math.max(Math.floor((drop.x - dock.rowLeft) / dock.step + 0.5), 0), dock.count);
                for (const url of drop.urls) {
                    if (!String(url).endsWith(".desktop")) continue;
                    if (tasksModel.launcherPosition(url) >= 0) continue;
                    if (tasksModel.requestAddLauncher(url))
                        root.moveLauncher(tasksModel.launcherPosition(url), target);
                }
                drop.accept();
            }
        }

        PlasmaExtras.Menu {
            id: menu
            property var task: null
            readonly property bool opened: status === PlasmaExtras.Menu.Open
            placement: root.growDown ? PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
                                     : PlasmaExtras.Menu.TopPosedLeftAlignedPopup

            PlasmaExtras.MenuItem {
                text: menu.task && !menu.task.isLauncher ? "Nytt fönster" : "Starta"
                icon: "window-new"
                onClicked: tasksModel.requestNewInstance(tasksModel.makeModelIndex(menu.task.index))
            }
            PlasmaExtras.MenuItem {
                visible: menu.task !== null && menu.task.windows > 0
                text: menu.task && menu.task.windows > 1 ? "Stäng alla fönster" : "Stäng"
                icon: "window-close"
                onClicked: tasksModel.requestClose(tasksModel.makeModelIndex(menu.task.index))
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: "Lossa från dockan"
                icon: "window-unpin"
                onClicked: tasksModel.requestRemoveLauncher(menu.task.model.LauncherUrlWithoutIcon)
            }
        }
    }
}
