import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// "Mental Health Counseling" window (next to Cardinal System, Equipment, Yui's Heart and System Authority):
// Yui's own task as MHCP-001, caring for the player. The settings are grouped by what they are about:
// Perception (what she knows of right now: the weather, the song), Care (when she speaks up by herself:
// how often, greetings, small talk, well-being, your days, reports) and Bond (birthday and the day of
// meeting). What was recorded (the daily moods, Yui's weekly reports) is shown in System Console, Records.
// The settings are SAO Utils' own preferences synced with the widget's settings (ObjectPreferenceGroup),
// taking effect at once; Reset restores the settings only, never the moods or the reports.
NVG.Window {
    id: counselingWindow

    property var targetWidget
    // The settings of each tab, for Reset This Tab and the title bar's Reset.
    readonly property var perceptionPreferences: [weatherPreference, weatherDataPreference, temperatureDataPreference, nowPlayingPreference]
    readonly property var carePreferences: [careLevelPreference, quietPreference, quietFromPreference, quietToPreference, greetPreference, spontaneousPreference, carePreference, moodPreference, moodCarePreference, followupsPreference, weatherChangesPreference, weeklyPreference]
    readonly property var bondPreferences: [birthdayPreference, meetingPreference]

    title: qsTr("Mental Health Counseling")
    visible: true
    minimumWidth: 420
    minimumHeight: 420
    width: 520
    height: 720
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

                model: [qsTr("Perception"), qsTr("Care"), qsTr("Bond")]
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabs.shownIndex

                // ---------------------------------------------------------------- Perception
                // What Yui knows of right now, under headings: Weather, Music.
                SettingsPage {
                    P.ObjectPreferenceGroup {
                        id: perceptionGroup

                        Layout.fillWidth: true
                        defaultValue: counselingWindow.targetWidget.settings
                        syncProperties: true

                        Heading {
                            text: qsTr("Weather")
                        }

                        P.SwitchPreference {
                            id: weatherPreference

                            name: "weather_report"
                            label: qsTr("Weather Report")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui always knows the weather now: she mentions it in her morning greeting (and an umbrella when it rains), answers weather questions with it, and may care about it when it fits. Choose the values below, e.g. Weather Data → General Data → Weather Forecast and Current Temperature, and set the place there.")
                        }

                        P.DataPreference {
                            id: weatherDataPreference

                            name: "weather_data"
                            label: qsTr("Weather")
                            visible: weatherPreference.value
                        }

                        P.DataPreference {
                            id: temperatureDataPreference

                            name: "weather_temperature"
                            label: qsTr("Temperature")
                            visible: weatherPreference.value
                        }

                        Heading {
                            text: qsTr("Music")
                        }

                        P.SwitchPreference {
                            id: nowPlayingPreference

                            name: "now_playing"
                            label: qsTr("Now Playing")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui knows the song you are listening to and can talk about it, without bringing it up when it does not fit. It reads the system media through the Media Player package (com.gpbeta.media).")
                        }

                        // Shown whatever Help says: without the package this does nothing.
                        SettingNote {
                            visible: nowPlayingPreference.value && !counselingWindow.targetWidget.mediaLoaded
                            besidePreferences: true
                            text: qsTr("Media Player (com.gpbeta.media) was not found, so this does nothing.")
                        }

                    }

                    ResetTabButton {
                        yui: counselingWindow.targetWidget
                        windowTitle: counselingWindow.title
                        tabTitle: qsTr("Perception")
                        preferences: counselingWindow.perceptionPreferences
                        groups: [perceptionGroup]
                    }

                }

                // ---------------------------------------------------------------- Care
                SettingsPage {
                    P.ObjectPreferenceGroup {
                        id: careGroup

                        Layout.fillWidth: true
                        defaultValue: counselingWindow.targetWidget.settings
                        syncProperties: true

                        Heading {
                            text: qsTr("Frequency")
                        }

                        // Kept as its index (0 Auto, 1 Quiet, 2 Normal, 3 Chatty).
                        P.SelectPreference {
                            id: careLevelPreference

                            name: "care_level"
                            defaultValue: 0
                            label: qsTr("Care Level")
                            model: [qsTr("Auto"), qsTr("Quiet"), qsTr("Normal"), qsTr("Chatty")]
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("How often Yui speaks up by herself (care, reminders, small talk). Auto learns it from you: answering her or opening the chat makes her talk a little more, closing her bubble or leaving it unanswered a little less, and telling her to be quiet or to talk more counts the most. Greetings, follow-ups and system warnings are always said.")
                        }

                        // What Auto has learned, and a way back to the start.
                        Label {
                            visible: careLevelPreference.value === 0
                            Layout.fillWidth: true
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            wrapMode: Text.Wrap
                            font.pixelSize: 12
                            text: {
                                var settings = counselingWindow.targetWidget.settings;
                                var budget = Yui.careBudget(Yui.careScore("auto", settings.care_score));
                                var hours = Yui.careLikedHours(settings.care_hours);
                                return qsTr("Learned: about %1 a day, at least %2 min apart").arg(budget.perDay).arg(budget.gapMinutes) + (hours.length > 0 ? qsTr("; you answer most at %1").arg(hours.join(", ")) : "");
                            }
                        }

                        CenteredFlow {
                            visible: careLevelPreference.value === 0

                            Button {
                                text: qsTr("Reset Learning")
                                onClicked: {
                                    counselingWindow.targetWidget.settings.care_score = 0.5;
                                    counselingWindow.targetWidget.settings.care_hours = [];
                                }
                            }

                        }

                        P.SwitchPreference {
                            id: quietPreference

                            name: "quiet_hours"
                            defaultValue: true
                            label: qsTr("Quiet Hours")
                        }

                        // SAO Utils' own time pickers; only the time of day counts.
                        P.TimePreference {
                            id: quietFromPreference

                            visible: quietPreference.value
                            name: "quiet_from"
                            defaultValue: new Date(2000, 0, 1, 0, 0)
                            label: qsTr("From")
                        }

                        P.TimePreference {
                            id: quietToPreference

                            visible: quietPreference.value
                            name: "quiet_to"
                            defaultValue: new Date(2000, 0, 1, 8, 0)
                            label: qsTr("To")
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("In these hours Yui makes no small talk. Late-night care still comes, as it only does while you are at the computer.")
                        }

                        Heading {
                            text: qsTr("Greeting")
                        }

                        P.SwitchPreference {
                            id: greetPreference

                            name: "greet_on_start"
                            defaultValue: true
                            label: qsTr("Login Greeting")
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui greets you when you return, at start-up or when you wake her up: good morning on the first morning of a day, long time no see after two days or more, otherwise welcome back after half an hour.")
                        }

                        Heading {
                            text: qsTr("Small Talk")
                        }

                        P.SwitchPreference {
                            id: spontaneousPreference

                            name: "spontaneous_talk"
                            defaultValue: true
                            label: qsTr("Spontaneous Talk")
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("While the chat is closed, Yui sometimes speaks up by herself (uses the API), often starting from something of right now. How often follows Care Level above.")
                        }

                        // Standby has no setting: Yui falls asleep when what she says by herself goes
                        // unanswered twice (the user seems away), and wakes on any interaction.
                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("When two things Yui says by herself go unanswered, she takes you to be away and falls asleep (Standby) until you click her or write to her.")
                        }

                        Heading {
                            text: qsTr("Well-being")
                        }

                        P.SwitchPreference {
                            id: carePreference

                            name: "proactive_care"
                            defaultValue: true
                            label: qsTr("Rest Reminders")
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui reminds you to sleep late at night and to rest after long sessions, as often as Care Level allows.")
                        }

                        P.SwitchPreference {
                            id: moodPreference

                            name: "daily_mood"
                            defaultValue: true
                            label: qsTr("Daily Mood Check")
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Once a day Yui asks how you feel and records it (Mental Record); after a few low days she cares more.")
                        }

                        P.SwitchPreference {
                            id: moodCarePreference

                            name: "mood_care"
                            defaultValue: true
                            label: qsTr("Mood Care")
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("When your last three moods were low (Daily Mood Check), Yui gently asks if you want to talk, once a day at most (09:00–22:00).")
                        }

                        Heading {
                            text: qsTr("Your Days")
                        }

                        P.SwitchPreference {
                            id: followupsPreference

                            name: "followups"
                            defaultValue: true
                            label: qsTr("Follow-ups")
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("When Yui remembers something with a date to come (an exam, an interview), she cheers you on that day and asks how it went in the week after (08:00–22:00). See them in Yui's Heart, Follow-ups.")
                        }

                        P.SwitchPreference {
                            id: weatherChangesPreference

                            name: "weather_changes"
                            defaultValue: true
                            label: qsTr("Weather Changes")
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("When it starts to rain or snow, or gets 5° colder within three hours, Yui tells you (an umbrella, something warm; 07:00–22:00). Needs Weather Report's values (Perception).")
                        }

                        Heading {
                            text: qsTr("Reports")
                        }

                        P.SwitchPreference {
                            id: weeklyPreference

                            name: "weekly_report"
                            label: qsTr("Sunday Report")
                            defaultValue: false
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui looks back on the last seven days (chats, moods, Boss Raids, finished to-dos) and writes you a few words about your week (one request to the AI). Sunday Report writes it by itself on Sunday evenings.")
                        }

                    }

                    ResetTabButton {
                        yui: counselingWindow.targetWidget
                        windowTitle: counselingWindow.title
                        tabTitle: qsTr("Care")
                        preferences: counselingWindow.carePreferences
                        groups: [careGroup]
                    }

                }

                // ---------------------------------------------------------------- Bond
                SettingsPage {
                    P.ObjectPreferenceGroup {
                        id: bondGroup

                        Layout.fillWidth: true
                        defaultValue: counselingWindow.targetWidget.settings
                        syncProperties: true

                        P.TextFieldPreference {
                            id: birthdayPreference

                            name: "player_birthday"
                            label: qsTr("Player Birthday")
                            display: P.TextFieldPreference.ExpandLabel
                            hint: "MM-DD"
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("On your birthday Yui wishes you a happy birthday (MM-DD, or yyyy-MM-dd).")
                        }

                        P.TextFieldPreference {
                            id: meetingPreference

                            name: "meeting_day"
                            label: qsTr("Meeting Day")
                            display: P.TextFieldPreference.ExpandLabel
                            hint: "yyyy-MM-dd"
                        }

                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("The day you met Yui (the first day she ran, unless you set another, yyyy-MM-dd); she remembers each anniversary.")
                        }

                    }

                    ResetTabButton {
                        yui: counselingWindow.targetWidget
                        windowTitle: counselingWindow.title
                        tabTitle: qsTr("Bond")
                        preferences: counselingWindow.bondPreferences
                        groups: [bondGroup]
                    }

                }

            }

        }

        // Reset: the settings of every tab, never the moods or the reports.
        header: SettingsTitleBar {
            yui: counselingWindow.targetWidget
            settingsWindow: counselingWindow
            // load() is no edit, so the synced groups write the defaults to the settings by save().
            onResetRequested: {
                counselingWindow.perceptionPreferences.concat(counselingWindow.carePreferences, counselingWindow.bondPreferences).forEach(function(preference) {
                    preference.load();
                });
                perceptionGroup.save();
                careGroup.save();
                bondGroup.save();
            }
        }

    }

}
