import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// Yui's Heart (YuisHeart.qml window): the heart core (sent with every request) and the memory
// fragments (recalled when they match the conversation). Memories can be added, and every memory
// can be edited, deleted, pinned (core only: never moved out of a full core) and moved between core
// and fragments.
ColumnLayout {
    id: page

    property var yui
    // Lower-case text a memory must contain to be listed ("" lists all).
    property string filter: ""
    // id of the memory being edited, or -1.
    property int editingId: -1
    property string message: ""

    readonly property var core: Yui.coreMemories(yui.heartCache)
    readonly property var fragments: yui.heartCache.filter(function(entry) {
        return entry.kind !== "core";
    }).sort(function(x, y) {
        return (y.lastUsed || 0) - (x.lastUsed || 0);
    })

    function shown(entries) {
        return entries.filter(function(entry) {
            return !page.filter || entry.text.toLowerCase().indexOf(page.filter) !== -1;
        });
    }

    function change(id, changes) {
        page.message = yui.changeMemory(id, changes) ? "" : qsTr("The heart core is full (%1). Move a memory out of it first.").arg(yui.heartCoreCapacity);
    }

    function add() {
        var kind = addKind.currentIndex === 1 ? "core" : "fragment";
        if (yui.addMemory(addText.text, kind)) {
            addText.text = "";
            page.message = "";
        } else if (addText.text.trim()) {
            page.message = qsTr("The heart core is full (%1). Move a memory out of it first.").arg(yui.heartCoreCapacity);
        }
    }

    // Deleting asks first, in SAO Utils' message box.
    function remove(entry) {
        NVG.SystemCall.messageBox({
            "title": qsTr("Yui's Heart"),
            "text": qsTr("Delete this memory?") + "\n" + entry.text,
            "modal": true
        }).then(function(result) {
            if (result !== false && result !== 0)
                yui.deleteMemory(entry.id);

        });
    }

    spacing: 8

    Label {
        text: "♥ " + qsTr("Yui's Heart") + "  (" + yui.heartCache.length + ")"
        font.pixelSize: 13
        font.bold: true
    }

    // A new memory, as a fragment or in the heart core.
    RowLayout {
        Layout.fillWidth: true

        TextField {
            id: addText

            Layout.fillWidth: true
            selectByMouse: true
            placeholderText: qsTr("Something Yui should remember")
            onAccepted: page.add()
        }

        ComboBox {
            id: addKind

            model: [qsTr("Fragment"), qsTr("Heart Core")]
        }

        Button {
            text: qsTr("Add")
            enabled: addText.text.trim() !== ""
            onClicked: page.add()
        }

    }

    TextField {
        Layout.fillWidth: true
        selectByMouse: true
        placeholderText: qsTr("Search memories")
        onTextChanged: page.filter = text.trim().toLowerCase()
    }

    Label {
        visible: page.message !== ""
        Layout.fillWidth: true
        text: page.message
        color: "#D48800"
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    ListView {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        // Section headers are rows of their own ({header: "core" | "fragment"}).
        model: [{
            "header": "core"
        }].concat(page.shown(page.core), [{
            "header": "fragment"
        }], page.shown(page.fragments))

        ScrollBar.vertical: SaoScrollBar {
        }

        delegate: Column {
            id: row

            readonly property var memory: modelData
            readonly property bool editing: !memory.header && page.editingId === memory.id
            readonly property bool isCore: memory.kind === "core"

            function act(action) {
                if (action === "edit") {
                    page.editingId = memory.id;
                    editor.text = memory.text;
                    editor.forceActiveFocus();
                } else if (action === "save") {
                    page.change(memory.id, {
                        "text": editor.text
                    });
                    page.editingId = -1;
                } else if (action === "cancel") {
                    page.editingId = -1;
                } else if (action === "pin") {
                    page.change(memory.id, {
                        "pinned": !memory.pinned
                    });
                } else if (action === "core" || action === "fragment") {
                    page.change(memory.id, {
                        "kind": action
                    });
                } else if (action === "delete") {
                    page.remove(memory);
                }
            }

            width: list.width - 12
            spacing: 3

            Text {
                visible: !!row.memory.header
                width: parent.width
                topPadding: 6
                text: row.memory.header === "core" ? "◆ " + qsTr("Heart Core") + "  " + page.core.length + " / " + page.yui.heartCoreCapacity : "· " + qsTr("Memory Fragments") + "  " + page.fragments.length
                color: "#F59B00"
                font.pixelSize: 12
                font.bold: true
            }

            Label {
                visible: !row.memory.header && !row.editing
                width: parent.width
                text: (row.memory.pinned ? "📌 " : "") + (row.memory.text || "")
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            TextField {
                id: editor

                visible: row.editing
                width: parent.width
                selectByMouse: true
                onAccepted: row.act("save")
            }

            // Small text buttons under each memory.
            Row {
                visible: !row.memory.header
                spacing: 12

                Repeater {
                    model: row.editing ? [[qsTr("Save"), "save"], [qsTr("Cancel"), "cancel"]] : [[qsTr("Edit"), "edit"]].concat(row.isCore ? [[row.memory.pinned ? qsTr("Unpin") : qsTr("Pin"), "pin"], [qsTr("To Fragments"), "fragment"]] : [[qsTr("To Core"), "core"]], [[qsTr("Delete"), "delete"]])

                    Label {
                        text: modelData[0]
                        color: buttonMouse.containsMouse ? "#F59B00" : palette.windowText
                        opacity: buttonMouse.containsMouse ? 1 : 0.6
                        font.pixelSize: 11

                        MouseArea {
                            id: buttonMouse

                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: row.act(modelData[1])
                        }

                    }

                }

            }

        }

    }

    Label {
        visible: yui.heartCache.length === 0
        text: qsTr("No memories yet")
        opacity: 0.6
        font.pixelSize: 12
    }

}
