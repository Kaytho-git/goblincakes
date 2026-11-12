// The mouse wheel in a list or page (every Flickable/ListView gets one: `FastWheel { flick: <id> }`, through a
// line `component FastWheel: G.FastWheel {}` in the window). Moved here from seven windows (P16, 12 Nov).
//   - step: share of the mouse wheel's step (GoblinAmp 0.5); a touchpad's pixels are used as they are
//   - chain: at its end (or with nothing to scroll) the list around it scrolls instead – otherwise a code box or
//     editor under the pointer stops the whole page (GoblinAmp: off)
//   - takeSideways: a sideways wheel/swipe emits sideways(amount) instead (the dashboard changes view)
import QtQuick

WheelHandler {
    id: wheel
    required property Flickable flick
    property real step: 1
    property bool chain: true
    property bool takeSideways: false
    signal sideways(real amount)
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y * wheel.step;
        event.accepted = true;
        if (wheel.takeSideways) {
            const side = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x;
            if (Math.abs(side) > Math.abs(delta)) {
                wheel.sideways(side);
                return;
            }
        }
        for (let f = wheel.flick; f; ) {
            const top = f.originY, bottom = top + Math.max(0, f.contentHeight - f.height);
            const y = Math.max(top, Math.min(bottom, f.contentY - delta));
            if (y !== f.contentY || !wheel.chain) {
                f.cancelFlick();
                f.contentY = y;
                return;
            }
            let p = f.parent;
            while (p && (p.cancelFlick === undefined || p.contentY === undefined))
                p = p.parent;
            f = p;
        }
    }
}
