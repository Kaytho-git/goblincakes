// One scale for every own window (docs/ux/norm.md 2, 22 Nov): zoom = base × screen × growth.
//   base 0.94     – the user's choice 5 Nov (94 % at the start size, 104 % maximized – "känns bättre")
//   screen        – a 1440p screen draws a little bigger (1 + 0.5 × (height/1080 − 1), at most 1.3: ≈1.17 at 1440p),
//                   1 when Plasma or the user already scales (devicePixelRatio ≠ 1). screenWeight is the one number
//                   to change after trying a real 1440p screen.
//   growth        – 1.00 at the start size → 1 + grow (1.10) maximized, evenly between (Config's formula since 5 Nov)
// The window draws its layout in units: `G.Zoom { id: zoomer; win: win; startW: 1180; startH: 800 }`, then
// `width: zoomer.startWidth; height: zoomer.startHeight; minimumWidth: zoomer.px(760) …`. It scales win.contentItem
// (as Config did with fitZoom) – so no child may use win.width/win.height for layout; use the root item's size.
// No QT_SCALE_FACTOR in the window's program any more (it made devicePixelRatio 0.9).
import QtQuick
import QtQuick.Window

QtObject {
    id: z
    required property Window win
    property real startW: 1000
    property real startH: 700
    property real base: 0.94
    property real grow: 0.10
    property real screenWeight: 0.5
    property bool growing: true          // false: the same size whatever the window's size (the voice box, Dashboard)

    readonly property var scr: win ? win.screen : null
    readonly property real screenFactor: !scr || Math.abs(scr.devicePixelRatio - 1) > 0.01 ? 1
        : Math.max(1, Math.min(1.3, 1 + screenWeight * (scr.height / 1080 - 1)))
    readonly property real startZoom: base * screenFactor
    function px(units) { return Math.round(units * startZoom) }
    // the start size, never more than 85 % of the screen
    readonly property real startWidth: Math.min(px(startW), scr ? scr.desktopAvailableWidth * 0.85 : px(startW))
    readonly property real startHeight: Math.min(px(startH), scr ? scr.desktopAvailableHeight * 0.85 : px(startH))
    readonly property real grown: !growing || !scr ? 0
        : (Math.max(0, Math.min(1, (win.width - startWidth) / Math.max(1, scr.desktopAvailableWidth - startWidth)))
           + Math.max(0, Math.min(1, (win.height - startHeight) / Math.max(1, scr.desktopAvailableHeight - startHeight)))) / 2
    readonly property real zoom: startZoom * (1 + grow * grown)

    function fit() {
        if (!win || !win.contentItem)
            return;
        const w = win.width / zoom, h = win.height / zoom;
        win.contentItem.transformOrigin = Item.TopLeft;
        if (win.contentItem.scale !== zoom) win.contentItem.scale = zoom;
        if (Math.abs(win.contentItem.width - w) > 0.01) win.contentItem.width = w;
        if (Math.abs(win.contentItem.height - h) > 0.01) win.contentItem.height = h;
    }
    onZoomChanged: Qt.callLater(fit)
    property Connections _w: Connections {
        target: z.win
        function onWidthChanged() { Qt.callLater(z.fit) }
        function onHeightChanged() { Qt.callLater(z.fit) }
        function onVisibleChanged() { Qt.callLater(z.fit) }
    }
    // Qt sets the content back to the window's size on every resize event – also when the size stays the same
    // (Dashboard: made hidden at 1920×1080, then showFullScreen on a 1080p screen → no widthChanged, the
    // content stayed 1920 wide at 94 % = a black strip right and below, 22 Nov). Fit again when that happens.
    property Connections _c: Connections {
        target: z.win ? z.win.contentItem : null
        function onWidthChanged() { Qt.callLater(z.fit) }
        function onHeightChanged() { Qt.callLater(z.fit) }
    }
    Component.onCompleted: fit()
}
