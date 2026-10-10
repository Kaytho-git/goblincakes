// GOBLINCAKES Config opens in the middle of the main screen (the first in Display settings'
// priority order), not on the screen you happen to be on or down by the dock while the panels
// and screens are still being set up at login (10 Oct).
const CENTERED = ["goblincakes-config"];

function center(window) {
    if (!window || CENTERED.indexOf(window.resourceClass) < 0)
        return;
    const screen = workspace.screenOrder.length ? workspace.screenOrder[0] : window.output;
    const area = workspace.clientArea(KWin.PlacementArea, screen, workspace.currentDesktop);
    const geo = window.frameGeometry;
    window.frameGeometry = {
        x: Math.round(area.x + Math.max(0, (area.width - geo.width) / 2)),
        y: Math.round(area.y + Math.max(0, (area.height - geo.height) / 2)),
        width: geo.width,
        height: geo.height
    };
}

workspace.windowAdded.connect(center);
