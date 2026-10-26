// MHCP-YUI action category "Mental Record" (see YuiActionBase.qml).
import QtQml 2.12

YuiActionBase {
    title: qsTr("Mental Record")
    commands: [{
            "id": "record_mood",
            "name": qsTr("Record Mood...")
        }, {
            "id": "weekly_report",
            "name": qsTr("Write Weekly Report")
        }]
}
