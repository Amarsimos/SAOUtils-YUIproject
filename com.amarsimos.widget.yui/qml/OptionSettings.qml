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
