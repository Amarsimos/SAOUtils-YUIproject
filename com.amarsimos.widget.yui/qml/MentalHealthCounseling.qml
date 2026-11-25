import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// "Mental Health Counseling" window (next to Cardinal System, Equipment, Yui's Heart and System Console):
// Yui's own task as MHCP-001, caring for the player. The settings are grouped by what they do:
// Companion (greetings, speaking up by herself, standby, the weather), Care (rest reminders, the daily mood
// check, the Sunday report) and Bond (birthday and the day of meeting); Records holds no settings, only
// what was recorded (the daily moods, Yui's weekly reports), to become a window of its own later.
// The settings are SAO Utils' own preferences synced with the widget's settings (ObjectPreferenceGroup),
// taking effect at once; Reset restores the settings only, never the moods or the reports.
NVG.Window {
    id: counselingWindow

    property var targetWidget
    // Records: the moods of the last 30 days, oldest first (refreshed when one is recorded), and the
    // reports written, newest first.
    property var moods: []
    property var reports: []
    // The settings of each tab, for Reset This Tab and the title bar's Reset.
    readonly property var companionPreferences: [greetPreference, spontaneousPreference, weatherPreference, weatherDataPreference, temperatureDataPreference, nowPlayingPreference]
    readonly property var carePreferences: [careLevelPreference, quietPreference, quietFromPreference, quietToPreference, carePreference, followupsPreference, moodPreference, weeklyPreference]
    readonly property var bondPreferences: [birthdayPreference, meetingPreference]

    function refreshReports() {
        reports = targetWidget.reportsList();
    }

    function refreshMoods() {
        moods = targetWidget.moodsSince(30);
    }

    title: qsTr("Mental Health Counseling")
    visible: true
    minimumWidth: 420
    minimumHeight: 420
    width: 520
    height: 720
    transientParent: widget.NVG.View.window
    onClosing: destroy()
    Component.onCompleted: {
        refreshMoods();
        refreshReports();
    }

    Connections {
        target: counselingWindow.targetWidget
        onMoodRevisionChanged: counselingWindow.refreshMoods()
        onReportRevisionChanged: counselingWindow.refreshReports()
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

                model: [qsTr("Companion"), qsTr("Care"), qsTr("Bond"), qsTr("Records")]
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabs.shownIndex

                // ---------------------------------------------------------------- Companion
                // Under headings: Greeting, Presence (talking up and standby), Weather.
                SettingsPage {
                    P.ObjectPreferenceGroup {
                        id: companionGroup

                        Layout.fillWidth: true
                        defaultValue: counselingWindow.targetWidget.settings
                        syncProperties: true

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
                            text: qsTr("Yui greets you when you return: good morning on the first morning of a day, long time no see after three days or more, otherwise welcome back after half an hour.")
                        }

                        Heading {
                            text: qsTr("Presence")
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
                            text: qsTr("While the chat is closed, Yui sometimes speaks up by herself (uses the API). How often follows Care Level (Care tab).")
                        }

                        // Standby has no setting: Yui falls asleep when what she says by herself goes
                        // unanswered twice (the user seems away), and wakes on any interaction.
                        SettingNote {
                            visible: counselingWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("When two things Yui says by herself go unanswered, she takes you to be away and falls asleep (Standby) until you click her or write to her.")
                        }

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
                            text: qsTr("Yui mentions the weather in her morning greeting (and an umbrella when it rains) and answers weather questions with it. Choose the values below, e.g. Weather Data → General Data → Weather Forecast and Current Temperature, and set the place there.")
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
                        tabTitle: qsTr("Companion")
                        preferences: counselingWindow.companionPreferences
                        groups: [companionGroup]
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
                            text: qsTr("Reminders")
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

                // ---------------------------------------------------------------- Records
                // No settings: what Yui recorded (moods) and wrote (weekly reports).
                SettingsPage {
                    Heading {
                        text: qsTr("Mental Record")
                    }

                    SettingNote {
                        visible: counselingWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Yui asks how you feel once a day and keeps it here (5 best, 1 worst); after a few low days she cares more. Daily Mood Check on the Care tab turns it on or off.")
                    }

                    // The last 30 days: one point a recorded day (score 1–5), joined day by day.
                    Canvas {
                        id: moodChart

                        readonly property var moods: counselingWindow.moods

                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.preferredHeight: 140
                        onMoodsChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var left = 18, top = 8, right = width - 4, bottom = height - 18;
                            var y = function(score) {
                                return bottom - (score - 1) / 4 * (bottom - top);
                            };
                            var day0 = new Date();
                            day0.setHours(0, 0, 0, 0);
                            var x = function(day) {
                                var parts = day.split("-");
                                var date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
                                var back = Math.round((day0 - date) / 86400000);
                                return right - back / 29 * (right - left);
                            };
                            ctx.font = "10px sans-serif";
                            ctx.fillStyle = "#88888888";
                            ctx.strokeStyle = "#33888888";
                            ctx.lineWidth = 1;
                            for (var score = 1; score <= 5; score++) {
                                ctx.beginPath();
                                ctx.moveTo(left, y(score));
                                ctx.lineTo(right, y(score));
                                ctx.stroke();
                                ctx.fillText(String(score), 4, y(score) + 3);
                            }
                            ctx.fillText(qsTr("30 days ago"), left, height - 4);
                            ctx.fillText(qsTr("today"), right - 26, height - 4);
                            if (moods.length === 0)
                                return ;

                            ctx.strokeStyle = "#F59B00";
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            moods.forEach(function(entry, i) {
                                if (i === 0)
                                    ctx.moveTo(x(entry.day), y(entry.score));
                                else
                                    ctx.lineTo(x(entry.day), y(entry.score));
                            });
                            ctx.stroke();
                            ctx.fillStyle = "#F59B00";
                            moods.forEach(function(entry) {
                                ctx.beginPath();
                                ctx.arc(x(entry.day), y(entry.score), 3, 0, Math.PI * 2);
                                ctx.fill();
                            });
                        }
                    }

                    Label {
                        Layout.leftMargin: 16
                        visible: counselingWindow.moods.length === 0
                        opacity: 0.7
                        text: qsTr("No moods recorded in the last 30 days.")
                    }

                    // Newest first; ✕ deletes a day's record.
                    Repeater {
                        model: counselingWindow.moods.slice().reverse()

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16

                            Label {
                                text: modelData.day
                            }

                            Label {
                                color: "#F59B00"
                                text: "★★★★★".slice(0, modelData.score) + "☆☆☆☆☆".slice(0, 5 - modelData.score)
                            }

                            Label {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: modelData.note || ""
                            }

                            ToolButton {
                                text: "✕"
                                onClicked: counselingWindow.targetWidget.askConfirm(qsTr("Mental Health Counseling"), qsTr("Delete the mood of %1?").arg(modelData.day), function() {
                                    counselingWindow.targetWidget.deleteMood(modelData.day);
                                }, true)
                            }

                        }

                    }

                    Heading {
                        text: qsTr("Weekly Report")
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter

                        Button {
                            text: counselingWindow.targetWidget.writingReport ? qsTr("Writing...") : qsTr("Write This Week's Report")
                            enabled: !counselingWindow.targetWidget.writingReport
                            onClicked: counselingWindow.targetWidget.writeWeeklyReport(false, function(error) {
                                reportMessage.text = error;
                            })
                        }

                    }

                    Label {
                        id: reportMessage

                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        color: "#E53935"
                    }

                    Label {
                        Layout.leftMargin: 16
                        visible: counselingWindow.reports.length === 0
                        opacity: 0.7
                        text: qsTr("No reports yet.")
                    }

                    Repeater {
                        model: counselingWindow.reports

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    Layout.fillWidth: true
                                    font.bold: true
                                    text: modelData.week
                                }

                                ToolButton {
                                    text: "✕"
                                    onClicked: counselingWindow.targetWidget.askConfirm(qsTr("Mental Health Counseling"), qsTr("Delete the report of %1?").arg(modelData.week), function() {
                                        counselingWindow.targetWidget.deleteReport(modelData.id);
                                    }, true)
                                }

                            }

                            // Read-only but selectable, so a part can be copied.
                            TextArea {
                                Layout.fillWidth: true
                                readOnly: true
                                selectByMouse: true
                                wrapMode: Text.Wrap
                                background: null
                                text: modelData.text
                            }

                        }

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
                counselingWindow.companionPreferences.concat(counselingWindow.carePreferences, counselingWindow.bondPreferences).forEach(function(preference) {
                    preference.load();
                });
                companionGroup.save();
                careGroup.save();
                bondGroup.save();
            }
        }

    }

}
