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
    width: 480
    height: 420
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

            }

        }

        header: TitleBar {
            text: qsTr("Option")
        }

    }

}
