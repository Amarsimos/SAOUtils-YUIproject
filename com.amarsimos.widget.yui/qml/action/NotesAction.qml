// MHCP-YUI action category "Quest Log" (see YuiActionBase.qml).
import QtQml 2.12

YuiActionBase {
    title: qsTr("Quest Log")
    commands: [{
            "id": "add_note",
            "name": qsTr("Add Note...")
        }, {
            "id": "finish_note",
            "name": qsTr("Finish First Note")
        }]
}
