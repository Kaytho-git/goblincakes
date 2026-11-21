// The text sizes of the UI norm (docs/ux/norm.md 3, 22 Nov) – six instead of 10–12 per window. In units (G.Zoom
// draws them at 94 % and up). Use: `font.pixelSize: G.Type.body`. 12, 14 and 16 are going (12 → small, 14 →
// small or body after what it is, 16 → body), one window at a time.
pragma Singleton
import QtQuick

QtObject {
    readonly property int meta: 11      // times, version line, key hints, tags – never smaller
    readonly property int small: 13     // descriptions, card text, Note, table cells
    readonly property int body: 15      // running text, buttons, fields, list rows, a page's subtitle
    readonly property int label: 13     // SectionTitle / frame headings (Chakra Petch, capitals, letterSpacing 2.5)
    readonly property int tab: 15       // tabs (Chakra Petch, capitals, letterSpacing 2.5)
    readonly property int title: 30     // a page's title (Chakra Petch Bold, letterSpacing 4)
}
