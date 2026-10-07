// GOBLINCAKES Config: pin an app in the dock after installing it.
// Run through plasmashell's evaluateScript; %LAUNCHER% is replaced with "applications:<id>.desktop".
var launcher = "%LAUNCHER%";
panels().forEach(function (panel) {
    panel.widgets().forEach(function (widget) {
        if (widget.type !== "org.kde.plasma.icontasks") return;
        widget.currentConfigGroup = ["General"];
        var list = widget.readConfig("launchers", []);
        if (typeof list === "string") list = list ? list.split(",") : [];
        if (list.indexOf(launcher) < 0) {
            list.push(launcher);
            widget.writeConfig("launchers", list);
        }
    });
});
