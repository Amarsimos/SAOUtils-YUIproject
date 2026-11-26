import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

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

    // Reset (title bar): the settings back to their defaults (Code Editor and Network off).
    function reset() {
        codePreference.value = false;
        networkPreference.value = false;
        targetWidget.settings.show_code = false;
        targetWidget.settings.allow_network = false;
        if (targetWidget.workbench)
            targetWidget.workbench.render(true);

    }

    function confirmReset() {
        try {
            var answer = NVG.SystemCall.messageBox({
                "title": qsTr("Warning"),
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

                currentIndex: Math.max(0, Math.min(1, settingsWindow.targetWidget.settings.settings_tab || 0))
                onCurrentIndexChanged: settingsWindow.targetWidget.settings.settings_tab = currentIndex
                model: [qsTr("General"), qsTr("Test")]
                hiddenTabs: settingsWindow.advanced ? [] : [1]
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
                            onValueChanged: settingsWindow.targetWidget.settings.show_code = value === true
                        }

                    }

                    SettingNote {
                        visible: settingsWindow.help && settingsWindow.advanced
                        besidePreferences: true
                        text: qsTr("Advanced: shows the code beside the preview in the workbench, with Run and Examples, to read or change what Yui wrote. Off, the workbench shows the widget only.")
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

                }

                // ---------------------------------------------------------------- Test
                SettingsPage {
                    SettingNote {
                        visible: settingsWindow.help
                        besidePreferences: true
                        text: qsTr("Test tries the workbench without the AI: nothing here makes a request. Each button opens the workbench (or uses the open one).")
                    }

                    Repeater {
                        model: [{
                            "title": "Render",
                            "note": qsTr("Code put in the editor and rendered: a widget, a compile error (red marks, RENDER FAILED), refused by the safety check, one that needs to go online (Network is turned off first; the question comes as for code Yui brings, and on Save when typed in), and one larger than the preview (Fit, − / +)."),
                            "tests": [["Widget", "widget"], ["Compile Error", "broken"], ["Safety Check", "unsafe"], ["Needs Network", "network"], ["Large Widget", "large"]]
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

    function run(tag) {
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
