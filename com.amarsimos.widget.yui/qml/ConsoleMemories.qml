import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// System Console, Memories (moved from Yui's Heart), in three tabs: Memories (view, add and edit them,
// YuisHeartPage.qml), Follow-ups (memories about a day to come, which Yui brings up) and Recollection
// Log (searching the chat history). What is remembered, the transfer, backups and forgetting stay in
// Yui's Heart.
ColumnLayout {
    id: memories

    property var yui
    // Follow-ups: the memories about a day to come, soonest first.
    property var followupItems: []
    // Recollection Log: how many messages it keeps, and the messages found (newest first, at most 50).
    property int logSize: 0
    property var logResults: []
    property string logQuery: ""

    function refreshFollowups() {
        followupItems = yui.followupList(Date.now());
    }

    function followupState(item) {
        if (item.phase === "ahead")
            return item.days === 1 ? qsTr("Tomorrow") : qsTr("In %1 days").arg(item.days);

        if (item.phase === "today")
            return item.stage ? qsTr("Today, cheered on") : qsTr("Today");

        return item.stage === "asked" ? qsTr("Asked") : qsTr("To ask");
    }

    function searchLog() {
        logQuery = logSearchField.text.trim();
        logResults = logQuery ? yui.searchMessageLog(logQuery, 50) : [];
    }

    spacing: 10

    Connections {
        target: memories.yui
        onFollowupsChanged: memories.refreshFollowups()
    }

    WrapTabBar {
        id: tabs

        onShownIndexChanged: {
            if (shownIndex === 1)
                memories.refreshFollowups();

            if (shownIndex === 2)
                memories.logSize = memories.yui.messageLogCount();

        }
        model: [qsTr("Memories"), qsTr("Follow-ups"), qsTr("Recollection Log")]
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        currentIndex: tabs.shownIndex

        // ---------------------------------------------------------------- Memories
        YuisHeartPage {
            yui: memories.yui
        }

        // ---------------------------------------------------------------- Follow-ups
        SettingsPage {
            SettingNote {
                besidePreferences: true
                text: qsTr("Things Yui remembered with a date to come. She cheers you on that day and asks how it went in the week after. Removing one here keeps the memory.")
            }

            Label {
                visible: memories.followupItems.length === 0
                Layout.alignment: Qt.AlignHCenter
                opacity: 0.7
                text: memories.yui.featureEnabled("followups") ? qsTr("Nothing to follow up") : qsTr("Follow-ups are off (Mental Health Counseling, Care)")
            }

            Repeater {
                model: memories.followupItems

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
                        text: memories.followupState(modelData)
                    }

                    Button {
                        text: qsTr("Remove")
                        onClicked: memories.yui.dismissFollowup(modelData.key)
                    }

                }

            }

        }

        // ---------------------------------------------------------------- Recollection Log
        SettingsPage {
            SettingNote {
                visible: memories.yui.settingsHelp
                besidePreferences: true
                text: qsTr("Every chat message is kept here, only for exports and searching. It is never sent to the AI. Exporting and clearing it are in Yui's Heart, Local Memory.")
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("%1 messages").arg(memories.logSize)
            }

            // Searching the log as you type.
            TextField {
                id: logSearchField

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                selectByMouse: true
                placeholderText: qsTr("Search the log")
                onTextChanged: logSearchTimer.restart()

                Timer {
                    id: logSearchTimer

                    interval: 300
                    onTriggered: memories.searchLog()
                }

            }

            Label {
                Layout.leftMargin: 16
                visible: memories.logQuery !== ""
                opacity: 0.7
                text: memories.logResults.length >= 50 ? qsTr("The latest 50 messages found") : qsTr("%1 messages found").arg(memories.logResults.length)
            }

            Repeater {
                model: memories.logResults

                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: Yui.logLine(modelData, memories.yui.userTitle())
                }

            }

        }

    }

}
