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

    // The widget Yui writes for (beginWriting), or null. Its workbench is looked up each time, not
    // kept: closed while she writes, it is gone (the progress is then not shown), and the result opens
    // it again (preview() opens it).
    property var writingWidget: null

    // The workbench of the widget being written for while it is open, else null.
    function writingBench() {
        var widget = writingWidget;
        return widget && widgets.indexOf(widget) !== -1 ? widget.workbench : null;
    }

    // Opens the workbench of the last widget in its writing state; returns it, or null. keep: the code
    // stays (Yui changes it with edits) instead of being written anew.
    function beginWriting(title, keep) {
        if (widgets.length === 0)
            return null;

        writingWidget = widgets[widgets.length - 1];
        var bench = writingWidget.openWorkbench();
        if (bench)
            bench.beginWriting(String(title || ""), keep === true);

        return bench;
    }

    function streamCode(code) {
        var bench = writingBench();
        if (bench)
            bench.streamCode(code);

    }

    function setPhase(text) {
        var bench = writingBench();
        if (bench)
            bench.setPhase(text);

    }

    function endWriting(ok, message) {
        var bench = writingBench();
        if (bench)
            bench.endWriting(ok, message);

        writingWidget = null;
    }

    // Stop (the workbench): the writer ends its request; what was written stays.
    function stop() {
        if (writer && writer.seedlingStop)
            writer.seedlingStop();

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
    // changes (optional, Yui's edits): {lines: changed line numbers (0-based), added, removed, count}.
    function preview(code, title, onResult, changes) {
        if (widgets.length === 0)
            return "no Seedling widget on the desktop";

        var widget = widgets[widgets.length - 1];
        var bench = widget.openWorkbench();
        if (!bench)
            return "the workbench could not be opened";

        bench.loadExternal(String(code || ""), String(title || ""), onResult, changes || null);
        return "";
    }
}
