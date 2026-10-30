// MHCP-YUI action category "Yui" (see YuiActionBase.qml): talking with Yui and what she cares for (Mental Health Counseling).
import QtQml 2.12

YuiActionBase {
    title: qsTr("Yui")
    allCommands: [{
            "id": "chat",
            "name": qsTr("Open Chat")
        }, {
            "id": "speak",
            "name": qsTr("Spontaneous Talk")
        }, {
            "id": "record_mood",
            "name": qsTr("Record Mood...")
        }, {
            "id": "weekly_report",
            "name": qsTr("Write Weekly Report")
        }]
}
