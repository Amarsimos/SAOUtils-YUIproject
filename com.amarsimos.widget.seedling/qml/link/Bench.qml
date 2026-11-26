pragma Singleton
import QtQml 2.12

// Seedling's door for other extensions (MHCP-YUI): the Seedling widgets on the desktop register here,
// and preview(code, title, onResult) shows code in the workbench of the one registered last, then
// calls onResult({"ok", "result": "ok" / "error" / "unsafe", "status", "width", "height"}).
// Others reach it through Probe.qml, created at run time, so they still work when Seedling is missing.
QtObject {
    property var widgets: []
    readonly property int version: 1
    // Writes code for the workbench's Generate: MHCP-YUI when it is running (it sets itself here), with
    // seedlingWrite(request, onDone(message, ok)).
    property var writer: null

    // The code being worked on: the open workbench's, else the last widget's ("" when none).
    function currentCode() {
        if (widgets.length === 0)
            return "";

        var widget = widgets[widgets.length - 1];
        return widget.workbench ? widget.workbench.currentCode() : (widget.code || "");
    }

    // Whether the last widget may go online (its workbench's Network).
    function allowNetwork() {
        return widgets.length > 0 && widgets[widgets.length - 1].settings.allow_network === true;
    }

    // The workbench's Generate: has the writer write request; "" or why not.
    function generate(request, onDone) {
        if (!writer)
            return "needs MHCP-YUI (Yui writes the code)";

        writer.seedlingWrite(request, onDone);
        return "";
    }

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
