// A number that counts to its new value (Levande utseende step 4, 11 Nov): `G.Count { value: 42; suffix: " %" }`.
// Platt or a game running: the number at once, written exactly as before (value + suffix).
import QtQuick

Text {
    id: count
    property real value
    property string suffix: ""
    readonly property bool moving: typeof look !== "undefined" && !!look && look.motion === true
    property real shown: value
    Glide on shown { duration: 600 }
    text: (moving && shown !== value ? shown.toFixed(Number.isInteger(value) ? 0 : 1) : String(value)) + suffix
}
