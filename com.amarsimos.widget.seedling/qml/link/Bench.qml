pragma Singleton
import QtQml 2.12
import "../templates.js" as Templates

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

    // The code being worked on: the target widget's open workbench's, else its saved code ("" when none).
    function currentCode() {
        if (widgets.length === 0)
            return "";

        var widget = target();
        return widget.workbench ? widget.workbench.currentCode() : (widget.code || "");
    }

    // What Yui's writing follows, set in the target widget's Seedling Settings (kept in Seedling, so
    // it stays when Seedling works on its own): Widget Style (or the default) and Seedling Model ("":
    // the chat's model).
    function writingStyle() {
        var style = widgets.length > 0 ? String(target().settings.widget_style || "").trim() : "";
        return style || Templates.DEFAULT_STYLE;
    }

    function writingModel() {
        return widgets.length > 0 ? String(target().settings.seedling_model || "").trim() : "";
    }

    // A template of the same kind as request, for Yui to look at ("" when none fits).
    function templateFor(request) {
        var found = Templates.match(request);
        return found ? found.code : "";
    }

    // Whether the target widget may go online (its Network).
    function allowNetwork() {
        return widgets.length > 0 && target().settings.allow_network === true;
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

    // Opens the target widget's workbench in its writing state; returns it, or null. keep: the code
    // stays (Yui changes it with edits) instead of being written anew.
    function beginWriting(title, keep) {
        if (widgets.length === 0)
            return null;

        writingWidget = target();
        var bench = openFor(writingWidget);
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

    // The widget whose workbench was opened last (Yui writes for it), else the last placed.
    property var lastUsed: null

    function used(widget) {
        lastUsed = widget;
    }

    // Opens a widget's workbench for Yui: it does not count as the user's own opening (that is what
    // decides who she writes for next).
    function openFor(widget) {
        var kept = lastUsed;
        var bench = widget.openWorkbench();
        lastUsed = kept;
        return bench;
    }

    function target() {
        if (lastUsed && widgets.indexOf(lastUsed) !== -1)
            return lastUsed;

        return widgets.length > 0 ? widgets[widgets.length - 1] : null;
    }

    // "No. 2" for the workbench's title when there is more than one Seedling widget ("" otherwise).
    function labelOf(widget) {
        return widgets.length > 1 && widgets.indexOf(widget) !== -1 ? "No. " + (widgets.indexOf(widget) + 1) : "";
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

        // While Yui writes, the widget she started for: opening another workbench meanwhile does not
        // send the result there. Removed meanwhile: not sent anywhere else.
        var widget = target();
        if (writingWidget) {
            if (widgets.indexOf(writingWidget) === -1)
                return "the Seedling widget being written for was removed";

            widget = writingWidget;
        }
        var bench = openFor(widget);
        if (!bench)
            return "the workbench could not be opened";

        bench.loadExternal(String(code || ""), String(title || ""), onResult, changes || null);
        return "";
    }
}
