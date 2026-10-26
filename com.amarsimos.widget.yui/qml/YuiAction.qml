import NERvGear.Preferences 1.0
import NERvGear.Templates 1.0 as T
import QtQml 2.12
import "link" 1.0 as Link

// MHCP-YUI as a SAO Utils action (launcher menu, Quick Menu, HUD buttons, shortcuts): talks to the
// running Yui through Link.Server. configuration: {command (index into commands), text, minutes,
// score, slot}; which of them a command uses is in its entry below.
T.Action {
    id: action

    // New commands go at the end: a bound action keeps the index of its command.
    // uses: the settings shown for it ("text", "minutes", "score", "slot"); hint: for its text.
    readonly property var commands: [{
        "id": "chat",
        "name": qsTr("Open Chat"),
        "uses": ["text"],
        "hint": qsTr("Sent to Yui when the chat opens (optional)")
    }, {
        "id": "speak",
        "name": qsTr("Spontaneous Talk")
    }, {
        "id": "raid",
        "name": qsTr("Start / End Boss Raid")
    }, {
        "id": "cardinal",
        "name": qsTr("Cardinal System")
    }, {
        "id": "equipment",
        "name": qsTr("Equipment")
    }, {
        "id": "heart",
        "name": qsTr("Yui's Heart")
    }, {
        "id": "counseling",
        "name": qsTr("Mental Health Counseling")
    }, {
        "id": "console",
        "name": qsTr("System Console")
    }, {
        "id": "skills",
        "name": qsTr("Skill Slots")
    }, {
        "id": "start_raid",
        "name": qsTr("Start Boss Raid"),
        "uses": ["minutes"]
    }, {
        "id": "end_raid",
        "name": qsTr("End Boss Raid")
    }, {
        "id": "add_reminder",
        "name": qsTr("Add Reminder"),
        "uses": ["text"],
        "hint": qsTr("time|text, e.g. +30|Drink water, 08:00|Meeting, 每天 23:00|Sleep")
    }, {
        "id": "dismiss_reminder",
        "name": qsTr("Remove Next Reminder")
    }, {
        "id": "add_note",
        "name": qsTr("Add Note"),
        "uses": ["text"],
        "hint": qsTr("What to note down")
    }, {
        "id": "finish_note",
        "name": qsTr("Finish First Note")
    }, {
        "id": "record_mood",
        "name": qsTr("Record Mood"),
        "uses": ["score", "text"],
        "hint": qsTr("A note (optional)")
    }, {
        "id": "weekly_report",
        "name": qsTr("Write Weekly Report")
    }, {
        "id": "sword_skill",
        "name": qsTr("Run Sword Skill"),
        "uses": ["slot"]
    }]
    readonly property int shown: configuration && configuration.command !== undefined ? configuration.command : 0

    title: qsTr("MHCP-YUI")
    description: qsTr("Talk to Yui, start a Boss Raid, add reminders and notes, record your mood or open her windows.")
    label: title + " · " + (commands[shown] ? commands[shown].name : "")
    execute: function() {
        return new Promise(function(resolve, reject) {
            var yui = Link.Server.yui;
            var command = action.commands[action.shown];
            if (!yui || !command || !yui.runCommand(command.id, configuration ? configuration.text || "" : "", configuration || {}))
                return reject();

            resolve();
        });
    }

    preference: PreferenceGroup {
        SelectPreference {
            id: commandPreference

            readonly property var uses: action.commands[value] && action.commands[value].uses || []

            name: "command"
            label: qsTr("Command")
            model: action.commands.map(function(command) {
                return command.name;
            })
            defaultValue: 0
        }

        TextFieldPreference {
            name: "text"
            label: qsTr("Text")
            hint: action.commands[commandPreference.value] && action.commands[commandPreference.value].hint || ""
            visible: commandPreference.uses.indexOf("text") !== -1
        }

        SpinPreference {
            name: "minutes"
            label: qsTr("Minutes")
            display: TextFieldPreference.ExpandLabel
            editable: true
            from: 0
            to: 180
            stepSize: 5
            defaultValue: 0
            visible: commandPreference.uses.indexOf("minutes") !== -1
        }

        SpinPreference {
            name: "score"
            label: qsTr("Mood (1–5)")
            display: TextFieldPreference.ExpandLabel
            from: 1
            to: 5
            stepSize: 1
            defaultValue: 3
            visible: commandPreference.uses.indexOf("score") !== -1
        }

        SpinPreference {
            name: "slot"
            label: qsTr("Slot")
            display: TextFieldPreference.ExpandLabel
            from: 1
            to: 5
            stepSize: 1
            defaultValue: 1
            visible: commandPreference.uses.indexOf("slot") !== -1
        }

    }

}
