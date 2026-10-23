import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// "System Console" window (after the GM console Yui uses in Aincrad), in three tabs: the Cardinal
// System Monitor (loads and the crystal's thresholds), Object Control Authority (what Yui may do on the
// desktop) and the System Log. Test Call runs each desktop action without the AI, through the same
// message, SAO confirmation box and execution as a real one. The settings are SAO Utils' own
// preferences; the plain ones are synced with the widget's settings (ObjectPreferenceGroup).
NVG.Window {
    id: consoleWindow

    property var targetWidget
    // Changed thresholds (their preferences are made by a Repeater, so each reports here), for Reset
    // This Tab.
    property int changedThresholds: 0
    // The action switches, for Reset This Tab and the title bar's Reset.
    readonly property var switchPreferences: [webSwitch, launchSwitch, findSwitch, killSwitch]

    function recount() {
        var thresholds = 0;
        for (var i = 0; i < thresholdRows.count; i++) {
            var row = thresholdRows.itemAt(i);
            if (row && row.changed)
                thresholds++;

        }
        changedThresholds = thresholds;
    }

    // Monitor: the crystal's thresholds and the report interval.
    function resetMonitor() {
        targetWidget.settings.load_thresholds = {};
        for (var i = 0; i < thresholdRows.count; i++)
            thresholdRows.itemAt(i).reset();

        reportPreference.load();
        // load() is no edit, so the synced group writes the default to the settings by save().
        reportGroup.save();
    }

    // Authority: the action switches. The es.exe path and the two process lists are the user's own
    // entries and stay.
    function resetAuthority() {
        switchPreferences.forEach(function(preference) {
            preference.load();
        });
        authorityGroup.save();
    }

    title: qsTr("System Console")
    visible: true
    minimumWidth: 420
    minimumHeight: 320
    width: 520
    height: 720
    transientParent: widget.NVG.View.window
    onClosing: destroy()

    Page {
        anchors.fill: parent

        // Three tabs (as the other settings windows); the last one shown is remembered.
        ColumnLayout {
            anchors.fill: parent
            // Little room at the sides, as the other settings windows.
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.bottomMargin: 16
            spacing: 10

            WrapTabBar {
                id: tabs

                currentIndex: Math.max(0, Math.min(2, consoleWindow.targetWidget.settings.console_tab || 0))
                onCurrentIndexChanged: consoleWindow.targetWidget.settings.console_tab = currentIndex
                model: [qsTr("Monitor"), qsTr("Authority"), qsTr("Log")]
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabs.shownIndex

                // ---------------------------------------------------------------- Monitor
                SettingsPage {
                    Heading {
                        text: qsTr("Cardinal System Monitor")
                    }

                    LoadBars {
                        Layout.fillWidth: true
                        yui: consoleWindow.targetWidget
                    }

                    SettingNote {
                        visible: consoleWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("The crystal turns yellow or red when a load stays at or above these values (in %) for 5 seconds, and back once it drops 5 points below them. It shows the worst of the three.")
                    }

                    // Yellow and red of each load, saved as a pair (load_thresholds, red always above
                    // yellow), so not synced one by one like the other settings.
                    P.PreferenceGroup {
                        Layout.fillWidth: true

                        Repeater {
                            id: thresholdRows

                            model: [{
                                "metric": "cpu",
                                "label": qsTr("Computing Load (CPU)")
                            }, {
                                "metric": "gpu",
                                "label": qsTr("Visual Engine (GPU)")
                            }, {
                                "metric": "ram",
                                "label": qsTr("Memory Capacity (RAM)")
                            }]

                            P.PreferenceGroup {
                                id: thresholdGroup

                                readonly property var defaults: Yui.loadThresholds({}, modelData.metric)
                                readonly property bool changed: Yui.anyChanged([yellowPreference, redPreference])
                                // Off while values are put in (not changes by the user).
                                property bool ready: false

                                function save() {
                                    if (!ready)
                                        return ;

                                    if (redPreference.value <= yellowPreference.value)
                                        redPreference.value = Math.min(100, yellowPreference.value + 1);

                                    var all = JSON.parse(JSON.stringify(consoleWindow.targetWidget.settings.load_thresholds || {}));
                                    all[modelData.metric] = [yellowPreference.value, redPreference.value];
                                    consoleWindow.targetWidget.settings.load_thresholds = all;
                                }

                                // Back to the defaults (their saved pair was cleared by the caller).
                                function reset() {
                                    ready = false;
                                    yellowPreference.load();
                                    redPreference.load();
                                    ready = true;
                                }

                                onChangedChanged: consoleWindow.recount()
                                Component.onCompleted: {
                                    var pair = Yui.loadThresholds(consoleWindow.targetWidget.settings.load_thresholds, modelData.metric);
                                    yellowPreference.value = pair[0];
                                    redPreference.value = pair[1];
                                    ready = true;
                                }

                                P.SpinPreference {
                                    id: yellowPreference

                                    label: modelData.label + " · " + qsTr("Yellow")
                                    display: P.TextFieldPreference.ExpandLabel
                                    editable: true
                                    from: 1
                                    to: 99
                                    defaultValue: thresholdGroup.defaults[0]
                                    onValueChanged: thresholdGroup.save()
                                }

                                P.SpinPreference {
                                    id: redPreference

                                    label: modelData.label + " · " + qsTr("Red")
                                    display: P.TextFieldPreference.ExpandLabel
                                    editable: true
                                    from: 2
                                    to: 100
                                    defaultValue: thresholdGroup.defaults[1]
                                    onValueChanged: thresholdGroup.save()
                                }

                            }

                        }

                    }

                    P.ObjectPreferenceGroup {
                        id: reportGroup

                        Layout.fillWidth: true
                        defaultValue: consoleWindow.targetWidget.settings
                        syncProperties: true

                        P.SpinPreference {
                            id: reportPreference

                            name: "load_report_hours"
                            label: qsTr("Report Interval (h)")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 1
                            to: 24
                            defaultValue: 1
                        }

                        SettingNote {
                            visible: consoleWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Each load is reported at most once in this time.")
                        }

                    }

                    ResetTabButton {
                        yui: consoleWindow.targetWidget
                        windowTitle: consoleWindow.title
                        tabTitle: qsTr("Monitor")
                        changed: consoleWindow.changedThresholds > 0 || Yui.preferenceChanged(reportPreference)
                        onReset: consoleWindow.resetMonitor()
                    }

                }

                // ---------------------------------------------------------------- Authority
                SettingsPage {
                    Heading {
                        text: qsTr("Object Control Authority")
                    }

                    // What Yui may do on the desktop (written out, not by a Repeater: the group loads
                    // the preferences it has when it is made).
                    P.ObjectPreferenceGroup {
                        id: authorityGroup

                        Layout.fillWidth: true
                        defaultValue: consoleWindow.targetWidget.settings
                        syncProperties: true

                        P.SwitchPreference {
                            id: webSwitch

                            name: "action_web"
                            label: qsTr("Open Web Pages and Search")
                            defaultValue: true
                        }

                        P.SwitchPreference {
                            id: launchSwitch

                            name: "action_launch"
                            label: qsTr("Start Programs")
                            defaultValue: true
                        }

                        P.SwitchPreference {
                            id: findSwitch

                            name: "action_find"
                            label: qsTr("Search Files")
                            defaultValue: true
                        }

                        P.SwitchPreference {
                            id: killSwitch

                            name: "action_kill"
                            label: qsTr("Close Programs")
                            defaultValue: true
                        }

                    }

                    SettingNote {
                        visible: consoleWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Actions turned off here are not offered to the AI, and are not carried out even if a reply asks for them.")
                    }

                    // es.exe: synced by hand, as surrounding quotes from "Copy as path" are dropped and
                    // Yui fills it in herself once she finds es.exe (settingsRevision).
                    P.PreferenceGroup {
                        Layout.fillWidth: true

                        P.TextFieldPreference {
                            id: esPathPreference

                            property bool ready: false

                            function show() {
                                ready = false;
                                value = consoleWindow.targetWidget.settings.es_path || "";
                                ready = true;
                            }

                            label: qsTr("es.exe Path")
                            display: P.TextFieldPreference.ExpandAll
                            hint: "D:\\Tools\\everything\\es.exe"
                            // Empty means es.exe is looked for in PATH and the usual install folders.
                            onValueChanged: {
                                if (ready)
                                    consoleWindow.targetWidget.settings.es_path = String(value || "").replace(/"/g, "").trim();

                            }
                            Component.onCompleted: show()

                            Connections {
                                target: consoleWindow.targetWidget
                                onSettingsRevisionChanged: esPathPreference.show()
                            }

                        }

                        SettingNote {
                            visible: consoleWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("File search uses Everything's command line tool es.exe. When this is empty, Yui looks for it in PATH and the usual install folders and fills it in once found. Everything itself must be running.")
                        }

                    }

                    Heading {
                        level: 2
                        text: qsTr("Delete Authority")
                    }

                    SettingNote {
                        visible: consoleWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Yui closes these programs without asking. After closing a program for the first time, Yui asks whether to add it here.")
                    }

                    ProcessListEditor {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        // Re-read when Yui adds a program while this window is open.
                        names: consoleWindow.targetWidget.settingsRevision, consoleWindow.targetWidget.settings.kill_whitelist || []
                        emptyText: qsTr("No programs yet.")
                        // A removed program is not offered for the whitelist again; closing it is confirmed.
                        onEdited: {
                            var removed = Yui.processList(consoleWindow.targetWidget.settings.kill_whitelist).filter(function(name) {
                                return list.indexOf(name) === -1;
                            });
                            consoleWindow.targetWidget.settings.kill_asked = Yui.processList((consoleWindow.targetWidget.settings.kill_asked || []).concat(removed));
                            consoleWindow.targetWidget.settings.kill_whitelist = list;
                        }
                    }

                    Heading {
                        level: 2
                        text: qsTr("Immortal Objects")
                    }

                    SettingNote {
                        visible: consoleWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Yui never closes these programs. The locked system processes cannot be removed; you can protect more.")
                    }

                    ProcessListEditor {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        fixedNames: Yui.PROTECTED_PROCESSES
                        names: consoleWindow.targetWidget.settings.kill_protected || []
                        onEdited: consoleWindow.targetWidget.settings.kill_protected = list
                    }

                    ResetTabButton {
                        yui: consoleWindow.targetWidget
                        windowTitle: consoleWindow.title
                        tabTitle: qsTr("Authority")
                        preferences: consoleWindow.switchPreferences
                        groups: [authorityGroup]
                    }

                }

                // ---------------------------------------------------------------- Log
                // The test calls, then the log filling the rest of the window.
                ColumnLayout {
                    spacing: 10

                    Heading {
                        text: qsTr("System Log")
                    }

                    Heading {
                        level: 2
                        text: qsTr("Test Call")
                    }

                    SettingNote {
                        visible: consoleWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Try each desktop action. Every button posts a test message and asks for confirmation like a real action; the protected process must be refused without asking.")
                    }

                    // Inset (16 px each side) so the slanted buttons stay inside the page.
                    Flow {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        spacing: 8

                        Repeater {
                            model: [{
                                "label": qsTr("Launch Notepad"),
                                "tag": "<<launch:notepad>>"
                            }, {
                                "label": qsTr("Close Notepad"),
                                "tag": "<<kill:notepad.exe>>"
                            }, {
                                "label": qsTr("Find File"),
                                "tag": "<<find:notepad.exe>>"
                            }, {
                                "label": qsTr("Open Link"),
                                "tag": "<<open:https://www.bilibili.com>>"
                            }, {
                                "label": qsTr("Protected Process"),
                                "tag": "<<kill:explorer.exe>>"
                            }, {
                                "label": qsTr("Test Bubble"),
                                "tag": ""
                            }, {
                                "label": qsTr("Test Streaming"),
                                "tag": "stream"
                            }]

                            // "Test Bubble" shows a sample line in the speech bubble, "Test Streaming" a
                            // made-up streamed reply in the chat (neither makes an API request).
                            Button {
                                text: modelData.label
                                onClicked: modelData.tag === "stream" ? consoleWindow.targetWidget.testStreamReply() : modelData.tag ? consoleWindow.targetWidget.testAction(modelData.tag) : consoleWindow.targetWidget.testBubble()
                            }

                        }

                    }

                    // Live log of the desktop actions: confirmations, commands and their results.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Log")
                        }

                        // The full requests to the AI and its raw replies (tags included) in the log.
                        CheckBox {
                            text: qsTr("Log Requests")
                            checked: consoleWindow.targetWidget.logRequests
                            onToggled: consoleWindow.targetWidget.settings.log_requests = checked
                        }

                        Button {
                            text: qsTr("Copy Log")
                            enabled: consoleWindow.targetWidget.diagLog.length > 0
                            onClicked: {
                                logText.selectAll();
                                logText.copy();
                                logText.deselect();
                            }
                        }

                        Button {
                            text: qsTr("Clear Log")
                            onClicked: consoleWindow.targetWidget.diagLog = []
                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 120
                        color: "#1A1D24"
                        radius: 4

                        // Read-only but selectable text, so the log can be copied (drag + Ctrl+C or Copy Log).
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 6
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            contentWidth: availableWidth
                            ScrollBar.vertical: SaoScrollBar {
                            }

                            TextArea {
                                id: logText

                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextArea.WrapAnywhere
                                text: consoleWindow.targetWidget.diagLog.join("\n")
                                color: "#DDFFFFFF"
                                selectionColor: "#F59B00"
                                selectedTextColor: "#FFFFFF"
                                font.family: "Consolas"
                                font.pixelSize: 11
                                padding: 0
                                background: null
                                // Follow new lines unless the user is selecting text.
                                onTextChanged: {
                                    if (selectionStart === selectionEnd)
                                        cursorPosition = length;

                                }
                            }

                        }

                        Text {
                            anchors.centerIn: parent
                            visible: consoleWindow.targetWidget.diagLog.length === 0
                            text: qsTr("Run a test to see its steps here.")
                            color: "#88FFFFFF"
                            font.pixelSize: 11
                        }

                    }

                }

            }

        }

        // Reset: the thresholds, the report interval and the action switches.
        header: SettingsTitleBar {
            yui: consoleWindow.targetWidget
            settingsWindow: consoleWindow
            onResetRequested: {
                consoleWindow.resetMonitor();
                consoleWindow.resetAuthority();
            }
        }

    }

}
