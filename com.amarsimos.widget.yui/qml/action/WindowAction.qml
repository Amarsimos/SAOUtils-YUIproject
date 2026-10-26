// MHCP-YUI action category "Windows" (see YuiActionBase.qml).
import QtQml 2.12

YuiActionBase {
    title: qsTr("Windows")
    allCommands: [{
            "id": "cardinal",
            "name": qsTr("Cardinal System")
        }, {
            "id": "equipment",
            "name": qsTr("Equipment")
        }, {
            "id": "heart",
            "name": qsTr("Yui's Heart")
        }, {
            "id": "counseling",
            "name": qsTr("Mental Health Counseling")
        }, {
            "id": "console",
            "name": qsTr("System Console")
        }, {
            "id": "skills",
            "name": qsTr("Skill Slots"),
            "tool": true
        }]
}
