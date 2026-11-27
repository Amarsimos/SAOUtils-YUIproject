import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// "Yui's Heart" window (next to Cardinal System, Equipment, Mental Health Counseling and System Console),
// in pages: Memories (view, add and edit them, YuisHeartPage.qml), Follow-ups (memories about a day to
// come, which Yui brings up), Recall (what is remembered and sent
// with each request) and Local Memory (export, import, backups, the recollection log, forgetting all;
// always the last page).
// The settings are SAO Utils' own preferences synced with the widget's settings (ObjectPreferenceGroup),
// taking effect at once; Reset restores the settings only, never memories or the log.
NVG.Window {
    id: heartWindow

    property var targetWidget
    // Chat messages kept in the recollection log (refreshed when the Local Memory page opens).
    property int logSize: 0
    // Recollection Log search: the messages found (newest first, at most 50) for logQuery.
    property var logResults: []
    property string logQuery: ""

    function searchLog() {
        logQuery = logSearchField.text.trim();
        logResults = logQuery ? targetWidget.searchMessageLog(logQuery, 50) : [];
    }
    // The settings of each tab, for Reset This Tab and the title bar's Reset.
    readonly property var recallPreferences: [autoMemoryPreference, coreCapacity, recalled, logRecallPreference, conversation, savedChat]
    readonly property var localPreferences: [backupDays]

    // Follow-ups page: the memories about a day to come, soonest first.
    property var followupItems: []

    function refreshFollowups() {
        followupItems = targetWidget.followupList(Date.now());
    }

    function followupState(item) {
        if (item.phase === "ahead")
            return item.days === 1 ? qsTr("Tomorrow") : qsTr("In %1 days").arg(item.days);

        if (item.phase === "today")
            return item.stage ? qsTr("Today, cheered on") : qsTr("Today");

        return item.stage === "asked" ? qsTr("Asked") : qsTr("To ask");
    }

    Connections {
        target: heartWindow.targetWidget
        onFollowupsChanged: heartWindow.refreshFollowups()
    }

    function refreshLogSize() {
        logSize = targetWidget.messageLogCount();
    }

    title: qsTr("Yui's Heart")
    visible: true
    minimumWidth: 420
    minimumHeight: 420
    width: 520
    height: 1008
    transientParent: widget.NVG.View.window
    onClosing: destroy()

    Page {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            // Little room at the sides, as the other settings windows.
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.bottomMargin: 16
            spacing: 10

            // Wraps into a second row when the window is narrow (see WrapTabBar.qml).
            WrapTabBar {
                id: tabs

                onShownIndexChanged: {
                    if (shownIndex === 1)
                        heartWindow.refreshFollowups();

                    if (shownIndex === model.length - 1)
                        heartWindow.refreshLogSize();

                }
                model: [qsTr("Memories"), qsTr("Follow-ups"), qsTr("Recall"), qsTr("Local Memory")]
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabs.shownIndex

                // ---------------------------------------------------------------- Memories
                YuisHeartPage {
                    yui: heartWindow.targetWidget
                }

                // ---------------------------------------------------------------- Follow-ups
                SettingsPage {
                    SettingNote {
                        besidePreferences: true
                        text: qsTr("Things Yui remembered with a date to come. She cheers you on that day and asks how it went in the week after. Removing one here keeps the memory.")
                    }

                    Label {
                        visible: heartWindow.followupItems.length === 0
                        Layout.alignment: Qt.AlignHCenter
                        opacity: 0.7
                        text: heartWindow.targetWidget.featureEnabled("followups") ? qsTr("Nothing to follow up") : qsTr("Follow-ups are off (Mental Health Counseling, Care)")
                    }

                    Repeater {
                        model: heartWindow.followupItems

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            spacing: 10

                            Label {
                                text: modelData.due.slice(5).replace("-", "/")
                                font.bold: true
                            }

                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                text: modelData.text
                            }

                            Label {
                                opacity: 0.7
                                text: heartWindow.followupState(modelData)
                            }

                            Button {
                                text: qsTr("Remove")
                                onClicked: heartWindow.targetWidget.dismissFollowup(modelData.key)
                            }

                        }

                    }

                }

                // ---------------------------------------------------------------- Recall
                // Under headings: Memory, Context (sent with each request), Chat History.
                SettingsPage {
                    P.ObjectPreferenceGroup {
                        id: recallGroup

                        Layout.fillWidth: true
                        defaultValue: heartWindow.targetWidget.settings
                        syncProperties: true

                        Heading {
                            text: qsTr("Memory")
                        }

                        P.SwitchPreference {
                            id: autoMemoryPreference

                            name: "auto_memory"
                            label: qsTr("Auto Memory")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: heartWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui decides by herself what to remember and forget while chatting. When off, only the memories you add or edit here are kept (and the instructions for it are not sent).")
                        }

                        P.SpinPreference {
                            id: coreCapacity

                            name: "heart_core_capacity"
                            label: qsTr("Heart Core Capacity")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 5
                            to: 50
                            defaultValue: 20
                        }

                        SettingNote {
                            visible: heartWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("The heart core is sent with every request. When it is full, the memory used longest ago (unless pinned) becomes a fragment.")
                        }

                        Heading {
                            text: qsTr("Context")
                        }

                        P.SpinPreference {
                            id: recalled

                            name: "recall_count"
                            label: qsTr("Recalled Memories")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 0
                            to: 20
                            defaultValue: 5
                        }

                        SettingNote {
                            visible: heartWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("How many memories related to the current topic are sent with each request (the heart core is always sent). Fewer use fewer tokens.")
                        }

                        // A number typed in (or stepped with the arrows), like the precise values in SAO Utils' own settings.
                        P.SpinPreference {
                            id: logRecallPreference

                            name: "log_recall"
                            label: qsTr("Log Recall")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 0
                            to: 10
                            stepSize: 1
                            defaultValue: 3
                        }

                        SettingNote {
                            visible: heartWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("How many older chat messages about the same thing Yui looks up in the recollection log and reads with each request, so she can recall what was said long ago without remembering it. 0 turns it off; fewer use fewer tokens.")
                        }

                        P.SpinPreference {
                            id: conversation

                            name: "max_history"
                            label: qsTr("Conversation Memory")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 2
                            to: 60
                            stepSize: 2
                            defaultValue: 20
                        }

                        SettingNote {
                            visible: heartWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("How many of the latest messages (count) are sent with each request. Fewer use fewer tokens; more let Yui remember more of the conversation.")
                        }

                        Heading {
                            text: qsTr("Chat History")
                        }

                        P.SpinPreference {
                            id: savedChat

                            name: "saved_messages"
                            label: qsTr("Saved Chat")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 10
                            to: 200
                            stepSize: 10
                            defaultValue: 50
                        }

                        SettingNote {
                            visible: heartWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("How many chat messages are still shown after a restart. Not sent to the AI.")
                        }

                    }

                    ResetTabButton {
                        yui: heartWindow.targetWidget
                        windowTitle: heartWindow.title
                        tabTitle: qsTr("Recall")
                        preferences: heartWindow.recallPreferences
                        groups: [recallGroup]
                    }

                }

                // ---------------------------------------------------------------- Local Memory
                // Under headings: Transfer, Backup, Recollection Log, Forget Everything.
                SettingsPage {
                    Heading {
                        text: qsTr("Transfer")
                    }

                    SettingNote {
                        visible: heartWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Export Yui's memories to a file to keep them or move them to another computer; importing adds the memories of such a file. A backup is also made once a day.")
                    }

                    CheckBox {
                        id: withMessages

                        Layout.leftMargin: 16
                        text: qsTr("Include the chat history (private conversations)")
                    }

                    CenteredFlow {
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
                                    var picked = dialog.fileUrl;
                                    dialog.destroy();
                                    // read asynchronously: the message once it is imported
                                    heartWindow.targetWidget.importHeart(picked, function(message) {
                                        heartMessage.text = message;
                                        heartWindow.refreshLogSize();
                                    });
                                });
                                dialog.rejected.connect(function() {
                                    dialog.destroy();
                                });
                                dialog.open();
                            }
                        }

                    }

                    Heading {
                        text: qsTr("Backup")
                    }

                    CenteredFlow {
                        Button {
                            text: qsTr("Open Backup Folder")
                            onClicked: heartWindow.targetWidget.openHeartFolder()
                        }

                    }

                    P.ObjectPreferenceGroup {
                        id: localGroup

                        Layout.fillWidth: true
                        defaultValue: heartWindow.targetWidget.settings
                        syncProperties: true

                        P.SpinPreference {
                            id: backupDays

                            name: "backup_days"
                            label: qsTr("Backup Days")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 1
                            to: 30
                            defaultValue: 7
                        }

                        SettingNote {
                            visible: heartWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("How many daily backups are kept (without the chat history).")
                        }

                    }

                    Heading {
                        text: qsTr("Recollection Log")
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("%1 messages").arg(heartWindow.logSize)
                    }

                    CenteredFlow {

                        Button {
                            text: qsTr("Clear Log")
                            enabled: heartWindow.logSize > 0
                            onClicked: heartWindow.targetWidget.askConfirm(qsTr("Yui's Heart"), qsTr("Delete the whole chat history kept in the recollection log, and clear the chat window? This cannot be undone."), function() {
                                heartWindow.targetWidget.clearMessageLog();
                                // The chat window too, or Yui keeps the cleared talk in her context.
                                heartWindow.targetWidget.clearChat();
                                heartWindow.refreshLogSize();
                                heartWindow.searchLog();
                            }, true)
                        }

                        Button {
                            text: qsTr("Export Log")
                            enabled: heartWindow.logSize > 0
                            onClicked: heartWindow.targetWidget.exportMessageLog(function(path) {
                                heartMessage.text = path ? qsTr("Exported to %1").arg(path) : qsTr("The export could not be written. See the log in System Console.");
                            })
                        }

                    }

                    SettingNote {
                        visible: heartWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Every chat message is kept here, only for exports and searching. It is never sent to the AI, and Yui's memories stay when it is cleared.")
                    }

                    // Searching the log (as you type) and exporting all of it as text.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16

                        TextField {
                            id: logSearchField

                            Layout.fillWidth: true
                            selectByMouse: true
                            placeholderText: qsTr("Search the log")
                            onTextChanged: logSearchTimer.restart()
                        }

                        Timer {
                            id: logSearchTimer

                            interval: 300
                            onTriggered: heartWindow.searchLog()
                        }

                    }

                    Label {
                        Layout.leftMargin: 16
                        visible: heartWindow.logQuery !== ""
                        opacity: 0.7
                        text: heartWindow.logResults.length >= 50 ? qsTr("The latest 50 messages found") : qsTr("%1 messages found").arg(heartWindow.logResults.length)
                    }

                    Repeater {
                        model: heartWindow.logResults

                        Label {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            text: Yui.logLine(modelData, heartWindow.targetWidget.userTitle())
                        }

                    }

                    Heading {
                        text: qsTr("Forget Everything")
                    }

                    Button {
                        Layout.alignment: Qt.AlignHCenter
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
                        visible: heartWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Deletes every memory (heart core and fragments). The recollection log stays. A backup is written first, so the memories can be imported again.")
                    }

                    Label {
                        id: heartMessage

                        visible: text !== ""
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        wrapMode: Text.Wrap
                    }

                    ResetTabButton {
                        yui: heartWindow.targetWidget
                        windowTitle: heartWindow.title
                        tabTitle: qsTr("Local Memory")
                        preferences: heartWindow.localPreferences
                        groups: [localGroup]
                    }

                }

            }

        }

        // Reset: the settings of Recall and Backup Days, never the memories or the log.
        header: SettingsTitleBar {
            yui: heartWindow.targetWidget
            settingsWindow: heartWindow
            // load() is no edit, so the synced groups write the defaults to the settings by save().
            onResetRequested: {
                heartWindow.recallPreferences.concat(heartWindow.localPreferences).forEach(function(preference) {
                    preference.load();
                });
                recallGroup.save();
                localGroup.save();
            }
        }

    }

}
