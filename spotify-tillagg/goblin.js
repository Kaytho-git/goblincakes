// GOBLINCAKES för Spotify (21 Oct): only in the Spotify web app that GOBLINCAKES starts
// (/usr/libexec/goblincakes-spotify-web). Its address ends with #goblincakes=<colours>, the
// user's accent from GOBLINCAKES' colour choice (Utseende → Färg): color.hover.on.text.dim,
// six hex digits each. It is kept for the window (sessionStorage), so reloads keep the look;
// ordinary Spotify tabs never get the class and look as Spotify made them.
(function () {
    const KEY = "goblincakes-spotify";
    const NAMES = ["accent", "hover", "on", "text", "dim"];
    let colours = null;
    const match = location.hash.match(/goblincakes=([0-9a-fA-F.]*)/);
    if (match) {
        colours = match[1].split(".");
        try {
            sessionStorage.setItem(KEY, match[1]);
        } catch (e) { /* storage off: this load only */ }
        history.replaceState(history.state, "", location.pathname + location.search);
    } else {
        try {
            const saved = sessionStorage.getItem(KEY);
            colours = saved !== null ? saved.split(".") : null;
        } catch (e) { /* no storage */ }
    }
    if (!colours)
        return;

    const root = document.documentElement;
    function mark() {
        if (!root.classList.contains("goblincakes"))
            root.classList.add("goblincakes");
    }
    mark();
    // The colours as a style element of our own (Spotify may set the html element's style)
    const vars = NAMES.filter(function (name, i) { return /^[0-9a-fA-F]{6}$/.test(colours[i] || ""); })
        .map(function (name) { return "--gc-" + name + ":#" + colours[NAMES.indexOf(name)] + ";"; }).join("");
    const style = document.createElement("style");
    style.id = "goblincakes-accent";
    style.textContent = "html.goblincakes{" + vars + "}";
    (document.head || root).appendChild(style);
    // Spotify sets the html element's classes itself (its theme): put ours back if it goes
    new MutationObserver(mark).observe(root, { attributes: true, attributeFilter: ["class"] });
})();
