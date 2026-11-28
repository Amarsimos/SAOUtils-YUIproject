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
// settings only; the Boss Raid now, the reminders and the notes are in System Console, Quests. The settings
// are SAO Utils' own preferences synced with the widget's settings (ObjectPreferenceGroup); Reset
// restores the settings only, never the reminders or the notes.
NVG.Window {
    id: skillsWindow

    property var targetWidget
    // The settings of each tab, for Reset This Tab and the title bar's Reset.
    readonly property var raidPreferences: [raidPreference, restPreference, bannerPreference]
    readonly property var alarmPreferences: [alarmPreference]
    readonly property var notesPreferences: [notesPreference]
    readonly property var swordPreferences: [skillName1, skillAction1, skillName2, skillAction2, skillName3, skillAction3, skillName4, skillAction4, skillName5, skillAction5]

    title: qsTr("Skill Slots")
    visible: true
    minimumWidth: 420
    minimumHeight: 420
    width: 520
    height: 640
    transientParent: widget.NVG.View.window
    onClosing: destroy()

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
                        Layout.alignment: Qt.AlignHCenter

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
