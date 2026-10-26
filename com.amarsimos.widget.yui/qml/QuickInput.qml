import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// A small window at the cursor for what an action needs each time (main-stand's openQuickInput):
// "alarm" (what and when, with +10 / +30 / +60 minutes at hand), "note" (what to note down), "mood"
// (1–5 stars and an optional note) or "raid" (how long). Enter confirms, Esc or clicking elsewhere
// closes it; "Ask Yui" opens the chat with the start of a message instead, for what the boxes cannot
// take.
NVG.Window {
    id: quick

    property var targetWidget
    property string mode: "note"

    // Shows the window for mode at the cursor, with the first box focused.
    function start(newMode) {
        mode = newMode;
        var cursor = NVG.Utils.cursorPosition();
        x = cursor.x - width / 2;
        y = cursor.y - 24;
        requestActivate();
        Qt.callLater(function() {
            if (mode === "alarm")
                alarmText.forceActiveFocus();
            else if (mode === "note")
                noteText.forceActiveFocus();
            else if (mode === "mood")
                moodNote.forceActiveFocus();
        });
    }

    function finish(done) {
        if (done)
            close();
        else
            message.text = mode === "alarm" ? qsTr("Write what to remind of, and the time as 08:00, 明天 08:00, 周五 15:00, 每天 23:00 or +30.") : qsTr("Write something first.");
    }

    function addAlarm(time) {
        finish(targetWidget.quickAlarm(time, alarmText.text));
    }

    function askYui() {
        var starts = {
            "alarm": "提醒我 ",
            "note": "帮我记一下：",
            "mood": "我今天的心情：",
            "raid": "陪我专注 "
        };
        targetWidget.prefillChat(starts[mode] + (mode === "alarm" ? alarmText.text : mode === "note" ? noteText.text : mode === "mood" ? moodNote.text : ""));
        close();
    }

    title: ({
        "alarm": qsTr("Alarm"),
        "note": qsTr("Quest Log"),
        "mood": qsTr("Mental Record"),
        "raid": qsTr("Boss Raid")
    })[mode] || qsTr("MHCP-YUI")
    visible: true
    width: 380
    height: page.implicitHeight
    minimumWidth: 300
    onActiveChanged: {
        if (!active)
            close();

    }
    onClosing: destroy()

    Page {
        id: page

        anchors.fill: parent
        implicitHeight: header.implicitHeight + content.implicitHeight + 28

        Shortcut {
            sequence: "Esc"
            onActivated: quick.close()
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ---------------------------------------------------------------- Alarm
            TextField {
                id: alarmText

                Layout.fillWidth: true
                visible: quick.mode === "alarm"
                placeholderText: qsTr("Remind me of…")
                selectByMouse: true
                onAccepted: quick.addAlarm(alarmTime.text.trim())
            }

            RowLayout {
                Layout.fillWidth: true
                visible: quick.mode === "alarm"

                Repeater {
                    model: [10, 30, 60]

                    Button {
                        text: "+" + modelData
                        onClicked: quick.addAlarm("+" + modelData)
                    }

                }

                TextField {
                    id: alarmTime

                    Layout.fillWidth: true
                    placeholderText: qsTr("08:00 / 明天 8:00 / 周五 15:00")
                    selectByMouse: true
                    onAccepted: quick.addAlarm(text.trim())
                }

            }

            // ---------------------------------------------------------------- Quest Log
            TextField {
                id: noteText

                Layout.fillWidth: true
                visible: quick.mode === "note"
                placeholderText: qsTr("Something to note down")
                selectByMouse: true
                onAccepted: quick.finish(quick.targetWidget.quickNote(text))
            }

            // ---------------------------------------------------------------- Mental Record
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: quick.mode === "mood"

                Repeater {
                    model: 5

                    Button {
                        flat: true
                        font.pixelSize: 22
                        text: "★"
                        palette.buttonText: hovered ? "#F59B00" : "#88888888"
                        ToolTip.visible: hovered
                        ToolTip.text: String(index + 1)
                        onClicked: quick.finish(quick.targetWidget.quickMood(index + 1, moodNote.text))
                    }

                }

            }

            TextField {
                id: moodNote

                Layout.fillWidth: true
                visible: quick.mode === "mood"
                placeholderText: qsTr("A note (optional), then a star")
                selectByMouse: true
            }

            // ---------------------------------------------------------------- Boss Raid
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: quick.mode === "raid"

                Repeater {
                    model: [15, 25, 45, 60]

                    Button {
                        text: qsTr("%1 min").arg(modelData)
                        onClicked: {
                            quick.targetWidget.startRaid(modelData, true);
                            quick.close();
                        }
                    }

                }

            }

            Label {
                id: message

                Layout.fillWidth: true
                visible: text !== ""
                wrapMode: Text.Wrap
                color: "#E53935"
            }

            RowLayout {
                Layout.fillWidth: true

                // What the boxes cannot take ("下周一下午三点"): Yui understands it in the chat.
                Button {
                    flat: true
                    text: qsTr("Ask Yui")
                    onClicked: quick.askYui()
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    visible: quick.mode === "alarm" || quick.mode === "note"
                    highlighted: true
                    text: qsTr("Add")
                    onClicked: quick.mode === "alarm" ? quick.addAlarm(alarmTime.text.trim()) : quick.finish(quick.targetWidget.quickNote(noteText.text))
                }

            }

        }

        header: TitleBar {
            text: quick.title
        }

    }

}
