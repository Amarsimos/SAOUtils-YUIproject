import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// "Yui's Heart" window (next to Cardinal System, Equipment and Option): her memories, to view and
// edit (YuisHeartPage.qml), and to export, import and back up.
NVG.Window {
    id: heartWindow

    property var targetWidget

    title: qsTr("Yui's Heart")
    visible: true
    minimumWidth: 420
    minimumHeight: 420
    width: 520
    height: 720
    transientParent: widget.NVG.View.window
    onClosing: destroy()

    Page {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 0
            spacing: 10

            YuisHeartPage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                yui: heartWindow.targetWidget
            }

            Heading {
                text: qsTr("Export and Backup")
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
                    onClicked: heartWindow.targetWidget.exportHeart(withMessages.checked, function(path) {
                        heartMessage.text = path ? qsTr("Exported to %1").arg(path) : qsTr("The export could not be written. See the log in Option.");
                    })
                }

                Button {
                    text: qsTr("Import")
                    onClicked: {
                        var component = Qt.createComponent("YuisHeartImportDialog.qml");
                        if (component.status !== Component.Ready) {
                            heartWindow.targetWidget.diag("import dialog unavailable: " + component.errorString());
                            heartMessage.text = qsTr("The file picker is not available. See the log in Option.");
                            return ;
                        }
                        var dialog = component.createObject(heartWindow);
                        dialog.accepted.connect(function() {
                            heartMessage.text = heartWindow.targetWidget.importHeart(dialog.fileUrl);
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
                    enabled: (heartWindow.targetWidget.settingsRevision, !!heartWindow.targetWidget.settings.heart_backup_path)
                    onClicked: heartWindow.targetWidget.showInExplorer(heartWindow.targetWidget.settings.heart_backup_path)
                }

            }

            Label {
                id: heartMessage

                visible: text !== ""
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

        }

        header: TitleBar {
            text: qsTr("Yui's Heart")
        }

    }

}
