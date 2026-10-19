import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

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
                    text: optionWindow.targetWidget.settings.es_path || ""
                    // Saved as soon as it is edited; empty means es.exe is found through PATH.
                    onEditingFinished: optionWindow.targetWidget.settings.es_path = text.trim()
                }

                SettingNote {
                    text: qsTr("File search uses Everything's command line tool es.exe. Enter its full path here, or leave it empty when es.exe is in PATH. Everything itself must be running.")
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
                        text: qsTr("Clear Log")
                        onClicked: optionWindow.targetWidget.diagLog = []
                    }

                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    color: "#1A1D24"
                    radius: 4

                    ListView {
                        id: logView

                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true
                        model: optionWindow.targetWidget.diagLog
                        onCountChanged: Qt.callLater(positionViewAtEnd)

                        delegate: Text {
                            width: logView.width
                            text: modelData
                            color: "#DDFFFFFF"
                            font.family: "Consolas"
                            font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere
                        }

                        ScrollBar.vertical: SaoScrollBar {
                        }

                    }

                    Text {
                        anchors.centerIn: parent
                        visible: logView.count === 0
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
