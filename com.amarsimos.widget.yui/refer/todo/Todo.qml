import QtQml.Models 2.3

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12

import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import NERvGear.Preferences 1.0 as P

WidgetTemplate {
    id: widget

    editing: dialog.active

    action: T.Action {
        id: thiz

        title: qsTr("Todo List Action")
        description: title

        execute: function () {
            return new Promise(function (resolve, reject) {
                dialog.active = true;
                resolve();
            });
        }

        preference: P.SelectPreference {
            label: qsTr("Command")
            model: [ qsTr("New Item") ]
            defaultValue: 0
            load: function () {}
            save: function () {}
        }
    }

    version: "1.0.2"
    defaultValues: {
        "Index Settings":
        {
            "Text": "Todo",
            "Font Style": fonts.length - 1,
            "Font Size": 30,
            "Font Weight": 1,
            "Color": "#f5f5f5",
            "Shadow Color": "#f5f5f5",
            "Shadow Size": 0,
            "X Offset": 0
        },
        "Content Settings":
        {
            "Font Style": fonts.length - 1,
            "Font Size": 24,
            "Font Weight": 1,
            "Todo Color": "#fffcf9",
            "Done Color": "#616161",
            "Shadow Color": "#f5f5f5",
            "Shadow Size": 0,
            "Show Priority Flag": true,
            "Priority Low Color": "#00ff00",
            "Priority Normal Color": "#ffffff",
            "Priority Medium Color": "#f2ff00",
            "Priority High Color": "#ff0000",
            "Button Color": "#fffcf9",
            "X Offset": 0,
            "Y Offset": 0
        },
        "Hover Color": "#9e9e9e",
        "Confirm Before Delete": true
    }

    onCompleted: {
        widget.settings.index_font_style = widget.settings.index_font_style ?? "";
        let _i = fonts.indexOf(widget.settings.index_font_style);
        if (_i === -1) {
            widget.settings.index_font_style = fonts[widget.settings.styles["Index Settings"]["Font Style"]];
        } else {
             widget.settings.styles["Index Settings"]["Font Style"] = _i;
        }
        widget.settings.content_font_style = widget.settings.content_font_style ?? "";
        _i = fonts.indexOf(widget.settings.index_font_style);
        if (_i === -1) {
            widget.settings.content_font_style = fonts[widget.settings.styles["Content Settings"]["Font Style"]];
        } else {
             widget.settings.styles["Content Settings"]["Font Style"] = _i;
        }
        widget.settings.view = widget.settings.view ?? 0;
        widget.settings.auto_sort = widget.settings.auto_sort ?? true;
        widget.settings.reversed_by_time = widget.settings.reversed_by_time ?? false;
        if(widget.settings.data) {
            sortData();
        }
        else
            widget.settings.data = [];
    }


    readonly property var fonts: Qt.fontFamilies()
    readonly property var fontweight: [Font.Light, Font.Normal, Font.Bold]
    readonly property var sfontweight: [qsTr("Light"), qsTr("Normal"), qsTr("Bold")]

    readonly property var configs: widget.settings.styles

    readonly property var priority_colors: [configs["Content Settings"]["Priority Low Color"], configs["Content Settings"]["Priority Normal Color"], configs["Content Settings"]["Priority Medium Color"], configs["Content Settings"]["Priority High Color"]]

    menu: Menu {
        Action {
            id: action_all
            text: qsTr("All")
            checkable: true
            checked: widget.settings.view === 0
            onTriggered: {
                if(checked) {
                    widget.settings.view = 0;
                    if (action_todo.checked) action_todo.checked = false;
                    if (action_done.checked) action_done.checked = false;
                } else {
                    checked = true;
                }
            }
        }

        Action {
            id: action_todo
            text: qsTr("Todo")
            checkable: true
            checked: widget.settings.view === 1
            onTriggered: {
                if(checked) {
                    widget.settings.view = 1;
                    if (action_all.checked) action_all.checked = false;
                    if (action_done.checked) action_done.checked = false;
                } else {
                    checked = true;
                }
            }
        }

        Action {
            id: action_done
            text: qsTr("Done")
            checkable: true
            checked: widget.settings.view === 2
            onTriggered: {
                if(checked) {
                    widget.settings.view = 2;
                    if (action_todo.checked) action_todo.checked = false;
                    if (action_all.checked) action_all.checked = false;
                } else {
                    checked = true;
                }
            }
        }

        Action {
            id: auto_sort
            text: qsTr("Auto Sort")
            checkable: true
            checked: widget.settings.auto_sort ?? true
            onTriggered: {
                sortData();
                widget.settings.auto_sort = checked;
            }
        }

        Action {
            id: reversed_by_time
            text: qsTr("Reversed by Time")
            checkable: true
            checked: widget.settings.reversed_by_time ?? false
            onTriggered: {
                sortData();
                widget.settings.reversed_by_time = checked;
            }
        }

        Action {
            text: qsTr("Settings") + "..."
            enabled: !styleDialog.active
            onTriggered: {
                styleDialog.active = true;
            }
        }
    }

    function sortData() {
        if(widget.settings.data) {
            todoModel.clear();
            if (auto_sort.checked) {
                if (reversed_by_time.checked) {
                    widget.settings.data.sort(function (x, y) {
                        if (x.priority < y.priority)
                            return 1;
                        else if(x.priority > y.priority)
                            return -1;
                        else {
                            if (x.createTime < y.createTime)
                                return 1;
                            else if(x.createTime > y.createTime)
                                return -1;
                            else
                                return 0
                        }
                    });
                } else {
                    widget.settings.data.sort(function (x, y) {
                        if (x.priority < y.priority)
                            return 1;
                        else if(x.priority > y.priority)
                            return -1;
                        else {
                            if (x.createTime < y.createTime)
                                return -1;
                            else if(x.createTime > y.createTime)
                                return 1;
                            else
                                return 0
                        }
                    });
                }
            } else {
                if (reversed_by_time.checked) {
                    widget.settings.data.sort(function (x, y) {
                        if (x.createTime < y.createTime)
                            return 1;
                        else if(x.createTime > y.createTime)
                            return -1;
                        else
                            return 0
                    });
                } else {
                    widget.settings.data.sort(function (x, y) {
                        if (x.createTime < y.createTime)
                            return -1;
                        else if(x.createTime > y.createTime)
                            return 1;
                        else
                            return 0
                    });
                }
            }

            widget.settings.data.forEach((each)=>{
                todoModel.append(each);
            });
        }
    }

    Loader {
        id: styleDialog
        active: false
        sourceComponent: StyleCFG {}
    }

    Item {
        id: todo_btn
        anchors.left: parent.left
        anchors.leftMargin: (widget.width - width)*configs["Index Settings"]["X Offset"]/100
        width: todo_btn_text.width
        height: todo_btn_text.height
        Text {
            id: todo_btn_text
            text: configs["Index Settings"]["Text"] ? configs["Index Settings"]["Text"] : "Todo"

            style: Text.Outline
            styleColor: "transparent"

            font.pointSize: configs["Index Settings"]["Font Size"]
            font.family: fonts[configs["Index Settings"]["Font Style"]]
            font.weight: fontweight[configs["Index Settings"]["Font Weight"]]
            font.bold: true
            font.underline: false
            anchors.leftMargin: 24
            color: configs["Index Settings"]["Color"]
            layer.enabled: Boolean(configs["Index Settings"]["Shadow Size"])
            layer.effect: Glow {
                color: configs["Index Settings"]["Shadow Color"]
                samples: todo_btn_text.height*configs["Index Settings"]["Shadow Size"]/200
                spread: 0
            }
            Rectangle {
                anchors.fill: parent
                id: bg
                color: configs["Hover Color"]
                radius: 5
                opacity: 0
                Behavior on opacity {
                    PropertyAnimation {
                        duration: 100
                    }
                }
                MouseArea {
                    anchors.fill: bg
                    onEntered: bg.opacity = 0.4
                    onExited: bg.opacity = 0.0
                    hoverEnabled: true
                    z: -1
                    onClicked: {
                        dialog.active = true;
                    }
                }
            }
        }
    }

    Loader {
        id: dialog
        active: false
        sourceComponent: Toset { }

        property var callback: (()=>{})

        onLoaded: {
            callback();
            callback = (()=>{});
        }
    }

    DelegateModel {
        id: filterModel

        model: ListModel {
            id: todoModel
            onCountChanged: filterModel.setGroups()
        }

        filterOnGroup: ["","todo","done"][widget.settings.view]

        groups: [
            DelegateModelGroup {
                name: "todo"
                includeByDefault: true
            },
            DelegateModelGroup {
                name: "done"
            }]

        delegate: Item {
            id: item
            height: todo_text.height
            width: widget.width
            Item {
                width: widget.width
                height: item.height
                anchors.left: parent.left
                Rectangle {
                    id: highlight_bg
                    anchors.fill: parent
                    color: configs["Hover Color"]
                    radius: 5
                    opacity: 0
                    Behavior on opacity {
                        PropertyAnimation {
                            duration: 100
                        }
                    }
                }
                Text {
                    id: todo_text
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: widget.width*configs["Content Settings"]["X Offset"]/100
                    font.pixelSize: configs["Content Settings"]["Font Size"]
                    textFormat: Text.RichText
                    text: (configs["Content Settings"]["Show Priority Flag"] ? "<font color='" + priority_colors[priority] + "'>·</font>" : "") + (done ? "<s>"+todo+"</s>" : todo)
                    color: done ? configs["Content Settings"]["Done Color"] : configs["Content Settings"]["Todo Color"]
                    font.bold: true
                    font.underline: false
                    font.family: fonts[configs["Content Settings"]["Font Style"]]
                    font.weight: fontweight[configs["Content Settings"]["Font Weight"]]

                    style: Text.Outline
                    styleColor: "transparent"

                    layer.enabled: Boolean(configs["Content Settings"]["Shadow Size"])
                    layer.effect: Glow {
                        color: configs["Content Settings"]["Shadow Color"]
                        samples: todo_text.height*configs["Content Settings"]["Shadow Size"]/200
                        spread: 0
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onEntered: {
                        highlight_bg.opacity = 0.4;
                        utils.opacity = 1;
                    }
                    onExited: {
                        highlight_bg.opacity = 0.0;
                        utils.opacity = 0;
                    }
                    hoverEnabled: true
                    onClicked: {
                        done = !done;
                        item.DelegateModel.inTodo = !done;
                        item.DelegateModel.inDone = done;
                        widget.settings.data[index].done = done;
                    }
                }
            }

            Item {
                id: utils
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                width: 0.2 * widget.width
                height: item.height
                opacity: 0
                Behavior on opacity {
                    PropertyAnimation {
                        duration: 100
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onEntered: {
                        highlight_bg.opacity = 0.4;
                        utils.opacity = 1;
                    }
                    onExited: {
                        highlight_bg.opacity = 0.0;
                        utils.opacity = 0;
                    }
                    hoverEnabled: true
                    z: -1
                }
                Button {
                    id: edit
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    width: 0.1 * widget.width
                    height: item.height

                    contentItem: Item {}
                    background: Text {
                        anchors.centerIn: parent
                        font.pointSize: 12
                        text: "☰"
                        color: configs["Content Settings"]["Button Color"]
                        layer.enabled: Boolean(configs["Content Settings"]["Shadow Size"])
                        layer.effect: Glow {
                            color: configs["Content Settings"]["Shadow Color"]
                            samples: todo_text.height*configs["Content Settings"]["Shadow Size"]/200
                            spread: 0
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }
                    }
                    onClicked: {
                        dialog.callback = (()=>{
                            dialog.item.load(todoModel.get(index), index);
                        });
                        dialog.active = true;
                    }
                }
                Button {
                    id: cross
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    width: 0.1 * widget.width
                    height: item.height

                    contentItem: Item {}
                    background: Text {
                        anchors.centerIn: parent
                        font.pointSize: 16
                        text: "✖"
                        color: configs["Content Settings"]["Button Color"]
                        layer.enabled: Boolean(configs["Content Settings"]["Shadow Size"])
                        layer.effect: Glow {
                            color: configs["Content Settings"]["Shadow Color"]
                            samples: todo_text.height*configs["Content Settings"]["Shadow Size"]/200
                            spread: 0
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }
                    }
                    onClicked: {
                        if (configs["Confirm Before Delete"]) {
                            comfirmDialog.index = index;
                            comfirmDialog.open();
                        } else {
                            todoModel.remove(index);
                            let data = widget.settings.data;
                            data.pop(index);
                            widget.settings.data = data;
                        }
                    }
                }
            }
        }

        function setGroups() {
            var newItem = todoModel.get(todoModel.count - 1)
            if (!newItem) return;
            var groups;
            if (newItem.done){
                groups = ['items', 'done'];
            }else{
                groups = ['items', 'todo'];
            }
            items.setGroups(todoModel.count - 1, 1, groups)
        }
    }

    Dialog {
        id: comfirmDialog
        title: qsTr("Warning")
        anchors.centerIn: parent

        property int index: -1

        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        contentItem: Label {
            text: qsTr("Are you sure you want to delete?")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        onAccepted: {
            todoModel.remove(index);
            let data = widget.settings.data;
            data.pop(index);
            widget.settings.data = data;
        }
    }

    ListView {
        anchors.fill: parent
        anchors.topMargin: todo_btn.height + (widget.height-todo_btn.height)*configs["Content Settings"]["Y Offset"]/100
        clip: true
        model: filterModel
        height: widget.height
        width: widget.width
        anchors.margins: 0
        spacing: 0
    }
}
