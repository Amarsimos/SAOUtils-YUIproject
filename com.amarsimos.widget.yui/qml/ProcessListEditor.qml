import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// An editable list of process names (Option window): each name is a chip with a remove button,
// and new names are typed below. fixedNames are shown first, locked (no remove button).
ColumnLayout {
    id: editor

    property var names: []
    property var fixedNames: []
    property string emptyText: ""

    // The new list, cleaned by Yui.processList() ("x" -> "x.exe", lower case, no duplicates); the
    // handler saves it, and the chips show it right away.
    signal edited(var list)

    function setNames(list) {
        editor.edited(list);
        editor.names = list;
    }

    function add() {
        var name = Yui.processName(input.text);
        if (!name)
            return ;

        setNames(Yui.processList(editor.names.concat([name])));
        input.clear();
    }

    spacing: 6

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: editor.fixedNames.map(function(name) {
                return {
                    "name": name,
                    "fixed": true
                };
            }).concat(Yui.processList(editor.names).map(function(name) {
                return {
                    "name": name,
                    "fixed": false
                };
            }))

            Rectangle {
                height: 26
                width: chipRow.implicitWidth + 16
                radius: 13
                color: modelData.fixed ? "transparent" : "#F59B00"
                border.width: modelData.fixed ? 1 : 0
                border.color: "#88888888"

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: 4

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (modelData.fixed ? "🔒 " : "") + modelData.name
                        color: modelData.fixed ? palette.windowText : "#FFFFFF"
                        font.pixelSize: 12
                    }

                    Label {
                        visible: !modelData.fixed
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        color: "#FFFFFF"
                        font.pixelSize: 12

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: editor.setNames(Yui.processList(editor.names).filter(function(name) {
                                return name !== modelData.name;
                            }))
                        }

                    }

                }

            }

        }

    }

    Label {
        visible: editor.fixedNames.length === 0 && Yui.processList(editor.names).length === 0
        text: editor.emptyText
        opacity: 0.6
        font.pixelSize: 12
    }

    RowLayout {
        Layout.fillWidth: true

        TextField {
            id: input

            Layout.fillWidth: true
            selectByMouse: true
            placeholderText: "notepad.exe"
            onAccepted: editor.add()
        }

        Button {
            text: qsTr("Add")
            enabled: Yui.processName(input.text) !== ""
            onClicked: editor.add()
        }

    }

}
