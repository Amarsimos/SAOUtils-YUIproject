import NERvGear.Preferences 1.0
import NERvGear.Templates 1.0 as T
import QtQml 2.12
import "../link" 1.0 as Link

// One category of MHCP-YUI's SAO Utils actions (ChatAction.qml, RaidAction.qml...): talks to the
// running Yui through Link.Server. commands: [{id, name, uses, hint}]; uses: the settings shown for
// it ("text", "minutes", "score", "slot"), hint: for its text. configuration: {command (index into
// commands), text, minutes, score, slot}.
T.Action {
    id: action

    // New commands go at the end of a category: a bound action keeps the index of its command.
    property var commands: []
    readonly property int shown: configuration && configuration.command !== undefined ? configuration.command : 0

    description: title
    label: commands.length > 1 && commands[shown] ? title + " · " + commands[shown].name : title
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
            visible: action.commands.length > 1
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
