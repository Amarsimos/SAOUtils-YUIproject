import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// System Console, Memories (as the preview; moved from Yui's Heart). Three chips choose:
// - Memories: Through Yui's Eyes (what she makes of you, folded to three lines, Unfold / Ask Again),
//   then the heart core or the fragments (a switch in the header, with the search), the core's
//   capacity as a HUD bar, the memories (orange stripe: core, grey: fragment; on hover Edit, Pin (core
//   only), To Fragments / To Core and Forget; editing in place with Save / Cancel) and a row to add one.
// - Follow-ups: the memories about a day to come, a date box (orange today, faded once past), what Yui
//   does about it as a tag (to cheer on, cheered on, to ask, asked) and Remove.
// - Recollection Log: searching the chat history, the words found in orange.
// What is remembered, the transfer, backups and forgetting everything stay in Yui's Heart.
ColumnLayout {
    id: memories

    property var yui
    property int tab: 0
    // Memories: 0 heart core, 1 fragments; the search (lower case); the memory being edited (-1: none).
    property int side: 0
    property string filter: ""
    property int editingId: -1
    property string message: ""
    property bool portraitOpen: false
    readonly property var portrait: yui.settings.heart_portrait || null
    readonly property var core: Yui.coreMemories(yui.heartCache)
    readonly property var fragments: yui.heartCache.filter(function(entry) {
        return entry.kind !== "core";
    }).sort(function(x, y) {
        return (y.lastUsed || 0) - (x.lastUsed || 0);
    })
    readonly property var shown: (side === 0 ? core : fragments).filter(function(entry) {
        return !filter || entry.text.toLowerCase().indexOf(filter) !== -1;
    })
    // Follow-ups: the memories about a day to come, soonest first.
    property var followupItems: []
    // Recollection Log: how many messages it keeps, and the messages found (newest first, at most 50).
    property int logSize: 0
    property var logResults: []
    property string logQuery: ""

    function change(id, changes) {
        message = yui.changeMemory(id, changes) ? "" : qsTr("The heart core is full (%1). Move a memory out of it first.").arg(yui.heartCoreCapacity);
    }

    function add(text, kind) {
        if (yui.addMemory(text, kind)) {
            message = "";
            side = kind === "core" ? 0 : 1;
            return true;
        }
        if (text.trim())
            message = qsTr("The heart core is full (%1). Move a memory out of it first.").arg(yui.heartCoreCapacity);

        return false;
    }

    // Forgetting asks first, in SAO Utils' message box with the system alert sound.
    function remove(entry) {
        yui.askConfirm(qsTr("Yui's Heart"), qsTr("Delete this memory?") + "\n" + entry.text, function() {
            yui.deleteMemory(entry.id);
        }, true);
    }

    // "10-12 noted · recalled 34 times".
    function details(entry) {
        var parts = [];
        if (entry.created)
            parts.push(qsTr("noted %1").arg(Qt.formatDate(new Date(entry.created), "MM-dd")));

        if (entry.uses > 0)
            parts.push(qsTr("recalled %1 times").arg(entry.uses));

        return parts.join("  ·  ");
    }

    function refreshFollowups() {
        followupItems = yui.followupList(Date.now());
    }

    // Under the date: how far the day is.
    function followupWhen(item) {
        if (item.phase === "ahead")
            return item.days === 1 ? qsTr("Tomorrow") : qsTr("In %1 days").arg(item.days);

        if (item.phase === "today")
            return qsTr("Today");

        return item.days === -1 ? qsTr("Yesterday") : qsTr("%1 days ago").arg(-item.days);
    }

    // What Yui does about it: [tag text, color]. Before and on the day she cheers you on, after it she
    // asks how it went.
    function followupStage(item) {
        if (item.phase === "after")
            return item.stage === "asked" ? [qsTr("Asked"), "#9A9A9A"] : [qsTr("To ask"), "#C82864"];

        if (item.phase === "today" && item.stage)
            return [qsTr("Cheered on"), "#F1AA03"];

        return [qsTr("To cheer on"), "#4BB4EC"];
    }

    function searchLog(text) {
        logQuery = text.trim();
        logResults = logQuery ? yui.searchMessageLog(logQuery, 50) : [];
    }

    // A log line with the words searched for in orange (rich text, the rest escaped).
    function marked(line) {
        var escape = function(text) {
            return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        };
        if (!logQuery)
            return escape(line);

        var lower = line.toLowerCase(), query = logQuery.toLowerCase(), out = "", from = 0, at;
        while ((at = lower.indexOf(query, from)) !== -1) {
            out += escape(line.slice(from, at)) + "<b><font color=\"#D48800\">" + escape(line.slice(at, at + query.length)) + "</font></b>";
            from = at + query.length;
        }
        return out + escape(line.slice(from));
    }

    spacing: 12
    onTabChanged: {
        if (tab === 1)
            refreshFollowups();

        if (tab === 2)
            logSize = yui.messageLogCount();

    }

    Connections {
        target: memories.yui
        onFollowupsChanged: memories.refreshFollowups()
    }

    Row {
        spacing: 8

        Repeater {
            model: ["Memories", "Follow-ups", "Recollection Log"]

            ConsoleChip {
                text: modelData
                checked: memories.tab === index
                onClicked: memories.tab = index
            }

        }

    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        currentIndex: memories.tab

        // ---------------------------------------------------------------- Memories
        ConsolePage {
            // Through Yui's Eyes: an orange stripe at the left, a quote mark, three lines while folded.
            ConsolePanel {
                Layout.fillWidth: true
                title: "Through Yui's Eyes"
                note: memories.portrait ? Qt.formatDateTime(new Date(memories.portrait.created), "MM-dd HH:mm") : ""

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillHeight: true
                        implicitWidth: 4
                        color: "#F1AA03"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Read-only but selectable, so a part can be copied.
                        TextEdit {
                            Layout.fillWidth: true
                            Layout.maximumHeight: memories.portraitOpen ? -1 : 3 * 13 * 1.6 + 2
                            visible: !!(memories.portrait && memories.portrait.text)
                            clip: true
                            readOnly: true
                            selectByMouse: true
                            wrapMode: Text.Wrap
                            selectionColor: "#F59B00"
                            font.family: Yui.messageFont
                            font.pixelSize: 13
                            color: "#333333"
                            text: "“ " + (memories.portrait ? memories.portrait.text : "")
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !(memories.portrait && memories.portrait.text)
                            wrapMode: Text.Wrap
                            font.family: Yui.fontFor(text)
                            font.pixelSize: 13
                            color: "#7A7A7A"
                            text: memories.yui.heartCache.length > 0 ? qsTr("Ask Yui what she makes of you from her memories.") : qsTr("No memories yet: chat with Yui a little first.")
                        }

                        Row {
                            Layout.alignment: Qt.AlignRight
                            spacing: 8

                            ConsoleChip {
                                small: true
                                visible: !!(memories.portrait && memories.portrait.text)
                                text: memories.portraitOpen ? "Fold" : "Unfold"
                                onClicked: memories.portraitOpen = !memories.portraitOpen
                            }

                            ConsoleChip {
                                small: true
                                enabled: !memories.yui.writingPortrait && memories.yui.heartCache.length > 0
                                text: memories.yui.writingPortrait ? "Writing..." : (memories.portrait ? "Ask Again" : "Hear from Yui")
                                onClicked: memories.yui.writePortrait(function(error) {
                                    memories.message = error;
                                })
                            }

                        }

                    }

                }

            }

            ConsolePanel {
                Layout.fillWidth: true
                leading: [
                    ConsoleSwitch {
                        model: ["◆ Heart Core  " + memories.core.length, "● Fragments  " + memories.fragments.length]
                        current: memories.side
                        onPicked: {
                            memories.side = index;
                            memories.editingId = -1;
                        }
                    }
                ]
                tools: [
                    TextField {
                        width: 160
                        selectByMouse: true
                        font.family: Yui.messageFont
                        font.pixelSize: 12
                        placeholderText: qsTr("Search memories")
                        onTextChanged: memories.filter = text.trim().toLowerCase()
                    }
                ]

                // The heart core's room, as a HUD bar (red when full).
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    visible: memories.side === 0
                    spacing: 10

                    Text {
                        text: "CORE"
                        font.family: "SAO UI"
                        font.pixelSize: 13
                        color: "#7A7A7A"
                    }

                    ConsoleHpBar {
                        Layout.fillWidth: true
                        value: memories.yui.heartCoreCapacity > 0 ? memories.core.length / memories.yui.heartCoreCapacity * 100 : NaN
                        level: memories.core.length >= memories.yui.heartCoreCapacity ? 2 : 0
                    }

                    Text {
                        text: memories.core.length + " / " + memories.yui.heartCoreCapacity
                        font.family: "SAO UI"
                        font.pixelSize: 13
                        color: "#7A7A7A"
                    }

                }

                Text {
                    Layout.fillWidth: true
                    visible: memories.message !== ""
                    text: memories.message
                    wrapMode: Text.Wrap
                    font.family: Yui.fontFor(text)
                    font.pixelSize: 12
                    color: "#D48800"
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    visible: memories.shown.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.family: Yui.fontFor(text)
                    font.pixelSize: 12
                    color: "#7A7A7A"
                    text: memories.filter ? qsTr("No memory contains this.") : (memories.side === 0 ? qsTr("The heart core is empty: what matters most about you goes here.") : qsTr("No memory fragments yet: chat with Yui and she will remember."))
                }

                // The memories.
                Repeater {
                    model: memories.shown

                    Rectangle {
                        id: item

                        readonly property var memory: modelData
                        readonly property bool isCore: memory.kind === "core"
                        readonly property bool editing: memories.editingId === memory.id

                        function save() {
                            memories.change(memory.id, {
                                "text": editor.text
                            });
                            memories.editingId = -1;
                        }

                        Layout.fillWidth: true
                        implicitHeight: (editing ? editColumn.implicitHeight : textColumn.implicitHeight) + 16
                        color: hover.containsMouse || editing ? "#FFF8E6" : "transparent"

                        MouseArea {
                            id: hover

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        // Core: orange, fragment: grey.
                        Rectangle {
                            x: 0
                            y: 8
                            width: 4
                            height: parent.height - 16
                            color: item.isCore ? "#F1AA03" : "#C4C4C4"
                        }

                        ColumnLayout {
                            id: textColumn

                            visible: !item.editing
                            x: 14
                            y: 8
                            width: parent.width - 14 - actions.width - 10
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                font.family: Yui.messageFont
                                font.pixelSize: 13
                                color: "#333333"
                                text: (item.memory.pinned ? "📌 " : "") + (item.memory.text || "")
                            }

                            Text {
                                visible: text !== ""
                                font.family: Yui.fontFor(text)
                                font.pixelSize: 11
                                color: "#7A7A7A"
                                text: memories.details(item.memory)
                            }

                        }

                        // Edit, Pin (core only), To Fragments / To Core, Forget: shown on hover.
                        Row {
                            id: actions

                            visible: !item.editing
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            opacity: hover.containsMouse || actionsHover.containsMouse ? 1 : 0

                            ConsoleChip {
                                small: true
                                text: "Edit"
                                onClicked: {
                                    memories.editingId = item.memory.id;
                                    editor.text = item.memory.text;
                                    editor.forceActiveFocus();
                                }
                            }

                            ConsoleChip {
                                small: true
                                visible: item.isCore
                                text: item.memory.pinned ? "Unpin" : "Pin"
                                onClicked: memories.change(item.memory.id, {
                                    "pinned": !item.memory.pinned
                                })
                            }

                            ConsoleChip {
                                small: true
                                text: item.isCore ? "To Fragments" : "To Core"
                                onClicked: memories.change(item.memory.id, {
                                    "kind": item.isCore ? "fragment" : "core"
                                })
                            }

                            ConsoleChip {
                                small: true
                                text: "Forget"
                                onClicked: memories.remove(item.memory)
                            }

                        }

                        MouseArea {
                            id: actionsHover

                            anchors.fill: actions
                            visible: actions.visible
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        // Editing in place: Ctrl+Enter saves, Esc cancels.
                        ColumnLayout {
                            id: editColumn

                            visible: item.editing
                            x: 14
                            y: 8
                            width: parent.width - 18
                            spacing: 6

                            TextArea {
                                id: editor

                                Layout.fillWidth: true
                                selectByMouse: true
                                wrapMode: Text.Wrap
                                font.family: Yui.messageFont
                                font.pixelSize: 13
                                Keys.onReturnPressed: {
                                    if (event.modifiers & Qt.ControlModifier)
                                        item.save();
                                    else
                                        event.accepted = false;
                                }
                                Keys.onEscapePressed: memories.editingId = -1
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    font.family: Yui.fontFor(text)
                                    font.pixelSize: 11
                                    color: "#7A7A7A"
                                    text: qsTr("Ctrl+Enter saves · Esc cancels")
                                }

                                ConsoleChip {
                                    small: true
                                    text: "Save"
                                    onClicked: item.save()
                                }

                                ConsoleChip {
                                    small: true
                                    text: "Cancel"
                                    onClicked: memories.editingId = -1
                                }

                            }

                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: "#E9E9E9"
                        }

                    }

                }

                // Adding, under a dashed line.
                Row {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 4

                    Repeater {
                        model: Math.floor(parent.width / 8)

                        Rectangle {
                            width: 4
                            height: 1
                            color: "#CCCCCC"
                        }

                    }

                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    TextField {
                        id: addText

                        Layout.fillWidth: true
                        selectByMouse: true
                        font.family: Yui.messageFont
                        font.pixelSize: 13
                        placeholderText: "＋  " + qsTr("Something Yui should remember")
                        onAccepted: {
                            if (memories.add(text, addKind.current === 0 ? "core" : "fragment"))
                                text = "";

                        }
                    }

                    ConsoleSwitch {
                        id: addKind

                        model: ["Core", "Fragment"]
                        current: memories.side
                    }

                    ConsoleChip {
                        text: "Add"
                        enabled: addText.text.trim() !== ""
                        onClicked: {
                            if (memories.add(addText.text, addKind.current === 0 ? "core" : "fragment"))
                                addText.text = "";

                        }
                    }

                }

            }

        }

        // ---------------------------------------------------------------- Follow-ups
        ConsolePage {
            ConsolePanel {
                Layout.fillWidth: true
                title: "Follow-ups"
                note: qsTr("days to come")

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.family: Yui.fontFor(text)
                    font.pixelSize: 12
                    color: "#7A7A7A"
                    text: qsTr("Things Yui remembered with a date to come. She cheers you on that day and asks how it went in the week after. Removing one here keeps the memory.")
                }

                Text {
                    visible: memories.followupItems.length === 0
                    font.family: Yui.fontFor(text)
                    font.pixelSize: 13
                    color: "#7A7A7A"
                    text: memories.yui.featureEnabled("followups") ? qsTr("Nothing to follow up") : qsTr("Follow-ups are off (Mental Health Counseling, Care)")
                }

                Repeater {
                    model: memories.followupItems

                    Item {
                        readonly property bool today: modelData.phase === "today"
                        readonly property bool past: modelData.phase !== "ahead" && !today

                        Layout.fillWidth: true
                        implicitHeight: Math.max(dateBox.height, followText.implicitHeight) + 16

                        // The date box: orange today, faded once past.
                        Rectangle {
                            id: dateBox

                            anchors.verticalCenter: parent.verticalCenter
                            width: 68
                            height: 44
                            color: "#FFFFFF"
                            border.color: parent.today ? "#F1AA03" : "#DDDDDD"
                            opacity: parent.past ? 0.6 : 1

                            Column {
                                anchors.centerIn: parent

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.due.slice(5).replace("-", "/")
                                    font.family: "SAO UI"
                                    font.pixelSize: 18
                                    color: dateBox.parent.today ? "#F1AA03" : "#4D4D4D"
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: memories.followupWhen(modelData)
                                    font.family: Yui.fontFor(text)
                                    font.pixelSize: 10
                                    color: "#7A7A7A"
                                }

                            }

                        }

                        Text {
                            id: followText

                            anchors.left: dateBox.right
                            anchors.leftMargin: 12
                            anchors.right: stageTag.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            font.family: Yui.messageFont
                            font.pixelSize: 13
                            color: "#333333"
                            text: modelData.text
                        }

                        ConsoleTag {
                            id: stageTag

                            readonly property var stage: memories.followupStage(modelData)

                            anchors.right: removeChip.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: stage[0]
                            color: stage[1]
                        }

                        ConsoleChip {
                            id: removeChip

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            small: true
                            text: "Remove"
                            onClicked: memories.yui.dismissFollowup(modelData.key)
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: "#E9E9E9"
                            visible: index < memories.followupItems.length - 1
                        }

                    }

                }

            }

        }

        // ---------------------------------------------------------------- Recollection Log
        ConsolePage {
            ConsolePanel {
                Layout.fillWidth: true
                title: "Recollection Log"
                note: qsTr("%1 messages").arg(memories.logSize)

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.family: Yui.fontFor(text)
                    font.pixelSize: 12
                    color: "#7A7A7A"
                    text: qsTr("Every chat message is kept here, only for exports and searching. It is never sent to the AI. Exporting and clearing it are in Yui's Heart, Local Memory.")
                }

                // Searching the log as you type.
                TextField {
                    id: logSearchField

                    Layout.fillWidth: true
                    selectByMouse: true
                    font.family: Yui.messageFont
                    placeholderText: qsTr("Search the log")
                    onTextChanged: logSearchTimer.restart()

                    Timer {
                        id: logSearchTimer

                        interval: 300
                        onTriggered: memories.searchLog(logSearchField.text)
                    }

                }

                Text {
                    visible: memories.logQuery !== ""
                    font.family: Yui.fontFor(text)
                    font.pixelSize: 12
                    color: "#7A7A7A"
                    text: memories.logResults.length >= 50 ? qsTr("The latest 50 messages found") : qsTr("%1 messages found").arg(memories.logResults.length)
                }

                Repeater {
                    model: memories.logResults

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: logLine.implicitHeight + 12

                        Text {
                            id: logLine

                            width: parent.width
                            y: 6
                            wrapMode: Text.Wrap
                            textFormat: Text.StyledText
                            font.family: Yui.messageFont
                            font.pixelSize: 13
                            color: "#333333"
                            text: memories.marked(Yui.logLine(modelData, memories.yui.userTitle()))
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: "#EEEEEE"
                        }

                    }

                }

            }

        }

    }

}
