import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// "System Console" window (after the GM console Yui uses in Aincrad), in three tabs: Monitor (loads and
// the crystal's thresholds, Navigation Reports, Col Ledger), Authority (what Yui may do on the desktop,
// where pages and searches open, the process lists) and Log. Test Call runs each desktop action without the AI, through the same
// message, SAO confirmation box and execution as a real one. The settings are SAO Utils' own
// preferences; the plain ones are synced with the widget's settings (ObjectPreferenceGroup).
NVG.Window {
    id: consoleWindow

    property var targetWidget
    // Changed thresholds (their preferences are made by a Repeater, so each reports here), for Reset
    // This Tab.
    property int changedThresholds: 0
    // The action switches, for Reset This Tab and the title bar's Reset.
    readonly property var switchPreferences: [webSwitch, launchSwitch, findSwitch, killSwitch, mediaSwitch]
    // Where web pages and searches open, for the same resets.
    readonly property var browsingPreferences: [externalBrowserPreference, searchPreference, searchCustomPreference]

    function recount() {
        var thresholds = 0;
        for (var i = 0; i < thresholdRows.count; i++) {
            var row = thresholdRows.itemAt(i);
            if (row && row.changed)
                thresholds++;

        }
        changedThresholds = thresholds;
    }

    // Monitor: the crystal's thresholds, Navigation Reports and their interval, storage and network, and (all, or while
    // shown) the monthly budget.
    function resetMonitor(all) {
        targetWidget.settings.load_thresholds = {};
        for (var i = 0; i < thresholdRows.count; i++)
            thresholdRows.itemAt(i).reset();

        statusPreference.load();
        reportPreference.load();
        storagePreference.load();
        networkPreference.load();
        if (all || budgetPreference.visible)
            budgetPreference.load();

        // load() is no edit, so the synced groups write the defaults to the settings by save().
        reportGroup.save();
        ledgerGroup.save();
    }

    // Authority: the action switches and where web pages and searches open. The es.exe path and the two process lists are the user's own
    // entries and stay.
    function resetAuthority() {
        switchPreferences.concat(browsingPreferences).forEach(function(preference) {
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
                // A StackLayout is at least as tall as its tallest page needs: the Log page's fixed part
                // (test calls, notes, buttons) kept it taller than a low window, so the other pages ran
                // past the window's bottom and could not be scrolled to their end.
                Layout.minimumHeight: 0
                currentIndex: tabs.shownIndex

                // ---------------------------------------------------------------- Monitor
                SettingsPage {
                    Heading {
                        text: qsTr("Load")
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

                        // The six thresholds in a dialog of their own (they are set once and take room);
                        // the row tells how many of the loads differ from the default.
                        P.DialogPreference {
                            label: qsTr("Crystal Thresholds")
                            live: true
                            displayValue: consoleWindow.changedThresholds ? qsTr("%1 changed").arg(consoleWindow.changedThresholds) : qsTr("All default")

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

                    }

                    Heading {
                        text: qsTr("Navigation Reports")
                    }

                    P.ObjectPreferenceGroup {
                        id: reportGroup

                        Layout.fillWidth: true
                        defaultValue: consoleWindow.targetWidget.settings
                        syncProperties: true

                        P.SwitchPreference {
                            id: statusPreference

                            name: "status_reports"
                            defaultValue: true
                            label: qsTr("Navigation Reports")
                        }

                        SettingNote {
                            visible: consoleWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui warns you about low battery and high CPU or memory usage.")
                        }

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

                        P.SpinPreference {
                            id: storagePreference

                            name: "storage_free_min"
                            label: qsTr("Storage Capacity (%)")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 0
                            to: 50
                            defaultValue: 10
                        }

                        SettingNote {
                            visible: consoleWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui warns you when the system drive (C:) has less free space than this, at most once a day. 0 turns it off.")
                        }

                        P.SwitchPreference {
                            id: networkPreference

                            name: "network_watch"
                            label: qsTr("Network Link")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: consoleWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui tells you when the network seems lost (no traffic at all for two minutes) and when it is back.")
                        }

                    }

                    // Col Ledger: the tokens of this month's replies, as the servers report them.
                    Heading {
                        text: qsTr("Col Ledger")
                    }

                    Label {
                        readonly property var ledger: consoleWindow.targetWidget.colLedger

                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        wrapMode: Text.Wrap
                        text: ledger ? qsTr("%1: %2 tokens sent, %3 received, %4 replies").arg(ledger.month).arg(ledger.input.toLocaleString(Qt.locale(), "f", 0)).arg(ledger.output.toLocaleString(Qt.locale(), "f", 0)).arg(ledger.requests) : qsTr("No replies counted yet this month.")
                    }

                    SettingNote {
                        visible: consoleWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Counted from what the servers report with each reply (not every server does), and started afresh each month. Tokens only: prices differ between servers.")
                    }

                    P.ObjectPreferenceGroup {
                        id: ledgerGroup

                        Layout.fillWidth: true
                        visible: consoleWindow.targetWidget.settingsAdvanced
                        defaultValue: consoleWindow.targetWidget.settings
                        syncProperties: true

                        P.SpinPreference {
                            id: budgetPreference

                            name: "col_budget"
                            label: qsTr("Monthly Budget (k tokens)")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 0
                            to: 1000000
                            stepSize: 100
                            defaultValue: 0
                        }

                        SettingNote {
                            visible: consoleWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui tells you once a month when this month's tokens pass the budget, in thousands. 0: no budget.")
                        }

                    }

                    ResetTabButton {
                        yui: consoleWindow.targetWidget
                        windowTitle: consoleWindow.title
                        tabTitle: qsTr("Monitor")
                        changed: consoleWindow.changedThresholds > 0 || Yui.anyChanged([statusPreference, reportPreference, storagePreference, networkPreference].concat(budgetPreference.visible ? [budgetPreference] : []))
                        onReset: consoleWindow.resetMonitor(false)
                    }

                }

                // ---------------------------------------------------------------- Authority
                SettingsPage {
                    Heading {
                        text: qsTr("Actions")
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
                            defaultValue: false
                        }

                        P.SwitchPreference {
                            id: killSwitch

                            name: "action_kill"
                            label: qsTr("Close Programs")
                            defaultValue: false
                        }

                        P.SwitchPreference {
                            id: mediaSwitch

                            name: "media_control"
                            label: qsTr("Control Media")
                            defaultValue: false
                        }

                    }

                    SettingNote {
                        visible: consoleWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Actions turned off here are not offered to the AI, and are not carried out even if a reply asks for them.")
                    }

                    SettingNote {
                        visible: consoleWindow.targetWidget.settingsHelp
                        besidePreferences: true
                        text: qsTr("Control Media: Yui plays, pauses, skips tracks and changes the volume without asking. It uses the Media Player package (com.gpbeta.media); without it this does nothing. For Yui to know what is playing, see Now Playing in Mental Health Counseling.")
                    }

                    Heading {
                        visible: webSwitch.value
                        text: qsTr("Browsing")
                    }

                    // Where Open Web Pages and Search opens them (moved from Cardinal System): synced by
                    // hand, as the engine is kept by its id; shown while that action is on.
                    P.PreferenceGroup {
                        id: browsingGroup

                        property bool ready: false

                        function show() {
                            ready = false;
                            var settings = consoleWindow.targetWidget.settings;
                            externalBrowserPreference.value = settings.external_browser === true;
                            searchPreference.value = Math.max(0, searchPreference.ids.indexOf(settings.search_engine || "bing"));
                            searchCustomPreference.value = settings.search_custom || "";
                            ready = true;
                        }

                        function store() {
                            if (!ready)
                                return ;

                            var settings = consoleWindow.targetWidget.settings;
                            settings.external_browser = !!externalBrowserPreference.value;
                            settings.search_engine = searchPreference.ids[searchPreference.value] || "bing";
                            settings.search_custom = String(searchCustomPreference.value || "").trim();
                        }

                        visible: webSwitch.value
                        Layout.fillWidth: true
                        spacing: 10
                        Component.onCompleted: show()

                        P.SwitchPreference {
                            id: externalBrowserPreference

                            defaultValue: false
                            label: qsTr("External Browser")
                            onValueChanged: browsingGroup.store()
                        }

                        SettingNote {
                            visible: consoleWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Open the links and searches Yui offers in the system's default browser instead of SAO Utils' built-in browser.")
                        }

                        P.SelectPreference {
                            id: searchPreference

                            readonly property var ids: ["bing", "google", "baidu", "duckduckgo", "custom"]

                            defaultValue: 0
                            label: qsTr("Search Engine")
                            model: ["Bing", "Google", qsTr("Baidu"), "DuckDuckGo", qsTr("Custom")]
                            onValueChanged: browsingGroup.store()
                        }

                        SettingNote {
                            visible: consoleWindow.targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Where the searches Yui offers are opened.")
                        }

                        // Only with Custom chosen above.
                        P.TextFieldPreference {
                            id: searchCustomPreference

                            visible: searchPreference.value === 4
                            defaultValue: ""
                            label: qsTr("Custom Search Address")
                            display: P.TextFieldPreference.ExpandAll
                            hint: "https://example.com/search?q=%s"
                            onValueChanged: browsingGroup.store()
                        }

                        SettingNote {
                            visible: consoleWindow.targetWidget.settingsHelp && searchPreference.value === 4
                            besidePreferences: true
                            text: qsTr("%s is replaced by the search words.")
                        }

                    }

                    Heading {
                        text: qsTr("File Search")
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
                        preferences: consoleWindow.switchPreferences.concat(consoleWindow.browsingPreferences)
                        groups: [authorityGroup]
                    }

                }

                // ---------------------------------------------------------------- Log
                // The test calls (in a dialog), then the log filling the rest of the window.
                ColumnLayout {
                    spacing: 10

                    Heading {
                        text: qsTr("Test Call")
                    }

                    // The test calls in a dialog of their own, so the log keeps the window's height.
                    P.PreferenceGroup {
                        Layout.fillWidth: true

                        P.DialogPreference {
                            label: qsTr("Run a Test")
                            live: true

                            SettingNote {
                                visible: consoleWindow.targetWidget.settingsHelp
                                besidePreferences: true
                                // The dialog takes its size from its content: wrapped at a set width.
                                wrapWidth: 360
                                text: qsTr("Try each desktop action. Every button posts a test message and asks for confirmation like a real action; the protected process must be refused without asking.")
                            }

                            CenteredFlow {
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
                                    }, {
                                        "label": qsTr("Test Link Start"),
                                        "tag": "linkstart"
                                    }, {
                                        "label": qsTr("Test Media"),
                                        "tag": "media"
                                    }]

                                    // "Test Bubble" shows a sample line in the speech bubble, "Test Streaming" a
                                    // made-up streamed reply in the chat (neither makes an API request),
                                    // "Test Link Start" plays the startup effect, "Test Media" logs the track
                                    // playing and plays / pauses it.
                                    Button {
                                        text: modelData.label
                                        onClicked: modelData.tag === "linkstart" ? consoleWindow.targetWidget.testLinkStart() : modelData.tag === "media" ? consoleWindow.targetWidget.testMedia() : modelData.tag === "stream" ? consoleWindow.targetWidget.testStreamReply() : modelData.tag ? consoleWindow.targetWidget.testAction(modelData.tag) : consoleWindow.targetWidget.testBubble()
                                    }

                                }

                            }
                        }

                    }

                    // Live log of the desktop actions: confirmations, commands and their results.
                    // The live log, under its own heading (it was a label beside the buttons).
                    Heading {
                        text: qsTr("Log")
                    }

                    CenteredFlow {

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
                consoleWindow.resetMonitor(true);
                consoleWindow.resetAuthority();
            }
        }

    }

}
