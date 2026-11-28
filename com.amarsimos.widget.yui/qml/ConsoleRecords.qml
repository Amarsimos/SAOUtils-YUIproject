import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// System Console, Records (moved from Mental Health Counseling): what Yui recorded (the daily moods of
// the last 30 days) and wrote (weekly reports). Daily Mood Check and Weekly Report are set in Mental
// Health Counseling, Care.
SettingsPage {
    id: records

    property var yui
    // The moods of the last 30 days, oldest first (refreshed when one is recorded), and the reports
    // written, newest first.
    property var moods: []
    property var reports: []

    function refreshReports() {
        reports = yui.reportsList();
    }

    function refreshMoods() {
        moods = yui.moodsSince(30);
    }

    Component.onCompleted: {
        refreshMoods();
        refreshReports();
    }

    Connections {
        target: records.yui
        onMoodRevisionChanged: records.refreshMoods()
        onReportRevisionChanged: records.refreshReports()
    }

    Heading {
        text: qsTr("Mental Record")
    }

    SettingNote {
        visible: records.yui.settingsHelp
        besidePreferences: true
        text: qsTr("Yui asks how you feel once a day and keeps it here (5 best, 1 worst); after a few low days she cares more. Daily Mood Check (Mental Health Counseling, Care) turns it on or off.")
    }

    // The last 30 days: one point a recorded day (score 1–5), joined day by day.
    Canvas {
        id: moodChart

        readonly property var moods: records.moods

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
        visible: records.moods.length === 0
        opacity: 0.7
        text: qsTr("No moods recorded in the last 30 days.")
    }

    // Newest first; ✕ deletes a day's record.
    Repeater {
        model: records.moods.slice().reverse()

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
                onClicked: records.yui.askConfirm(qsTr("System Console"), qsTr("Delete the mood of %1?").arg(modelData.day), function() {
                    records.yui.deleteMood(modelData.day);
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
            text: records.yui.writingReport ? qsTr("Writing...") : qsTr("Write This Week's Report")
            enabled: !records.yui.writingReport
            onClicked: records.yui.writeWeeklyReport(false, function(error) {
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
        visible: records.reports.length === 0
        opacity: 0.7
        text: qsTr("No reports yet.")
    }

    Repeater {
        model: records.reports

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
                    onClicked: records.yui.askConfirm(qsTr("System Console"), qsTr("Delete the report of %1?").arg(modelData.week), function() {
                        records.yui.deleteReport(modelData.id);
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
