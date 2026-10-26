// MHCP-YUI action category "Boss Raid" (see YuiActionBase.qml).
import QtQml 2.12

YuiActionBase {
    title: qsTr("Boss Raid")
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
        }]
}
