import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// System Console, Quests (as the preview; moved from Skill Slots): two cards (the Boss Raid now, the next
// reminder), then the Alarm and Quest Log lists, each with a row to add one. Their settings stay in
// Skill Slots; a list whose skill is off there cannot be added to.
ConsolePage {
    id: quests

    property var yui
    property var reminders: []
    property var notes: []
    property string alarmError: ""
    property string notesMessage: ""
    // The time now, for the Boss Raid (ticks while shown).
    property double now: Date.now()
    readonly property bool alarmOn: yui.settings.alarm_enabled !== false
    readonly property bool notesOn: yui.settings.notes_enabled !== false
    readonly property bool raiding: yui.raidActive || yui.resting
    readonly property double raidLeft: Math.max(0, (yui.raidActive ? yui.raidEnd : yui.restEnd) - now)
    readonly property var nextReminder: reminders.length > 0 ? reminders.slice().sort(function(a, b) {
        return a.due - b.due;
    })[0] : null

    function refreshReminders() {
        reminders = yui.remindersList();
    }

    function refreshNotes() {
        notes = yui.notesList(true);
    }

    function when(reminder) {
        return reminder.daily ? qsTr("Daily %1").arg(Qt.formatDateTime(new Date(reminder.due), "HH:mm")) : Qt.formatDateTime(new Date(reminder.due), "MM-dd HH:mm");
    }

    // Adds the reminder typed in; its time as for <<remind:>> (Yui.remindFrom).
    function addTypedReminder() {
        var time = (dailyBox.checked ? "每天 " : "") + alarmTimeField.text.trim();
        var reminder = Yui.remindFrom(time + "|" + alarmTextField.text.trim(), Date.now());
        if (!reminder) {
            alarmError = qsTr("Write the time as HH:mm, yyyy-MM-dd HH:mm or +minutes, in the future, and what to remind of.");
            return ;
        }
        yui.addReminder(reminder);
        alarmError = "";
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

    GridLayout {
        Layout.fillWidth: true
        columns: quests.width > 420 ? 2 : 1
        columnSpacing: 14
        rowSpacing: 14

        ConsoleCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: "Boss Raid"
            note: quests.yui.raidActive ? qsTr("in a raid") : quests.yui.resting ? qsTr("resting") : ""
            big: quests.raiding ? Math.floor(quests.raidLeft / 60000) + ":" + ("0" + Math.floor(quests.raidLeft % 60000 / 1000)).slice(-2) : "--:--"
            sub: quests.raiding ? qsTr("left") : qsTr("No raid now.")
            meter: quests.yui.raidActive ? quests.raidLeft / (quests.yui.raidMinutes * 60000) : quests.yui.resting ? quests.raidLeft / (quests.yui.restMinutes * 60000) : -1
            meterColor: "#F1AA03"
            tools: [
                ConsoleChip {
                    small: true
                    visible: quests.raiding
                    text: qsTr("Banner")
                    onClicked: quests.yui.showRaidBanner()
                },
                ConsoleChip {
                    small: true
                    text: quests.raiding ? qsTr("End") : qsTr("Start")
                    onClicked: {
                        var yui = quests.yui;
                        if (quests.raiding)
                            yui.stopRaid();
                        else
                            yui.startRaid(yui.raidMinutes, true);
                    }
                }
            ]
        }

        ConsoleCard {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            title: "Alarm"
            note: qsTr("next reminder")
            big: quests.nextReminder ? Qt.formatDateTime(new Date(quests.nextReminder.due), "HH:mm") : "--:--"
            sub: quests.nextReminder ? quests.nextReminder.text : (quests.alarmOn ? qsTr("No reminders.") : qsTr("Alarm is off (Skill Slots, Alarm)."))
        }

    }

    ConsolePanel {
        Layout.fillWidth: true
        title: "Alarm"
        note: quests.alarmOn ? "" : qsTr("off in Skill Slots")

        RowLayout {
            Layout.fillWidth: true
            enabled: quests.alarmOn

            TextField {
                id: alarmTimeField

                Layout.preferredWidth: 110
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

            ConsoleChip {
                text: "＋ " + qsTr("Add")
                onClicked: quests.addTypedReminder()
            }

        }

        Text {
            Layout.fillWidth: true
            visible: quests.alarmError !== ""
            text: quests.alarmError
            wrapMode: Text.Wrap
            font.pixelSize: 12
            color: "#C82864"
        }

        Repeater {
            model: quests.reminders

            ConsoleRow {
                Layout.fillWidth: true
                keyWidth: 96
                key: quests.when(modelData)
                text: modelData.text
                last: index === quests.reminders.length - 1

                ConsoleChip {
                    small: true
                    text: qsTr("Dismiss")
                    onClicked: quests.yui.deleteReminder(modelData.id)
                }

            }

        }

    }

    ConsolePanel {
        Layout.fillWidth: true
        title: "Quest Log"
        note: quests.notesOn ? "" : qsTr("off in Skill Slots")
        tools: [
            ConsoleChip {
                small: true
                enabled: quests.notes.length > 0
                text: qsTr("Export")
                onClicked: quests.yui.exportNotes(function(path) {
                    quests.notesMessage = path ? qsTr("Exported to %1").arg(path) : qsTr("The export could not be written. See the log in System Authority.");
                })
            }
        ]

        RowLayout {
            Layout.fillWidth: true
            enabled: quests.notesOn

            TextField {
                id: noteField

                Layout.fillWidth: true
                placeholderText: qsTr("Something to note down")
                selectByMouse: true
                onAccepted: quests.addTypedNote()
            }

            ConsoleChip {
                text: "＋ " + qsTr("Add")
                onClicked: quests.addTypedNote()
            }

        }

        Text {
            Layout.fillWidth: true
            visible: quests.notesMessage !== ""
            text: quests.notesMessage
            wrapMode: Text.Wrap
            font.pixelSize: 12
            color: "#7A7A7A"
        }

        // Open notes first, then the done ones.
        Repeater {
            model: quests.notes

            ConsoleRow {
                Layout.fillWidth: true
                keyWidth: 24
                key: modelData.done ? "☑" : "☐"
                text: modelData.text
                done: !!modelData.done
                last: index === quests.notes.length - 1

                ConsoleChip {
                    small: true
                    text: modelData.done ? qsTr("Undo") : qsTr("Done")
                    onClicked: quests.yui.editNote(modelData.id, modelData.text, !modelData.done)
                }

                ConsoleChip {
                    small: true
                    text: "✕"
                    onClicked: quests.yui.deleteNote(modelData.id)
                }

            }

        }

    }

}
