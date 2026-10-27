import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// Yui's Heart (YuisHeart.qml window): the heart core (sent with every request) and the memory
// fragments (recalled when they match the conversation). From the top: Through Yui's Eyes (what she
// makes of the user, folded to three lines), the core / fragments switch with the search, the
// memories as cards (orange stripe: core, grey: fragment; edit, pin (core only: never moved out of a
// full core), move between core and fragments and delete appear on hover), and adding a memory at
// the bottom, always in reach. Cards and small buttons are SAO Utils' own (Card, SmallButton with
// Font Awesome icons), so they follow its theme.
ColumnLayout {
    id: page

    property var yui
    // Lower-case text a memory must contain to be listed ("" lists all).
    property string filter: ""
    // id of the memory being edited, or -1.
    property int editingId: -1
    property string message: ""
    // The cards shown: 0 heart core, 1 fragments.
    property int tab: 0
    property bool portraitOpen: false

    readonly property color orange: "#F59B00"
    readonly property color line: "#E3E3E3"
    readonly property color muted: "#8A8A8A"
    readonly property var portrait: yui.settings.heart_portrait || null
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
        var kind = addKind.currentIndex === 0 ? "core" : "fragment";
        if (yui.addMemory(addText.text, kind)) {
            addText.text = "";
            page.message = "";
            page.tab = kind === "core" ? 0 : 1;
        } else if (addText.text.trim()) {
            page.message = qsTr("The heart core is full (%1). Move a memory out of it first.").arg(yui.heartCoreCapacity);
        }
    }

    // Deleting asks first, in SAO Utils' message box with the system alert sound.
    function remove(entry) {
        yui.askConfirm(qsTr("Yui's Heart"), qsTr("Delete this memory?") + "\n" + entry.text, function() {
            yui.deleteMemory(entry.id);
        }, true);
    }

    // "10-12 记下 · 想起过 34 次"-style line under a memory.
    function details(entry) {
        var parts = [];
        if (entry.created)
            parts.push(qsTr("noted %1").arg(Qt.formatDate(new Date(entry.created), "MM-dd")));

        if (entry.uses > 0)
            parts.push(qsTr("recalled %1 times").arg(entry.uses));

        return parts.join("  ·  ");
    }

    spacing: 10

    // ---------------------------------------------------------------- Through Yui's Eyes
    Card {
        id: portraitCard

        Layout.fillWidth: true

        RowLayout {
            anchors.fill: parent
            spacing: 10

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 4
                radius: 2
                color: page.orange
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        text: "“ " + qsTr("Through Yui's Eyes")
                        font.pixelSize: 13
                        font.bold: true
                    }

                    // Folded to three lines; the whole text when open.
                    SmallButton {
                        visible: !!(page.portrait && page.portrait.text)
                        icon.name: page.portraitOpen ? "regular:" : "regular:"
                        ToolTip.visible: hovered
                        ToolTip.text: page.portraitOpen ? qsTr("Fold") : qsTr("Unfold")
                        onClicked: page.portraitOpen = !page.portraitOpen
                    }

                }

                // Read-only but selectable, so a part can be copied.
                TextEdit {
                    Layout.fillWidth: true
                    // Three lines while folded (TextEdit has no maximumLineCount).
                    Layout.maximumHeight: page.portraitOpen ? -1 : 3 * (font.pixelSize * 1.5) + 2
                    visible: !!(page.portrait && page.portrait.text)
                    clip: true
                    readOnly: true
                    selectByMouse: true
                    wrapMode: Text.Wrap
                    color: portraitCard.palette.windowText
                    selectionColor: page.orange
                    font.pixelSize: 12
                    text: page.portrait ? page.portrait.text : ""
                }

                Label {
                    Layout.fillWidth: true
                    visible: !(page.portrait && page.portrait.text)
                    wrapMode: Text.Wrap
                    opacity: 0.7
                    font.pixelSize: 12
                    text: page.yui.heartCache.length > 0 ? qsTr("Ask Yui what she makes of you from her memories.") : qsTr("No memories yet: chat with Yui a little first.")
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 6

                    Label {
                        visible: !!page.portrait
                        opacity: 0.6
                        font.pixelSize: 11
                        text: page.portrait ? Qt.formatDateTime(new Date(page.portrait.created), "yyyy-MM-dd HH:mm") : ""
                    }

                    SmallButton {
                        enabled: !page.yui.writingPortrait && page.yui.heartCache.length > 0
                        icon.name: "regular:"
                        display: AbstractButton.TextBesideIcon
                        text: page.yui.writingPortrait ? qsTr("Writing...") : (page.portrait ? qsTr("Ask Again") : qsTr("Hear from Yui"))
                        onClicked: page.yui.writePortrait(function(error) {
                            page.message = error;
                        })
                    }

                }

            }

        }

    }

    // ---------------------------------------------------------------- core / fragments and search
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: [["◆  " + qsTr("Heart Core"), page.core.length + " / " + page.yui.heartCoreCapacity], ["●  " + qsTr("Fragments"), String(page.fragments.length)]]

            Rectangle {
                readonly property bool active: index === page.tab

                implicitWidth: tabLabel.implicitWidth + 24
                implicitHeight: 30
                radius: 15
                color: active ? page.orange : (tabMouse.containsMouse ? "#33F59B00" : "transparent")
                border.color: active ? page.orange : page.line

                Label {
                    id: tabLabel

                    anchors.centerIn: parent
                    text: modelData[0] + "   " + modelData[1]
                    color: parent.active ? "#FFFFFF" : palette.windowText
                    font.pixelSize: 12
                    font.bold: parent.active
                }

                MouseArea {
                    id: tabMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        page.tab = index;
                        page.editingId = -1;
                    }
                }

            }

        }

        TextField {
            Layout.fillWidth: true
            Layout.minimumWidth: 100
            selectByMouse: true
            placeholderText: qsTr("Search memories")
            onTextChanged: page.filter = text.trim().toLowerCase()
        }

    }

    Label {
        Layout.fillWidth: true
        visible: page.message !== ""
        text: page.message
        color: "#D48800"
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    // ---------------------------------------------------------------- the memories
    ListView {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: page.shown(page.tab === 0 ? page.core : page.fragments)

        ScrollBar.vertical: SaoScrollBar {
        }

        // An empty tab says why.
        Label {
            anchors.centerIn: parent
            width: parent.width - 40
            visible: list.count === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            opacity: 0.6
            font.pixelSize: 12
            text: page.filter ? qsTr("No memory contains this.") : (page.tab === 0 ? qsTr("The heart core is empty: what matters most about you goes here.") : qsTr("No memory fragments yet: chat with Yui and she will remember."))
        }

        delegate: Card {
            id: card

            readonly property var memory: modelData
            readonly property bool isCore: memory.kind === "core"
            readonly property bool editing: page.editingId === memory.id
            readonly property bool active: hover.hovered || editing

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
                } else if (action === "move") {
                    page.change(memory.id, {
                        "kind": isCore ? "fragment" : "core"
                    });
                } else if (action === "delete") {
                    page.remove(memory);
                }
            }

            width: list.width - 12

            HoverHandler {
                id: hover
            }

            RowLayout {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: 4
                    radius: 2
                    color: card.isCore ? page.orange : "#C4C4C4"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        Layout.fillWidth: true
                        visible: !card.editing
                        text: (card.memory.pinned ? "📌 " : "") + (card.memory.text || "")
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }

                    // Several lines, for long memories; Ctrl+Enter saves, Esc cancels.
                    TextArea {
                        id: editor

                        Layout.fillWidth: true
                        visible: card.editing
                        selectByMouse: true
                        wrapMode: Text.Wrap
                        font.pixelSize: 13
                        Keys.onReturnPressed: {
                            if (event.modifiers & Qt.ControlModifier)
                                card.act("save");
                            else
                                event.accepted = false;
                        }
                        Keys.onEscapePressed: card.act("cancel")
                    }

                    Label {
                        visible: !card.editing && text !== ""
                        text: page.details(card.memory)
                        opacity: 0.6
                        font.pixelSize: 10
                    }

                }

                // Edit, pin (core only), move to the other side, delete: on hover; save / cancel while
                // editing. Font Awesome icons: pen, thumbtack, exchange, times; check, undo.
                Row {
                    Layout.alignment: Qt.AlignTop
                    // Keeps its room, so the text does not jump when the buttons appear.
                    opacity: card.active ? 1 : 0
                    enabled: card.active
                    spacing: 2

                    Repeater {
                        model: card.editing ? [["", "save", qsTr("Save")], ["", "cancel", qsTr("Cancel")]] : [["", "edit", qsTr("Edit")]].concat(card.isCore ? [["", "pin", card.memory.pinned ? qsTr("Unpin") : qsTr("Pin")]] : [], [["", "move", card.isCore ? qsTr("To Fragments") : qsTr("To Core")], ["", "delete", qsTr("Delete")]])

                        SmallButton {
                            icon.name: (modelData[1] === "pin" && card.memory.pinned ? "solid:" : "regular:") + modelData[0]
                            icon.color: modelData[1] === "delete" ? "#E53935" : page.orange
                            ToolTip.visible: hovered
                            ToolTip.text: modelData[2]
                            onClicked: card.act(modelData[1])
                        }

                    }

                }

            }

        }

    }

    // ---------------------------------------------------------------- adding, always at the bottom
    Card {
        Layout.fillWidth: true

        RowLayout {
            anchors.fill: parent
            spacing: 6

            TextField {
                id: addText

                Layout.fillWidth: true
                selectByMouse: true
                placeholderText: "＋  " + qsTr("Something Yui should remember")
                onAccepted: page.add()
            }

            ComboBox {
                id: addKind

                currentIndex: page.tab
                model: [qsTr("Heart Core"), qsTr("Fragment")]
            }

            Button {
                highlighted: true
                text: qsTr("Add")
                enabled: addText.text.trim() !== ""
                onClicked: page.add()
            }

        }

    }

}
