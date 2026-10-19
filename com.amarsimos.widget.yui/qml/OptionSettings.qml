import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// "Option" window (next to Cardinal System and Equipment): tools that are not settings.
// Diagnostics run each desktop action without the AI, through the same message, SAO confirmation
// box and execution as a real one.
NVG.Window {
    id: optionWindow

    property var targetWidget

    title: qsTr("Option")
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
                    text: qsTr("Everything")
                }

                Label {
                    text: qsTr("es.exe Path")
                }

                TextField {
                    Layout.fillWidth: true
                    selectByMouse: true
                    placeholderText: "D:\\Tools\\everything\\es.exe"
                    text: (optionWindow.targetWidget.settingsRevision, optionWindow.targetWidget.settings.es_path || "")
                    // Saved on every edit (also when the window is closed right after typing); empty
                    // means es.exe is looked for in PATH and the usual install folders. Surrounding quotes from "Copy as path" are dropped.
                    onTextEdited: optionWindow.targetWidget.settings.es_path = text.replace(/"/g, "").trim()
                }

                SettingNote {
                    text: qsTr("File search uses Everything's command line tool es.exe. When this is empty, Yui looks for it in PATH and the usual install folders and fills it in once found. Everything itself must be running.")
                }

                Heading {
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

                            var all = JSON.parse(JSON.stringify(optionWindow.targetWidget.settings.load_thresholds || {}));
                            all[modelData.metric] = [yellowBox.value, redBox.value];
                            optionWindow.targetWidget.settings.load_thresholds = all;
                        }

                        // Shows the saved values (or the defaults).
                        function load() {
                            var pair = Yui.loadThresholds(optionWindow.targetWidget.settings.load_thresholds, modelData.metric);
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
                        text: qsTr("Idle Chatter (minutes, 0 = off)")
                    }

                    SpinBox {
                        Layout.preferredWidth: 120
                        from: 0
                        to: 240
                        stepSize: 5
                        editable: true
                        value: optionWindow.targetWidget.settings.idle_chat_minutes !== undefined ? optionWindow.targetWidget.settings.idle_chat_minutes : 15
                        onValueModified: optionWindow.targetWidget.settings.idle_chat_minutes = value
                    }

                }

                SettingNote {
                    text: qsTr("While Yui is a crystal, what she says appears in a bubble next to it, and she says something by herself after this long without interaction (each time uses the API).")
                }

                Button {
                    text: qsTr("Restore Defaults")
                    onClicked: {
                        optionWindow.targetWidget.settings.load_thresholds = {};
                        for (var i = 0; i < thresholdRows.count; i++)
                            thresholdRows.itemAt(i).load();

                    }
                }

                Heading {
                    text: qsTr("Yui's Heart")
                }

                SettingNote {
                    text: qsTr("Export Yui's memories to a file to keep them or move them to another computer; importing adds the memories of such a file. A backup is also made once a day (the last 7 days are kept).")
                }

                CheckBox {
                    id: withMessages

                    text: qsTr("Include the chat history (private conversations)")
                }

                RowLayout {
                    Button {
                        text: qsTr("Export")
                        onClicked: optionWindow.targetWidget.exportHeart(withMessages.checked, function(path) {
                            heartMessage.text = path ? qsTr("Exported to %1").arg(path) : qsTr("The export could not be written. See the log below.");
                        })
                    }

                    Button {
                        text: qsTr("Import")
                        onClicked: {
                            var component = Qt.createComponent("HeartImportDialog.qml");
                            if (component.status !== Component.Ready) {
                                optionWindow.targetWidget.diag("import dialog unavailable: " + component.errorString());
                                heartMessage.text = qsTr("The file picker is not available. See the log below.");
                                return ;
                            }
                            var dialog = component.createObject(optionWindow);
                            dialog.accepted.connect(function() {
                                heartMessage.text = optionWindow.targetWidget.importHeart(dialog.fileUrl);
                                dialog.destroy();
                            });
                            dialog.rejected.connect(function() {
                                dialog.destroy();
                            });
                            dialog.open();
                        }
                    }

                    Button {
                        text: qsTr("Open Backup Folder")
                        enabled: (optionWindow.targetWidget.settingsRevision, !!optionWindow.targetWidget.settings.heart_backup_path)
                        onClicked: optionWindow.targetWidget.showInExplorer(optionWindow.targetWidget.settings.heart_backup_path)
                    }

                }

                Label {
                    id: heartMessage

                    visible: text !== ""
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }

                Heading {
                    text: qsTr("Close Programs")
                }

                Label {
                    text: qsTr("Whitelist")
                }

                SettingNote {
                    text: qsTr("Yui closes these programs without asking. After closing a program for the first time, Yui asks whether to add it here.")
                }

                ProcessListEditor {
                    Layout.fillWidth: true
                    // Re-read when Yui adds a program while this window is open.
                    names: optionWindow.targetWidget.settingsRevision, optionWindow.targetWidget.settings.kill_whitelist || []
                    emptyText: qsTr("No programs yet.")
                    // A removed program is not offered for the whitelist again; closing it is confirmed.
                    onEdited: {
                        var removed = Yui.processList(optionWindow.targetWidget.settings.kill_whitelist).filter(function(name) {
                            return list.indexOf(name) === -1;
                        });
                        optionWindow.targetWidget.settings.kill_asked = Yui.processList((optionWindow.targetWidget.settings.kill_asked || []).concat(removed));
                        optionWindow.targetWidget.settings.kill_whitelist = list;
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
                    names: optionWindow.targetWidget.settings.kill_protected || []
                    onEdited: optionWindow.targetWidget.settings.kill_protected = list
                }

                Heading {
                    text: qsTr("Diagnostics")
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
                        }]

                        Button {
                            text: modelData.label
                            onClicked: optionWindow.targetWidget.testAction(modelData.tag)
                        }

                    }

                }

                // Live log of the desktop actions: confirmations, commands and their results.
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Log")
                        font.bold: true
                    }

                    Button {
                        text: qsTr("Copy Log")
                        enabled: optionWindow.targetWidget.diagLog.length > 0
                        onClicked: {
                            logText.selectAll();
                            logText.copy();
                            logText.deselect();
                        }
                    }

                    Button {
                        text: qsTr("Clear Log")
                        onClicked: optionWindow.targetWidget.diagLog = []
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
                            text: optionWindow.targetWidget.diagLog.join("\n")
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
                        visible: optionWindow.targetWidget.diagLog.length === 0
                        text: qsTr("Run a test to see its steps here.")
                        color: "#88FFFFFF"
                        font.pixelSize: 11
                    }

                }

            }

        }

        header: TitleBar {
            text: qsTr("Option")
        }

    }

}
