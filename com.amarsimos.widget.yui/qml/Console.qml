import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Shapes 1.12

// The console: opened over the chat area with the ⬡ button. A column of hexagon buttons on the left
// selects a page: Talk (back to the chat), Cardinal (system load), Memory (Yui's Heart), Option.
// TEMPORARY layout (pending decision): button position, how much of the chat it covers, page list.
Item {
    id: console_

    // The widget (main-stand.qml), for data and actions.
    property var yui
    property string page: "cardinal"

    signal closeRequested()

    // ---------------------------------------------------------------- system load
    // Percentages, NaN when unavailable; refreshed every 2 s while the Cardinal page is shown.
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

    // HP-bar colors: green, yellow from 70 %, red from 90 % (same as the crystal). For the battery,
    // low values are the dangerous ones.
    function levelColor(value, lowIsBad) {
        var danger = lowIsBad ? 100 - value : value;
        return danger >= yui.crystalRedAt ? "#FF3B30" : (danger >= yui.crystalYellowAt ? "#FFCC00" : "#2CE67C");
    }

    Timer {
        interval: 2000
        running: console_.visible && console_.page === "cardinal"
        repeat: true
        triggeredOnStart: true
        onTriggered: console_.refresh()
    }

    // Backdrop hiding the chat below; also swallows clicks so they do not reach it.
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#B31A1D24"

        MouseArea {
            anchors.fill: parent
        }

    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 10

        // ------------------------------------------------------------ hexagon menu
        Column {
            Layout.alignment: Qt.AlignTop
            spacing: 6

            Repeater {
                model: [{
                    "id": "talk",
                    "label": qsTr("Talk")
                }, {
                    "id": "cardinal",
                    "label": qsTr("Cardinal")
                }, {
                    "id": "memory",
                    "label": qsTr("Memory")
                }, {
                    "id": "option",
                    "label": qsTr("Option")
                }]

                Item {
                    readonly property bool active: console_.page === modelData.id

                    width: 64
                    height: 56

                    Shape {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeColor: "#CCFFFFFF"
                            strokeWidth: 1
                            fillColor: active ? "#F59B00" : (hexArea.containsMouse ? "#F2EAECEF" : "#D9EAECEF")
                            startX: 16
                            startY: 0

                            PathLine {
                                x: 48
                                y: 0
                            }

                            PathLine {
                                x: 64
                                y: 28
                            }

                            PathLine {
                                x: 48
                                y: 56
                            }

                            PathLine {
                                x: 16
                                y: 56
                            }

                            PathLine {
                                x: 0
                                y: 28
                            }

                            PathLine {
                                x: 16
                                y: 0
                            }

                        }

                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: active ? "#FFFFFF" : "#333333"
                        font.pixelSize: 11
                        font.bold: active
                    }

                    MouseArea {
                        id: hexArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.id === "talk")
                                console_.closeRequested();
                            else
                                console_.page = modelData.id;
                        }
                    }

                }

            }

        }

        // ------------------------------------------------------------ page panel
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Dark panel with chamfered (45°) corners.
            Shape {
                id: panelShape

                readonly property real c: 12

                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    strokeColor: "#AAFFFFFF"
                    strokeWidth: 1.5
                    fillColor: "#D91A1D24"
                    startX: panelShape.c
                    startY: 0

                    PathLine {
                        x: panelShape.width - panelShape.c
                        y: 0
                    }

                    PathLine {
                        x: panelShape.width
                        y: panelShape.c
                    }

                    PathLine {
                        x: panelShape.width
                        y: panelShape.height - panelShape.c
                    }

                    PathLine {
                        x: panelShape.width - panelShape.c
                        y: panelShape.height
                    }

                    PathLine {
                        x: panelShape.c
                        y: panelShape.height
                    }

                    PathLine {
                        x: 0
                        y: panelShape.height - panelShape.c
                    }

                    PathLine {
                        x: 0
                        y: panelShape.c
                    }

                    PathLine {
                        x: panelShape.c
                        y: 0
                    }

                }

            }

            // Cardinal: system load as HP bars.
            Column {
                visible: console_.page === "cardinal"
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "❖ CARDINAL SYSTEM MONITOR"
                    color: "#FFFFFF"
                    font.pixelSize: 13
                    font.bold: true
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

                    Column {
                        readonly property real value: console_[modelData.key]
                        readonly property bool lowIsBad: modelData.key === "battery"

                        width: parent.width
                        spacing: 3

                        Text {
                            text: modelData.label + "   " + (isNaN(value) ? qsTr("N/A") : Math.round(value) + "%")
                            color: "#DDFFFFFF"
                            font.pixelSize: 12
                        }

                        Rectangle {
                            width: parent.width
                            height: 6
                            radius: 3
                            color: "#33FFFFFF"

                            Rectangle {
                                width: isNaN(value) ? 0 : parent.width * Math.max(0, Math.min(100, value)) / 100
                                height: parent.height
                                radius: 3
                                color: console_.levelColor(value, lowIsBad)

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

            // Memory: what Yui remembers (edited in Cardinal System).
            ColumnLayout {
                visible: console_.page === "memory"
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                Text {
                    text: "♥ " + qsTr("Yui's Heart") + "  (" + console_.yui.heartCache.length + ")"
                    color: "#FFFFFF"
                    font.pixelSize: 13
                    font.bold: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: console_.yui.heartCache

                    delegate: Text {
                        width: ListView.view.width
                        text: "· " + modelData
                        color: "#DDFFFFFF"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    ScrollBar.vertical: SaoScrollBar {
                    }

                }

                Text {
                    visible: console_.yui.heartCache.length === 0
                    text: qsTr("No memories yet")
                    color: "#99FFFFFF"
                    font.pixelSize: 12
                }

            }

            // Option: quick settings.
            Column {
                visible: console_.page === "option"
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "⚙ " + qsTr("Option")
                    color: "#FFFFFF"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    text: qsTr("Collapsed Form")
                    color: "#DDFFFFFF"
                    font.pixelSize: 12
                }

                Row {
                    spacing: 8

                    Repeater {
                        model: [{
                            "id": "pixie",
                            "label": qsTr("Navigation Pixie")
                        }, {
                            "id": "crystal",
                            "label": qsTr("Yui's Heart Crystal")
                        }]

                        Button {
                            text: modelData.label
                            highlighted: (console_.yui.styles.collapsed_form || "pixie") === modelData.id
                            onClicked: console_.yui.setCollapsedForm(modelData.id)
                        }

                    }

                }

                Button {
                    text: qsTr("Reset Log")
                    onClicked: {
                        console_.yui.clearChat();
                        console_.closeRequested();
                    }
                }

                Row {
                    spacing: 8

                    Button {
                        text: qsTr("Cardinal System") + "..."
                        onClicked: console_.yui.showDialog(console_.yui.coreSettingsDialog, "coreSettingsDialogInstance")
                    }

                    Button {
                        text: qsTr("Equipment") + "..."
                        onClicked: console_.yui.showDialog(console_.yui.styleSettingsDialog, "styleSettingsDialogInstance")
                    }

                }

            }

        }

    }

}
