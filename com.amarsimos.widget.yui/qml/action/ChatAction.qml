// MHCP-YUI action category "Chat" (see YuiActionBase.qml).
import QtQml 2.12

YuiActionBase {
    title: qsTr("Chat")
    commands: [{
            "id": "chat",
            "name": qsTr("Open Chat"),
            "uses": ["text"],
            "hint": qsTr("Sent to Yui when the chat opens (optional)")
        }, {
            "id": "speak",
            "name": qsTr("Spontaneous Talk")
        }]
}
