import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// System Console, Records (as the preview; moved from Mental Health Counseling): Mood · 30 days, a
// square a day colored by the mood Yui recorded (hover: the day and its note; click: delete it), and
// the Weekly Reports Yui wrote. Daily Mood Check and Weekly Report are set in Mental Health
// Counseling, Care.
ConsolePage {
    id: records

    property var yui
    // The moods recorded in the last 30 days, oldest first, also by day ("yyyy-MM-dd": entry), and
    // the reports, newest first.
    property var moods: []
    readonly property var moodByDay: {
        var byDay = {};
        moods.forEach(function(entry) {
            byDay[entry.day] = entry;
        });
        return byDay;
    }
    property var reports: []
    property string reportError: ""
    // Score 1-5 to color: low, tired, calm, good, good.
    readonly property var moodColors: ["#C82864", "#F1AA03", "#4BB4EC", "#7CC63E", "#7CC63E"]

    function refreshMoods() {
        moods = yui.moodsSince(30);
    }

    function refreshReports() {
        reports = yui.reportsList();
    }

    // The last 30 days, oldest first, as "yyyy-MM-dd".
    function days() {
        var list = [];
        var day = new Date();
        day.setHours(12, 0, 0, 0);
        for (var i = 29; i >= 0; i--)
            list.push(Qt.formatDate(new Date(day.getTime() - i * 86400000), "yyyy-MM-dd"));

        return list;
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

    ConsolePanel {
        Layout.fillWidth: true
        title: "Mood · 30 days"
        note: qsTr("recorded by Yui")

        GridLayout {
            id: moodGrid

            Layout.fillWidth: true
            columns: 15
            columnSpacing: 5
            rowSpacing: 5

            Repeater {
                model: records.days()

                Rectangle {
                    readonly property var entry: records.moodByDay[modelData] || null

                    Layout.fillWidth: true
                    Layout.preferredHeight: width
                    color: entry ? records.moodColors[Math.max(1, Math.min(5, entry.score)) - 1] : "#DDDDDD"
                    border.color: dayArea.containsMouse ? "#4D4D4D" : "transparent"

                    MouseArea {
                        id: dayArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.entry ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            var entry = parent.entry;
                            if (entry)
                                records.yui.askConfirm(qsTr("System Console"), qsTr("Delete the mood of %1?").arg(entry.day), function() {
                                    records.yui.deleteMood(entry.day);
                                }, true);

                        }
                    }

                    ToolTip.visible: dayArea.containsMouse
                    ToolTip.text: modelData.slice(5).replace("-", "/") + (entry ? "  " + "★★★★★".slice(0, entry.score) + (entry.note ? "\n" + entry.note : "") : "  " + qsTr("not recorded"))
                }

            }

        }

        // The legend.
        Row {
            Layout.topMargin: 4
            spacing: 12

            Repeater {
                model: [[qsTr("Good"), "#7CC63E"], [qsTr("Calm"), "#4BB4EC"], [qsTr("Tired"), "#F1AA03"], [qsTr("Low"), "#C82864"], [qsTr("Not recorded"), "#DDDDDD"]]

                Row {
                    spacing: 4

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: modelData[1]
                    }

                    Text {
                        font.family: Yui.fontFor(text)
                        text: modelData[0]
                        font.pixelSize: 12
                        color: "#7A7A7A"
                    }

                }

            }

        }

    }

    ConsolePanel {
        Layout.fillWidth: true
        title: "Weekly Reports"
        tools: [
            ConsoleChip {
                small: true
                enabled: !records.yui.writingReport
                text: records.yui.writingReport ? "Writing..." : "Write This Week's"
                onClicked: records.yui.writeWeeklyReport(false, function(error) {
                    records.reportError = error;
                })
            }
        ]

        Text {
            font.family: Yui.fontFor(text)
            Layout.fillWidth: true
            visible: records.reportError !== ""
            text: records.reportError
            wrapMode: Text.Wrap
            font.pixelSize: 12
            color: "#C82864"
        }

        Text {
            font.family: Yui.fontFor(text)
            visible: records.reports.length === 0
            text: qsTr("No reports yet.")
            font.pixelSize: 13
            color: "#7A7A7A"
        }

        Repeater {
            model: records.reports

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: modelData.week
                        font.family: Yui.fontFor(text)
                        font.pixelSize: 15
                        color: "#4D4D4D"
                    }

                    ConsoleChip {
                        small: true
                        text: "✕"
                        onClicked: records.yui.askConfirm(qsTr("System Console"), qsTr("Delete the report of %1?").arg(modelData.week), function() {
                            records.yui.deleteReport(modelData.id);
                        }, true)
                    }

                }

                // Read-only but selectable, so a part can be copied.
                TextEdit {
                    font.family: Yui.messageFont
                    Layout.fillWidth: true
                    readOnly: true
                    selectByMouse: true
                    wrapMode: Text.Wrap
                    selectionColor: "#F59B00"
                    font.pixelSize: 13
                    color: "#333333"
                    text: modelData.text
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    height: 1
                    color: "#E9E9E9"
                    visible: index < records.reports.length - 1
                }

            }

        }

    }

}
