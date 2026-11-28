import QtQuick 2.12
import QtQuick.Layouts 1.12

// System Console, Operations (as the preview's Recent Operations): what Yui did on the desktop (opening
// pages, searching, starting and closing programs, finding files, media, sword skills, Seedling
// widgets) and how it ended, newest first, the last 50 (main-stand.qml, logOperation). Read only;
// Clear empties it.
ConsolePage {
    id: operations

    property var yui
    property var entries: []
    // Result: [text, tag color].
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

    function when(time) {
        var date = new Date(time);
        return date.toDateString() === new Date().toDateString() ? Qt.formatDateTime(date, "HH:mm") : Qt.formatDateTime(date, "MM-dd HH:mm");
    }

    Component.onCompleted: refresh()

    Connections {
        target: operations.yui
        onOperationRevisionChanged: operations.refresh()
    }

    ConsolePanel {
        Layout.fillWidth: true
        title: "Recent Operations"
        note: qsTr("last 50 · read only")
        tools: [
            ConsoleChip {
                small: true
                visible: operations.entries.length > 0
                text: qsTr("Clear")
                onClicked: operations.yui.askConfirm(qsTr("System Console"), qsTr("Clear the list of recent operations?"), function() {
                    operations.yui.clearOperations();
                }, true)
            }
        ]

        Text {
            visible: operations.entries.length === 0
            text: qsTr("Nothing done on the computer yet.")
            font.pixelSize: 13
            color: "#7A7A7A"
        }

        Repeater {
            model: operations.entries

            ConsoleRow {
                readonly property var result: operations.results[modelData.result] || [modelData.result, "#9A9A9A"]

                Layout.fillWidth: true
                keyWidth: 150
                key: operations.when(modelData.time) + "   " + String(modelData.kind).toUpperCase()
                text: modelData.target
                last: index === operations.entries.length - 1

                ConsoleTag {
                    text: parent.parent.result[0]
                    color: parent.parent.result[1]
                }

            }

        }

    }

}
