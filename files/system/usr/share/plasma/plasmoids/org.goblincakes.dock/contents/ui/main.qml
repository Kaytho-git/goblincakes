/*
    GOBLINCAKES Dock – the bottom dock as a launcher only (plan 29 Oct, the user's wish):
    pinned apps and nothing else; a pinned app that is open gets a marker in the accent colour.
    Open apps that aren't pinned show only in the top bar. Plasma's icontasks can't filter
    "pinned only", so this is our own widget on the same TasksModel.

    - TasksModel with launchInPlace: an open pinned app takes its launcher's place, so every
      pinned app is one row; rows whose launcher position is -1 (not pinned) are hidden.
    - The wave (like macOS, the user's wish): the icon under the pointer grows the most, its
      neighbours less, out to `zoomRange` icons each way (cosine falloff). The icons stay inside
      the frame (the user's wish): the frame is `thickness` high (48 px × the scale setting, at most the panel's height), icons rest centred and
      the biggest reaches 1 px inside it. The frame stays put while the wave runs: the gaps
      at rest (about a quarter of the icon) absorb the growth; a wave that won't fit is toned down.
    - Size: everything comes from the panel's thickness – biggest icon = thickness − 4,
      icon at rest = that / zoom, so dragging the panel's edge (or Config later) resizes the
      dock and the icons follow.
    - Click: launcher → start; one window → show / minimise; several → a list of the windows to pick from. Middle click = new window. Right click = menu
      (new window, close, unpin). Drag an icon = move it; drop an app (.desktop) = pin it there.
    - The widget's width is fixed (the frame), so the panel
      doesn't resize while the pointer moves.
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
    readonly property bool atTop: Plasmoid.location === PlasmaCore.Types.TopEdge
    // The most an icon can grow inside the frame (rest size = frame − 4 over this, so the dock's
    // size never depends on the setting): Förstoring goes from 1.0 to this
    readonly property real zoomCap: 1.5
    readonly property real zoomMax: Plasmoid.configuration.zoom && isFinite(Plasmoid.configuration.zoomFactor) ? Math.min(zoomCap, Math.max(1, Plasmoid.configuration.zoomFactor)) : 1
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

    // The app that was active last (the panel taking focus doesn't change it). wasActive: the panel
    // takes focus on the press, and a window raised from the dock often never gets focus back,
    // so "active" = the last app that was active and is showing – one click minimises it
    property string lastActiveKey: ""
    function activate(task, wasActive) {
        if (!task.isLauncher && !task.isStartup) lastActiveKey = task.key;
        const idx = tasksModel.makeModelIndex(task.index);
        if (task.isStartup) return;
        if (task.isLauncher) {
            tasksModel.requestActivate(idx); // starts it
            return;
        }
        // (several windows: the dock shows a list instead, see showWindows)
        if (task.active || wasActive || task.model.IsMinimized) {
            tasksModel.requestToggleMinimized(idx);
        } else {
            tasksModel.requestActivate(idx);
        }
    }

    fullRepresentation: Item {
        id: dock

        readonly property int count: tasksModel.launcherList.length
        // The frame stays put while the wave runs; the gaps shrink as the icons grow
        // Sizes: all from the panel's thickness. The frame is the whole height; the biggest icon
        // reaches 1 px inside the frame (1 px border + 1 px air top and bottom).
        // Size at scale 1 = the old dock (48 px); Config's scale multiplies it, up to the panel's height
        // A saved "nan" (from the broken Storlek box) counts as 1
        readonly property real userScale: isFinite(Plasmoid.configuration.scale) ? Math.max(0.5, Plasmoid.configuration.scale) : 1
        readonly property real thickness: Math.max(16, Math.min(height, 48 * userScale))
        readonly property real frameTop: (height - thickness) / 2
        readonly property real maxSize: thickness - 4
        readonly property real base: Math.max(8, Math.floor(maxSize / root.zoomCap))
        readonly property real spacing: Math.round(base * 0.12)
        readonly property real pad: Math.round(base * 0.12)

        // Gap at rest like the old dock (about a quarter of the icon); the frame is the row at rest
        readonly property real airyGap: Math.max(2, Math.round(base * 0.25))
        readonly property real frameWidth: count * base + (count + 1) * airyGap + 2

        // Rest layout: slot i starts at restLeft + i × restStep (used for the pointer and drags)
        readonly property real restStep: base + airyGap
        readonly property real rowWidth: count * restStep
        readonly property real totalWidth: frameWidth
        readonly property real rowLeft: (width - frameWidth) / 2
        readonly property real restLeft: rowLeft + 1 + airyGap / 2

        Layout.minimumWidth: totalWidth
        Layout.preferredWidth: totalWidth
        Layout.maximumWidth: totalWidth
        Layout.fillHeight: true

        // Where the pointer is along the row, in icons (0 … count); kept when it leaves so the
        // wave sinks where it was
        property real pointer: 0
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
        property real amount: hover.hovered && inFrame && !dragging && !root.editMode && root.zoomMax > 1 ? 1 : 0
        Behavior on amount { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        function falloff(d) {
            return d >= root.zoomRange ? 0 : (Math.cos(Math.PI * d / root.zoomRange) + 1) / 2;
        }
        function scale(i, t, a) {
            return 1 + (root.zoomMax - 1) * a * falloff(Math.abs(i + 0.5 - t));
        }

        // Sizes and places for pointer position t (icons) at wave strength a, relative to rowLeft.
        // x[i]/width[i] = slot i (icon + gap, the icon gap/2 in); frameL/frameR = the frame's edges.
        function layout(t, a) {
            const xs = [], sizes = [], widths = [];
            for (let i = 0; i < count; i++) sizes.push(base * scale(i, t, a));
            // The frame stays put: what the icons don't use is shared out as equal gaps
            // If the grown icons don't fit with 1 px gaps, the wave is toned down to fit
            const room = frameWidth - 2 - (count + 1) - count * base;
            const extra = sizes.reduce((sum, v) => sum + v - base, 0);
            if (extra > room) {
                const k = Math.max(0, room) / extra;
                for (let i = 0; i < count; i++) sizes[i] = base + (sizes[i] - base) * k;
            }
            const used = sizes.reduce((sum, v) => sum + v, 0);
            const gap = Math.max(1, (frameWidth - 2 - used) / (count + 1));
            let x = 1 + gap / 2;
            for (let i = 0; i < count; i++) {
                xs.push(x);
                widths.push(sizes[i] + gap);
                x += sizes[i] + gap;
            }
            return { x: xs, size: sizes, width: widths, gap: gap, frameL: 0, frameR: frameWidth };
        }

        readonly property var geo: layout(pointer, amount)

        // Only the frame reacts to the pointer – the panel around it can be taller. The handler sits
        // on the whole dock (a sibling item under the icons would never get the hover) and
        // checks the frame's rectangle itself (the widget can be wider and taller than the frame).
        property bool inFrame: false
        HoverHandler {
            id: hover
            onPointChanged: {
                dock.inFrame = point.position.y >= dock.frameTop && point.position.y <= dock.frameTop + dock.thickness
                               && point.position.x >= dock.rowLeft && point.position.x <= dock.rowLeft + dock.frameWidth;
                if (hovered && dock.inFrame)
                    dock.pointer = Math.min(Math.max((point.position.x - dock.restLeft) / dock.restStep, 0), dock.count);
            }
        }

        // The dock's own background + frame in the accent colour (height = thickness, centred in the panel)
        // (the panel's own background is hidden)
        Rectangle {
            x: dock.rowLeft + dock.geo.frameL
            y: dock.frameTop
            width: dock.geo.frameR - dock.geo.frameL
            height: dock.thickness
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
                readonly property string key: String(model.LauncherUrlWithoutIcon ?? model.AppId ?? task.index)
                onActiveChanged: if (active) root.lastActiveKey = key
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
                    x: dock.geo.gap / 2
                    y: (dock.height - task.size) / 2
                    source: task.model.decoration
                    active: mouse.containsMouse
                    roundToIconSize: false
                    SequentialAnimation on opacity {
                        running: task.isStartup
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.35; duration: 400 }
                        NumberAnimation { to: 1; duration: 400 }
                    }
                }

                // Open marker: one square per window (at most 3), the active app's first one wide
                // (drawn over the icon, so a grown icon doesn't hide it)
                Row {
                    z: 1
                    spacing: Math.max(2, Math.round(dock.pad * 0.3))
                    anchors.horizontalCenter: icon.horizontalCenter
                    y: root.atTop ? dock.frameTop + 3 : dock.frameTop + dock.thickness - height - 3
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
                    y: dock.frameTop
                    width: parent.width
                    height: dock.thickness
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
                            dock.dragTo = Math.min(Math.max(Math.floor((px - dock.restLeft) / dock.restStep), 0), dock.count - 1);
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
                                if (task.windows > 1) dock.showWindows(task, icon);
                                else root.activate(task, task.key === root.lastActiveKey && !task.model.IsMinimized);
                            }
                        }
                    }
                }
            }
        }

        // Drop an app from the AppGrid/menu → pinned where it was dropped
        DropArea {
            y: dock.frameTop
            width: parent.width
            height: dock.thickness
            onEntered: drag => drag.accepted = drag.hasUrls
            onDropped: drop => {
                const target = Math.min(Math.max(Math.floor((drop.x - dock.restLeft) / dock.restStep + 0.5), 0), dock.count);
                for (const url of drop.urls) {
                    if (!String(url).endsWith(".desktop")) continue;
                    if (tasksModel.launcherPosition(url) >= 0) continue;
                    if (tasksModel.requestAddLauncher(url))
                        root.moveLauncher(tasksModel.launcherPosition(url), target);
                }
                drop.accept();
            }
        }

        // Several windows of one app: a list of them to choose from
        PlasmaExtras.Menu {
            id: winMenu
            placement: menu.placement
        }
        function showWindows(task, parentItem) {
            root.lastActiveKey = task.key;
            winMenu.clearMenuItems();
            const kids = task.model.ChildCount ?? 0;
            for (let i = 0; i < kids; i++) {
                const child = tasksModel.makeModelIndex(task.index, i);
                const item = Qt.createQmlObject("import org.kde.plasma.extras as PlasmaExtras; PlasmaExtras.MenuItem {}", winMenu);
                item.text = tasksModel.data(child, Qt.DisplayRole) || "";
                item.icon = tasksModel.data(child, Qt.DecorationRole);
                item.clicked.connect(() => {
                    if (tasksModel.data(child, TaskManager.AbstractTasksModel.IsMinimized))
                        tasksModel.requestToggleMinimized(child);
                    tasksModel.requestActivate(child);
                });
                winMenu.addMenuItem(item);
            }
            winMenu.visualParent = parentItem;
            winMenu.openRelative();
        }

        PlasmaExtras.Menu {
            id: menu
            property var task: null
            readonly property bool opened: status === PlasmaExtras.Menu.Open
            placement: root.atTop ? PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
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
