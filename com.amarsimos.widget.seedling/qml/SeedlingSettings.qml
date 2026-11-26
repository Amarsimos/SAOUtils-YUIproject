import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "probes.js" as Probes

// Seedling Settings (the Seedling widget's menu). Test: tries the workbench's looks and states
// without the AI and without a request: renders, the safety check, the preview's zoom, Yui writing
// and changing code (made up and streamed by a timer), a failure, trying on the desktop and the frame
// taking the code's size. Later: Seedling's own AI (API settings).
NVG.Window {
    id: settingsWindow

    property var targetWidget
    // A made-up writing in progress: {code, shown, edit} (see writeTimer).
    property var simulation: null

    readonly property string sampleCode: "import QtQuick 2.12\n\nRectangle {\n    width: 220; height: 90; radius: 10\n    color: \"#E61F2630\"\n\n    Text {\n        id: time\n        anchors.centerIn: parent\n        color: \"white\"\n        font.pixelSize: 36\n        text: Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n\n    Timer {\n        interval: 1000; running: true; repeat: true\n        onTriggered: time.text = Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n}\n"
    readonly property string brokenCode: "import QtQuick 2.12\n\nRectangle {\n    width: 160; height: 80\n    color: \"#C82864\"\n\n    Text {\n        anchors.centerIn: parent\n        text: \"missing brace\"\n        colr: \"white\"\n    }\n}\n"
    readonly property string unsafeCode: "import QtQuick 2.12\nimport NERvGear 1.0 as NVG\n\nRectangle {\n    width: 120; height: 60\n    MouseArea {\n        anchors.fill: parent\n        onClicked: NVG.SystemCall.execute(\"cmd\")\n    }\n}\n"
    readonly property string networkCode: "import QtQuick 2.12\n\nRectangle {\n    width: 240; height: 80; radius: 8\n    color: \"#E61F2630\"\n\n    Text {\n        id: answer\n        anchors.centerIn: parent\n        color: \"white\"\n        font.pixelSize: 18\n        text: \"asking the Internet...\"\n    }\n\n    Component.onCompleted: {\n        var request = new XMLHttpRequest();\n        request.onreadystatechange = function() {\n            if (request.readyState === XMLHttpRequest.DONE)\n                answer.text = request.status === 200 ? \"online: OK\" : \"offline (\" + request.status + \")\";\n        };\n        request.open(\"GET\", \"https://www.bing.com/\");\n        request.send();\n    }\n}\n"
    readonly property string largeCode: "import QtQuick 2.12\n\nRectangle {\n    width: 900; height: 600\n    gradient: Gradient {\n        GradientStop { position: 0; color: \"#F1AA03\" }\n        GradientStop { position: 1; color: \"#4BB4EC\" }\n    }\n\n    Text {\n        anchors.centerIn: parent\n        text: \"900 x 600\"\n        color: \"white\"\n        font.pixelSize: 64\n    }\n}\n"

    // The workbench, opened (or brought forward) for a test.
    function bench() {
        return targetWidget.openWorkbench();
    }

    // Code put in the editor and rendered at once.
    function load(code) {
        var workbench = bench();
        if (workbench)
            workbench.loadExternal(code, "Test", null, null);

    }

    // Yui writing (made up): the workbench in its writing state, the code streamed in line by line,
    // then rendered. edit: changing the code there (the editor keeps it, then two lines are marked).
    function simulateWriting(edit) {
        var workbench = bench();
        if (!workbench || simulation)
            return ;

        // Changing needs code to change: the sample when the editor is empty.
        if (edit && workbench.currentCode().trim() === "")
            workbench.loadExternal(sampleCode, "Test", null, null);

        workbench.beginWriting("Test", edit);
        simulation = {
            "workbench": workbench,
            "code": sampleCode,
            "shown": 0,
            "edit": edit,
            "ticks": 0
        };
        writeTimer.start();
    }

    function simulateFailure() {
        var workbench = bench();
        if (!workbench || simulation)
            return ;

        workbench.beginWriting("Test", true);
        failTimer.start();
    }

    title: "Seedling Settings"
    visible: true
    minimumWidth: 460
    minimumHeight: 520
    width: 520
    height: 640
    transientParent: targetWidget.NVG.View.window
    onClosing: {
        writeTimer.stop();
        failTimer.stop();
        destroy();
    }

    // Streams the made-up writing: 3 s of thinking (nothing out yet), then a line every 150 ms; an
    // edit says how many places it changes instead.
    Timer {
        id: writeTimer

        interval: 150
        repeat: true
        onTriggered: {
            var sim = settingsWindow.simulation;
            sim.ticks++;
            if (sim.ticks < 20)
                return ;

            var lines = sim.code.split("\n");
            if (sim.edit) {
                sim.workbench.setPhase(qsTr("Changing · %1 place(s)").arg(2));
                if (sim.ticks < 35)
                    return ;

                var changed = sim.workbench.currentCode().replace("#E61F2630", "#E64BB4EC").replace("font.pixelSize: 36", "font.pixelSize: 40");
                stop();
                settingsWindow.simulation = null;
                sim.workbench.loadExternal(changed, "Test", null, {
                    "lines": [4, 10],
                    "added": 2,
                    "removed": 2,
                    "count": 2
                });
                sim.workbench.endWriting(true, "");
                return ;
            }
            sim.shown++;
            sim.workbench.streamCode(lines.slice(0, sim.shown).join("\n"));
            sim.workbench.setPhase(qsTr("Writing · %1 lines").arg(sim.shown));
            if (sim.shown >= lines.length) {
                stop();
                settingsWindow.simulation = null;
                sim.workbench.loadExternal(sim.code, "Test", null, null);
                sim.workbench.endWriting(true, "");
            }
        }
    }

    Timer {
        id: failTimer

        interval: 3000
        onTriggered: {
            var workbench = settingsWindow.bench();
            if (workbench)
                workbench.endWriting(false, qsTr("Test: not done (no request was made)."));

        }
    }

    Page {
        anchors.fill: parent

        // A Flickable with the SAO scroll bar (a ScrollView would add its wide default one).
        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight + 16
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: SaoScrollBar {
                z: 10
                onLight: true
            }

            ColumnLayout {
                id: settingsColumn

                width: parent.width
                spacing: 14

                Label {
                    Layout.fillWidth: true
                    Layout.margins: 16
                    Layout.bottomMargin: 0
                    wrapMode: Text.Wrap
                    color: "#666666"
                    text: qsTr("Test tries the workbench without the AI: nothing here makes a request. Each button opens the workbench (or uses the open one).")
                }

                // General: Code Editor (advanced). Off: the workbench shows the preview only.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 6

                    Label {
                        text: "General"
                        font.family: "SAO UI"
                        font.pixelSize: 18
                        color: "#4D4D4D"
                    }

                    CheckBox {
                        text: "Code Editor"
                        checked: settingsWindow.targetWidget.settings.show_code === true
                        onToggled: settingsWindow.targetWidget.settings.show_code = checked
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: "#888888"
                        font.pixelSize: 12
                        text: qsTr("Advanced: shows the code beside the preview in the workbench, with Try and Examples, to read or change what Yui wrote. Off, the workbench shows the widget only.")
                    }

                    CheckBox {
                        id: networkBox

                        text: "Network"
                        checked: settingsWindow.targetWidget.settings.allow_network === true
                        onToggled: {
                            settingsWindow.targetWidget.settings.allow_network = checked;
                            var workbench = settingsWindow.targetWidget.workbench;
                            if (workbench)
                                workbench.render(true);

                        }

                        // Turned on by the workbench's question too.
                        Connections {
                            target: settingsWindow.targetWidget.workbench || null
                            ignoreUnknownSignals: true
                            onStatusChanged: networkBox.checked = settingsWindow.targetWidget.settings.allow_network === true
                        }

                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: "#888888"
                        font.pixelSize: 12
                        text: qsTr("Lets this widget go online (weather, exchange rates, pictures from the Internet). Off by default: the safety check refuses code that goes online, and Yui writes widgets that do not. When a widget is refused only for going online, the workbench asks whether to allow it.")
                    }

                }

                Repeater {
                    model: [{
                        "title": "Render",
                        "note": qsTr("Code put in the editor and rendered: a widget, a compile error (red marks, RENDER FAILED), refused by the safety check, one that needs to go online (Network is turned off first; the question comes as for code Yui brings, and on Save when typed in), nothing (NO SIGNAL), and one larger than the preview (Fit, − / + / 100%)."),
                        "tests": [["Widget", "widget"], ["Compile Error", "broken"], ["Safety Check", "unsafe"], ["Needs Network", "network"], ["Empty", "empty"], ["Large Widget", "large"]]
                    }, {
                        "title": "Yui's Work",
                        "note": qsTr("Made up, as when Yui writes: Thinking for 3 s, then the code streamed in line by line; Change keeps the code and marks two changed lines in orange; Failure ends with the failure sound."),
                        "tests": [["Writing", "write"], ["Change", "edit"], ["Failure", "fail"]]
                    }, {
                        "title": "S1 Probes · Workbench",
                        "note": qsTr("Seedling Development Plan, S1: harmless probes of what a generated widget can reach. Each shows what it found in the preview (and in SAO Utils' log as [seedling probe]); nothing is called, sent or changed. P7 reads C:\\Windows\\win.ini and shows only its length. These run in the workbench's preview."),
                        "tests": Probes.PROBES.map(function(p) {
                            return [p.name, "probe:" + p.key];
                        })
                    }, {
                        "title": "S1 Probes · Widget",
                        "note": qsTr("The same probes saved to this widget, to see what they reach from a widget on the desktop (it replaces the widget's code: go back with Versions in the workbench)."),
                        "tests": Probes.PROBES.map(function(p) {
                            return [p.name, "probewidget:" + p.key];
                        })
                    }, {
                        "title": "Desktop",
                        "note": qsTr("Try puts the code on the desktop for a while; Save to Widget saves it to this widget, whose frame takes its size."),
                        "tests": [["Try", "try"], ["Save to Widget", "save"]]
                    }]

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        spacing: 6

                        Label {
                            text: modelData.title
                            font.family: "SAO UI"
                            font.pixelSize: 18
                            color: "#4D4D4D"
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: "#888888"
                            font.pixelSize: 12
                            text: modelData.note
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: modelData.tests

                                Button {
                                    text: modelData[0]
                                    onClicked: settingsWindow.run(modelData[1])
                                }

                            }

                        }

                    }

                }

                Item {
                    Layout.fillHeight: true
                }

            }

        }

        header: TitleBar {
            Style.primary: settingsWindow.Style.dialogColor
            text: "Seedling Settings"
        }

    }

    function probeCode(key) {
        var found = Probes.PROBES.filter(function(p) {
            return p.key === key;
        });
        return found.length ? found[0].code : "";
    }

    function run(tag) {
        if (tag.indexOf("probe:") === 0) {
            load(probeCode(tag.slice(6)));
            return ;
        }
        if (tag.indexOf("probewidget:") === 0) {
            var code = probeCode(tag.slice(12));
            var workbench = bench();
            if (workbench)
                workbench.loadExternal(code, "Probe", null, null);

            var problem = targetWidget.apply(code);
            if (problem)
                console.log("[seedling probe] not saved to the widget: " + problem);

            return ;
        }
        if (tag === "widget")
            load(sampleCode);
        else if (tag === "broken")
            load(brokenCode);
        else if (tag === "unsafe")
            load(unsafeCode);
        else if (tag === "empty")
            load("");
        else if (tag === "large")
            load(largeCode);
        else if (tag === "network") {
            // Network off, so the question comes (as for code Yui brings).
            targetWidget.settings.allow_network = false;
            load(networkCode);
        }
        else if (tag === "write")
            simulateWriting(false);
        else if (tag === "edit")
            simulateWriting(true);
        else if (tag === "fail")
            simulateFailure();
        else if (tag === "try") {
            var workbench = bench();
            if (workbench)
                workbench.tryOnDesktop();

        } else if (tag === "save") {
            var saving = bench();
            if (saving)
                saving.save();

        }
    }
}
