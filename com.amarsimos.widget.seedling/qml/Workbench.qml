import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Shapes 1.12
import QtGraphicalEffects 1.0
// For Qt.application.screens, used to keep the workbench on a screen.
import QtQuick.Window 2.12
import "safety.js" as Safety
import "link" 1.0 as Link
import "sandbox.js" as Sandbox
import "props.js" as Props
import "templates.js" as Templates

// The Seedling workbench, drawn as SAO_UI-Window (the original's message window; colors measured from
// it): a title band (#E4E4E4 to #F9F9F9), a grey band (#D8D8D8, shaded at its top and bottom) with
// the tools, the code beside its live preview and what happened, and a white band with the SAO ok /
// cancel buttons (Save to the widget, Close), each centered in its half. The draft is kept while
// closed; Save keeps a version (up to 20).
NVG.View {
    id: bench

    property var targetWidget
    readonly property var settings: targetWidget.settings
    property bool showVersions: false
    // What the last render found wrong, in full: [{line (1-based, 0 when none), text}]. The status line
    // says the first and how many more; Problems lists them all in the right pane.
    property var problemList: []
    property bool showProblems: false
    readonly property bool previewShown: !showVersions && !showProblems

    // The status line for problems: the first one, and how many more.
    function problemSummary(prefix) {
        if (problemList.length === 0)
            return prefix;

        return prefix + problemList[0].text + (problemList.length > 1 ? "  (+" + (problemList.length - 1) + ")" : "");
    }

    // All the problems, one per line.
    function problemsText() {
        return problemList.map(function(problem) {
            return problem.text;
        }).join("\n");
    }

    function copyProblems() {
        clipboardHelper.text = problemsText();
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        clipboardHelper.text = "";
        status = qsTr("Copied %1 problem(s).").arg(problemList.length);
    }

    // Sent to Yui's chat at once; the start ("帮我修好这个挂件：", Yui's SEEDLING_FIX_PREFIX) makes her fix
    // it with the code flow. An older Yui without sendToChat: written in her input box instead.
    function sendProblemsToYui() {
        var yui = Link.Bench.yui;
        if (!yui)
            return ;

        var text = "帮我修好这个挂件：\n" + problemsText();
        if (yui.sendToChat)
            yui.sendToChat(text);
        else if (yui.prefillChat)
            yui.prefillChat(text);
    }

    // Problems: a click puts the cursor at the line (with Code Editor on).
    function goToLine(line) {
        if (line <= 0 || !showCode)
            return ;

        editor.cursorPosition = Math.min(lineStart(line - 1), editor.length);
        editor.forceActiveFocus();
    }
    property var preview: null
    // "ok", "error" or "unsafe", and what it says.
    property string result: "ok"
    property string status: ""
    property var versions: settings.versions || []
    property int versionIndex: versions.length - 1
    readonly property color ink: "#4D4D4D"
    // The height of the headers above the boxes (both columns).
    readonly property int headerHeight: 28
    // Chinese (or Japanese) text: SAO UI has no such characters and the system picked any font for
    // them. The Message Font of Yui's Equipment (MHCP-YUI running), else her default; English stays in
    // SAO UI.
    readonly property string messageFont: Link.Bench.writer && Link.Bench.writer.fontFamilyOf ? Link.Bench.writer.fontFamilyOf(Link.Bench.writer.styles.bubble_font_family) : "Source Han Sans SC"

    function fontFor(text) {
        return /[　-ヿ㐀-鿿豈-﫿＀-￯]/.test(String(text || "")) ? messageFont : "SAO UI";
    }
    // Code Editor (Seedling Settings, advanced, off by default): the code, Examples and Network shown.
    readonly property bool showCode: settings.show_code === true
    // The preview's scale: zoom when set (− / + / 100%, Ctrl + wheel), else Fit: 1, or less when the
    // widget is larger than the preview area.
    property real zoom: 0
    readonly property real fitScale: preview && preview.width > 0 && preview.height > 0 ? Math.min(1, previewArea.width / preview.width, previewArea.height / preview.height) : 1
    readonly property real previewScale: zoom > 0 ? zoom : fitScale

    function zoomBy(step) {
        zoom = Math.max(0.25, Math.min(4, Math.round((previewScale + step) * 4) / 4));
    }
    // The bands are translucent as Yui's chat (her Chat Opacity in Equipment when MHCP-YUI runs, else
    // 80 %); the code, the preview and the text on them stay opaque.
    readonly property real panelAlpha: Link.Bench.writer && Link.Bench.writer.chatOpacity !== undefined ? Link.Bench.writer.chatOpacity : 0.8
    readonly property int leastWidth: 720
    readonly property int leastHeight: 520
    readonly property int titleHeight: 64
    readonly property int buttonsHeight: 96
    // Room around the panel for its shadow (the view is this much larger on every side).
    readonly property int shadowMargin: 10
    // Open / close animation, as Yui's chat (the SAO Utils mail box message panel): the panel widens
    // from 10 % (scaleX) and fades in (panelOpacity), the message sound, the grey band unfolds between
    // the title and button bands (reveal), then its content fades in (contentOpacity).
    property real scaleX: 0.1
    property real panelOpacity: 0
    property real reveal: 0
    property real contentOpacity: 0

    // Yui is writing (Bench.beginWriting ... endWriting): the code streams into the read-only editor,
    // phase says the step, an orange strip breathes under the title band and Stop ends it.
    property bool writing: false
    // Lines Yui changed in her last edit (0-based), marked in the editor until the code is typed in.
    property var changedLines: []
    // Lines the last render found wrong (0-based): compile errors or what the safety check refused.
    property var errorLines: []
    property bool loadingExternal: false
    property string phase: ""
    property double writingSince: 0
    property int writingSeconds: 0

    // ---- Placed and layered as Yui's chat (YuiView.qml): shown where its widget is (desktop or
    // launcher) and at its z (on top, normal, at the bottom); opened at the remembered offset from the
    // widget, the first time beside it on the side with more room, kept in its screen (or the
    // launcher's space); placed again when the widget moves between the desktop and the launcher.
    readonly property var hostView: targetWidget.NVG.View.view
    readonly property bool inLauncher: compositor === NVG.LauncherCompositor
    property rect anchorRect
    property bool placing: false
    property bool moving: false
    property bool settling: false

    function widgetRect() {
        var corner = targetWidget.mapToGlobal(0, 0);
        return Qt.rect(corner.x, corner.y, targetWidget.width, targetWidget.height);
    }

    // Where it is relative to the widget, and its size (the widget's settings, the same for the
    // desktop and the launcher).
    function saveGeometry() {
        settings.bench_offset = {
            "dx": Math.round(x - anchorRect.x),
            "dy": Math.round(y - anchorRect.y),
            "width": Math.round(width),
            "height": Math.round(height)
        };
    }

    // The area containing a point ({virtualX, virtualY, width, height}), or null: in the launcher its
    // space, on the desktop the screen there.
    function areaAt(px, py) {
        if (inLauncher) {
            var g = NVG.LauncherCompositor.geometry;
            if (g.width <= 0 || (px >= g.x && px < g.x + g.width && py >= g.y && py < g.y + g.height))
                return {
                "virtualX": g.x,
                "virtualY": g.y,
                "width": g.width > 0 ? g.width : 1920,
                "height": g.height > 0 ? g.height : 1080
            };

            return null;
        }
        var screens = Qt.application.screens;
        for (var i = 0; i < screens.length; i++) {
            var screen = screens[i];
            if (px >= screen.virtualX && px < screen.virtualX + screen.width && py >= screen.virtualY && py < screen.virtualY + screen.height)
                return screen;

        }
        return null;
    }

    function place(anchor) {
        placing = true;
        anchorRect = anchor;
        var saved = settings.bench_offset;
        width = Math.max(leastWidth, saved ? saved.width : 900);
        height = Math.max(leastHeight, saved ? saved.height : 620);
        var area = areaAt(anchor.x + anchor.width / 2, anchor.y + anchor.height / 2) || areaAt(0, 0) || Qt.application.screens[0];
        var left = area.virtualX, top = area.virtualY, right = left + area.width, bottom = top + area.height;
        if (saved) {
            x = anchor.x + saved.dx;
            y = anchor.y + saved.dy;
        } else {
            var roomRight = right - (anchor.x + anchor.width);
            var roomLeft = anchor.x - left;
            x = roomRight >= width || roomRight >= roomLeft ? anchor.x + anchor.width : anchor.x - width;
            y = anchor.y + anchor.height / 2 - height / 2;
        }
        x = Math.round(Math.max(left, Math.min(right - width, x)));
        y = Math.round(Math.max(top, Math.min(bottom - height, y)));
        placing = false;
    }

    function follow() {
        if (visible && !aniClose.running)
            place(widgetRect());

    }

    // Changing the compositor resets x and y: placed again at once, and kept there while it settles.
    onCompositorChanged: {
        z = Qt.binding(function() {
            return bench.hostView ? bench.hostView.z : 0;
        });
        settling = true;
        settleTimer.restart();
        follow();
    }
    onXChanged: {
        if (settling && !placing && !moving)
            follow();

    }
    onYChanged: {
        if (settling && !placing && !moving)
            follow();

    }

    Connections {
        target: bench.settling ? bench.hostView : null
        ignoreUnknownSignals: true
        onXChanged: bench.follow()
        onYChanged: bench.follow()
    }

    Timer {
        id: settleTimer

        interval: 400
        onTriggered: bench.settling = false
    }

    // The close animation has finished and the view is gone.
    signal dismissed()

    // Closes as the chat does: the dismiss sound, narrows back to 10 % while fading out, then goes.
    function dismiss() {
        if (aniClose.running)
            return ;

        aniOpen.stop();
        aniClose.start();
    }
    // Examples (Code Editor): Seedling's templates (templates.js).
    readonly property var examples: Templates.TEMPLATES

    // Checks and renders the editor text into the preview; true when it is shown.
    // The problems of the last refusal by the safety check ([] when it was not refused).
    property var refusedProblems: []
    // A question about going online is open (not asked twice at once). Asked only on Save (○) and for
    // code Yui brings; typing renders live and never asks (it asked again with every key).
    property bool networkAsking: false

    // Refused only for going online (Network off): asks with SAO Utils' message box whether this
    // widget may go online; then(allowed) after the answer (allowed: Network turned on, rendered again).
    // question: the message box's text (default: the plain question).
    // Asked while another network question is open: called with that answer.
    property var networkWaiting: []

    function askNetwork(then, question) {
        if (settings.allow_network === true)
            return then(false);

        // A question already open: this one waits for its answer (not taken as a no).
        if (networkAsking) {
            networkWaiting = networkWaiting.concat([then]);
            return ;
        }
        networkAsking = true;
        var answered = function(allowed) {
            networkAsking = false;
            if (allowed) {
                settings.allow_network = true;
                render(true);
            }
            var waiting = networkWaiting;
            networkWaiting = [];
            then(allowed);
            waiting.forEach(function(waiter) {
                waiter(allowed);
            });
        };
        try {
            var answer = NVG.SystemCall.messageBox({
                "title": qsTr("Network"),
                "text": question || askOnlineText,
                "modal": true
            });
            if (answer && typeof answer.then === "function")
                answer.then(function(result) {
                answered(result !== false && result !== 0);
            }, function() {
                answered(false);
            });
            else
                answered(false);
        } catch (e) {
            console.log("Seedling: cannot ask about the network:", e);
            answered(false);
        }
    }

    // The sandbox the preview was created in (it goes with the preview).
    property var previewSandbox: null

    // The preview goes, with its sandbox.
    function clearPreview() {
        if (previewSandbox)
            previewSandbox.destroy();
        else if (preview)
            preview.destroy();
        preview = null;
        previewSandbox = null;
    }

    // The network questions (properties: lupdate misses qsTr inside those calls).
    readonly property string askOnlineText: qsTr("This widget needs to go online.\nLet it go online?")
    readonly property string askSaveOnlineText: qsTr("This widget goes online, and Network is off.\nAllow it to go online and save?")

    // The last render's @setting / @keep declarations that do not take effect (props.js notes).
    property var declNotes: []
    // The preview's @yui declarations: Yui's values given to it (timers every second, the rest every 10 s).
    property var previewYuis: []
    property int previewTicks: 0

    Timer {
        interval: 1000
        repeat: true
        running: !!bench.preview && bench.previewYuis.length > 0
        onTriggered: {
            bench.previewTicks = (bench.previewTicks + 1) % 10;
            Props.feed(bench.preview, bench.previewYuis, Link.Bench.yui, bench.previewTicks !== 0);
        }
    }

    // The widget's settings changed (its Settings window): given to the preview too.
    function applySettings() {
        if (!preview)
            return ;

        var decl = Props.parse(editor.text);
        Props.apply(preview, decl.settings, Props.carry(settings.prop_settings, decl.settings));
    }

    // What to do with an empty workbench: write code (Code Editor on), else ask Yui (or turn the Code
    // Editor on when she is not there): without the Code Editor there is nothing to write in.
    function emptyHint() {
        if (showCode)
            return qsTr("Write QML on the left, or pick one of the Examples.");

        if (Link.Bench.yui)
            return qsTr("Tell Yui in her chat what widget you want; she writes it here.");

        return canGenerate ? qsTr("Describe the widget you want below.") : qsTr("Set up the AI in Seedling Settings to have widgets written (or turn on Code Editor to write one yourself).");
    }

    // quiet: no question about the network (the caller asks, or has just been answered).
    function render(quiet) {
        clearPreview();
        declNotes = [];
        previewYuis = [];
        var code = editor.text;
        if (code.trim() === "") {
            errorLines = [];
            problemList = [];
            showProblems = false;
            result = "ok";
            status = emptyHint();
            return false;
        }
        // A widget reading Yui's data (@yui) may not go online, Network or not (refused, not asked).
        var problems = Props.guard(Safety.check(code, Props.networkAllowed(Props.parse(code), settings.allow_network === true)), Props.parse(code));
        refusedProblems = problems;

        if (problems.length > 0) {
            errorLines = problems.map(function(p) {
                return p.line - 1;
            });
            result = "unsafe";
            problemList = problems.map(function(p) {
                return {
                    "line": p.line,
                    "text": qsTr("Line %1: %2").arg(p.line).arg(p.message)
                };
            });
            status = problemSummary(qsTr("Refused by the safety check · "));
            return false;
        }
        try {
            // In the sandbox (sandbox.js): the code cannot see this file's names (S1, P1).
            var made = Sandbox.create(code, previewStage, Qt.resolvedUrl("Sandbox.qml"), "Seedling");
            if (made.error)
                throw new Error(made.error);

            preview = made.item;
            previewSandbox = made.sandbox;
            errorLines = [];
            showProblems = false;
            result = "ok";
            // @setting / @keep (props.js): the widget's settings given to the preview (kept values are
            // not: the preview starts from the defaults); declarations that do not take effect are
            // listed in Problems as notes (they do not stop it).
            var decl = Props.parse(code);
            Props.apply(preview, decl.settings, Props.carry(settings.prop_settings, decl.settings));
            // Yui's values too (read only, so the preview shows them as the widget will).
            previewYuis = decl.yuis;
            Props.feed(preview, decl.yuis, Link.Bench.yui, false);
            declNotes = decl.notes;
            problemList = decl.notes.map(function(n) {
                return {
                    "line": n.line,
                    "text": qsTr("Line %1: %2").arg(n.line).arg(n.message)
                };
            });
            status = qsTr("Rendered, %1 × %2 · safety check passed").arg(Math.round(preview.width)).arg(Math.round(preview.height)) + (decl.notes.length ? qsTr(" · %1 declaration(s) not used").arg(decl.notes.length) : "");
            return true;
        } catch (e) {
            errorLines = (e.qmlErrors || []).map(function(error) {
                return error.lineNumber - 1;
            });
            result = "error";
            problemList = (e.qmlErrors || []).map(function(error) {
                return {
                    "line": error.lineNumber,
                    "text": qsTr("Line %1, column %2: %3").arg(error.lineNumber).arg(error.columnNumber).arg(error.message)
                };
            });
            if (problemList.length === 0)
                problemList = [{
                "line": 0,
                "text": String(e)
            }];

            status = problemSummary("");
            return false;
        }
    }

    // Saves the code to the widget, and as a new version when it changed.
    // Save (○). Refused only for going online: asks whether to allow it and save (decided 2026-11-26:
    // Save is the user's own step, so a question then is no interruption); a yes saves it. It always
    // says how it went: a sound, a stamp on the preview (SAVED / NOT SAVED), a flash of the widget on
    // the desktop when saved, the status shaking when not.
    function save() {
        if (!render(true)) {
            if (result === "unsafe" && Safety.onlyNetwork(refusedProblems)) {
                askNetwork(function(allowed) {
                    if (allowed && result === "ok")
                        save();
                    else
                        saveFailed(qsTr("Not saved: this widget goes online, and going online was not allowed."));
                }, askSaveOnlineText);
                return ;
            }
            saveFailed("");
            return ;
        }

        var code = editor.text;
        var list = versions.slice();
        if (list.length === 0 || list[list.length - 1].code !== code) {
            list.push({
                "code": code,
                "at": Date.now()
            });
            if (list.length > 20)
                list = list.slice(list.length - 20);

            settings.versions = list;
            versions = list;
        }
        versionIndex = versions.length - 1;
        var problem = targetWidget.apply(code);
        if (problem) {
            saveFailed(problem);
            return ;
        }
        status = qsTr("Saved to the widget (version %1).").arg(versionIndex + 1);
        NVG.SystemCall.playSound(NVG.SFX.ProgramReady);
        stamp.show(true);
        if (targetWidget.flashSaved)
            targetWidget.flashSaved();

    }

    // Not saved: the warning sound, NOT SAVED on the preview, the status shaking (message: what to say,
    // "" keeps the render's), Problems flashing when there are some.
    function saveFailed(message) {
        if (message) {
            result = "error";
            status = message;
        }
        NVG.SystemCall.playSound(NVG.SFX.NotifyWarning);
        stamp.show(false);
        statusShake.restart();
        if (problemList.length > 0)
            problemsFlash.restart();

    }

    function currentCode() {
        return editor.text;
    }

    // Whether a widget can be written now (MHCP-YUI's connection, or Seedling's own set up).
    readonly property bool canGenerate: (Link.Bench.settingsRevision, Link.Bench.yui, Link.Bench.cannotWrite() === "")

    // Generate: the model (Seedling's own AI, or MHCP-YUI's) writes what the request field asks for,
    // or changes the code to it.
    function generate() {
        var request = requestField.text.trim();
        if (!request)
            return ;

        // No AI yet: said so, and Seedling Settings opened to set it up.
        if (!canGenerate) {
            result = "error";
            status = qsTr("Set up the AI in Seedling Settings first (General, AI).");
            if (targetWidget.openSettings)
                targetWidget.openSettings();

            return ;
        }
        requestField.text = "";

        result = "ok";
        status = qsTr("Thinking...");
        var refused = Link.Bench.generate(request, function(message, ok) {
            if (!ok) {
                result = "error";
                status = message;
            }
        });
        if (refused) {
            result = "error";
            status = refused;
        }
    }

    function beginWriting(title, keep) {
        // The code there is kept as a version first: Yui may write it anew (or be stopped halfway),
        // and Versions brings it back.
        addVersion(editor.text);
        showVersions = false;
        writing = true;
        writingSince = Date.now();
        writingSeconds = 0;
        renderTimer.stop();
        result = "ok";
        if (!keep) {
            clearPreview();
            loadingExternal = true;
            editor.text = "";
            loadingExternal = false;
            changedLines = [];
        }
        // Thinking until something comes out (Writing / Changing, set by Yui as it streams in).
        setPhase(qsTr("Thinking..."));
        requestActivate();
    }

    // A version of code, unless it is the last one already.
    function addVersion(code) {
        if (!code.trim() || (versions.length > 0 && versions[versions.length - 1].code === code))
            return ;

        var list = versions.concat([{
            "code": code,
            "at": Date.now()
        }]);
        if (list.length > 20)
            list = list.slice(list.length - 20);

        settings.versions = list;
        versions = list;
        versionIndex = list.length - 1;
    }

    // The character position where line n (0-based) starts in the editor.
    function lineStart(n) {
        var text = editor.text;
        var position = 0;
        for (var i = 0; i < n; i++) {
            position = text.indexOf("\n", position);
            if (position === -1)
                return text.length;

            position++;
        }
        return position;
    }

    // The code written so far (not rendered: half a widget does not compile).
    function streamCode(code) {
        if (!writing)
            return ;

        loadingExternal = true;
        editor.text = code;
        loadingExternal = false;
        editor.cursorPosition = editor.length;
    }

    function setPhase(text) {
        phase = text;
        status = text;
    }

    // ok: the widget is shown; message: what to say otherwise (kept on the status line).
    function endWriting(ok, message) {
        if (!writing)
            return ;

        writing = false;
        if (!ok) {
            result = "error";
            status = message;
        }
        NVG.SystemCall.playSound(ok ? NVG.SFX.ProgramReady : NVG.SFX.NotifyWarning);
    }

    // Code from another extension (Bench.preview): shown and rendered at once, the result sent back.
    function loadExternal(code, title, onResult, changes) {
        showVersions = false;
        // Yui's edit: the code before it is kept as a version, so ◀ goes back to it.
        if (changes)
            addVersion(editor.text);

        loadingExternal = true;
        editor.text = code;
        loadingExternal = false;
        changedLines = changes ? changes.lines : [];
        renderTimer.stop();
        var ok = render(true);
        requestActivate();
        var declined = false;
        var tell = function() {
            if (ok && changes) {
                addVersion(code);
                status = qsTr("Changed %1 place(s) · +%2 −%3 lines · %4").arg(changes.count).arg(changes.added).arg(changes.removed).arg(status);
            }
            if (typeof onResult === "function")
                onResult({
                    "ok": ok,
                    "result": result,
                    "status": status,
                    "title": title,
                    "width": preview ? Math.round(preview.width) : 0,
                    "height": preview ? Math.round(preview.height) : 0,
                    // Asked whether it may go online, and the user said no.
                    "networkDeclined": declined,
                    // @setting / @keep declarations that do not take effect ("Line n: why").
                    "notes": ok ? declNotes.map(function(n) {
                        return "Line " + n.line + ": " + n.message;
                    }) : []
                });

        };
        // Refused only for going online: asked first; a yes renders it as it is.
        if (!ok && result === "unsafe" && Safety.onlyNetwork(refusedProblems))
            askNetwork(function(allowed) {
            ok = allowed && result === "ok";
            declined = !allowed;
            tell();
        });
        else
            tell();
    }

    function loadVersion(index) {
        if (index < 0 || index >= versions.length)
            return ;

        versionIndex = index;
        editor.text = versions[index].code;
    }

    // Run (Code Editor): renders the code now; refused only for going online, asks whether it may (the
    // only question for code typed in; Yui's code is asked about when it comes).
    function run() {
        renderTimer.stop();
        if (render(true) || result !== "unsafe" || !Safety.onlyNetwork(refusedProblems))
            return ;

        askNetwork(function() {
        });
    }

    // A view of its own (no system frame): the title band moves it, the bottom-right corner resizes it.
    color: "transparent"
    compositor: hostView ? hostView.compositor : NVG.WindowCompositor
    z: hostView ? hostView.z : 0
    // It takes the keyboard (the code, the request).
    acceptFocus: true
    acceptInput: true
    visible: true
    Component.onCompleted: {
        place(widgetRect());
        render();
        requestActivate();
        aniOpen.start();
    }

    Shortcut {
        sequence: "Esc"
        onActivated: bench.dismiss()
    }

    ParallelAnimation {
        id: aniOpen

        NumberAnimation {
            target: bench
            property: "scaleX"
            from: 0.1
            to: 1
            duration: 200
            easing.type: Easing.OutQuad
        }

        SequentialAnimation {
            NumberAnimation {
                target: bench
                property: "panelOpacity"
                from: 0
                to: 1
                duration: 250
            }

            ScriptAction {
                script: NVG.SystemCall.playSound(NVG.SFX.PopupMessage)
            }

            NumberAnimation {
                target: bench
                property: "reveal"
                from: 0
                to: 1
                duration: 250
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: bench
                property: "contentOpacity"
                from: 0
                to: 1
                duration: 250
            }

        }

    }

    SequentialAnimation {
        id: aniClose

        ScriptAction {
            script: NVG.SystemCall.playSound(NVG.SFX.DismissMessage)
        }

        ParallelAnimation {
            NumberAnimation {
                target: bench
                property: "scaleX"
                to: 0.1
                duration: 250
                easing.type: Easing.InQuad
            }

            NumberAnimation {
                target: bench
                property: "panelOpacity"
                to: 0
                duration: 250
            }

        }

        ScriptAction {
            script: {
                bench.clearPreview();

                bench.visible = false;
                bench.dismissed();
                bench.destroy();
            }
        }

    }

    // The shadow of SAO Utils' panels (as Yui's chat panel): a smooth 8 px glow, black from about 12 %
    // next to the panel to nothing. Drawn at the panel's full size from the start (following the
    // opening panel, it was left cut off at a size from the middle of the animation), it fades in with
    // the content at the end of the opening and out with the panel when closing.
    Item {
        id: shadowArea

        anchors.fill: parent
        anchors.margins: bench.shadowMargin
    }

    RectangularGlow {
        anchors.fill: shadowArea
        glowRadius: 8
        spread: 0
        cornerRadius: 8
        color: "#1E000000"
        opacity: Math.min(bench.panelOpacity, bench.contentOpacity)
    }

    // The panel: its title and button bands keep their size and move apart as the grey band unfolds.
    Item {
        id: panel

        readonly property real fullHeight: parent.height - bench.shadowMargin * 2

        anchors.centerIn: parent
        width: parent.width - bench.shadowMargin * 2
        height: bench.titleHeight + bench.buttonsHeight + (fullHeight - bench.titleHeight - bench.buttonsHeight) * bench.reveal
        opacity: bench.panelOpacity
        clip: true

        transform: Scale {
            origin.x: panel.width / 2
            origin.y: panel.height / 2
            xScale: bench.scaleX
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#B9B9B9"
        }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0

        // Title band.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: bench.titleHeight

            Text {
                id: titleText

                anchors.centerIn: parent
                text: "Seedling"
                font.family: "SAO UI"
                font.pixelSize: 30
                color: bench.ink
            }

            // Which widget this is, when there is more than one ("No. 2").
            Text {
                anchors.left: titleText.right
                anchors.leftMargin: 10
                anchors.baseline: titleText.baseline
                text: Link.Bench.labelOf(bench.targetWidget)
                visible: text !== ""
                font.family: "SAO UI"
                font.pixelSize: 16
                color: "#8A8A8A"
            }

            // While Yui writes: a thin SAO orange strip at the title band's foot, breathing (as the chat's).
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 3
                color: "#F1AA03"
                visible: bench.writing

                SequentialAnimation on opacity {
                    running: bench.writing
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 0.25
                        to: 1
                        duration: 700
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        from: 1
                        to: 0.25
                        duration: 700
                        easing.type: Easing.InOutSine
                    }

                }

            }

            // As Yui's chat title: a click closes, pressing and dragging moves (a drag once the mouse has
            // moved more than 4 px), by the cursor's distance from the grabbed point in the window's own
            // coordinates (right with display scaling and several screens).
            MouseArea {
                property point grab
                property bool dragging: false

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                onPressed: {
                    grab = Qt.point(mouse.x, mouse.y);
                    dragging = false;
                    bench.moving = true;
                }
                onPositionChanged: {
                    if (!pressed)
                        return ;

                    if (!dragging && Math.abs(mouse.x - grab.x) + Math.abs(mouse.y - grab.y) <= 4)
                        return ;

                    dragging = true;
                    bench.x += mouse.x - grab.x;
                    bench.y += mouse.y - grab.y;
                }
                onReleased: {
                    bench.moving = false;
                    if (dragging)
                        bench.saveGeometry();
                    else if (containsMouse)
                        bench.dismiss();
                    dragging = false;
                }
            }

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0.894, 0.894, 0.894, bench.panelAlpha)
                }

                GradientStop {
                    position: 1
                    color: Qt.rgba(0.976, 0.976, 0.976, bench.panelAlpha)
                }

            }

        }

        // Grey band, shaded at its top and bottom (black 20% to 0, as the original).
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0.847, 0.847, 0.847, bench.panelAlpha)

            Rectangle {
                width: parent.width
                height: 11

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#33040404"
                    }

                    GradientStop {
                        position: 1
                        color: "#00040404"
                    }

                }

            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 11

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#00040404"
                    }

                    GradientStop {
                        position: 1
                        color: "#33040404"
                    }

                }

            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                anchors.topMargin: 18
                opacity: bench.contentOpacity
                visible: bench.reveal > 0.5
                anchors.bottomMargin: 14
                spacing: 12

                // Tools: Try, Versions, Examples, Network (and Stop while Yui writes).
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Run: advanced (with Code Editor on), as Examples.
                    Chip {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 30
                        visible: bench.showCode
                        text: "Run"
                        icon: "run"
                        onClicked: bench.run()
                    }

                    Chip {

                        Layout.alignment: Qt.AlignVCenter

                        Layout.preferredHeight: 30
                        text: "Versions"
                        icon: "folder"
                        checked: bench.showVersions
                        onClicked: {
                            bench.showVersions = !bench.showVersions;
                            bench.showProblems = false;
                        }
                    }

                    Chip {

                        Layout.alignment: Qt.AlignVCenter

                        Layout.preferredHeight: 30
                        id: problemsChip

                        // Flashes (lit for a moment, twice) when a Save fails with problems.
                        property bool flash: false

                        visible: bench.problemList.length > 0
                        text: "Problems (" + bench.problemList.length + ")"
                        icon: "help"
                        checked: bench.showProblems || flash
                        onClicked: {
                            bench.showProblems = !bench.showProblems;
                            bench.showVersions = false;
                        }
                    }

                    Chip {

                        Layout.alignment: Qt.AlignVCenter

                        Layout.preferredHeight: 30
                        id: examplesChip

                        visible: bench.showCode
                        text: "Examples"
                        icon: "items"
                        onClicked: examplesMenu.popup(examplesChip, 0, examplesChip.height + 2)
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Stop: red and breathing while Yui writes, so it is found at once (also in the
                    // chat: its Send button is Stop then).
                    Chip {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 30
                        text: "Stop"
                        icon: "logout"
                        danger: true
                        visible: bench.writing
                        onClicked: Link.Bench.stop()

                        SequentialAnimation on opacity {
                            running: bench.writing
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.55
                                duration: 700
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 1
                                duration: 700
                                easing.type: Easing.InOutSine
                            }

                        }

                    }

                    Menu {
                        id: examplesMenu

                        Repeater {
                            model: bench.examples

                            MenuItem {
                                font.family: "SAO UI"
                                font.pixelSize: 15
                                text: modelData.name
                                onTriggered: {
                                    editor.text = modelData.code;
                                    bench.showVersions = false;
                                }
                            }

                        }

                    }

                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    // The code: only with Code Editor on (Seedling Settings); else the preview alone.
                    ColumnLayout {
                        visible: bench.showCode
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        spacing: 5

                        // The header, as tall as the right side's (with or without its buttons), so the
                        // code, preview, versions and problems boxes line up and do not jump.
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: bench.headerHeight
                            Layout.minimumHeight: bench.headerHeight
                            Layout.maximumHeight: bench.headerHeight

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Code"
                                font.family: "SAO UI"
                                font.pixelSize: 15
                                color: "#5F5F5F"
                            }

                        }

                        // The code, set into the band.
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.fill: parent
                                color: "#F9F9F9"
                            }

                            // A Flickable with the text as its TextArea.flickable (Qt's way for a scrolled
                            // TextArea): no scroll bar of its own (a ScrollView kept its wide default bar
                            // beside the SAO one), and the SAO bar places itself at the right edge.
                            Flickable {
                                id: codeScroll

                                anchors.fill: parent
                                anchors.margins: 2
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: SaoScrollBar {
                                    // Above the content (the code covered its whole width and took the clicks).
                                    z: 10
                                    onLight: true
                                }

                                TextArea.flickable: TextArea {
                                    id: editor

                                    selectByMouse: true
                                    wrapMode: TextArea.Wrap
                                    font.family: "Consolas"
                                    font.pixelSize: 12
                                    color: "#3A3A3A"
                                    text: bench.settings.draft !== undefined ? bench.settings.draft : (bench.settings.code || "")
                                    // Where each line starts, for the line numbers and the marks.
                                    readonly property var starts: {
                                        var list = [0];
                                        for (var i = 0; i < text.length; i++)
                                            if (text.charAt(i) === "\n")
                                                list.push(i + 1);

                                        return list;
                                    }

                                    // The top of line n (0-based), after wrapping (width counted so it follows).
                                    function lineTop(n) {
                                        return lineRect(n).y;
                                    }

                                    // Line n's rectangle once laid out. Read again whenever the layout
                                    // changes (layoutStamp): read too early, the numbers stayed where the
                                    // lines were before and drifted further down the code.
                                    function lineRect(n) {
                                        var stamp = layoutStamp;
                                        // Within the text the editor holds now: while new code comes in, the
                                        // lines are counted from it a moment before the editor has it, and a
                                        // position past its end flooded the log (QTextCursor::setPosition).
                                        var at = Math.min(starts[Math.min(n, starts.length - 1)], length);
                                        return width > 0 ? positionToRectangle(at) : Qt.rect(0, 0, 0, 0);
                                    }

                                    // Changes with the text, the width and the laid-out height.
                                    readonly property string layoutStamp: text.length + ":" + width + ":" + contentHeight + ":" + lineCount

                                    readOnly: bench.writing
                                    leftPadding: 50
                                    // Room at the right for the scroll bar.
                                    rightPadding: 16
                                    selectionColor: "#80F1AA03"
                                    selectedTextColor: "#3A3A3A"
                                    onTextChanged: {
                                        bench.settings.draft = text;
                                        // Typed in: the marks of Yui's edit no longer fit.
                                        if (!bench.loadingExternal && bench.changedLines.length > 0)
                                            bench.changedLines = [];

                                        if (!bench.writing)
                                            renderTimer.restart();

                                    }

                                    background: null

                                    // An SAO orange cursor, blinking.
                                    cursorDelegate: Rectangle {
                                        width: 2
                                        color: "#F1AA03"
                                        visible: editor.activeFocus && !editor.readOnly

                                        SequentialAnimation on opacity {
                                            running: editor.activeFocus
                                            loops: Animation.Infinite

                                            NumberAnimation {
                                                to: 0
                                                duration: 500
                                            }

                                            NumberAnimation {
                                                to: 1
                                                duration: 500
                                            }

                                        }

                                    }

                                    // The line number column, set apart by a thin line.
                                    Rectangle {
                                        x: 0
                                        y: 0
                                        width: 40
                                        height: Math.max(editor.height, editor.contentHeight + editor.topPadding + editor.bottomPadding)
                                        color: "#EFEFEF"

                                        Rectangle {
                                            anchors.right: parent.right
                                            width: 1
                                            height: parent.height
                                            color: "#D4D4D4"
                                        }

                                    }

                                    Repeater {
                                        model: editor.starts.length

                                        Text {
                                            readonly property rect line: editor.lineRect(index)

                                            // In the middle of its line (the numbers' font is taller than
                                            // the code's).
                                            x: 0
                                            y: line.y
                                            width: 34
                                            height: line.height
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignRight
                                            text: index + 1
                                            font.family: "SAO UI"
                                            font.pixelSize: 13
                                            color: bench.errorLines.indexOf(index) !== -1 ? "#C82864" : "#A0A0A0"
                                        }

                                    }

                                    // Marks between the numbers and the code: orange for the lines Yui changed,
                                    // red for the lines found wrong.
                                    Repeater {
                                        model: bench.changedLines

                                        Rectangle {
                                            x: 42
                                            y: editor.lineTop(modelData)
                                            width: 4
                                            height: Math.max(4, editor.lineRect(modelData).height)
                                            color: "#F1AA03"
                                        }

                                    }

                                    Repeater {
                                        model: bench.errorLines

                                        Rectangle {
                                            x: 42
                                            y: editor.lineTop(modelData)
                                            width: 4
                                            height: Math.max(4, editor.lineRect(modelData).height)
                                            color: "#C82864"
                                        }

                                    }

                                }

                            }

                            InsetFrame {
                                anchors.fill: parent
                            }

                        }


                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        spacing: 5

                        // The header: one fixed height whatever buttons it shows (Preview's zoom,
                        // Problems' copy / send, none for Versions).
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: bench.headerHeight
                            Layout.minimumHeight: bench.headerHeight
                            Layout.maximumHeight: bench.headerHeight

                            Text {
                                text: bench.showVersions ? "Versions" : bench.showProblems ? "Problems" : "Preview"
                                font.family: "SAO UI"
                                font.pixelSize: 15
                                color: "#5F5F5F"
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: bench.showVersions ? qsTr("%1 saved").arg(bench.versions.length) : bench.showProblems ? String(bench.problemList.length) : (bench.preview ? Math.round(bench.preview.width) + " × " + Math.round(bench.preview.height) + " · " + Math.round(bench.previewScale * 100) + "%" : "")
                                font.family: "SAO UI"
                                font.pixelSize: 13
                                color: "#7A7A7A"
                            }

                            // Problems: all of them copied, or sent to Yui's chat (with MHCP-YUI).
                            Row {
                                visible: bench.showProblems
                                spacing: 4

                                Chip {
                                    text: "Copy All"
                                    icon: "file"
                                    implicitHeight: 26
                                    onClicked: bench.copyProblems()
                                }

                                Chip {
                                    visible: Link.Bench.yui !== null && Link.Bench.yui.prefillChat !== undefined
                                    text: "Send to Yui"
                                    icon: "guide"
                                    implicitHeight: 26
                                    onClicked: bench.sendProblemsToYui()
                                }

                            }

                            // Zoom: smaller, Fit (the default), 100 %, larger.
                            Row {
                                visible: bench.previewShown && bench.preview !== null
                                spacing: 4

                                Chip {
                                    text: "−"

                                    icon: "remove"

                                    iconOnly: true
                                    onClicked: bench.zoomBy(-0.25)
                                }

                                Chip {
                                    text: "Fit"
                                    icon: "move"
                                    implicitHeight: 26
                                    checked: bench.zoom === 0
                                    onClicked: bench.zoom = 0
                                }

                                Chip {
                                    text: "+"

                                    icon: "add"

                                    iconOnly: true
                                    onClicked: bench.zoomBy(0.25)
                                }

                            }

                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#F9F9F9"
                            clip: true

                            // A faint grid behind the widget (its transparent parts show it).
                            Item {
                                id: previewGrid

                                anchors.fill: parent
                                anchors.margins: 2
                                visible: bench.previewShown
                                clip: true

                                Repeater {
                                    model: Math.ceil(previewGrid.width / 20)

                                    Rectangle {
                                        x: index * 20
                                        width: 1
                                        height: previewGrid.height
                                        color: "#E4E8EC"
                                    }

                                }

                                Repeater {
                                    model: Math.ceil(previewGrid.height / 20)

                                    Rectangle {
                                        y: index * 20
                                        width: previewGrid.width
                                        height: 1
                                        color: "#E4E8EC"
                                    }

                                }

                            }

                            Item {
                                id: previewArea

                                anchors.fill: parent
                                anchors.margins: 12
                                visible: bench.previewShown

                                // The widget at its own size, centered and scaled (previewScale); larger
                                // than the preview it can be dragged or scrolled around. Ctrl + wheel zooms.
                                Flickable {
                                    id: previewFlick

                                    anchors.fill: parent
                                    clip: true
                                    contentWidth: Math.max(width, previewStage.width * bench.previewScale)
                                    contentHeight: Math.max(height, previewStage.height * bench.previewScale)
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: SaoScrollBar {
                                        // Above the content (the code covered its whole width and took the clicks).
                                        z: 10
                                        onLight: true
                                    }

                                    Item {
                                        width: previewFlick.contentWidth
                                        height: previewFlick.contentHeight

                                        // Ctrl + wheel zooms; the wheel alone goes on to the Flickable
                                        // (scrolling when larger). A MouseArea: SAO Utils' Qt 5.13 has no
                                        // WheelHandler.
                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.NoButton
                                            onWheel: {
                                                if (wheel.modifiers & Qt.ControlModifier)
                                                    bench.zoomBy(wheel.angleDelta.y > 0 ? 0.25 : -0.25);
                                                else
                                                    wheel.accepted = false;
                                            }
                                        }

                                        Item {
                                            id: previewStage

                                            anchors.centerIn: parent
                                            width: bench.preview ? bench.preview.width : 0
                                            height: bench.preview ? bench.preview.height : 0
                                            scale: bench.previewScale
                                        }

                                    }


                                }

                            }

                            ListView {
                                anchors.fill: parent
                                anchors.margins: 2
                                visible: bench.showVersions
                                clip: true
                                model: bench.versions.length
                                ScrollBar.vertical: SaoScrollBar {
                                    // Above the content (the code covered its whole width and took the clicks).
                                    z: 10
                                    onLight: true
                                }

                                delegate: Rectangle {
                                    readonly property int number: bench.versions.length - index - 1
                                    // The chosen version in SAO orange; the hovered one only tinted (two
                                    // rows in the same orange looked like two chosen).
                                    readonly property bool lit: number === bench.versionIndex
                                    readonly property bool hovered: versionArea.containsMouse && !lit

                                    width: ListView.view.width
                                    height: 36
                                    color: lit ? "#F1AA03" : hovered ? "#FCE8C0" : "transparent"

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 12
                                        text: "Ver " + (parent.number + 1)
                                        font.family: "SAO UI"
                                        font.pixelSize: 15
                                        color: parent.lit ? "#FFFFFF" : bench.ink
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        text: Qt.formatDateTime(new Date(bench.versions[parent.number].at), "MM-dd hh:mm")
                                        font.family: "SAO UI"
                                        font.pixelSize: 14
                                        color: parent.lit ? "#FFFFFF" : "#7A7A7A"
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 1
                                        color: "#E6E6E6"
                                    }

                                    MouseArea {
                                        id: versionArea

                                        anchors.fill: parent
                                        // Off while the list is hidden: the row clicked last kept its
                                        // hover until the mouse passed over it again.
                                        hoverEnabled: bench.showVersions
                                        onClicked: {
                                            bench.loadVersion(parent.number);
                                            bench.showVersions = false;
                                        }
                                    }

                                }

                            }

                            // Problems: every one in full, selectable; a click on its red bar goes to its line.
                            ListView {
                                anchors.fill: parent
                                anchors.margins: 2
                                visible: bench.showProblems
                                clip: true
                                model: bench.problemList
                                ScrollBar.vertical: SaoScrollBar {
                                    // Above the content (the code covered its whole width and took the clicks).
                                    z: 10
                                    onLight: true
                                }

                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: problemText.implicitHeight + 16
                                    color: problemArea.containsMouse ? "#22C82864" : "transparent"

                                    Rectangle {
                                        x: 8
                                        y: 8
                                        width: 4
                                        height: parent.height - 16
                                        color: "#C82864"
                                    }

                                    // Selectable, to copy a part (Ctrl + C).
                                    TextEdit {
                                        id: problemText

                                        x: 20
                                        y: 8
                                        width: parent.width - 28
                                        wrapMode: Text.Wrap
                                        readOnly: true
                                        selectByMouse: true
                                        selectionColor: "#80F1AA03"
                                        selectedTextColor: "#3A3A3A"
                                        text: modelData.text
                                        font.family: bench.fontFor(text)
                                        font.pixelSize: 14
                                        color: "#4D4D4D"
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 1
                                        color: "#E6E6E6"
                                    }

                                    // The red bar goes to the line (the text is for selecting).
                                    MouseArea {
                                        id: problemArea

                                        x: 0
                                        width: 18
                                        height: parent.height
                                        hoverEnabled: true
                                        cursorShape: modelData.line > 0 && bench.showCode ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: bench.goToLine(modelData.line)
                                    }

                                }

                            }

                            // SAVED / NOT SAVED after Save, as Yui's Boss Raid banner (SaveBanner.qml).
                            SaveBanner {
                                id: stamp

                                anchors.fill: parent
                                z: 20
                            }

                            // The target frame's corners, and what is there when nothing is shown.
                            CornerMarks {
                                anchors.fill: parent
                                visible: bench.previewShown
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: bench.previewShown && !bench.preview && !bench.writing
                                text: bench.result === "ok" ? "NO SIGNAL" : "RENDER FAILED"
                                font.family: "SAO UI"
                                font.pixelSize: 24
                                font.letterSpacing: 4
                                color: bench.result === "ok" ? "#B8B8B8" : "#D98BA6"
                            }

                            InsetFrame {
                                anchors.fill: parent
                            }

                        }

                    }

                }

                // The request, at the foot of the band: only without MHCP-YUI (with her, Yui is asked in the
                // chat). As her chat's input: a white rounded box (Enter sends, Shift+Enter a new line)
                // and the theme's button, Generate / Stop.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8
                    visible: Link.Bench.yui === null

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(96, Math.max(40, requestField.implicitHeight))
                        Layout.alignment: Qt.AlignBottom
                        radius: 20
                        color: "#FFFFFF"
                        border.color: requestField.activeFocus ? "#F1AA03" : "#D4D4D4"
                        border.width: 1

                        TextArea {
                            id: requestField

                            function handleReturn(event) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    insert(cursorPosition, "\n");
                                else
                                    bench.generate();
                                event.accepted = true;
                            }

                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            readOnly: bench.writing
                            color: "black"
                            wrapMode: TextArea.Wrap
                            selectByMouse: true
                            leftPadding: 10
                            rightPadding: 10
                            topPadding: 10
                            bottomPadding: 10
                            background: null
                            font.family: bench.fontFor(text || placeholderText)
                            font.pixelSize: 14
                            placeholderText: bench.canGenerate ? qsTr("Describe the widget, then Enter") : qsTr("Set up the AI in Seedling Settings to have widgets written")
                            Keys.onReturnPressed: handleReturn(event)
                            Keys.onEnterPressed: handleReturn(event)
                        }

                    }

                    Button {
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignBottom
                        text: bench.writing ? "Stop" : "Generate"
                        enabled: bench.writing || requestField.text.trim() !== ""
                        onClicked: {
                            if (bench.writing)
                                Link.Bench.stop();
                            else
                                bench.generate();
                        }
                    }

                }

            }

        }

        // White band (translucent as the rest): Save (ok) and Close (cancel), each centered in its half,
        // and what happened between them.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: bench.buttonsHeight
            color: Qt.rgba(1, 1, 1, bench.panelAlpha)

            SaoIcon {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width / 4 - width / 2
                icon: "misc/ok"
                size: 56
                onClicked: bench.save()
            }

            // What happened, centered between the buttons (as an SAO dialog's message between its ○ and ✕).
            Text {
                id: statusLine

                property real shake: 0

                anchors.centerIn: parent
                anchors.horizontalCenterOffset: shake
                width: parent.width / 2 - 72
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: bench.writing ? bench.phase + "  ·  " + bench.writingSeconds + " s" : bench.status
                font.family: bench.fontFor(text)
                font.pixelSize: 15
                color: bench.result === "error" ? "#C82864" : bench.result === "unsafe" ? "#9A6C00" : bench.ink
            }

            SaoIcon {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * 3 / 4 - width / 2
                icon: "misc/cancel"
                size: 56
                onClicked: bench.dismiss()
            }

        }

    }


        // The edge of SAO Utils' own dialogs (measured from its theme's dialog.png): a grey line, inside it a
        // white line (88 %), then a faint light fading inward over 4 px at the left and right.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            border.color: "#E0FFFFFF"
            border.width: 1
        }

        Rectangle {
            x: 2
            y: 2
            width: 4
            height: parent.height - 4

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "#59FFFFFF"
                }

                GradientStop {
                    position: 1
                    color: "#00FFFFFF"
                }

            }

        }

        Rectangle {
            x: parent.width - 6
            y: 2
            width: 4
            height: parent.height - 4

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "#00FFFFFF"
                }

                GradientStop {
                    position: 1
                    color: "#59FFFFFF"
                }

            }

        }

    }

    // Resize grip (as Yui's chat): a triangle filling the bottom-right corner, orange while hovered;
    // only a drag with the button held resizes, by the cursor's distance in the view's coordinates.
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: bench.shadowMargin
        anchors.bottomMargin: bench.shadowMargin
        width: 18
        height: 18
        z: 100

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: resizeArea.containsMouse || resizeArea.pressed ? "#F59B00" : "#99707070"
                strokeColor: "transparent"
                startX: 18
                startY: 0

                PathLine {
                    x: 18
                    y: 18
                }

                PathLine {
                    x: 0
                    y: 18
                }

                PathLine {
                    x: 18
                    y: 0
                }

            }

        }

        MouseArea {
            id: resizeArea

            property point start
            property size origin

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            onPressed: {
                start = mapToItem(null, mouse.x, mouse.y);
                origin = Qt.size(bench.width, bench.height);
            }
            onPositionChanged: {
                if (!pressed)
                    return ;

                var now = mapToItem(null, mouse.x, mouse.y);
                bench.width = Math.round(Math.max(bench.leastWidth, origin.width + now.x - start.x));
                bench.height = Math.round(Math.max(bench.leastHeight, origin.height + now.y - start.y));
            }
            onReleased: bench.saveGeometry()
        }

    }

    Timer {
        interval: 1000
        repeat: true
        running: bench.writing
        onTriggered: bench.writingSeconds = Math.round((Date.now() - bench.writingSince) / 1000)
    }

    // For copying to the clipboard (QML has no clipboard of its own): never shown.
    TextEdit {
        id: clipboardHelper

        visible: false
    }

    // Not saved: the status line shakes left and right.
    SequentialAnimation {
        id: statusShake

        NumberAnimation {
            target: statusLine
            property: "shake"
            to: -8
            duration: 50
        }

        NumberAnimation {
            target: statusLine
            property: "shake"
            to: 8
            duration: 80
        }

        NumberAnimation {
            target: statusLine
            property: "shake"
            to: -5
            duration: 70
        }

        NumberAnimation {
            target: statusLine
            property: "shake"
            to: 0
            duration: 60
        }

    }

    SequentialAnimation {
        id: problemsFlash

        PropertyAction {
            target: problemsChip
            property: "flash"
            value: true
        }

        PauseAnimation {
            duration: 180
        }

        PropertyAction {
            target: problemsChip
            property: "flash"
            value: false
        }

        PauseAnimation {
            duration: 120
        }

        PropertyAction {
            target: problemsChip
            property: "flash"
            value: true
        }

        PauseAnimation {
            duration: 180
        }

        PropertyAction {
            target: problemsChip
            property: "flash"
            value: false
        }

    }

    Timer {
        id: renderTimer

        interval: 400
        onTriggered: bench.render()
    }

}
