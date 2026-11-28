import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// System Console, Quests (moved from Skill Slots): the Boss Raid now, the reminders (Alarm) and the
// notes (Quest Log). Their settings stay in Skill Slots; a list whose skill is off there cannot be
// added to.
SettingsPage {
    id: quests

    property var yui
    property var reminders: []
    property var notes: []
    // The time now, for the Boss Raid status (ticks while shown).
    property double now: Date.now()
    readonly property bool alarmOn: yui.settings.alarm_enabled !== false
    readonly property bool notesOn: yui.settings.notes_enabled !== false

    function refreshReminders() {
        reminders = yui.remindersList();
    }

    function refreshNotes() {
        notes = yui.notesList(true);
    }

    // Adds the reminder typed in; its time as for <<remind:>> (Yui.remindFrom).
    function addTypedReminder() {
        var time = (dailyBox.checked ? "每天 " : "") + alarmTimeField.text.trim();
        var reminder = Yui.remindFrom(time + "|" + alarmTextField.text.trim(), Date.now());
        if (!reminder) {
            alarmMessage.text = qsTr("Write the time as HH:mm, yyyy-MM-dd HH:mm or +minutes, in the future, and what to remind of.");
            return ;
        }
        yui.addReminder(reminder);
        alarmMessage.text = "";
        alarmTimeField.text = "";
        alarmTextField.text = "";
    }

    function addTypedNote() {
        if (!noteField.text.trim())
            return ;

        yui.addQuestNote(noteField.text);
        noteField.text = "";
    }

    Component.onCompleted: {
        refreshReminders();
        refreshNotes();
    }

    Connections {
        target: quests.yui
        onAlarmRevisionChanged: quests.refreshReminders()
        onNotesRevisionChanged: quests.refreshNotes()
    }

    Timer {
        interval: 1000
        repeat: true
        running: quests.visible
        onTriggered: quests.now = Date.now()
    }

    // ---------------------------------------------------------------- Boss Raid
    Heading {
        text: qsTr("Boss Raid")
    }

    Label {
        Layout.leftMargin: 16
        font.pixelSize: 16
        text: {
            var yui = quests.yui;
            if (yui.raidActive)
                return qsTr("In a raid: %1 min left").arg(Math.max(0, Math.ceil((yui.raidEnd - quests.now) / 60000)));

            if (yui.resting)
                return qsTr("Resting: %1 min left").arg(Math.max(0, Math.ceil((yui.restEnd - quests.now) / 60000)));

            return qsTr("No raid now.");
        }
    }

    CenteredFlow {
        Button {
            visible: quests.yui.raidActive || quests.yui.resting
            text: qsTr("Show Raid Banner")
            onClicked: quests.yui.showRaidBanner()
        }

        Button {
            text: quests.yui.raidActive || quests.yui.resting ? qsTr("End Boss Raid") : qsTr("Start Boss Raid")
            onClicked: {
                var yui = quests.yui;
                if (yui.raidActive || yui.resting)
                    yui.stopRaid();
                else
                    yui.startRaid(yui.raidMinutes, true);
            }
        }

    }

    // ---------------------------------------------------------------- Alarm
    Heading {
        text: qsTr("Reminders")
    }

    Label {
        Layout.leftMargin: 16
        visible: !quests.alarmOn
        opacity: 0.7
        text: qsTr("Alarm is off (Skill Slots, Alarm).")
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        enabled: quests.alarmOn

        TextField {
            id: alarmTimeField

            Layout.preferredWidth: 120
            placeholderText: qsTr("HH:mm / +30")
            selectByMouse: true
        }

        CheckBox {
            id: dailyBox

            text: qsTr("Daily")
        }

        TextField {
            id: alarmTextField

            Layout.fillWidth: true
            placeholderText: qsTr("Remind me of…")
            selectByMouse: true
            onAccepted: quests.addTypedReminder()
        }

        Button {
            text: qsTr("Add")
            onClicked: quests.addTypedReminder()
        }

    }

    Label {
        id: alarmMessage

        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        visible: text !== ""
        wrapMode: Text.Wrap
        color: "#E53935"
    }

    Label {
        Layout.leftMargin: 16
        visible: quests.reminders.length === 0
        opacity: 0.7
        text: qsTr("No reminders.")
    }

    Repeater {
        model: quests.reminders

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            Label {
                Layout.preferredWidth: 110
                text: modelData.daily ? qsTr("Daily %1").arg(Qt.formatDateTime(new Date(modelData.due), "HH:mm")) : Qt.formatDateTime(new Date(modelData.due), "MM-dd HH:mm")
            }

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: modelData.text
            }

            ToolButton {
                text: "✕"
                onClicked: quests.yui.deleteReminder(modelData.id)
            }

        }

    }

    // ---------------------------------------------------------------- Quest Log
    Heading {
        text: qsTr("Quest Log")
    }

    Label {
        Layout.leftMargin: 16
        visible: !quests.notesOn
        opacity: 0.7
        text: qsTr("Quest Log is off (Skill Slots, Quest Log).")
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        enabled: quests.notesOn

        TextField {
            id: noteField

            Layout.fillWidth: true
            placeholderText: qsTr("Something to note down")
            selectByMouse: true
            onAccepted: quests.addTypedNote()
        }

        Button {
            text: qsTr("Add")
            onClicked: quests.addTypedNote()
        }

        Button {
            text: qsTr("Export")
            enabled: quests.notes.length > 0
            onClicked: quests.yui.exportNotes(function(path) {
                notesMessage.text = path ? qsTr("Exported to %1").arg(path) : qsTr("The export could not be written. See the log in System Authority.");
            })
        }

    }

    Label {
        id: notesMessage

        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        visible: text !== ""
        wrapMode: Text.Wrap
        opacity: 0.7
    }

    Label {
        Layout.leftMargin: 16
        visible: quests.notes.length === 0
        opacity: 0.7
        text: qsTr("No notes.")
    }

    // Open notes first, then the done ones; the check box marks a note done.
    Repeater {
        model: quests.notes

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            CheckBox {
                checked: !!modelData.done
                onToggled: quests.yui.editNote(modelData.id, modelData.text, checked)
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                opacity: modelData.done ? 0.5 : 1
                font.strikeout: !!modelData.done
                text: modelData.text
            }

            ToolButton {
                text: "✕"
                onClicked: quests.yui.deleteNote(modelData.id)
            }

        }

    }

}
