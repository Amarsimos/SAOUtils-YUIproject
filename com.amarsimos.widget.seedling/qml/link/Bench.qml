pragma Singleton
import QtQml 2.12

// Seedling's door for other extensions (MHCP-YUI): the Seedling widgets on the desktop register here,
// and preview(code, title, onResult) shows code in the workbench of the one registered last, then
// calls onResult({"ok", "result": "ok" / "error" / "unsafe", "status", "width", "height"}).
// Others reach it through Probe.qml, created at run time, so they still work when Seedling is missing.
QtObject {
    property var widgets: []
    readonly property int version: 1

    function register(widget) {
        if (widgets.indexOf(widget) === -1)
            widgets = widgets.concat([widget]);

    }

    function unregister(widget) {
        widgets = widgets.filter(function(other) {
            return other !== widget;
        });
    }

    // Returns "" when it was shown, or why not.
    function preview(code, title, onResult) {
        if (widgets.length === 0)
            return "no Seedling widget on the desktop";

        var widget = widgets[widgets.length - 1];
        var bench = widget.openWorkbench();
        if (!bench)
            return "the workbench could not be opened";

        bench.loadExternal(String(code || ""), String(title || ""), onResult);
        return "";
    }
}
