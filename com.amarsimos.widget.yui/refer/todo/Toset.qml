import QtQuick 2.12

import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import NERvGear 1.0 as NVG
import NERvGear.Preferences 1.0 as P


NVG.Window {
    id: window
    title: qsTr("Edit Item")
    visible: true
    minimumWidth: 300
    minimumHeight: 300
    width: minimumWidth
    height: minimumHeight

    transientParent: widget.NVG.View.window

    property int index: -1

    function load(cfg, _index) {
        if (_index > -1) {
            rootPreference.load(cfg);
            index = _index;
        }
    }

    function save(index) {
        return rootPreference.save();
    }

    ColumnLayout {
        id: root
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 0

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            contentWidth: preferenceLayout.implicitWidth
            contentHeight: preferenceLayout.implicitHeight

            ColumnLayout {
                id: preferenceLayout
                width: root.width

                P.PreferenceGroup {
                    id: rootPreference
                    Layout.fillWidth: true

                    P.TextFieldPreference {
                        id: _cfg_todo_content
                        name: "todo"
                        label: qsTr("Content")
                        display: P.TextFieldPreference.ExpandControl
                    }

                    P.SelectPreference {
                        name: "priority"
                        label: qsTr("Priority")

                        defaultValue: 1
                        model: [ "Low", "Normal", "Medium", "High" ]
                    }
                }
            }
        }

        ItemDelegate {
            Layout.fillWidth: true
            enabled: Boolean(_cfg_todo_content.value)

            Label {
                anchors.centerIn: parent
                text: "Save"
                font.weight: Font.DemiBold
            }

            onClicked: {
                let cfg = rootPreference.save();
                if (cfg.todo.length > 0) {
                    if (index > -1) {
                        todoModel.set(index, {"todo": cfg.todo, "priority": cfg.priority});
                        let _data = widget.settings.data;
                        _data[index].todo = cfg.todo;
                        _data[index].priority = cfg.priority;
                        widget.settings.data = _data;
                    } else {
                        let _time = new Date();
                        let _cfg = {
                            "todo": cfg.todo, "priority": cfg.priority, "done": false, "createTime": _time.getTime()+_time.getMilliseconds()
                        };
                        todoModel.append(_cfg);
                        widget.settings.data = widget.settings.data.concat(_cfg);
                    }
                    dialog.active = false;
                    sortData();
                }
            }
        }
    }



    onClosing: {
        dialog.active = false;
    }
}
