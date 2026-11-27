import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "link" 1.0 as Link
import "templates.js" as Templates
import "api.js" as Api
import "fakes.js" as Fakes

// Seedling Settings (the Seedling widget's menu): General (Code Editor, Network) and Test, which
// tries the workbench's states without the AI and without a request: a widget, a compile error, the
// safety check, the network question, one larger than the preview. Yui's writing is tested from her
// System Console (Seedling group), through the whole way.
NVG.Window {
    id: settingsWindow

    property var targetWidget
    // As MHCP-YUI's settings windows: Help shows the notes under the settings, Advanced the Code
    // Editor and the Test tab (each Seedling widget keeps its own).
    readonly property bool help: targetWidget.settings.show_help === true
    readonly property bool advanced: targetWidget.settings.show_advanced === true

    // Seedling's own AI is used (no MHCP-YUI, or Connection: Own).
    // Seedling's own Link settings are used (and shown): no MHCP-YUI, or she is not set up yet.
    readonly property bool ownConnection: (linkRevision, yuiRevision, Link.Bench.yui, Link.Bench.connectionKind() === "own")
    // Which settings changed (Bench.settingChanged), so each binding follows only its own: the
    // connection, the scanned lists (a single revision for all made binding loops).
    property int linkRevision: 0
    property int scannedRevision: 0

    // The core list follows what it is made of (refreshModels, not a binding).
    onOwnConnectionChanged: corePreference.refreshModels()
    onScannedChanged: corePreference.refreshModels()
    onYuiModelsChanged: corePreference.refreshModels()

    Connections {
        target: Link.Bench
        onSettingChanged: {
            if (key === "scanned_models")
                settingsWindow.scannedRevision++;
            else if (["provider", "endpoint", "api_key", "custom_model"].indexOf(key) !== -1)
                settingsWindow.linkRevision++;
        }
    }
    // With MHCP-YUI: her server's name, models and chat model (her port's models()); yuiRevision makes it
    // read again after Scan Cores / Restore Registry.
    property int yuiRevision: 0
    readonly property var yuiModels: (yuiRevision, Link.Bench.yui ? Link.Bench.yui.models() : null)
    // Scan Cores (Link, Core): the server's own model list, kept per server (scanned_models) until
    // Restore Registry.
    readonly property var scanned: (scannedRevision, Link.Bench.setting("scanned_models", {}))
    property bool scanning: false
    property string scanStatus: ""

    // "Same as Yui's chat": the first core with MHCP-YUI (stored as "").
    readonly property string sameAsChat: qsTr("Same as Yui's chat") + (yuiModels && yuiModels.chatModel ? " (" + yuiModels.chatModel + ")" : "")

    function scanCores() {
        if (!ownConnection) {
            scanning = true;
            scanStatus = qsTr("Scanning...");
            Link.Bench.yui.scanModels(function(models, error) {
                scanning = false;
                yuiRevision++;
                scanStatus = models ? qsTr("Found %1 core(s).").arg(models.length) : qsTr("Scan failed: %1").arg(error);
            });
            return ;
        }
        var config = Link.Bench.ownConfig();
        var id = config.provider;
        scanning = true;
        scanStatus = qsTr("Scanning...");
        var timer = Qt.createQmlObject("import QtQml 2.12; Timer { interval: 30000 }", settingsWindow);
        var handle = Api.listModels(config, function(models, error) {
            timer.stop();
            timer.destroy();
            scanning = false;
            if (!models) {
                scanStatus = qsTr("Scan failed: %1").arg(error);
                return ;
            }
            var all = JSON.parse(JSON.stringify(scanned));
            all[id] = models;
            Link.Bench.setSetting("scanned_models", all);
            scanStatus = qsTr("Found %1 core(s).").arg(models.length);
        });
        timer.triggered.connect(function() {
            handle.abort();
        });
        timer.start();
    }

    function restoreRegistry() {
        if (!ownConnection) {
            Link.Bench.yui.restoreModels();
            yuiRevision++;
            scanStatus = "";
            return ;
        }
        var all = JSON.parse(JSON.stringify(scanned));
        delete all[Link.Bench.ownConfig().provider];
        Link.Bench.setSetting("scanned_models", all);
        scanStatus = "";
    }

    // Link Start! (Link, Connection Test): a very short request through the connection chosen, as
    // MHCP-YUI's; the answer in the Connection Log.
    property bool testing: false
    property string testResult: ""

    function testConnection() {
        var why = Link.Bench.cannotWrite();
        if (why) {
            testResult = why;
            return ;
        }
        testing = true;
        testResult = qsTr("Linking...");
        var own = Link.Bench.connectionKind() === "own";
        var model = own ? Api.modelOf(Link.Bench.ownConfig()) : (Link.Bench.writingModel() || qsTr("Yui's chat model"));
        Link.Bench.ask("用一句话回复。", "你好", function() {
        }, function(text, isError) {
            testing = false;
            testResult = (isError ? "" : qsTr("Link established") + " (" + model + "):\n") + String(text).trim();
        });
    }

    // Reset (title bar): the settings back to their defaults (Code Editor and Network off).
    function reset() {
        codePreference.value = false;
        networkPreference.value = false;
        stylePreference.value = Templates.DEFAULT_STYLE;
        targetWidget.settings.show_code = false;
        targetWidget.settings.allow_network = false;
        // The Link settings (server, key, core) stay: Reset does not lose an access key.
        Link.Bench.setSetting("widget_style", "");
        if (targetWidget.workbench)
            targetWidget.workbench.render(true);

    }

    function confirmReset() {
        try {
            var answer = NVG.SystemCall.messageBox({
                // "Alert": SAO Utils' alert box and sound (as MHCP-YUI's confirmations).
                "title": "Alert",
                "text": qsTr("Restore all settings of %1 to their defaults?").arg(title),
                "modal": true
            });
            if (answer && typeof answer.then === "function")
                answer.then(function(result) {
                if (result !== false && result !== 0)
                    settingsWindow.reset();

            });
        } catch (e) {
            console.log("Seedling: cannot ask about Reset:", e);
        }
    }
    readonly property string sampleCode: "import QtQuick 2.12\n\nRectangle {\n    width: 220; height: 90; radius: 10\n    color: \"#E61F2630\"\n\n    Text {\n        id: time\n        anchors.centerIn: parent\n        color: \"white\"\n        font.pixelSize: 36\n        text: Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n\n    Timer {\n        interval: 1000; running: true; repeat: true\n        onTriggered: time.text = Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n}\n"
    readonly property string brokenCode: "import QtQuick 2.12\n\nRectangle {\n    width: 160; height: 80\n    color: \"#C82864\"\n\n    Text {\n        anchors.centerIn: parent\n        text: \"missing brace\"\n        colr: \"white\"\n    }\n}\n"
    readonly property string unsafeCode: "import QtQuick 2.12\nimport NERvGear 1.0 as NVG\n\nRectangle {\n    width: 120; height: 60\n    MouseArea {\n        anchors.fill: parent\n        onClicked: NVG.SystemCall.execute(\"cmd\")\n    }\n}\n"
    readonly property string networkCode: "import QtQuick 2.12\n\nRectangle {\n    width: 240; height: 80; radius: 8\n    color: \"#E61F2630\"\n\n    Text {\n        id: answer\n        anchors.centerIn: parent\n        color: \"white\"\n        font.pixelSize: 18\n        text: \"asking the Internet...\"\n    }\n\n    Component.onCompleted: {\n        var request = new XMLHttpRequest();\n        request.onreadystatechange = function() {\n            if (request.readyState === XMLHttpRequest.DONE)\n                answer.text = request.status === 200 ? \"online: OK\" : \"offline (\" + request.status + \")\";\n        };\n        request.open(\"GET\", \"https://www.bing.com/\");\n        request.send();\n    }\n}\n"
    // A todo list with @name, @setting and @keep (props.js): its Settings... and what it remembers.
    readonly property string propsCode: "import QtQuick 2.12\nimport QtQuick.Controls 2.12\n\n// @name Todo\nRectangle {\n    id: root\n    width: 240; height: 220; radius: 8\n    color: root.dark ? \"#E61F2630\" : \"#E6F4F4F4\"\n\n    // @setting Title\n    property string heading: \"TODO\"\n    // @setting Theme | Light / Dark\n    property string theme: \"Light\"\n    // @setting Font Size | 12 - 24\n    property int fontSize: 15\n    // @setting Accent\n    property color accent: \"#F1AA03\"\n    // @setting Show Done\n    property bool showDone: true\n    // @keep\n    property var todos: []\n\n    readonly property bool dark: root.theme === \"Dark\"\n\n    Column {\n        anchors.fill: parent\n        anchors.margins: 10\n        spacing: 6\n\n        Text {\n            text: root.heading + \" · \" + root.todos.filter(function(t) { return !t.done; }).length\n            color: root.accent\n            font.pixelSize: root.fontSize + 3\n            font.bold: true\n        }\n\n        TextField {\n            id: input\n            width: parent.width\n            placeholderText: \"+\"\n            onAccepted: {\n                if (input.text.trim() === \"\")\n                    return;\n                root.todos = root.todos.concat([{\"text\": input.text, \"done\": false}]);\n                input.text = \"\";\n            }\n        }\n\n        Repeater {\n            model: root.todos\n            Text {\n                visible: root.showDone || !modelData.done\n                width: parent.width\n                elide: Text.ElideRight\n                text: (modelData.done ? \"✓ \" : \"○ \") + modelData.text\n                color: modelData.done ? \"#888888\" : (root.dark ? \"white\" : \"#333333\")\n                font.pixelSize: root.fontSize\n                font.strikeout: modelData.done\n                MouseArea {\n                    anchors.fill: parent\n                    onClicked: {\n                        var list = root.todos.slice();\n                        list[index] = {\"text\": modelData.text, \"done\": !modelData.done};\n                        root.todos = list;\n                    }\n                }\n            }\n        }\n    }\n}\n"
    readonly property string largeCode: "import QtQuick 2.12\n\nRectangle {\n    width: 900; height: 600\n    gradient: Gradient {\n        GradientStop { position: 0; color: \"#F1AA03\" }\n        GradientStop { position: 1; color: \"#4BB4EC\" }\n    }\n\n    Text {\n        anchors.centerIn: parent\n        text: \"900 x 600\"\n        color: \"white\"\n        font.pixelSize: 64\n    }\n}\n"

    // The workbench, opened (or brought forward) for a test.
    function bench() {
        return targetWidget.openWorkbench();
    }

    // Code put in the editor and rendered at once.
    function load(code) {
        var workbench = bench();
        if (workbench)
            workbench.loadExternal(code, "Test", null, null);

    }

    title: "Seedling Settings"
    visible: true
    minimumWidth: 460
    minimumHeight: 520
    width: 520
    height: 640
    transientParent: targetWidget.NVG.View.window
    onClosing: destroy()

    // As MHCP-YUI's settings windows: tabs (the last one shown is remembered), SAO Utils' own
    // preferences, notes under them, the test buttons in centered rows.
    Page {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.bottomMargin: 16
            spacing: 10

            WrapTabBar {
                id: tabs

                currentIndex: Math.max(0, Math.min(2, settingsWindow.targetWidget.settings.settings_tab || 0))
                onCurrentIndexChanged: settingsWindow.targetWidget.settings.settings_tab = currentIndex
                model: [qsTr("General"), "Link", qsTr("Test")]
                hiddenTabs: settingsWindow.advanced ? [] : [2]
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                currentIndex: tabs.shownIndex

                // ---------------------------------------------------------------- General
                SettingsPage {
                    Heading {
                        visible: settingsWindow.advanced
                        text: "Workbench"
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        visible: settingsWindow.advanced

                        // Code Editor (advanced). Off: the workbench shows the preview only.
                        P.SwitchPreference {
                            id: codePreference

                            name: "show_code"
                            label: "Code Editor"
                            Component.onCompleted: value = settingsWindow.targetWidget.settings.show_code === true
                            onValueChanged: {
                                settingsWindow.targetWidget.settings.show_code = value === true;
                                // The workbench's empty hint follows (write here, or ask Yui).
                                if (settingsWindow.targetWidget.workbench)
                                    settingsWindow.targetWidget.workbench.render(true);

                            }
                        }

                    }

                    SettingNote {
                        visible: settingsWindow.help && settingsWindow.advanced
                        besidePreferences: true
                        text: qsTr("Advanced: shows the code beside the preview in the workbench, to read or change what Yui wrote. Off, the workbench shows the widget only.")
                    }

                    Heading {
                        text: "Network"
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true

                        P.SwitchPreference {
                            id: networkPreference

                            property bool ready: false

                            name: "allow_network"
                            label: "Network"
                            Component.onCompleted: {
                                value = settingsWindow.targetWidget.settings.allow_network === true;
                                ready = true;
                            }
                            onValueChanged: {
                                if (!ready || settingsWindow.targetWidget.settings.allow_network === (value === true))
                                    return ;

                                settingsWindow.targetWidget.settings.allow_network = value === true;
                                var workbench = settingsWindow.targetWidget.workbench;
                                if (workbench)
                                    workbench.render(true);

                            }

                            // Turned on by the workbench's question too.
                            Connections {
                                target: settingsWindow.targetWidget.workbench || null
                                ignoreUnknownSignals: true
                                onStatusChanged: networkPreference.value = settingsWindow.targetWidget.settings.allow_network === true
                            }

                        }

                    }

                    SettingNote {
                        visible: settingsWindow.help
                        besidePreferences: true
                        text: qsTr("Lets this widget go online (weather, exchange rates, pictures from the Internet). Off by default: the safety check refuses code that goes online, and Yui writes widgets that do not. When a widget is refused only for going online, the workbench asks whether to allow it.")
                    }

                    // How the widgets look, for all Seedling widgets (Seedling's own settings).
                    Heading {
                        text: "Style"
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true

                        P.TextAreaPreference {
                            id: stylePreference

                            property bool ready: false

                            label: "Widget Style"
                            Component.onCompleted: {
                                value = String(Link.Bench.setting("widget_style", "")).trim() || Templates.DEFAULT_STYLE;
                                ready = true;
                            }
                            // The default is kept as "" (a later default then applies).
                            onValueChanged: {
                                if (ready)
                                    Link.Bench.setSetting("widget_style", value.trim() === Templates.DEFAULT_STYLE ? "" : value.trim());

                            }
                        }

                    }

                    SettingNote {
                        visible: settingsWindow.help
                        besidePreferences: true
                        text: qsTr("What the widgets the AI writes look like (colors, fonts, mood), sent with every widget, for all Seedling widgets; what is asked for comes first. Reset brings back the SAO style.")
                    }

                }

                // ---------------------------------------------------------------- Link
                // As MHCP-YUI's Link tab: the server, the core (model), the connection test. Shared by
                // all Seedling widgets (Seedling's own settings, Bench.setting).
                SettingsPage {
                    Heading {
                        text: "Server"
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        // With MHCP-YUI her server and key are used (nothing to set twice).
                        SettingNote {
                            visible: !settingsWindow.ownConnection
                            besidePreferences: true
                            text: qsTr("Yui's server: %1. Widgets are written through it, with the access key set in her Cardinal System.").arg(settingsWindow.yuiModels ? settingsWindow.yuiModels.server : "")
                        }

                        P.SelectPreference {
                            id: providerPreference

                            property bool ready: false

                            visible: settingsWindow.ownConnection
                            label: "Seed Server"
                            model: Api.PROVIDERS.map(function(p) {
                                return p.title;
                            })
                            Component.onCompleted: {
                                var id = Link.Bench.setting("provider", "openai");
                                value = Math.max(0, Api.PROVIDERS.map(function(p) {
                                    return p.id;
                                }).indexOf(id));
                                ready = true;
                            }
                            onValueChanged: {
                                if (!ready)
                                    return ;

                                Link.Bench.setSetting("provider", Api.PROVIDERS[value].id);
                                corePreference.refreshModels();
                            }
                        }

                        SettingNote {
                            visible: settingsWindow.help && settingsWindow.ownConnection
                            besidePreferences: true
                            text: qsTr("The AI service that writes the widgets.")
                        }

                        P.TextFieldPreference {
                            id: endpointPreference

                            property bool ready: false

                            visible: settingsWindow.ownConnection && (settingsWindow.advanced || Api.PROVIDERS[providerPreference.value].id === "custom")
                            label: "Server Address"
                            display: P.TextFieldPreference.ExpandAll
                            hint: Api.PROVIDERS[providerPreference.value].endpoint || "https://.../v1/chat/completions"
                            Component.onCompleted: {
                                value = String(Link.Bench.setting("endpoint", ""));
                                ready = true;
                            }
                            onValueChanged: {
                                if (ready)
                                    Link.Bench.setSetting("endpoint", value.trim());

                            }
                        }

                        SettingNote {
                            visible: settingsWindow.help && endpointPreference.visible
                            besidePreferences: true
                            text: qsTr("The API endpoint URL. Change it only when using a proxy or a self-hosted service; empty uses the server's own.")
                        }

                        P.TextFieldPreference {
                            id: keyPreference

                            property bool ready: false

                            visible: settingsWindow.ownConnection
                            label: "Access Key"
                            display: P.TextFieldPreference.ExpandAll
                            echoMode: TextInput.Password
                            hint: Api.PROVIDERS[providerPreference.value].keyOptional ? qsTr("not needed") : ""
                            Component.onCompleted: {
                                value = String(Link.Bench.setting("api_key", ""));
                                ready = true;
                            }
                            onValueChanged: {
                                if (ready)
                                    Link.Bench.setSetting("api_key", value.trim());

                            }
                        }

                        SettingNote {
                            visible: settingsWindow.help && settingsWindow.ownConnection
                            besidePreferences: true
                            text: qsTr("The API key of this server. It stays on this computer, in Seedling's own data.")
                        }

                    }

                    Heading {
                        text: "Core"
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        P.SelectPreference {
                            id: corePreference

                            property bool ready: false
                            // Own: the server's scanned list (Scan Cores), else the built-in one. With Yui:
                            // hers, after "Same as Yui's chat" (her chat's model, the default).
                            // Set by refreshModels, not bound (a binding over all of these looped).
                            property var models: []

                            function listNow() {
                                if (settingsWindow.ownConnection) {
                                    var p = Api.PROVIDERS[providerPreference.value];
                                    return settingsWindow.scanned[p.id] || p.models;
                                }
                                return [settingsWindow.sameAsChat].concat(settingsWindow.yuiModels ? settingsWindow.yuiModels.models : []);
                            }

                            // The list again (another server, a scan, Yui there or not); the core chosen
                            // stays when it is in it.
                            function refreshModels() {
                                var next = listNow();
                                if (JSON.stringify(next) === JSON.stringify(models))
                                    return ;

                                // The list swap moves the selection by itself: not a choice to save.
                                refreshing = true;
                                models = next;
                                refreshing = false;
                                Qt.callLater(followModels);
                            }

                            property bool refreshing: false

                            readonly property string key: settingsWindow.ownConnection ? "model" : "yui_model"

                            visible: models.length > 0
                            label: "Core Program"
                            model: models
                            // What a choice is saved as: "" for "Same as Yui's chat", else a model id from
                            // the list (never the shown text of another mode's first item).
                            function stored(index) {
                                if (!settingsWindow.ownConnection && index === 0)
                                    return "";

                                var id = String(models[index] || "");
                                return id === settingsWindow.sameAsChat ? "" : id;
                            }

                            function shown() {
                                var current = String(Link.Bench.setting(key, ""));
                                return !settingsWindow.ownConnection && current === "" ? 0 : Math.max(0, models.indexOf(current));
                            }

                            Component.onCompleted: {
                                models = listNow();
                                value = shown();
                                ready = true;
                                // A saved core not in the list (e.g. saved wrongly before) is put right.
                                Qt.callLater(followModels);
                            }
                            onValueChanged: {
                                if (ready && !refreshing && value >= 0 && value < models.length)
                                    Link.Bench.setSetting(key, stored(value));

                            }
                            // Another list (scanned, restored, another server): the core chosen stays
                            // when it is in it.

                            function followModels() {
                                if (!ready)
                                    return ;

                                var current = String(Link.Bench.setting(key, ""));
                                var at = !settingsWindow.ownConnection && current === "" ? 0 : models.indexOf(current);
                                value = Math.max(0, at);
                                if (at === -1 && models.length > 0)
                                    Link.Bench.setSetting(key, stored(0));

                            }
                        }

                        SettingNote {
                            visible: settingsWindow.help && corePreference.visible
                            besidePreferences: true
                            text: qsTr("The AI model that writes the widgets.")
                        }

                        RowLayout {
                            visible: settingsWindow.advanced
                            spacing: 12
                            Layout.alignment: Qt.AlignHCenter

                            Button {
                                text: "Scan Cores"
                                enabled: !settingsWindow.scanning
                                onClicked: settingsWindow.scanCores()
                            }

                            Button {
                                text: "Restore Registry"
                                visible: settingsWindow.ownConnection ? !!settingsWindow.scanned[Api.PROVIDERS[providerPreference.value].id] : !!(settingsWindow.yuiModels && settingsWindow.yuiModels.scanned)
                                onClicked: settingsWindow.restoreRegistry()
                            }

                        }

                        // What Scan Cores found (or why it failed), under the buttons.
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            visible: settingsWindow.advanced && text !== ""
                            text: settingsWindow.scanStatus
                            elide: Text.ElideRight
                        }

                        SettingNote {
                            visible: settingsWindow.advanced && settingsWindow.help
                            besidePreferences: true
                            text: qsTr("Scan Cores asks the server for its current model list; Restore Registry goes back to the built-in list.")
                        }

                        P.TextFieldPreference {
                            id: customModelPreference

                            property bool ready: false

                            visible: settingsWindow.advanced || corePreference.models.length === 0
                            label: "Manual Core ID"
                            display: P.TextFieldPreference.ExpandAll
                            hint: qsTr("model id, e.g. gpt-6-sol")
                            Component.onCompleted: {
                                value = String(Link.Bench.setting("custom_model", ""));
                                ready = true;
                            }
                            onValueChanged: {
                                if (ready)
                                    Link.Bench.setSetting("custom_model", value.trim());

                            }
                        }

                        SettingNote {
                            visible: settingsWindow.help && customModelPreference.visible
                            besidePreferences: true
                            text: qsTr("When filled in, this model id is used instead of the Core Program selected above.")
                        }

                    }

                    Heading {
                        text: "Connection Test"
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        RowLayout {
                            spacing: 20
                            Layout.alignment: Qt.AlignHCenter

                            Button {
                                text: "Link Start!"
                                enabled: !settingsWindow.testing
                                onClicked: settingsWindow.testConnection()
                            }

                            Button {
                                text: "Clear Log"
                                onClicked: settingsWindow.testResult = ""
                            }

                        }

                        P.TextAreaPreference {
                            label: "Connection Log"
                            readOnly: true
                            hint: qsTr("Press Link Start! to test the connection.")
                            wrapMode: Text.Wrap
                            value: settingsWindow.testResult
                            Layout.fillWidth: true
                        }

                    }

                }


                // ---------------------------------------------------------------- Test
                SettingsPage {
                    SettingNote {
                        visible: settingsWindow.help
                        besidePreferences: true
                        text: qsTr("Test tries the workbench without the AI: nothing here makes a request. Each button opens the workbench (or uses the open one).")
                    }

                    // Temporary: Seedling as if MHCP-YUI were not installed (its own AI, the workbench's
                    // request field, no @yui data). Not saved: back after a restart.
                    Heading {
                        text: "Standalone"
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true

                        P.SwitchPreference {
                            label: "Pretend No Yui"
                            Component.onCompleted: value = Link.Bench.hideYui
                            onValueChanged: Link.Bench.hideYui = value === true
                        }

                    }

                    Repeater {
                        model: [{
                            "title": "Render",
                            "note": qsTr("Code put in the editor and rendered: a widget, a compile error (red marks, RENDER FAILED), refused by the safety check, one that needs to go online (Network is turned off first; the question comes as for code Yui brings, and on Save when typed in), and one larger than the preview (Fit, − / +)."),
                            "tests": [["Widget", "widget"], ["Compile Error", "broken"], ["Safety Check", "unsafe"], ["Needs Network", "network"], ["Large Widget", "large"]]
                        }, {
                            "title": "Writing",
                            "note": qsTr("The whole writing flow with made-up replies (no request): progress, edits, a fix after an error, the network question, Yui's data. Edit changes a color of the code there (Write first)."),
                            "tests": [["Write", "fake:write"], ["Edit", "fake:edit"], ["Fix", "fake:fix"], ["Network", "fake:network"], ["Mood Calendar", "fake:moods"]]
                        }, {
                            "title": "Settings & Keep",
                            "note": qsTr("A todo list with its own settings and memory (@name, @setting, @keep): save it with ○, then right-click the widget: Settings... and the Show Done switch. Add a few todos (Enter), restart SAO Utils: they are still there. The preview does not keep them."),
                            "tests": [["Todo Widget", "props"]]
                        }]

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Heading {
                                text: modelData.title
                            }

                            SettingNote {
                                visible: settingsWindow.help
                                besidePreferences: true
                                text: modelData.note
                            }

                            CenteredFlow {
                                Repeater {
                                    model: modelData.tests

                                    Button {
                                        text: modelData[0]
                                        onClicked: settingsWindow.run(modelData[1])
                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

        // As MHCP-YUI's SettingsTitleBar: Advanced, Help, Reset.
        header: TitleBar {
            Style.primary: settingsWindow.Style.dialogColor
            text: "Seedling Settings"

            Button {
                text: "Advanced"
                flat: true
                checkable: true
                checked: settingsWindow.advanced
                onToggled: settingsWindow.targetWidget.settings.show_advanced = checked
                DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            }

            Button {
                text: "Help"
                flat: true
                checkable: true
                checked: settingsWindow.help
                onToggled: settingsWindow.targetWidget.settings.show_help = checked
                DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            }

            Button {
                text: "Reset"
                flat: true
                onClicked: settingsWindow.confirmReset()
                DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            }

        }

    }

    // Test, Writing: Bench.write with replies from fakes.js (no request), in this widget's workbench.
    function writeFake(kind) {
        var replies = Fakes.replies(kind, Link.Bench.currentCode());
        if (replies.length === 0) {
            console.log("Seedling test: no code with a color to change; Write first");
            return ;
        }
        if (kind === "network")
            targetWidget.settings.allow_network = false;

        Link.Bench.used(targetWidget);
        Link.Bench.fakeReplies = replies;
        Link.Bench.write("(test) " + kind, null, function(result, message) {
            Link.Bench.fakeReplies = [];
            console.log("Seedling test: " + kind + " - " + result + ", " + message);
        });
    }

    function run(tag) {
        if (tag.indexOf("fake:") === 0)
            return writeFake(tag.slice(5));

        if (tag === "widget")
            load(sampleCode);
        else if (tag === "broken")
            load(brokenCode);
        else if (tag === "unsafe")
            load(unsafeCode);
        else if (tag === "large")
            load(largeCode);
        else if (tag === "props")
            load(propsCode);
        else if (tag === "network") {
            // Network off, so the question comes (as for code Yui brings).
            targetWidget.settings.allow_network = false;
            load(networkCode);
        }
    }
}
