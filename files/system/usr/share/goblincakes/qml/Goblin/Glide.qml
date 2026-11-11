// A number that glides (Levande utseende step 4, 11 Nov): `G.Glide on width {}` on a bar's fill, a position …
// Only with Stil: Levande and no game running (look.motion); otherwise it jumps as before.
import QtQuick

Behavior {
    id: glide
    property int duration: 450
    enabled: typeof look !== "undefined" && !!look && look.motion === true
    NumberAnimation { duration: glide.duration; easing.type: Easing.OutCubic }
}
