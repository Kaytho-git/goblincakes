// The UI norm's measures in one place (docs/ux/norm.md, 22 Nov): a page of at most `page` units, centred in the
// window with at least `margin` on each side. Use: `x: G.Norm.pageX(view.width); width: G.Norm.pageWidth(view.width)`.
pragma Singleton
import QtQuick

QtObject {
    readonly property int page: 1240        // widest page (forms, settings, lists) – just over Config's start width
    readonly property int reading: 960      // widest chat/reading column (Goblin AI)
    readonly property int margin: 48        // side margin of a page
    readonly property int marginNarrow: 24  // … in windows under 900 units

    function pageWidth(w, maxW, m) {
        const mm = m === undefined ? margin : m;
        return Math.max(0, Math.min(w - 2 * mm, maxW === undefined ? page : maxW));
    }
    function pageX(w, maxW, m) {
        return Math.round((w - pageWidth(w, maxW, m)) / 2);
    }
}
