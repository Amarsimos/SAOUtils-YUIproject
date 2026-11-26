import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Shapes 1.12
// For Qt.application.screens, used to keep the workbench on a screen.
import QtQuick.Window 2.12
import "safety.js" as Safety
import "link" 1.0 as Link

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
    property var preview: null
    // "ok", "error" or "unsafe", and what it says.
    property string result: "ok"
    property string status: ""
    property var versions: settings.versions || []
    property int versionIndex: versions.length - 1
    readonly property color ink: "#4D4D4D"
    // The bands are translucent as Yui's chat (her Chat Opacity in Equipment when MHCP-YUI runs, else
    // 80 %); the code, the preview and the text on them stay opaque.
    readonly property real panelAlpha: Link.Bench.writer && Link.Bench.writer.chatOpacity !== undefined ? Link.Bench.writer.chatOpacity : 0.8
    readonly property int leastWidth: 720
    readonly property int leastHeight: 520
    readonly property int titleHeight: 64
    readonly property int buttonsHeight: 96
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
    readonly property var examples: [{
        "name": qsTr("Clock"),
        "code": "import QtQuick 2.12\n\nRectangle {\n    width: 200; height: 84; radius: 10\n    color: \"#E61F2630\"\n\n    Text {\n        id: time\n        anchors.centerIn: parent\n        color: \"white\"\n        font.pixelSize: 36\n        text: Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n\n    Timer {\n        interval: 1000; running: true; repeat: true\n        onTriggered: time.text = Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n}\n"
    }, {
        "name": qsTr("Color Block"),
        "code": "import QtQuick 2.12\n\nRectangle {\n    width: 180; height: 110; radius: 12\n    gradient: Gradient {\n        GradientStop { position: 0; color: \"#F1AA03\" }\n        GradientStop { position: 1; color: \"#F8BBD0\" }\n    }\n\n    Text {\n        anchors.centerIn: parent\n        text: \"MHCP001\"\n        color: \"white\"\n        font.pixelSize: 24\n        font.bold: true\n    }\n}\n"
    }, {
        "name": qsTr("Animation"),
        "code": "import QtQuick 2.12\n\nItem {\n    width: 140; height: 140\n\n    Rectangle {\n        anchors.centerIn: parent\n        width: 70; height: 70\n        color: \"#2CE67C\"\n        border.color: \"white\"; border.width: 2\n        RotationAnimation on rotation {\n            from: 0; to: 360; duration: 4000; loops: Animation.Infinite\n        }\n    }\n}\n"
    }, {
        "name": qsTr("Broken"),
        "code": "import QtQuick 2.12\n\nRectangle {\n    width: 120; height: 80\n    color: \"#C82864\"\n\n    Text {\n        text: \"missing brace\"\n\n}\n"
    }, {
        "name": qsTr("Unsafe"),
        "code": "import QtQuick 2.12\nimport NERvGear 1.0 as NVG\n\nRectangle {\n    width: 120; height: 60\n    MouseArea {\n        anchors.fill: parent\n        onClicked: NVG.SystemCall.execute(\"cmd\")\n    }\n}\n"
    }]

    // Checks and renders the editor text into the preview; true when it is shown.
    function render() {
        if (preview) {
            preview.destroy();
            preview = null;
        }
        var code = editor.text;
        if (code.trim() === "") {
            result = "ok";
            status = qsTr("Write QML on the left, or pick one of the Examples.");
            return false;
        }
        var problems = Safety.check(code, settings.allow_network === true);
        if (problems.length > 0) {
            result = "unsafe";
            status = qsTr("Not rendered, the safety check failed: %1").arg(problems.map(function(p) {
                return qsTr("line %1, %2").arg(p.line).arg(p.message);
            }).join("; "));
            return false;
        }
        try {
            preview = Qt.createQmlObject(code, previewArea, "Seedling");
            result = "ok";
            status = qsTr("Rendered, %1 × %2 · safety check passed").arg(Math.round(preview.width)).arg(Math.round(preview.height));
            return true;
        } catch (e) {
            result = "error";
            status = (e.qmlErrors || []).map(function(error) {
                return qsTr("Line %1, column %2: %3").arg(error.lineNumber).arg(error.columnNumber).arg(error.message);
            }).join("; ") || String(e);
            return false;
        }
    }

    // Saves the code to the widget, and as a new version when it changed.
    function save() {
        if (!render())
            return ;

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
        status = problem ? problem : qsTr("Saved to the widget (version %1).").arg(versionIndex + 1);
    }

    function currentCode() {
        return editor.text;
    }

    // Generate: Yui (MHCP-YUI) writes what the request field asks for, or changes the code to it.
    function generate() {
        var request = requestField.text.trim();
        if (!request)
            return ;

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
        showVersions = false;
        writing = true;
        writingSince = Date.now();
        writingSeconds = 0;
        renderTimer.stop();
        result = "ok";
        if (!keep) {
            if (preview) {
                preview.destroy();
                preview = null;
            }
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
        var ok = render();
        if (ok && changes) {
            addVersion(code);
            status = qsTr("Changed %1 place(s) · +%2 −%3 lines · %4").arg(changes.count).arg(changes.added).arg(changes.removed).arg(status);
        }
        requestActivate();
        if (typeof onResult === "function")
            onResult({
                "ok": ok,
                "result": result,
                "status": status,
                "title": title,
                "width": preview ? Math.round(preview.width) : 0,
                "height": preview ? Math.round(preview.height) : 0
            });

    }

    function loadVersion(index) {
        if (index < 0 || index >= versions.length)
            return ;

        versionIndex = index;
        editor.text = versions[index].code;
    }

    function tryOnDesktop() {
        if (!render())
            return ;

        var component = Qt.createComponent("TryView.qml");
        var view = component.createObject(null, {
            "code": editor.text
        });
        if (!view)
            console.log("Seedling: cannot try it:", component.errorString());

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
                if (bench.preview)
                    bench.preview.destroy();

                bench.visible = false;
                bench.dismissed();
                bench.destroy();
            }
        }

    }

    // The panel: its title and button bands keep their size and move apart as the grey band unfolds.
    Item {
        id: panel

        anchors.centerIn: parent
        width: parent.width
        height: bench.titleHeight + bench.buttonsHeight + (parent.height - bench.titleHeight - bench.buttonsHeight) * bench.reveal
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
            border.color: "#C8C8C8"
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
                anchors.centerIn: parent
                text: "Seedling"
                font.family: "SAO UI"
                font.pixelSize: 30
                color: bench.ink
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

                    Chip {
                        text: "Try"
                        onClicked: bench.tryOnDesktop()
                    }

                    Chip {
                        text: "Versions"
                        checked: bench.showVersions
                        onClicked: bench.showVersions = !bench.showVersions
                    }

                    Chip {
                        id: examplesChip

                        text: "Examples"
                        onClicked: examplesMenu.popup(examplesChip, 0, examplesChip.height + 2)
                    }

                    Chip {
                        text: "Network: " + (bench.settings.allow_network === true ? "On" : "Off")
                        checked: bench.settings.allow_network === true
                        onClicked: {
                            bench.settings.allow_network = !(bench.settings.allow_network === true);
                            bench.render();
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Chip {
                        text: "Stop"
                        visible: bench.writing
                        onClicked: Link.Bench.stop()
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        spacing: 5

                        Text {
                            text: "Code"
                            font.family: "SAO UI"
                            font.pixelSize: 15
                            color: "#5F5F5F"
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            contentWidth: availableWidth

                            TextArea {
                                id: editor

                                selectByMouse: true
                                wrapMode: TextArea.Wrap
                                font.family: "Consolas"
                                font.pixelSize: 12
                                color: "#3A3A3A"
                                text: bench.settings.draft !== undefined ? bench.settings.draft : (bench.settings.code || "")
                                readOnly: bench.writing
                                leftPadding: 10
                                onTextChanged: {
                                    bench.settings.draft = text;
                                    // Typed in: the marks of Yui's edit no longer fit.
                                    if (!bench.loadingExternal && bench.changedLines.length > 0)
                                        bench.changedLines = [];

                                    if (!bench.writing)
                                        renderTimer.restart();

                                }

                                background: Rectangle {
                                    color: "#F9F9F9"
                                }

                                // An orange bar at the left of each line Yui changed (as an editor's change marks).
                                Repeater {
                                    model: bench.changedLines

                                    Rectangle {
                                        readonly property rect line: editor.positionToRectangle(bench.lineStart(modelData))

                                        x: 2
                                        y: line.y
                                        width: 4
                                        height: Math.max(4, line.height)
                                        color: "#F1AA03"
                                    }

                                }

                            }

                        }

                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: bench.showVersions ? "Versions" : "Preview"
                                font.family: "SAO UI"
                                font.pixelSize: 15
                                color: "#5F5F5F"
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: bench.showVersions ? qsTr("%1 saved").arg(bench.versions.length) : (bench.preview ? Math.round(bench.preview.width) + " × " + Math.round(bench.preview.height) : "")
                                font.family: "SAO UI"
                                font.pixelSize: 13
                                color: "#7A7A7A"
                            }

                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#F9F9F9"
                            clip: true

                            Item {
                                id: previewArea

                                anchors.fill: parent
                                anchors.margins: 12
                                visible: !bench.showVersions
                            }

                            ListView {
                                anchors.fill: parent
                                visible: bench.showVersions
                                clip: true
                                model: bench.versions.length

                                delegate: Rectangle {
                                    readonly property int number: bench.versions.length - index - 1
                                    readonly property bool lit: number === bench.versionIndex || versionArea.containsMouse

                                    width: ListView.view.width
                                    height: 36
                                    color: lit ? "#F1AA03" : "transparent"

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
                                        hoverEnabled: true
                                        onClicked: {
                                            bench.loadVersion(parent.number);
                                            bench.showVersions = false;
                                        }
                                    }

                                }

                            }

                        }

                    }

                }

                // The request, at the foot of the band: only without MHCP-YUI. With her, Yui is asked in the
                // chat instead (she writes it, and the workbench shows it here).
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: Link.Bench.writer === null

                    TextField {
                        id: requestField

                        Layout.fillWidth: true
                        enabled: Link.Bench.writer !== null && !bench.writing
                        selectByMouse: true
                        font.family: "SAO UI"
                        font.pixelSize: 15
                        placeholderText: qsTr("Generate needs MHCP-YUI (or Seedling's own AI, coming later)")
                        onAccepted: bench.generate()

                        background: Rectangle {
                            color: "#F9F9F9"
                            opacity: 0.7
                        }

                    }

                    Chip {
                        text: "Generate"
                        enabled: requestField.enabled && requestField.text.trim() !== ""
                        onClicked: bench.generate()
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
                anchors.centerIn: parent
                width: parent.width / 2 - 72
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                text: bench.writing ? bench.phase + "  ·  " + bench.writingSeconds + " s" : bench.status
                font.family: "SAO UI"
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

    }

    // Resize grip (as Yui's chat): a triangle filling the bottom-right corner, orange while hovered;
    // only a drag with the button held resizes, by the cursor's distance in the view's coordinates.
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
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

    Timer {
        id: renderTimer

        interval: 400
        onTriggered: bench.render()
    }

}
