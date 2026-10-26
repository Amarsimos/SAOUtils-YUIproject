// MHCP-YUI action category "Skill Slots" (see YuiActionBase.qml): the tools of Skill Slots.
import QtQml 2.12

YuiActionBase {
    title: qsTr("Skill Slots")
    commands: [{
            "id": "raid",
            "name": qsTr("Start / End Boss Raid")
        }, {
            "id": "start_raid",
            "name": qsTr("Start Boss Raid"),
            "uses": ["minutes"]
        }, {
            "id": "end_raid",
            "name": qsTr("End Boss Raid")
        }, {
            "id": "add_reminder",
            "name": qsTr("Add Reminder...")
        }, {
            "id": "dismiss_reminder",
            "name": qsTr("Remove Next Reminder")
        }, {
            "id": "add_note",
            "name": qsTr("Add Note...")
        }, {
            "id": "finish_note",
            "name": qsTr("Finish First Note")
        }, {
            "id": "sword_skill",
            "name": qsTr("Run Sword Skill"),
            "uses": ["slot"]
        }, {
            "id": "raid_banner",
            "name": qsTr("Show Raid Banner")
        }]
}
