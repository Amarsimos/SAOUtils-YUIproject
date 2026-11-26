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

    // Pause All Seedling Widgets (Seedling Settings): kept in paused.txt in the package, written at once.
    readonly property url pausedFile: Qt.resolvedUrl("../../paused.txt")

    function paused() {
        try {
            var request = new XMLHttpRequest();
            // "?t=": not the copy read before.
            request.open("GET", pausedFile + "?t=" + Date.now(), false);
            request.send(null);
            return String(request.responseText || "").trim() === "1";
        } catch (e) {
            return false;
        }
    }

    function setPaused(on) {
        try {
            var request = new XMLHttpRequest();
            request.open("PUT", pausedFile, false);
            request.send(on ? "1" : "0");
        } catch (e) {
            console.log("Seedling: cannot write", pausedFile, e);
        }
        widgets.forEach(function(widget) {
            if (on)
                widget.pause();
            else
                widget.startUp();
        });
    }

    // The workbench Yui writes into (beginWriting), or null.
    property var writingBench: null

    // Opens the workbench of the last widget in its writing state; returns it, or null. keep: the code
    // stays (Yui changes it with edits) instead of being written anew.
    function beginWriting(title, keep) {
        if (widgets.length === 0)
            return null;

        var bench = widgets[widgets.length - 1].openWorkbench();
        if (bench)
            bench.beginWriting(String(title || ""), keep === true);

        writingBench = bench;
        return bench;
    }

    function streamCode(code) {
        if (writingBench)
            writingBench.streamCode(code);

    }

    function setPhase(text) {
        if (writingBench)
            writingBench.setPhase(text);

    }

    function endWriting(ok, message) {
        if (writingBench)
            writingBench.endWriting(ok, message);

        writingBench = null;
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
