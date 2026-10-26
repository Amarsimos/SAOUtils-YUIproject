import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// "Skill Slots" window (next to Mental Health Counseling): Yui's small tools, each a skill in a slot:
// Boss Raid (focus time, then a rest), Alarm (reminders, <<remind:>>), Quest Log (notes and to-dos,
// <<note:>> / <<done:>>) and Sword Skills (named SAO Utils actions Yui runs, <<skill:>>). Each tab has its
// settings first; below a heading comes what is not a setting (status, lists), to become a window later. The settings are SAO Utils' own preferences synced with the widget's settings
// (ObjectPreferenceGroup); Reset restores the settings only, never the reminders or the notes.
NVG.Window {
    id: skillsWindow

    property var targetWidget
    // Alarm and Quest Log lists, refreshed when Yui changes them.
    property var reminders: []
    property var notes: []
    // The time now, for the Boss Raid status (ticks while the window is open).
    property double now: Date.now()
    // The settings of each tab, for Reset This Tab and the title bar's Reset.
    readonly property var raidPreferences: [raidPreference, restPreference, bannerPreference]
    readonly property var alarmPreferences: [alarmPreference]
    readonly property var notesPreferences: [notesPreference]
    readonly property var swordPreferences: [skillName1, skillAction1, skillName2, skillAction2, skillName3, skillAction3, skillName4, skillAction4, skillName5, skillAction5]

    function refreshReminders() {
        reminders = targetWidget.remindersList();
    }

    function refreshNotes() {
        notes = targetWidget.notesList(true);
    }

    // Adds the reminder typed in; its time as for <<remind:>> (Yui.remindFrom).
    function addTypedReminder() {
        var time = (dailyBox.checked ? "每天 " : "") + alarmTimeField.text.trim();
        var reminder = Yui.remindFrom(time + "|" + alarmTextField.text.trim(), Date.now());
        if (!reminder) {
            alarmMessage.text = qsTr("Write the time as HH:mm, yyyy-MM-dd HH:mm or +minutes, in the future, and what to remind of.");
            return ;
        }
        targetWidget.addReminder(reminder);
        alarmMessage.text = "";
        alarmTimeField.text = "";
        alarmTextField.text = "";
    }

    function addTypedNote() {
        if (!noteField.text.trim())
            return ;

        targetWidget.addQuestNote(noteField.text);
        noteField.text = "";
    }

    title: qsTr("Skill Slots")
    visible: true
    minimumWidth: 420
    minimumHeight: 420
    width: 520
    height: 640
    transientParent: widget.NVG.View.window
    onClosing: destroy()
    Component.onCompleted: {
        refreshReminders();
        refreshNotes();
    }

    Connections {
        target: skillsWindow.targetWidget
        onAlarmRevisionChanged: skillsWindow.refreshReminders()
        onNotesRevisionChanged: skillsWindow.refreshNotes()
    }

    Timer {
        interval: 1000
        repeat: true
        running: skillsWindow.visible
        onTriggered: skillsWindow.now = Date.now()
    }

    Page {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            // Little room at the sides, as the other settings windows.
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.bottomMargin: 16
            spacing: 10

            // Wraps into a second row when the window is narrow (see WrapTabBar.qml).
            WrapTabBar {
                id: tabs

                model: [qsTr("Boss Raid"), qsTr("Alarm"), qsTr("Quest Log"), qsTr("Sword Skills")]
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabs.shownIndex

                // ---------------------------------------------------------------- Boss Raid
                SettingsPage {
                    P.ObjectPreferenceGroup {
                        id: raidGroup

                        Layout.fillWidth: true
                        defaultValue: skillsWindow.targetWidget.settings
                        syncProperties: true

                        P.SpinPreference {
                            id: raidPreference

                            name: "raid_minutes"
                            defaultValue: 25
                            label: qsTr("Raid Duration")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 1
                            to: 180
                            stepSize: 1
                        }

                        P.SpinPreference {
                            id: restPreference

                            name: "rest_minutes"
                            defaultValue: 5
                            label: qsTr("Rest Duration")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 1
                            to: 60
                            stepSize: 1
                        }

                        SettingNote {
                            visible: skillsWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Boss Raid: focus time with Yui, in minutes, then a rest. Start it here, from her menu or ask her (\"stay with me for 25 minutes\"); meanwhile the crystal turns violet and she does not speak up by herself.")
                        }

                        P.SwitchPreference {
                            id: bannerPreference

                            name: "raid_banner"
                            label: qsTr("Raid Banner")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: skillsWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("A banner on top of the screen shows the time left (drag it anywhere); when the raid is won it says \"Congratulations!\" across the screen, as when a floor boss falls.")
                        }

                    }

                    // Below: not settings (a window of its own later).
                    Heading {
                        level: 2
                        text: qsTr("Status")
                    }

                    Label {
                        Layout.leftMargin: 16
                        font.pixelSize: 16
                        text: {
                            var yui = skillsWindow.targetWidget;
                            if (yui.raidActive)
                                return qsTr("In a raid: %1 min left").arg(Math.max(0, Math.ceil((yui.raidEnd - skillsWindow.now) / 60000)));

                            if (yui.resting)
                                return qsTr("Resting: %1 min left").arg(Math.max(0, Math.ceil((yui.restEnd - skillsWindow.now) / 60000)));

                            return qsTr("No raid now.");
                        }
                    }

                    Button {
                        Layout.leftMargin: 16
                        visible: skillsWindow.targetWidget.raidActive || skillsWindow.targetWidget.resting
                        text: qsTr("Show Raid Banner")
                        onClicked: skillsWindow.targetWidget.showRaidBanner()
                    }

                    Button {
                        Layout.leftMargin: 16
                        text: skillsWindow.targetWidget.raidActive || skillsWindow.targetWidget.resting ? qsTr("End Boss Raid") : qsTr("Start Boss Raid")
                        onClicked: {
                            var yui = skillsWindow.targetWidget;
                            if (yui.raidActive || yui.resting)
                                yui.stopRaid();
                            else
                                yui.startRaid(yui.raidMinutes, true);
                        }
                    }

                    ResetTabButton {
                        yui: skillsWindow.targetWidget
                        windowTitle: skillsWindow.title
                        tabTitle: qsTr("Boss Raid")
                        preferences: skillsWindow.raidPreferences
                        groups: [raidGroup]
                    }

                }

                // ---------------------------------------------------------------- Alarm
                SettingsPage {
                    P.ObjectPreferenceGroup {
                        id: alarmGroup

                        Layout.fillWidth: true
                        defaultValue: skillsWindow.targetWidget.settings
                        syncProperties: true

                        P.SwitchPreference {
                            id: alarmPreference

                            name: "alarm_enabled"
                            label: qsTr("Alarm")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: skillsWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Ask Yui to remind you (\"remind me of the meeting in 30 minutes\", \"every day at 23:00, time to sleep\") or add a reminder here. She tells you when it is time, and missed ones when SAO Utils starts again.")
                        }

                    }

                    // Below: not settings (a window of its own later).
                    Heading {
                        level: 2
                        text: qsTr("Reminders")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        enabled: alarmPreference.value

                        TextField {
                            id: alarmTimeField

                            Layout.preferredWidth: 140
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
                            onAccepted: skillsWindow.addTypedReminder()
                        }

                        Button {
                            text: qsTr("Add")
                            onClicked: skillsWindow.addTypedReminder()
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
                        visible: skillsWindow.reminders.length === 0
                        opacity: 0.7
                        text: qsTr("No reminders.")
                    }

                    Repeater {
                        model: skillsWindow.reminders

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
                                onClicked: skillsWindow.targetWidget.deleteReminder(modelData.id)
                            }

                        }

                    }

                    ResetTabButton {
                        yui: skillsWindow.targetWidget
                        windowTitle: skillsWindow.title
                        tabTitle: qsTr("Alarm")
                        preferences: skillsWindow.alarmPreferences
                        groups: [alarmGroup]
                    }

                }

                // ---------------------------------------------------------------- Quest Log
                SettingsPage {
                    P.ObjectPreferenceGroup {
                        id: notesGroup

                        Layout.fillWidth: true
                        defaultValue: skillsWindow.targetWidget.settings
                        syncProperties: true

                        P.SwitchPreference {
                            id: notesPreference

                            name: "notes_enabled"
                            label: qsTr("Quest Log")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: skillsWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Ask Yui to note something down (\"note that I need milk\") and tell her when it is done. The notes are kept apart from Yui's Heart and are sent to her only when you ask about them.")
                        }

                    }

                    // Below: not settings (a window of its own later).
                    Heading {
                        level: 2
                        text: qsTr("Notes")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        enabled: notesPreference.value

                        TextField {
                            id: noteField

                            Layout.fillWidth: true
                            placeholderText: qsTr("Something to note down")
                            selectByMouse: true
                            onAccepted: skillsWindow.addTypedNote()
                        }

                        Button {
                            text: qsTr("Add")
                            onClicked: skillsWindow.addTypedNote()
                        }

                        Button {
                            text: qsTr("Export")
                            enabled: skillsWindow.notes.length > 0
                            onClicked: skillsWindow.targetWidget.exportNotes(function(path) {
                                notesMessage.text = path ? qsTr("Exported to %1").arg(path) : qsTr("The export could not be written. See the log in System Console.");
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
                        visible: skillsWindow.notes.length === 0
                        opacity: 0.7
                        text: qsTr("No notes.")
                    }

                    // Open notes first, then the done ones; the check box marks a note done.
                    Repeater {
                        model: skillsWindow.notes

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16

                            CheckBox {
                                checked: !!modelData.done
                                onToggled: skillsWindow.targetWidget.editNote(modelData.id, modelData.text, checked)
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
                                onClicked: skillsWindow.targetWidget.deleteNote(modelData.id)
                            }

                        }

                    }

                    ResetTabButton {
                        yui: skillsWindow.targetWidget
                        windowTitle: skillsWindow.title
                        tabTitle: qsTr("Quest Log")
                        preferences: skillsWindow.notesPreferences
                        groups: [notesGroup]
                    }

                }

                // ---------------------------------------------------------------- Sword Skills
                SettingsPage {
                    P.ObjectPreferenceGroup {
                        id: swordGroup

                        Layout.fillWidth: true
                        defaultValue: skillsWindow.targetWidget.settings
                        syncProperties: true

                        SettingNote {
                            visible: skillsWindow.targetWidget.settingsHelp
                            text: qsTr("Give a name and a SAO Utils action to a slot; when you tell Yui to do it (\"start work\"), she runs it after you confirm. To chain several steps (open programs, close a game, start a Boss Raid...), choose a Script Action and put them in its Input Actions.")
                        }

                        P.TextFieldPreference {
                            id: skillName1

                            name: "sword_skill_1_name"
                            label: qsTr("Sword Skill 1")
                            display: P.TextFieldPreference.ExpandLabel
                            hint: qsTr("Name, e.g. Start Work")
                        }

                        P.ActionPreference {
                            id: skillAction1

                            name: "sword_skill_1_action"
                            label: qsTr("Action")
                        }

                        P.TextFieldPreference {
                            id: skillName2

                            name: "sword_skill_2_name"
                            label: qsTr("Sword Skill 2")
                            display: P.TextFieldPreference.ExpandLabel
                            hint: qsTr("Name, e.g. Start Work")
                        }

                        P.ActionPreference {
                            id: skillAction2

                            name: "sword_skill_2_action"
                            label: qsTr("Action")
                        }

                        P.TextFieldPreference {
                            id: skillName3

                            name: "sword_skill_3_name"
                            label: qsTr("Sword Skill 3")
                            display: P.TextFieldPreference.ExpandLabel
                            hint: qsTr("Name, e.g. Start Work")
                        }

                        P.ActionPreference {
                            id: skillAction3

                            name: "sword_skill_3_action"
                            label: qsTr("Action")
                        }

                        P.TextFieldPreference {
                            id: skillName4

                            name: "sword_skill_4_name"
                            label: qsTr("Sword Skill 4")
                            display: P.TextFieldPreference.ExpandLabel
                            hint: qsTr("Name, e.g. Start Work")
                        }

                        P.ActionPreference {
                            id: skillAction4

                            name: "sword_skill_4_action"
                            label: qsTr("Action")
                        }

                        P.TextFieldPreference {
                            id: skillName5

                            name: "sword_skill_5_name"
                            label: qsTr("Sword Skill 5")
                            display: P.TextFieldPreference.ExpandLabel
                            hint: qsTr("Name, e.g. Start Work")
                        }

                        P.ActionPreference {
                            id: skillAction5

                            name: "sword_skill_5_action"
                            label: qsTr("Action")
                        }

                    }

                    // Below: not settings (a window of its own later).
                    Heading {
                        level: 2
                        text: qsTr("Test")
                    }

                    RowLayout {
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16

                        Repeater {
                            model: 5

                            Button {
                                text: qsTr("Test %1").arg(index + 1)
                                onClicked: skillsWindow.targetWidget.runSwordSkill(index + 1)
                            }

                        }

                    }

                    ResetTabButton {
                        yui: skillsWindow.targetWidget
                        windowTitle: skillsWindow.title
                        tabTitle: qsTr("Sword Skills")
                        preferences: skillsWindow.swordPreferences
                        groups: [swordGroup]
                    }

                }

            }

        }

        // Reset: the settings of every tab, never the reminders or the notes.
        header: SettingsTitleBar {
            yui: skillsWindow.targetWidget
            settingsWindow: skillsWindow
            // load() is no edit, so the synced groups write the defaults to the settings by save().
            onResetRequested: {
                skillsWindow.raidPreferences.concat(skillsWindow.alarmPreferences, skillsWindow.notesPreferences, skillsWindow.swordPreferences).forEach(function(preference) {
                    preference.load();
                });
                raidGroup.save();
                alarmGroup.save();
                notesGroup.save();
                swordGroup.save();
            }
        }

    }

}
