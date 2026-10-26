// MHCP-YUI action category "Alarm" (see YuiActionBase.qml).
import QtQml 2.12

YuiActionBase {
    title: qsTr("Alarm")
    commands: [{
            "id": "add_reminder",
            "name": qsTr("Add Reminder...")
        }, {
            "id": "dismiss_reminder",
            "name": qsTr("Remove Next Reminder")
        }]
}
