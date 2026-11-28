import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// System Console, Memories (as the preview; moved from Yui's Heart): three chips choose Memories (view,
// add and edit them: YuisHeartPage.qml on a panel), Follow-ups (memories about a day to come, which
// Yui brings up) and Recollection Log (searching the chat history). What is remembered, the transfer,
// backups and forgetting stay in Yui's Heart.
ColumnLayout {
    id: memories

    property var yui
    property int tab: 0
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

    function searchLog(text) {
        logQuery = text.trim();
        logResults = logQuery ? yui.searchMessageLog(logQuery, 50) : [];
    }

    spacing: 12
    onTabChanged: {
        if (tab === 1)
            refreshFollowups();

        if (tab === 2)
            logSize = yui.messageLogCount();

    }

    Connections {
        target: memories.yui
        onFollowupsChanged: memories.refreshFollowups()
    }

    Row {
        spacing: 8

        Repeater {
            model: [qsTr("Memories"), qsTr("Follow-ups"), qsTr("Recollection Log")]

            ConsoleChip {
                text: modelData
                checked: memories.tab === index
                onClicked: memories.tab = index
            }

        }

    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        currentIndex: memories.tab

        // ---------------------------------------------------------------- Memories
        Rectangle {
            color: "#F2F9F9F9"
            border.color: "#22000000"

            YuisHeartPage {
                anchors.fill: parent
                anchors.margins: 12
                yui: memories.yui
            }

        }

        // ---------------------------------------------------------------- Follow-ups
        ConsolePage {
            ConsolePanel {
                Layout.fillWidth: true
                title: "Follow-ups"
                note: qsTr("days to come")

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: 12
                    color: "#7A7A7A"
                    text: qsTr("Things Yui remembered with a date to come. She cheers you on that day and asks how it went in the week after. Removing one here keeps the memory.")
                }

                Text {
                    visible: memories.followupItems.length === 0
                    font.pixelSize: 13
                    color: "#7A7A7A"
                    text: memories.yui.featureEnabled("followups") ? qsTr("Nothing to follow up") : qsTr("Follow-ups are off (Mental Health Counseling, Care)")
                }

                Repeater {
                    model: memories.followupItems

                    ConsoleRow {
                        Layout.fillWidth: true
                        key: modelData.due.slice(5).replace("-", "/")
                        text: modelData.text
                        last: index === memories.followupItems.length - 1

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: memories.followupState(modelData)
                            font.pixelSize: 12
                            color: "#7A7A7A"
                        }

                        ConsoleChip {
                            small: true
                            text: qsTr("Remove")
                            onClicked: memories.yui.dismissFollowup(modelData.key)
                        }

                    }

                }

            }

        }

        // ---------------------------------------------------------------- Recollection Log
        ConsolePage {
            ConsolePanel {
                Layout.fillWidth: true
                title: "Recollection Log"
                note: qsTr("%1 messages").arg(memories.logSize)

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: 12
                    color: "#7A7A7A"
                    text: qsTr("Every chat message is kept here, only for exports and searching. It is never sent to the AI. Exporting and clearing it are in Yui's Heart, Local Memory.")
                }

                // Searching the log as you type.
                TextField {
                    id: logSearchField

                    Layout.fillWidth: true
                    selectByMouse: true
                    placeholderText: qsTr("Search the log")
                    onTextChanged: logSearchTimer.restart()

                    Timer {
                        id: logSearchTimer

                        interval: 300
                        onTriggered: memories.searchLog(logSearchField.text)
                    }

                }

                Text {
                    visible: memories.logQuery !== ""
                    font.pixelSize: 12
                    color: "#7A7A7A"
                    text: memories.logResults.length >= 50 ? qsTr("The latest 50 messages found") : qsTr("%1 messages found").arg(memories.logResults.length)
                }

                Repeater {
                    model: memories.logResults

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        font.pixelSize: 13
                        color: "#333333"
                        text: Yui.logLine(modelData, memories.yui.userTitle())
                    }

                }

            }

        }

    }

}
