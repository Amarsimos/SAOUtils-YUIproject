import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// System Console, Operations: what Yui did on the desktop (opening pages, searching, starting and
// closing programs, finding files, media, sword skills, Seedling widgets) and how it ended, newest
// first, the last 50 (main-stand.qml, logOperation). Read only; Clear empties it.
SettingsPage {
    id: operations

    property var yui
    property var entries: []
    readonly property var kinds: {
        "open": "OPEN",
        "search": "SEARCH",
        "launch": "LAUNCH",
        "kill": "KILL",
        "find": "FIND",
        "media": "MEDIA",
        "skill": "SKILL",
        "seedling": "SEEDLING",
        "web": "WEB"
    }
    // Result: [text, color].
    readonly property var results: {
        "done": [qsTr("Done"), "#7CC63E"],
        "cancelled": [qsTr("Cancelled"), "#9A9A9A"],
        "blocked": [qsTr("Blocked: Immortal Object"), "#C82864"],
        "disabled": [qsTr("Turned off in System Authority"), "#9A9A9A"],
        "failed": [qsTr("Failed"), "#C82864"]
    }

    function refresh() {
        entries = yui.settings.operation_log || [];
    }

    Component.onCompleted: refresh()

    Connections {
        target: operations.yui
        onOperationRevisionChanged: operations.refresh()
    }

    Heading {
        text: qsTr("Recent Operations")
    }

    SettingNote {
        visible: operations.yui.settingsHelp
        besidePreferences: true
        text: qsTr("What Yui did on the computer and how it ended, the last 50. Memories, moods, reminders and notes have pages of their own.")
    }

    Label {
        Layout.leftMargin: 16
        visible: operations.entries.length === 0
        opacity: 0.7
        text: qsTr("Nothing done on the computer yet.")
    }

    Repeater {
        model: operations.entries

        RowLayout {
            readonly property var result: operations.results[modelData.result] || [modelData.result, "#9A9A9A"]

            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 10

            Label {
                Layout.preferredWidth: 78
                opacity: 0.7
                font.family: "SAO UI"
                text: {
                    var time = new Date(modelData.time);
                    var today = new Date();
                    return time.toDateString() === today.toDateString() ? Qt.formatDateTime(time, "HH:mm") : Qt.formatDateTime(time, "MM-dd HH:mm");
                }
            }

            Label {
                Layout.preferredWidth: 72
                opacity: 0.7
                font.family: "SAO UI"
                text: operations.kinds[modelData.kind] || String(modelData.kind).toUpperCase()
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: modelData.target
            }

            // The result as a small colored tag.
            Rectangle {
                implicitWidth: tag.implicitWidth + 12
                implicitHeight: tag.implicitHeight + 4
                radius: 2
                color: parent.result[1]

                Label {
                    id: tag

                    anchors.centerIn: parent
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    text: parent.parent.result[0]
                }

            }

        }

    }

    Button {
        Layout.alignment: Qt.AlignHCenter
        visible: operations.entries.length > 0
        text: qsTr("Clear")
        onClicked: operations.yui.askConfirm(qsTr("System Console"), qsTr("Clear the list of recent operations?"), function() {
            operations.yui.clearOperations();
        }, true)
    }

}
