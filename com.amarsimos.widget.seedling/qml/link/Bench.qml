pragma Singleton
import QtQml 2.12
import QtQuick.LocalStorage 2.12
import "../templates.js" as Templates
import "../writer.js" as Writer
import "../api.js" as Api

// Seedling's door for other extensions (MHCP-YUI): the Seedling widgets on the desktop register here,
// and preview(code, title, onResult) shows code in the workbench of the one registered last, then
// calls onResult({"ok", "result": "ok" / "error" / "unsafe", "status", "width", "height"}).
// Others reach it through Probe.qml, created at run time, so they still work when Seedling is missing.
QtObject {
    id: bench

    property var widgets: []
    readonly property int version: 1
    // MHCP-YUI when it is running (it sets itself here): her connection (seedlingConnection) can be
    // borrowed, and her data read (@yui, linkValue).
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
        return String(setting("widget_style", "")).trim() || Templates.DEFAULT_STYLE;
    }

    function writingModel() {
        return String(setting("model", "")).trim();
    }

    // ---- Seedling's own settings, shared by all its widgets (section 11.3): connection ("yui" /
    // "own"), provider, endpoint, api_key, model, widget_style. In Seedling's own local database (only
    // Seedling itself uses it: the safety check refuses LocalStorage in widget code). The API key is
    // never written to a widget's settings or to the log.
    property var database: null
    property var cache: ({})
    // Changes with every setSetting, for bindings.
    property int settingsRevision: 0

    function openDatabase() {
        if (database)
            return database;

        try {
            database = LocalStorage.openDatabaseSync("Seedling", "1.0", "Seedling's settings", 100000);
            database.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)");
                var rows = tx.executeSql("SELECT key, value FROM settings").rows;
                var all = {};
                for (var i = 0; i < rows.length; i++)
                    all[rows.item(i).key] = JSON.parse(rows.item(i).value);
                cache = all;
            });
        } catch (e) {
            console.log("Seedling: its settings cannot be opened:", e);
        }
        return database;
    }

    function setting(key, fallback) {
        openDatabase();
        return cache.hasOwnProperty(key) ? cache[key] : fallback;
    }

    function setSetting(key, value) {
        openDatabase();
        var all = JSON.parse(JSON.stringify(cache));
        all[key] = value;
        cache = all;
        settingsRevision++;
        if (!database)
            return ;

        try {
            database.transaction(function(tx) {
                tx.executeSql("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", [key, JSON.stringify(value)]);
            });
        } catch (e) {
            console.log("Seedling: a setting cannot be saved:", key);
        }
    }

    // Widget Style and Seedling Model were kept on each widget before: moved here the first time.
    function moveOldSettings(widget) {
        var style = String(widget.settings.widget_style || "").trim();
        if (style && !String(setting("widget_style", "")).trim())
            setSetting("widget_style", style);

        var model = String(widget.settings.seedling_model || "").trim();
        if (model && !String(setting("model", "")).trim())
            setSetting("model", model);

        if (widget.settings.widget_style !== undefined)
            widget.settings.widget_style = undefined;

        if (widget.settings.seedling_model !== undefined)
            widget.settings.seedling_model = undefined;

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

    // ---- Writing a widget (section 11 of "Seedling Development Plan.md"): Seedling's own flow, with
    // MHCP-YUI's connection or its own (Connection). MHCP-YUI only says it in her chat.

    // The connection used: "yui" (MHCP-YUI's, when she is there and Connection is Yui) or "own".
    function connectionKind() {
        var hasYui = !!(writer && writer.seedlingConnection);
        return hasYui && setting("connection", "yui") !== "own" ? "yui" : "own";
    }

    // Whether a widget can be written now ("" when it can, else why not).
    function cannotWrite() {
        if (connectionKind() === "yui")
            return "";

        var lacking = Api.missing(ownConfig());
        return lacking ? "Seedling Settings: " + lacking + " is not set" : "";
    }

    function ownConfig() {
        return {
            "provider": setting("provider", "openai"),
            "endpoint": setting("endpoint", ""),
            "apiKey": setting("api_key", ""),
            "model": setting("model", "")
        };
    }

    // One request through the chosen connection: onDelta(soFar), onFinished(text, isError). Returns
    // {abort()}. timeout: no data for that long ends it.
    function ask(system, user, onDelta, onFinished) {
        if (connectionKind() === "yui")
            return writer.seedlingConnection(system, user, writingModel(), onDelta, onFinished);

        var timer = Qt.createQmlObject("import QtQml 2.12; Timer { interval: 240000 }", bench);
        var finished = false;
        var handle = Api.request(ownConfig(), system, user, 16384, function(soFar) {
            timer.restart();
            onDelta(soFar);
        }, function(text, isError) {
            if (finished)
                return ;

            finished = true;
            timer.stop();
            timer.destroy();
            onFinished(text, isError);
        });
        timer.triggered.connect(function() {
            handle.abort();
        });
        timer.start();
        return handle;
    }

    // The job being written, or null: {handle, stopped}.
    property var job: null

    // Stop (the workbench, Yui's chat): the request ends; what was written stays.
    function stop() {
        if (!job)
            return ;

        job.stopped = true;
        if (job.handle)
            job.handle.abort();

    }

    // Writes request (or changes the code there to it) for the target widget, live in its workbench.
    // onProgress(state) every second and at each step: {stage "writing" | "editing" | "fixing" |
    // "checking", lines, edits, seconds, attempt, problem}. onDone(kind, message, code) once: kind
    // "done", "edited", "failed", "stopped", "offline" (not allowed online), "busy", "missing" (no
    // widget), "unset" (no connection). Returns "" or why it did not start.
    function write(request, onProgress, onDone) {
        if (widgets.length === 0) {
            onDone("missing", "no Seedling widget on the desktop", "");
            return "missing";
        }
        if (job) {
            onDone("busy", "a widget is being written", "");
            return "busy";
        }
        var why = cannotWrite();
        if (why) {
            onDone("unset", why, "");
            return why;
        }
        var withYui = !!writer;
        var current = currentCode();
        var editing = current.trim() !== "";
        var system = Writer.codePrompt(allowNetwork(), editing, withYui) + Writer.styleNote(writingStyle()) + Writer.templateNote(editing ? "" : templateFor(request));
        var state = {
            "stage": editing ? "editing" : "writing",
            "lines": 0,
            "edits": 0,
            "seconds": 0,
            "attempt": 0,
            "problem": ""
        };
        var started = Date.now();
        var ticker = Qt.createQmlObject("import QtQml 2.12; Timer { interval: 1000; repeat: true }", bench);
        var current_job = {
            "handle": null,
            "stopped": false
        };
        // The last way out was taken: the whole code asked for once after the edits did not fit.
        var wholeTaken = false;
        var progress = function() {
            state.seconds = Math.round((Date.now() - started) / 1000);
            if (onProgress)
                onProgress(state);

        };
        var finish = function(kind, message, code) {
            ticker.stop();
            ticker.destroy();
            job = null;
            var ok = kind === "done" || kind === "edited";
            endWriting(ok, message);
            console.log("Seedling: " + kind + ", " + message);
            onDone(kind, message, code || "");
        };
        var askFor;
        // Asks again with what went wrong (twice at most); when editing, after that once more for the
        // whole code.
        var retry = function(problem, code, whole) {
            if (state.attempt >= 2) {
                if (editing && !whole && !wholeTaken) {
                    wholeTaken = true;
                    state.stage = "writing";
                    state.lines = 0;
                    state.edits = 0;
                    setPhase(qsTr("The edits did not fit · Thinking about the whole code..."));
                    progress();
                    return askFor(code, problem, true);
                }
                return finish("failed", "改了几次还是不行：" + String(problem).split("\n")[0], code);
            }
            state.attempt++;
            state.stage = "fixing";
            state.problem = String(problem).split("\n")[0];
            state.lines = 0;
            state.edits = 0;
            setPhase(qsTr("Thinking about the fix (%1 / 2): %2").arg(state.attempt).arg(state.problem));
            progress();
            askFor(code, problem, whole);
        };
        var show = function(code, changes, whole) {
            state.stage = "checking";
            setPhase(qsTr("Checking and rendering..."));
            progress();
            var refused = preview(code, request, function(result) {
                console.log("Seedling: " + result.result + " " + result.status);
                // Shown, but some @setting / @keep declarations do not take effect: asked to fix them
                // once (while a fix is left); otherwise it is done as it is.
                if (result.ok && result.notes && result.notes.length > 0 && !state.notesAsked && state.attempt < 2) {
                    state.notesAsked = true;
                    return retry("代码能显示，但这些 @setting / @keep / @yui 声明没有生效：\n" + result.notes.join("\n") + (editing && !whole ? "\n请用 SEARCH/REPLACE 块改正。" : "\n请改正后输出完整代码。"), code, whole);
                }
                if (result.ok)
                    return finish(changes ? "edited" : "done", changes ? "改了 " + changes.count + " 处（+" + changes.added + " −" + changes.removed + " 行），满意就点 ○ 保存" : "完成 · " + result.width + " × " + result.height + "，满意就点 ○ 保存", code);

                // Not allowed online (the user said no): said so, not rewritten without it behind
                // their back.
                if (result.networkDeclined)
                    return finish("offline", "没有允许联网", code);

                retry("上面这段代码没有通过：" + result.status + (editing && !whole ? "\n请用 SEARCH/REPLACE 块改正。" : "\n请改正后输出完整代码。"), code, whole);
            }, changes);
            if (refused)
                finish("failed", refused, code);

        };
        askFor = function(code, problem, whole) {
            var edits = editing && !whole;
            current_job.handle = ask(system, Writer.codeRequest(request, code, problem, editing && whole), function(soFar) {
                var count = edits ? Writer.editCount(soFar) : 0;
                if (count > 0) {
                    if (count !== state.edits) {
                        state.edits = count;
                        setPhase(qsTr("Changing · %1 place(s)").arg(count));
                        progress();
                    }
                    return ;
                }
                // Written whole (also when the model chose to while editing): streamed into the editor.
                var partial = Writer.partialCode(soFar);
                if (!partial)
                    return ;

                streamCode(partial);
                var lines = partial.split("\n").length;
                if (lines !== state.lines) {
                    state.lines = lines;
                    state.stage = state.stage === "editing" ? "writing" : state.stage;
                    setPhase(qsTr("Writing · %1 lines").arg(lines));
                    progress();
                }
            }, function(text, isError) {
                if (current_job.stopped)
                    return finish("stopped", "已停止" + (edits ? "，代码没有改动" : "，写到一半的代码留在工作台里"), "");

                if (isError)
                    return finish("failed", "写代码的请求失败了：" + String(text).split("\n")[0], "");

                var blocks = edits ? Writer.edits(text) : [];
                if (blocks.length > 0) {
                    var applied = Writer.applyEdits(code, blocks);
                    console.log("Seedling: " + blocks.length + " edit(s), " + (applied.ok ? "applied" : applied.failed.length + " did not fit"));
                    if (!applied.ok)
                        return retry(Writer.editProblem(applied.failed), code, false);

                    return show(applied.code, {
                        "lines": applied.changed,
                        "added": applied.added,
                        "removed": applied.removed,
                        "count": blocks.length
                    }, false);
                }
                // Cut off (too long for the limit): asked again for a shorter one.
                if (Writer.codeCut(text))
                    return retry("上一次的代码太长，没写完就被截断了。请大幅精简，控制在 120 行以内，输出完整代码。", code, true);

                var qml = Writer.codeFrom(text);
                if (!qml) {
                    if (edits)
                        return retry("没有找到 SEARCH/REPLACE 块。请按格式输出要改的地方。", code, false);

                    return finish("failed", "模型没有给出代码", "");
                }
                show(qml, null, true);
            });
        };
        ticker.triggered.connect(progress);
        ticker.start();
        job = current_job;
        beginWriting(request, editing);
        progress();
        askFor(current, "", false);
        return "";
    }

    // The workbench's Generate: a widget written from what was typed there (progress and the result
    // in the workbench itself). "" or why not.
    function generate(request, onDone) {
        return write(request, null, function(kind, message) {
            if (onDone)
                onDone(message, kind === "done" || kind === "edited");

        });
    }

    function register(widget) {
        moveOldSettings(widget);
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
