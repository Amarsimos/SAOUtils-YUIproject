import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// "Yui's Heart" window (next to Cardinal System, Equipment and System Console), in three pages:
// Memories (view, add and edit them, YuisHeartPage.qml), Recall (what is remembered and sent with
// each request) and Local Memory (export, import, backups, the recollection log, forgetting all).
// Settings take effect at once; Reset restores the settings only, never memories or the log.
NVG.Window {
    id: heartWindow

    property var targetWidget
    // Chat messages kept in the recollection log (refreshed when the Local Memory page opens).
    property int logSize: 0

    function refreshLogSize() {
        logSize = targetWidget.messageLogCount();
    }

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

            TabBar {
                id: tabs

                Layout.fillWidth: true
                onCurrentIndexChanged: {
                    if (currentIndex === 2)
                        heartWindow.refreshLogSize();

                }

                TabButton {
                    text: qsTr("Memories")
                }

                TabButton {
                    text: qsTr("Recall")
                }

                TabButton {
                    text: qsTr("Local Memory")
                }

            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabs.currentIndex

                // ---------------------------------------------------------------- Memories
                YuisHeartPage {
                    yui: heartWindow.targetWidget
                }

                // ---------------------------------------------------------------- Recall
                ScrollView {
                    id: recallScroll

                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: recallScroll.availableWidth - recallScroll.ScrollBar.vertical.width - 4
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                Layout.fillWidth: true
                                text: qsTr("Auto Memory")
                            }

                            Switch {
                                id: autoMemorySwitch

                                checked: heartWindow.targetWidget.autoMemory
                                onToggled: heartWindow.targetWidget.settings.auto_memory = checked
                            }

                            ResetButton {
                                changed: !autoMemorySwitch.checked
                                onClicked: {
                                    autoMemorySwitch.checked = true;
                                    heartWindow.targetWidget.settings.auto_memory = true;
                                }
                            }

                        }

                        SettingNote {
                            text: qsTr("Yui decides by herself what to remember and forget while chatting. When off, only the memories you add or edit here are kept (and the instructions for it are not sent).")
                        }

                        NumberSetting {
                            id: coreCapacity

                            label: qsTr("Heart Core Capacity")
                            from: 5
                            to: 50
                            value: heartWindow.targetWidget.heartCoreCapacity
                            defaultValue: 20
                            onEdited: heartWindow.targetWidget.settings.heart_core_capacity = value
                        }

                        SettingNote {
                            text: qsTr("The heart core is sent with every request. When it is full, the memory used longest ago (unless pinned) becomes a fragment.")
                        }

                        NumberSetting {
                            id: recalled

                            label: qsTr("Recalled Memories")
                            from: 0
                            to: 20
                            value: heartWindow.targetWidget.recallCount
                            defaultValue: 5
                            onEdited: heartWindow.targetWidget.settings.recall_count = value
                        }

                        SettingNote {
                            text: qsTr("How many memories related to the current topic are sent with each request (the heart core is always sent). Fewer use fewer tokens.")
                        }

                        NumberSetting {
                            id: conversation

                            label: qsTr("Conversation Memory")
                            from: 2
                            to: 60
                            stepSize: 2
                            value: heartWindow.targetWidget.maxHistory
                            defaultValue: 20
                            onEdited: heartWindow.targetWidget.settings.max_history = value
                        }

                        SettingNote {
                            text: qsTr("How many of the latest messages (count) are sent with each request. Fewer use fewer tokens; more let Yui remember more of the conversation.")
                        }

                        NumberSetting {
                            id: savedChat

                            label: qsTr("Saved Chat")
                            from: 10
                            to: 200
                            stepSize: 10
                            value: heartWindow.targetWidget.maxSavedMessages
                            defaultValue: 50
                            onEdited: heartWindow.targetWidget.settings.saved_messages = value
                        }

                        SettingNote {
                            text: qsTr("How many chat messages are still shown after a restart. Not sent to the AI.")
                        }

                    }

                }

                // ---------------------------------------------------------------- Local Memory
                ScrollView {
                    id: localScroll

                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: localScroll.availableWidth - localScroll.ScrollBar.vertical.width - 4
                        spacing: 10

                        SettingNote {
                            text: qsTr("Export Yui's memories to a file to keep them or move them to another computer; importing adds the memories of such a file. A backup is also made once a day.")
                        }

                        CheckBox {
                            id: withMessages

                            text: qsTr("Include the chat history (private conversations)")
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 8

                            Button {
                                text: qsTr("Export")
                                onClicked: heartWindow.targetWidget.exportHeart(withMessages.checked, function(path) {
                                    heartMessage.text = path ? qsTr("Exported to %1").arg(path) : qsTr("The export could not be written. See the log in System Console.");
                                })
                            }

                            Button {
                                text: qsTr("Import")
                                onClicked: {
                                    var component = Qt.createComponent("YuisHeartImportDialog.qml");
                                    if (component.status !== Component.Ready) {
                                        heartWindow.targetWidget.diag("import dialog unavailable: " + component.errorString());
                                        heartMessage.text = qsTr("The file picker is not available. See the log in System Console.");
                                        return ;
                                    }
                                    var dialog = component.createObject(heartWindow);
                                    dialog.accepted.connect(function() {
                                        heartMessage.text = heartWindow.targetWidget.importHeart(dialog.fileUrl);
                                        heartWindow.refreshLogSize();
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
                                onClicked: heartWindow.targetWidget.openHeartFolder()
                            }

                        }

                        NumberSetting {
                            id: backupDays

                            label: qsTr("Backup Days")
                            from: 1
                            to: 30
                            value: heartWindow.targetWidget.backupDays
                            defaultValue: 7
                            onEdited: heartWindow.targetWidget.settings.backup_days = value
                        }

                        SettingNote {
                            text: qsTr("How many daily backups are kept (without the chat history).")
                        }

                        Heading {
                            text: qsTr("Recollection Log")
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                Layout.fillWidth: true
                                text: qsTr("%1 messages").arg(heartWindow.logSize)
                            }

                            Button {
                                text: qsTr("Clear Log")
                                enabled: heartWindow.logSize > 0
                                onClicked: heartWindow.targetWidget.askConfirm(qsTr("Yui's Heart"), qsTr("Delete the whole chat history kept in the recollection log? This cannot be undone."), function() {
                                    heartWindow.targetWidget.clearMessageLog();
                                    heartWindow.refreshLogSize();
                                }, true)
                            }

                        }

                        SettingNote {
                            text: qsTr("Every chat message is kept here, only for exports. It is never sent to the AI, and Yui's memories stay when it is cleared.")
                        }

                        Heading {
                            text: qsTr("Forget Everything")
                        }

                        Button {
                            text: qsTr("Forget Everything")
                            enabled: heartWindow.targetWidget.heartCache.length > 0
                            onClicked: heartWindow.targetWidget.askConfirm(qsTr("Yui's Heart"), qsTr("Delete all %1 memories of Yui's Heart?").arg(heartWindow.targetWidget.heartCache.length), function() {
                                heartWindow.targetWidget.askConfirm(qsTr("Yui's Heart"), qsTr("Really forget everything? A backup file is written first."), function() {
                                    heartWindow.targetWidget.forgetEverything(function(text) {
                                        heartMessage.text = text;
                                    });
                                }, true);
                            }, true)
                        }

                        SettingNote {
                            text: qsTr("Deletes every memory (heart core and fragments). The recollection log stays. A backup is written first, so the memories can be imported again.")
                        }

                        Label {
                            id: heartMessage

                            visible: text !== ""
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }

                    }

                }

            }

        }

        // Reset: the settings of Recall and Backup Days, never the memories or the log.
        header: TitleBar {
            // Every settings window has the same light title bar (as SAO Utils' own dialogs, e.g. the
            // mail box composer); without this some came out in the theme's blue.
            Style.primary: heartWindow.Style.dialogColor
            text: qsTr("Yui's Heart")
            standardButtons: Dialog.Reset
            onReset: heartWindow.targetWidget.confirmReset(qsTr("Yui's Heart"), function() {
                autoMemorySwitch.checked = true;
                heartWindow.targetWidget.settings.auto_memory = true;
                coreCapacity.set(20);
                recalled.set(5);
                conversation.set(20);
                savedChat.set(50);
                backupDays.set(7);
            })
        }

    }

}
