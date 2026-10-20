import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// Cardinal System monitor (System Console): CPU, GPU, memory and battery as HP bars, colored with the
// crystal's thresholds (as measured, without the crystal's 5 s hold). For the battery, low values are
// the dangerous ones: yellow from 30 %, red from 10 % left. Refreshed every 2 s while shown.
ColumnLayout {
    id: bars

    // The widget (main-stand.qml), for its data sources.
    property var yui
    // Percentages, NaN when unavailable.
    property real cpu: NaN
    property real gpu: NaN
    property real ram: NaN
    property real battery: NaN

    function refresh() {
        cpu = yui.readData(yui.cpuLoad);
        gpu = yui.readData(yui.gpuLoad);
        ram = yui.readData(yui.ramUsage);
        // Battery flag 128 means "no system battery".
        var flags = yui.readData(yui.batteryStatus);
        battery = !isNaN(flags) && flags < 128 ? yui.readData(yui.batteryLevel) : NaN;
    }

    function levelColor(value, metric) {
        if (metric === "battery")
            return yui.levelColors[Yui.loadLevel(100 - value, [70, 90], 0)];

        return yui.levelColors[Yui.loadLevel(value, Yui.loadThresholds(yui.settings.load_thresholds, metric), 0)];
    }

    spacing: 8

    Timer {
        interval: 2000
        running: bars.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: bars.refresh()
    }

    Repeater {
        model: [{
            "label": qsTr("Computing Load (CPU)"),
            "key": "cpu"
        }, {
            "label": qsTr("Visual Engine (GPU)"),
            "key": "gpu"
        }, {
            "label": qsTr("Memory Capacity (RAM)"),
            "key": "ram"
        }, {
            "label": qsTr("Player HP (Battery)"),
            "key": "battery"
        }]

        ColumnLayout {
            readonly property real value: bars[modelData.key]

            Layout.fillWidth: true
            spacing: 3

            Label {
                text: modelData.label + "   " + (isNaN(value) ? qsTr("N/A") : Math.round(value) + "%")
                font.pixelSize: 12
            }

            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: "#33888888"

                Rectangle {
                    width: isNaN(value) ? 0 : parent.width * Math.max(0, Math.min(100, value)) / 100
                    height: parent.height
                    radius: 3
                    color: bars.levelColor(value, modelData.key)

                    Behavior on width {
                        NumberAnimation {
                            duration: 400
                        }

                    }

                }

            }

        }

    }

}
