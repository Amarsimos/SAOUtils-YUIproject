import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

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

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
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

                Repeater {
                    model: [{
                        "title": "Render",
                        "note": qsTr("Code put in the editor and rendered: a widget, a compile error (red marks, RENDER FAILED), refused by the safety check, nothing (NO SIGNAL), and one larger than the preview (Fit, − / + / 100%)."),
                        "tests": [["Widget", "widget"], ["Compile Error", "broken"], ["Safety Check", "unsafe"], ["Empty", "empty"], ["Large Widget", "large"]]
                    }, {
                        "title": "Yui's Work",
                        "note": qsTr("Made up, as when Yui writes: Thinking for 3 s, then the code streamed in line by line; Change keeps the code and marks two changed lines in orange; Failure ends with the failure sound."),
                        "tests": [["Writing", "write"], ["Change", "edit"], ["Failure", "fail"]]
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

    function run(tag) {
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
