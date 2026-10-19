import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// "System Console" window (after the GM console Yui uses in Aincrad): the Cardinal System Monitor
// (loads and the crystal's thresholds), Object Control Authority (what Yui may do on the desktop) and
// the System Log. Test Call runs each desktop action without the AI, through the same message, SAO
// confirmation box and execution as a real one.
NVG.Window {
    id: consoleWindow

    property var targetWidget

    title: qsTr("System Console")
    visible: true
    minimumWidth: 420
    minimumHeight: 320
    width: 520
    height: 720
    transientParent: widget.NVG.View.window
    onClosing: destroy()

    Page {
        anchors.fill: parent

        ScrollView {
            id: scrollView

            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 0
            clip: true

            ColumnLayout {
                width: scrollView.width
                spacing: 10

                Heading {
                    text: qsTr("Cardinal System Monitor")
                }

                LoadBars {
                    Layout.fillWidth: true
                    yui: consoleWindow.targetWidget
                }

                Label {
                    text: qsTr("Yui's Heart Crystal")
                }

                SettingNote {
                    text: qsTr("The crystal turns yellow or red when a load stays at or above these values (in %) for 5 seconds, and back once it drops 5 points below them. It shows the worst of the three.")
                }

                RowLayout {
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                    }

                    Label {
                        Layout.preferredWidth: 120
                        text: qsTr("Yellow")
                    }

                    Label {
                        Layout.preferredWidth: 120
                        text: qsTr("Red")
                    }

                }

                Repeater {
                    id: thresholdRows

                    model: [{
                        "metric": "cpu",
                        "label": qsTr("Computing Load (CPU)")
                    }, {
                        "metric": "gpu",
                        "label": qsTr("Visual Engine (GPU)")
                    }, {
                        "metric": "ram",
                        "label": qsTr("Memory Capacity (RAM)")
                    }]

                    RowLayout {
                        id: thresholdRow

                        // Saves both values; red always stays above yellow.
                        function save() {
                            if (redBox.value <= yellowBox.value)
                                redBox.value = Math.min(100, yellowBox.value + 1);

                            var all = JSON.parse(JSON.stringify(consoleWindow.targetWidget.settings.load_thresholds || {}));
                            all[modelData.metric] = [yellowBox.value, redBox.value];
                            consoleWindow.targetWidget.settings.load_thresholds = all;
                        }

                        // Shows the saved values (or the defaults).
                        function load() {
                            var pair = Yui.loadThresholds(consoleWindow.targetWidget.settings.load_thresholds, modelData.metric);
                            yellowBox.value = pair[0];
                            redBox.value = pair[1];
                        }

                        Layout.fillWidth: true
                        Component.onCompleted: load()

                        Label {
                            Layout.fillWidth: true
                            text: modelData.label
                        }

                        SpinBox {
                            id: yellowBox

                            Layout.preferredWidth: 120
                            from: 1
                            to: 99
                            editable: true
                            onValueModified: thresholdRow.save()
                        }

                        SpinBox {
                            id: redBox

                            Layout.preferredWidth: 120
                            from: 2
                            to: 100
                            editable: true
                            onValueModified: thresholdRow.save()
                        }

                    }

                }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Report Interval")
                    }

                    SpinBox {
                        Layout.preferredWidth: 120
                        from: 1
                        to: 24
                        editable: true
                        value: consoleWindow.targetWidget.loadReportHours
                        textFromValue: function(value) {
                            return qsTr("%1 h").arg(value);
                        }
                        valueFromText: function(text) {
                            return parseInt(text) || 1;
                        }
                        onValueModified: consoleWindow.targetWidget.settings.load_report_hours = value
                    }

                }

                SettingNote {
                    text: qsTr("Each load is reported at most once in this time.")
                }

                Button {
                    text: qsTr("Restore Defaults")
                    onClicked: {
                        consoleWindow.targetWidget.settings.load_thresholds = {};
                        for (var i = 0; i < thresholdRows.count; i++)
                            thresholdRows.itemAt(i).load();

                    }
                }

                Heading {
                    text: qsTr("Object Control Authority")
                }

                Label {
                    text: qsTr("Yui may")
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 12

                    Repeater {
                        model: [{
                            "key": "action_web",
                            "label": qsTr("Open Web Pages and Search")
                        }, {
                            "key": "action_launch",
                            "label": qsTr("Start Programs")
                        }, {
                            "key": "action_find",
                            "label": qsTr("Search Files")
                        }, {
                            "key": "action_kill",
                            "label": qsTr("Close Programs")
                        }]

                        CheckBox {
                            text: modelData.label
                            checked: consoleWindow.targetWidget.settings[modelData.key] !== false
                            onToggled: consoleWindow.targetWidget.settings[modelData.key] = checked
                        }

                    }

                }

                SettingNote {
                    text: qsTr("Actions turned off here are not offered to the AI, and are not carried out even if a reply asks for them.")
                }

                Label {
                    text: qsTr("Object Search")
                }

                Label {
                    text: qsTr("es.exe Path")
                    color: "#888888"
                }

                TextField {
                    Layout.fillWidth: true
                    selectByMouse: true
                    placeholderText: "D:\\Tools\\everything\\es.exe"
                    text: (consoleWindow.targetWidget.settingsRevision, consoleWindow.targetWidget.settings.es_path || "")
                    // Saved on every edit (also when the window is closed right after typing); empty
                    // means es.exe is looked for in PATH and the usual install folders. Surrounding quotes from "Copy as path" are dropped.
                    onTextEdited: consoleWindow.targetWidget.settings.es_path = text.replace(/"/g, "").trim()
                }

                SettingNote {
                    text: qsTr("File search uses Everything's command line tool es.exe. When this is empty, Yui looks for it in PATH and the usual install folders and fills it in once found. Everything itself must be running.")
                }

                Label {
                    text: qsTr("Delete Authority")
                }

                SettingNote {
                    text: qsTr("Yui closes these programs without asking. After closing a program for the first time, Yui asks whether to add it here.")
                }

                ProcessListEditor {
                    Layout.fillWidth: true
                    // Re-read when Yui adds a program while this window is open.
                    names: consoleWindow.targetWidget.settingsRevision, consoleWindow.targetWidget.settings.kill_whitelist || []
                    emptyText: qsTr("No programs yet.")
                    // A removed program is not offered for the whitelist again; closing it is confirmed.
                    onEdited: {
                        var removed = Yui.processList(consoleWindow.targetWidget.settings.kill_whitelist).filter(function(name) {
                            return list.indexOf(name) === -1;
                        });
                        consoleWindow.targetWidget.settings.kill_asked = Yui.processList((consoleWindow.targetWidget.settings.kill_asked || []).concat(removed));
                        consoleWindow.targetWidget.settings.kill_whitelist = list;
                    }
                }

                Label {
                    text: qsTr("Immortal Objects")
                }

                SettingNote {
                    text: qsTr("Yui never closes these programs. The locked system processes cannot be removed; you can protect more.")
                }

                ProcessListEditor {
                    Layout.fillWidth: true
                    fixedNames: Yui.PROTECTED_PROCESSES
                    names: consoleWindow.targetWidget.settings.kill_protected || []
                    onEdited: consoleWindow.targetWidget.settings.kill_protected = list
                }

                Heading {
                    text: qsTr("System Log")
                }

                Label {
                    text: qsTr("Test Call")
                }

                SettingNote {
                    text: qsTr("Try each desktop action. Every button posts a test message and asks for confirmation like a real action; the protected process must be refused without asking.")
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [{
                            "label": qsTr("Launch Notepad"),
                            "tag": "<<launch:notepad>>"
                        }, {
                            "label": qsTr("Close Notepad"),
                            "tag": "<<kill:notepad.exe>>"
                        }, {
                            "label": qsTr("Find File"),
                            "tag": "<<find:notepad.exe>>"
                        }, {
                            "label": qsTr("Open Link"),
                            "tag": "<<open:https://www.bilibili.com>>"
                        }, {
                            "label": qsTr("Protected Process"),
                            "tag": "<<kill:explorer.exe>>"
                        }, {
                            "label": qsTr("Test Bubble"),
                            "tag": ""
                        }, {
                            "label": qsTr("Test Streaming"),
                            "tag": "stream"
                        }]

                        // "Test Bubble" shows a sample line in the crystal's speech bubble, "Test Streaming" a
                        // made-up streamed reply in the chat (neither makes an API request).
                        Button {
                            text: modelData.label
                            onClicked: modelData.tag === "stream" ? consoleWindow.targetWidget.testStreamReply() : modelData.tag ? consoleWindow.targetWidget.testAction(modelData.tag) : consoleWindow.targetWidget.testBubble()
                        }

                    }

                }

                // Live log of the desktop actions: confirmations, commands and their results.
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Log")
                    }

                    Button {
                        text: qsTr("Copy Log")
                        enabled: consoleWindow.targetWidget.diagLog.length > 0
                        onClicked: {
                            logText.selectAll();
                            logText.copy();
                            logText.deselect();
                        }
                    }

                    Button {
                        text: qsTr("Clear Log")
                        onClicked: consoleWindow.targetWidget.diagLog = []
                    }

                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    color: "#1A1D24"
                    radius: 4

                    // Read-only but selectable text, so the log can be copied (drag + Ctrl+C or Copy Log).
                    ScrollView {
                        id: logScroll

                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true
                        ScrollBar.vertical: SaoScrollBar {
                        }

                        TextArea {
                            id: logText

                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextArea.WrapAnywhere
                            text: consoleWindow.targetWidget.diagLog.join("\n")
                            color: "#DDFFFFFF"
                            selectionColor: "#F59B00"
                            selectedTextColor: "#FFFFFF"
                            font.family: "Consolas"
                            font.pixelSize: 11
                            padding: 0
                            background: null
                            // Follow new lines unless the user is selecting text.
                            onTextChanged: {
                                if (selectionStart === selectionEnd)
                                    cursorPosition = length;

                            }
                        }

                    }

                    Text {
                        anchors.centerIn: parent
                        visible: consoleWindow.targetWidget.diagLog.length === 0
                        text: qsTr("Run a test to see its steps here.")
                        color: "#88FFFFFF"
                        font.pixelSize: 11
                    }

                }

            }

        }

        header: TitleBar {
            text: qsTr("System Console")
        }

    }

}
