import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// A Seedling widget's own settings (its code's @setting declarations, props.js), in the style of
// MHCP-YUI's settings windows: one SAO Utils preference per declaration, in their order, each change
// given to the widget at once. Reset: the code's defaults again. Clear Kept Data (when it has @keep):
// what the widget remembered goes.
NVG.Window {
    id: settingsWindow

    property var targetWidget
    readonly property var decl: targetWidget.shownDecl

    function confirm(text, then) {
        try {
            var answer = NVG.SystemCall.messageBox({
                // "Alert": SAO Utils' alert box and sound (as MHCP-YUI's confirmations).
                "title": "Alert",
                "text": text,
                "modal": true
            });
            if (answer && typeof answer.then === "function")
                answer.then(function(result) {
                if (result !== false && result !== 0)
                    then();

            });
        } catch (e) {
            console.log("Seedling: cannot ask:", e);
        }
    }

    title: (decl.name || "Seedling") + " Settings"
    visible: true
    minimumWidth: 380
    minimumHeight: 240
    width: 460
    height: Math.min(640, 150 + decl.settings.length * 64 + (decl.keeps.length > 0 ? 70 : 0))
    transientParent: targetWidget.NVG.View.window
    onClosing: destroy()

    Page {
        anchors.fill: parent

        SettingsPage {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.topMargin: 10
            anchors.bottomMargin: 16

            P.PreferenceGroup {
                Layout.fillWidth: true

                // One row per @setting: the preference that fits its type (the others hidden).
                Repeater {
                    // Built again after Reset (the values are read when the rows are made).
                    model: settingsWindow.targetWidget.created ? settingsWindow.decl.settings : []

                    P.PreferenceGroup {
                        id: row

                        readonly property var d: modelData
                        readonly property var current: settingsWindow.targetWidget.settingValue(d.name)
                        readonly property bool ranged: d.min !== null && d.max !== null
                        // Which preference: "text", "select", "switch", "color", "spin", "slider".
                        readonly property string kind: {
                            if (d.type === "bool")
                                return "switch";

                            if (d.type === "color")
                                return "color";

                            if (d.type === "string")
                                return d.choices ? "select" : "text";

                            if (d.type === "int")
                                return ranged && d.max - d.min <= 100 ? "slider" : "spin";

                            return ranged ? "slider" : "text";
                        }
                        property bool ready: false

                        function set(value) {
                            if (ready)
                                settingsWindow.targetWidget.setSetting(d.name, value);

                        }

                        Layout.fillWidth: true
                        Component.onCompleted: ready = true

                        P.TextFieldPreference {
                            visible: row.kind === "text"
                            label: row.d.label
                            value: row.current !== undefined ? String(row.current) : ""
                            onValueChanged: row.set(row.d.type === "real" ? Number(value) : value)
                        }

                        P.SelectPreference {
                            visible: row.kind === "select"
                            label: row.d.label
                            model: row.d.choices || []
                            value: Math.max(0, (row.d.choices || []).indexOf(String(row.current)))
                            onValueChanged: row.set((row.d.choices || [])[value])
                        }

                        P.SwitchPreference {
                            visible: row.kind === "switch"
                            label: row.d.label
                            value: row.current === true
                            onValueChanged: row.set(value === true)
                        }

                        P.ColorPreference {
                            visible: row.kind === "color"
                            label: row.d.label
                            value: row.current !== undefined ? row.current : "white"
                            onValueChanged: row.set(String(value))
                        }

                        P.SpinPreference {
                            visible: row.kind === "spin"
                            label: row.d.label
                            editable: true
                            from: row.ranged ? row.d.min : -1000000
                            to: row.ranged ? row.d.max : 1000000
                            stepSize: 1
                            value: row.current !== undefined ? Math.round(Number(row.current)) : 0
                            onValueChanged: row.set(value)
                        }

                        P.SliderPreference {
                            visible: row.kind === "slider"
                            label: row.d.label
                            live: true
                            from: row.ranged ? row.d.min : 0
                            to: row.ranged ? row.d.max : 1
                            stepSize: row.d.type === "int" ? 1 : (row.ranged ? (row.d.max - row.d.min) / 100 : 0.01)
                            displayValue: row.d.type === "int" ? String(Math.round(value)) : String(Math.round(value * 100) / 100)
                            value: row.current !== undefined ? Number(row.current) : 0
                            onValueChanged: row.set(value)
                        }

                    }

                }

            }

            // Nothing to set (no @setting, or the widget does not run).
            SettingNote {
                visible: settingsWindow.decl.settings.length === 0 || !settingsWindow.targetWidget.created
                besidePreferences: true
                text: settingsWindow.targetWidget.created ? qsTr("This widget has no settings.") : qsTr("The widget's code does not run: its settings come back once it does.")
            }

            // What it reads of Yui's (@yui): shown, so it is clear (such a widget never goes online).
            SettingNote {
                visible: settingsWindow.decl.yuis.length > 0
                besidePreferences: true
                text: qsTr("Reads from Yui: %1. A widget that reads Yui's data never goes online.").arg(settingsWindow.decl.yuis.map(function(y) {
                    return y.key;
                }).join(", "))
            }

            // What the widget remembers (@keep): cleared after asking.
            CenteredFlow {
                visible: settingsWindow.decl.keeps.length > 0

                Button {
                    text: "Clear Kept Data"
                    onClicked: settingsWindow.confirm(qsTr("Clear what this widget remembers (%1)? It starts again from its defaults.").arg(settingsWindow.decl.keeps.map(function(k) {
                        return k.name;
                    }).join(", ")), function() {
                        settingsWindow.targetWidget.clearKept();
                    })
                }

            }

        }

        header: TitleBar {
            Style.primary: settingsWindow.Style.dialogColor
            text: settingsWindow.title

            Button {
                text: "Reset"
                flat: true
                onClicked: settingsWindow.confirm(qsTr("Restore all settings of %1 to their defaults?").arg(settingsWindow.title), function() {
                    settingsWindow.targetWidget.resetSettings();
                })
                DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            }

        }

    }

}
