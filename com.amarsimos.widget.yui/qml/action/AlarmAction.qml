// MHCP-YUI action category "Alarm" (see YuiActionBase.qml).
import QtQml 2.12

YuiActionBase {
    title: qsTr("Alarm")
    commands: [{
            "id": "add_reminder",
            "name": qsTr("Add Reminder"),
            "uses": ["text"],
            "hint": qsTr("time|text, e.g. +30|Drink water, 08:00|Meeting, 每天 23:00|Sleep")
        }, {
            "id": "dismiss_reminder",
            "name": qsTr("Remove Next Reminder")
        }]
}
