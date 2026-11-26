import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import QtQuick 2.12
import QtQuick.Controls 2.12
import "safety.js" as Safety
import "link" 1.0 as Link

// A Seedling widget: shows the QML kept in its settings (code), after the safety check. Its menu opens
// the workbench, where the code is written, previewed, tried on the desktop and saved back here.
T.Widget {
    id: widget

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
        if (created) {
            created.destroy();
            created = null;
        }
        problem = "";
        if (!source)
            return "";

        var problems = Safety.check(source, settings.allow_network === true);
        if (problems.length > 0) {
            problem = Safety.describe(problems);
            return problem;
        }
        try {
            created = Qt.createQmlObject(source, content, "Seedling");
        } catch (e) {
            problem = (e.qmlErrors || []).map(function(error) {
                return "Line " + error.lineNumber + ", column " + error.columnNumber + ": " + error.message;
            }).join("\n") || String(e);
        }
        return problem;
    }

    // Saves code as this widget's content (from the workbench), the frame taking its size.
    function apply(source) {
        settings.code = source;
        var problem = show(source);
        if (!problem && created)
            fitFrame(Math.ceil(created.width), Math.ceil(created.height));

        return problem;
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

    // Opens the workbench (or brings it forward) and returns it.
    function openWorkbench() {
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
    implicitWidth: code ? 20 : 200
    implicitHeight: code ? 20 : 120
    Component.onCompleted: {
        show(code);
        Link.Bench.register(widget);
    }
    Component.onDestruction: Link.Bench.unregister(widget)

    Item {
        id: content

        anchors.fill: parent
    }

    // Nothing to show yet, or the code does not run: a small card that opens the workbench.
    Rectangle {
        anchors.fill: parent
        visible: !widget.created
        radius: 6
        color: "#E6F4F4F4"
        border.color: "#D4D4D4"

        Column {
            anchors.centerIn: parent
            width: parent.width - 16
            spacing: 4

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "SEEDLING"
                font.family: "SAO UI"
                font.pixelSize: 18
                color: "#6A6A6A"
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                text: widget.problem ? widget.problem : qsTr("Double-click or use the menu to open the workbench")
                font.family: "SAO UI"
                font.pixelSize: 13
                color: widget.problem ? "#D9473B" : "#9A9A9A"
            }

        }

        MouseArea {
            anchors.fill: parent
            onDoubleClicked: widget.openWorkbench()
        }

    }

    menu: Menu {
        Action {
            text: qsTr("Workbench") + "..."
            onTriggered: widget.openWorkbench()
        }

    }

}
