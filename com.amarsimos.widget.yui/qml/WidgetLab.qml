import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// "Seedling" window: turns QML source text into a widget-like view (Qt.createQmlObject). Render
// previews it here and lists compile errors; Pop Out puts it on the desktop as a LabWidget. Test
// stage: the code is typed in (later Yui may write it); nothing is kept except the editor text.
NVG.Window {
    id: labWindow

    property var targetWidget
    // The editor text (for Yui to fill in later).
    property alias code: editor.text
    // The object rendered in the preview, or null.
    property var preview: null

    // Examples for the editor; the last one is broken on purpose, to see the error list.
    readonly property var examples: [{
        "name": qsTr("Clock"),
        "code": "import QtQuick 2.12\n\nRectangle {\n    width: 220\n    height: 90\n    radius: 8\n    color: \"#CC1A1D24\"\n\n    Text {\n        id: time\n        anchors.centerIn: parent\n        color: \"white\"\n        font.pixelSize: 36\n        text: Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n\n    Timer {\n        interval: 1000\n        running: true\n        repeat: true\n        onTriggered: time.text = Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n}\n"
    }, {
        "name": qsTr("Color Block"),
        "code": "import QtQuick 2.12\n\nRectangle {\n    width: 180\n    height: 120\n    radius: 12\n    gradient: Gradient {\n        GradientStop { position: 0; color: \"#F59B00\" }\n        GradientStop { position: 1; color: \"#F8BBD0\" }\n    }\n\n    Text {\n        anchors.centerIn: parent\n        text: \"MHCP001\"\n        color: \"white\"\n        font.pixelSize: 24\n        font.bold: true\n    }\n}\n"
    }, {
        "name": qsTr("Animation"),
        "code": "import QtQuick 2.12\n\nItem {\n    width: 160\n    height: 160\n\n    Rectangle {\n        anchors.centerIn: parent\n        width: 80\n        height: 80\n        color: \"#2CE67C\"\n        border.color: \"white\"\n        border.width: 2\n        RotationAnimation on rotation {\n            from: 0; to: 360; duration: 4000; loops: Animation.Infinite\n        }\n    }\n}\n"
    }, {
        "name": qsTr("Broken"),
        "code": "import QtQuick 2.12\n\nRectangle {\n    width: 120\n    height: 80\n    color: \"#FF3B30\"\n    radius: 8\n\n    Text {\n        text: \"missing brace\"\n\n}\n"
    }]

    // Compiles the editor text into the preview; returns the object, or null with the errors shown.
    function render() {
        if (preview) {
            preview.destroy();
            preview = null;
        }
        try {
            preview = Qt.createQmlObject(editor.text, previewArea, "WidgetLab");
            result.text = qsTr("Rendered: %1 × %2").arg(Math.round(preview.width)).arg(Math.round(preview.height));
            result.color = "#2C9E5C";
            labWindow.targetWidget.diag("widget lab: rendered " + Math.round(preview.width) + "x" + Math.round(preview.height));
        } catch (e) {
            var lines = (e.qmlErrors || []).map(function(error) {
                return qsTr("Line %1, column %2: %3").arg(error.lineNumber).arg(error.columnNumber).arg(error.message);
            });
            result.text = lines.length > 0 ? lines.join("\n") : String(e);
            result.color = "#D0302A";
            labWindow.targetWidget.diag("widget lab: errors\n" + result.text);
        }
        return preview;
    }

    // Loads the editor text into Yui (Show in Yui) and reports the result below the editor.
    function loadLive() {
        var errors = labWindow.targetWidget.loadIntoYui(editor.text);
        result.text = errors ? errors : qsTr("Shown in Yui.");
        result.color = errors ? "#D0302A" : "#2C9E5C";
    }

    title: qsTr("Seedling")
    visible: true
    minimumWidth: 480
    minimumHeight: 560
    width: 560
    height: 820
    transientParent: widget.NVG.View.window
    onClosing: {
        if (preview)
            preview.destroy();

        destroy();
    }

    Page {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 0
            spacing: 8

            SettingNote {
                text: qsTr("Type or paste QML for a widget, then Render it here, Pop Out a quick test copy onto the desktop (drag its top bar to move it; it closes with SAO Utils), or name it and Save to My Widgets to keep it as a real widget.")
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Label {
                    text: qsTr("Examples:")
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: labWindow.examples

                    Button {
                        text: modelData.name
                        onClicked: editor.text = modelData.code
                    }

                }

            }

            // Code editor.
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 260
                clip: true

                TextArea {
                    id: editor

                    selectByMouse: true
                    wrapMode: TextArea.NoWrap
                    font.family: "Consolas"
                    font.pixelSize: 12
                    placeholderText: "import QtQuick 2.12\n\nRectangle { width: 100; height: 100; color: \"orange\" }"
                    text: labWindow.targetWidget.settings.lab_editor_code || ""
                    // Kept between openings (and shown in Yui after a restart when that is on).
                    onTextChanged: {
                        labWindow.targetWidget.settings.lab_editor_code = text;
                        if (showInYui.checked)
                            liveTimer.restart();

                    }
                    background: Rectangle {
                        color: "#F7F7F7"
                        border.color: "#CCCCCC"
                    }
                }

            }

            // Live in Yui: the code is loaded as an Item into Yui's own widget and reloaded 0.4 s after
            // each change; when it does not compile, the errors show below and the last working
            // version stays in Yui.
            CheckBox {
                id: showInYui

                text: qsTr("Show in Yui (live)")
                checked: labWindow.targetWidget.settings.lab_in_yui === true
                onToggled: {
                    labWindow.targetWidget.settings.lab_in_yui = checked;
                    labWindow.targetWidget.settingsRevision++;
                    if (checked)
                        labWindow.loadLive();
                    else
                        labWindow.targetWidget.clearYuiLab();
                }
            }

            Timer {
                id: liveTimer

                interval: 400
                onTriggered: labWindow.loadLive()
            }

            RowLayout {
                Button {
                    text: qsTr("Render")
                    onClicked: labWindow.render()
                }

                Button {
                    text: qsTr("Pop Out")
                    onClicked: {
                        if (labWindow.render())
                            labWindow.targetWidget.popOutLabWidget(editor.text);

                    }
                }

                Button {
                    text: qsTr("Close All (%1)").arg(labWindow.targetWidget.labWidgets.length)
                    enabled: labWindow.targetWidget.labWidgets.length > 0
                    onClicked: labWindow.targetWidget.closeLabWidgets()
                }

            }

            // Save as a real widget in Widget Gallery → My Widgets (renders first; the rendered widget
            // becomes the preview picture).
            RowLayout {
                Layout.fillWidth: true

                TextField {
                    id: widgetName

                    Layout.fillWidth: true
                    selectByMouse: true
                    placeholderText: qsTr("Widget name")
                }

                Button {
                    text: qsTr("Save to My Widgets")
                    enabled: widgetName.text.trim() !== ""
                    onClicked: {
                        var rendered = labWindow.render();
                        if (!rendered)
                            return ;

                        enabled = false;
                        result.text = qsTr("Saving...");
                        result.color = "#888888";
                        labWindow.targetWidget.saveLabPreset(widgetName.text.trim(), editor.text, rendered, function(folder) {
                            enabled = true;
                            result.text = folder ? qsTr("Saved to My Widgets: %1\nOpen Widget Gallery → My Widgets to place it (reopen the gallery if it is not listed yet).").arg(folder) : qsTr("Could not save the widget. See the log in Option.");
                            result.color = folder ? "#2C9E5C" : "#D0302A";
                        });
                    }
                }

            }

            Label {
                id: result

                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.family: "Consolas"
                font.pixelSize: 12
                visible: text !== ""
            }

            // Preview, on a checkered background so transparent parts are visible.
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 160
                color: "#E8E8E8"
                border.color: "#CCCCCC"
                clip: true

                Grid {
                    id: checker

                    anchors.fill: parent
                    columns: Math.ceil(width / 16)

                    Repeater {
                        model: checker.columns * Math.ceil(checker.height / 16)

                        Rectangle {
                            width: 16
                            height: 16
                            color: (index % checker.columns + Math.floor(index / checker.columns)) % 2 ? "#E8E8E8" : "#D8D8D8"
                        }

                    }

                }

                Item {
                    id: previewArea

                    anchors.fill: parent
                    anchors.margins: 12
                }

            }

        }

        header: TitleBar {
            text: qsTr("Seedling")
        }

    }

}
