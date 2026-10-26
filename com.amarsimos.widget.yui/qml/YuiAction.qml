import NERvGear.Preferences 1.0
import NERvGear.Templates 1.0 as T
import QtQml 2.12
import "link" 1.0 as Link

// MHCP-YUI as a SAO Utils action (launcher, menus, buttons of other widgets, shortcuts): talks to the
// running Yui through Link.Server. command is one of the ids below; text goes with "chat".
T.Action {
    id: action

    // New commands go at the end: a bound action keeps the index of its command.
    readonly property var commands: ["chat", "speak", "raid", "cardinal", "equipment", "heart", "counseling", "console", "skills"]

    title: qsTr("MHCP-YUI")
    description: qsTr("Talk to Yui, start a Boss Raid or open her windows.")
    label: {
        var index = configuration && configuration.command !== undefined ? configuration.command : 0;
        return title + " · " + commandNames[index];
    }
    readonly property var commandNames: [qsTr("Open Chat"), qsTr("Spontaneous Talk"), qsTr("Start / End Boss Raid"), qsTr("Cardinal System"), qsTr("Equipment"), qsTr("Yui's Heart"), qsTr("Mental Health Counseling"), qsTr("System Console"), qsTr("Skill Slots")]
    execute: function() {
        return new Promise(function(resolve, reject) {
            var yui = Link.Server.yui;
            var index = configuration && configuration.command !== undefined ? configuration.command : 0;
            if (!yui || !yui.runCommand(action.commands[index] || "chat", configuration ? configuration.text || "" : ""))
                return reject();

            resolve();
        });
    }

    preference: PreferenceGroup {
        SelectPreference {
            id: commandPreference

            name: "command"
            label: qsTr("Command")
            model: action.commandNames
            defaultValue: 0
        }

        TextFieldPreference {
            name: "text"
            label: qsTr("Message")
            hint: qsTr("Sent to Yui when the chat opens (optional)")
            visible: commandPreference.value === 0
        }

    }

}
