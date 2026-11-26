import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Shapes 1.12
import "safety.js" as Safety
import "link" 1.0 as Link
import "sandbox.js" as Sandbox

// A Seedling widget: shows the QML kept in its settings (code), after the safety check. Its menu opens
// the workbench, where the code is written, previewed, tried on the desktop and saved back here.
T.Widget {
    id: widget

    // The name in SAO Utils' own right-click menu and settings (blank without it).
    title: "Seedling"

    property Component workbenchComponent: Qt.createComponent("Workbench.qml")
    property var workbench: null
    // The object made from the code, or null.
    property var created: null
    // Why the code is not shown ("" when it is).
    property string problem: ""
    // Kept as the widget's own settings: code, draft, versions, allow_network.
    readonly property string code: settings.code || ""

    // Renders code into this widget; returns "" or what went wrong.
    function show(source) {
        clearShown();
        problem = "";
        if (!source)
            return "";

        var problems = Safety.check(source, settings.allow_network === true);
        if (problems.length > 0) {
            problem = Safety.describe(problems);
            return problem;
        }
        try {
            // In the sandbox (sandbox.js): the code cannot see this file's names (S1, P1).
            var made = Sandbox.create(source, content, Qt.resolvedUrl("Sandbox.qml"), "Seedling");
            if (made.error)
                throw new Error(made.error);

            created = made.item;
            sandboxShown = made.sandbox;
        } catch (e) {
            problem = (e.qmlErrors || []).map(function(error) {
                return "Line " + error.lineNumber + ", column " + error.columnNumber + ": " + error.message;
            }).join("\n") || String(e);
        }
        return problem;
    }

    // The sandbox of what is shown (it goes with it).
    property var sandboxShown: null

    // What is shown goes, with its sandbox.
    function clearShown() {
        if (sandboxShown)
            sandboxShown.destroy();
        else if (created)
            created.destroy();
        created = null;
        sandboxShown = null;
    }

    // Saved from the workbench: an SAO orange ring flashes around the widget, so it is clear which
    // widget it went to.
    function flashSaved() {
        savedFlash.restart();
    }

    // Saves code as this widget's content (from the workbench), the frame taking its size.
    // Refused or not compiling: not saved, and the widget shows its own code again.
    function apply(source) {
        var problem = show(source);
        if (problem) {
            show(settings.code || "");
            return problem;
        }
        settings.code = source;
        if (created)
            fitFrame(Math.ceil(created.width), Math.ceil(created.height));

        return "";
    }

    // How SAO Utils treats a widget's implicit size (as in MHCP-YUI's applyFrameSize): for a resizable
    // widget it is only the minimum, so the frame keeps its old size and the new content was cut off
    // until the frame was resized by hand. So: the implicit size, resizing off for a moment so the
    // frame takes it, then resizing back on with a small minimum again.
    property bool applyingFrameSize: false

    function fitFrame(w, h) {
        implicitWidth = Math.max(20, w);
        implicitHeight = Math.max(20, h);
        width = implicitWidth;
        height = implicitHeight;
        applyingFrameSize = true;
        frameTimer.restart();
    }

    Timer {
        id: frameTimer

        interval: 200
        onTriggered: {
            widget.applyingFrameSize = false;
            widget.implicitWidth = 20;
            widget.implicitHeight = 20;
        }
    }

    // Seedling Settings (its Test page), one at a time.
    property Component settingsComponent: Qt.createComponent("SeedlingSettings.qml")
    property var settingsWindow: null

    function openSettings() {
        if (settingsWindow) {
            settingsWindow.requestActivate();
            return ;
        }
        settingsWindow = settingsComponent.createObject(widget, {
            "targetWidget": widget
        });
        if (!settingsWindow) {
            console.log("Seedling: cannot open the settings:", settingsComponent.errorString());
            return ;
        }
        settingsWindow.closing.connect(function() {
            settingsWindow = null;
        });
    }

    // Opens the workbench (or brings it forward) and returns it.
    function openWorkbench() {
        // Yui writes for the widget whose workbench was opened last.
        Link.Bench.used(widget);
        if (workbench) {
            workbench.requestActivate();
            return workbench;
        }
        workbench = workbenchComponent.createObject(widget, {
            "targetWidget": widget
        });
        if (!workbench) {
            console.log("Seedling: cannot open the workbench:", workbenchComponent.errorString());
            return null;
        }
        workbench.dismissed.connect(function() {
            workbench = null;
        });
        return workbench;
    }

    resizable: !applyingFrameSize
    // The empty card's size; once there is code, the frame takes the code's size (fitFrame).
    implicitWidth: code ? 20 : 250
    implicitHeight: code ? 20 : 72
    Component.onCompleted: {
        show(code);
        Link.Bench.register(widget);
    }
    Component.onDestruction: Link.Bench.unregister(widget)

    Item {
        id: content

        anchors.fill: parent
    }

    // Inside the widget's bounds (drawn outside them it was cut off, so nothing showed): a soft glow
    // seeping in from the edge (ten 1 px rings, fainter inward, instead of a hard line), over a faint
    // orange on the whole widget.
    Item {
        id: savedRing

        anchors.fill: parent
        z: 10
        opacity: 0

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: "#1FF1AA03"
        }

        // Two white rings outside, then the orange fading inward: on an orange widget the white shows,
        // on a light one the orange does.
        Repeater {
            model: 10

            Rectangle {
                anchors.fill: parent
                anchors.margins: index
                radius: Math.max(0, 6 - index / 2)
                color: "transparent"
                border.width: 1
                border.color: index < 2 ? Qt.rgba(1, 1, 1, index === 0 ? 0.95 : 0.7) : Qt.rgba(0.945, 0.667, 0.012, 0.85 * Math.pow(1 - (index - 2) / 8, 2))
            }

        }

        // A slanted band of white light sweeping across once: seen by its movement whatever the
        // widget's colors (as the light across Yui's crystal).
        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                id: sweepBand

                x: -width
                y: -parent.height * 0.25
                width: Math.max(24, parent.width * 0.18)
                height: parent.height * 1.5
                rotation: 20

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: "#00FFFFFF"
                    }

                    GradientStop {
                        position: 0.5
                        color: "#B3FFFFFF"
                    }

                    GradientStop {
                        position: 1
                        color: "#00FFFFFF"
                    }

                }

            }

        }

        SequentialAnimation {
            id: savedFlash

            NumberAnimation {
                target: savedRing
                property: "opacity"
                from: 0
                to: 1
                duration: 150
            }

            // The light sweeps across while the glow holds.
            NumberAnimation {
                target: sweepBand
                property: "x"
                from: -sweepBand.width * 1.5
                to: widget.width + sweepBand.width * 0.5
                duration: 550
                easing.type: Easing.InOutQuad
            }

            NumberAnimation {
                target: savedRing
                property: "opacity"
                to: 0
                duration: 900
                easing.type: Easing.InQuad
            }

        }

    }

    // Nothing to show yet, or the code does not run: a card like the anime's menu items, a round icon
    // (a seedling, in an SAO orange ring; red when the code does not run) and a slanted name plate.
    Item {
        id: card

        readonly property bool failed: !!widget.problem
        readonly property color accent: failed ? "#C82864" : "#F1AA03"

        anchors.fill: parent
        visible: !widget.created

        // The name plate, slanted at its right end, behind the icon.
        Shape {
            id: plate

            anchors.verticalCenter: parent.verticalCenter
            x: icon.width / 2
            width: parent.width - x - 4
            height: 46
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: 0
                    y2: plate.height

                    GradientStop {
                        position: 0
                        color: "#FAFAFA"
                    }

                    GradientStop {
                        position: 1
                        color: "#E9E9E9"
                    }

                }

                startX: 0
                startY: 0

                PathLine {
                    x: plate.width
                    y: 0
                }

                PathLine {
                    x: plate.width - 12
                    y: plate.height
                }

                PathLine {
                    x: 0
                    y: plate.height
                }

            }

        }

        Column {
            anchors.verticalCenter: plate.verticalCenter
            x: icon.width + 10
            width: plate.x + plate.width - x - 16
            spacing: 1

            Text {
                width: parent.width
                text: card.failed ? "ERROR" : "SEEDLING"
                font.family: "SAO UI"
                font.pixelSize: 18
                font.letterSpacing: 2
                color: card.failed ? card.accent : "#555555"
                elide: Text.ElideRight
            }

            // One line: the first problem (all of them are in the workbench's Problems).
            Text {
                width: parent.width
                text: card.failed ? widget.problem.split("\n")[0] : qsTr("Right-click: Workbench")
                font.family: /[　-鿿＀-￯]/.test(text) ? Qt.application.font.family : "SAO UI"
                font.pixelSize: 11
                color: card.failed ? card.accent : "#8A8A8A"
                elide: Text.ElideRight
                maximumLineCount: 1
            }

        }

        // The round icon: white with an orange (red) inner ring, a seedling inside.
        Rectangle {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            x: 4
            width: 58
            height: 58
            radius: width / 2
            color: "#FFFFFF"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: width / 2
                color: "#F7F7F7"
                border.color: card.accent
                border.width: 2
            }

            Shape {
                anchors.centerIn: parent
                width: 30
                height: 30
                layer.enabled: true
                layer.samples: 4

                // The stem.
                ShapePath {
                    strokeColor: card.accent
                    strokeWidth: 2.4
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    startX: 15
                    startY: 27

                    PathLine {
                        x: 15
                        y: 14
                    }

                }

                // The left leaf.
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: card.accent
                    startX: 15
                    startY: 15

                    PathCubic {
                        x: 6
                        y: 7
                        control1X: 15
                        control1Y: 10
                        control2X: 11
                        control2Y: 7
                    }

                    PathCubic {
                        x: 15
                        y: 15
                        control1X: 6
                        control1Y: 12
                        control2X: 10
                        control2Y: 15
                    }

                }

                // The right leaf, lighter.
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: card.failed ? "#E06890" : "#F7C24A"
                    startX: 15
                    startY: 12

                    PathCubic {
                        x: 23
                        y: 5
                        control1X: 15
                        control1Y: 8
                        control2X: 18
                        control2Y: 5
                    }

                    PathCubic {
                        x: 15
                        y: 12
                        control1X: 23
                        control1Y: 9
                        control2X: 20
                        control2Y: 12
                    }

                }

            }

        }

    }

    menu: Menu {
        Action {
            text: "Workbench..."
            onTriggered: widget.openWorkbench()
        }

        Action {
            text: "Seedling Settings..."
            onTriggered: widget.openSettings()
        }

    }

}
