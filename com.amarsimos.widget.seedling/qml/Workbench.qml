import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "safety.js" as Safety

// The Seedling workbench, in the look of the SAO game menus: icons of SAO Utils' SAO theme on the
// left (Edit, Try on Desktop, Versions, Option), the code beside its live preview, a status line, and
// at the bottom the versions and the SAO ok / cancel buttons (Save to the widget, Close). The draft is
// kept while closed; Save keeps a version (up to 20).
NVG.Window {
    id: bench

    property var targetWidget
    readonly property var settings: targetWidget.settings
    // The page on the right: "preview", "versions" or "option".
    property string page: "preview"
    property var preview: null
    // "ok", "error" or "unsafe", and what it says.
    property string result: "ok"
    property string status: ""
    property var versions: settings.versions || []
    property int versionIndex: versions.length - 1
    readonly property string orange: "#F1AA03"
    readonly property var examples: [{
        "name": qsTr("Clock"),
        "code": "import QtQuick 2.12\n\nRectangle {\n    width: 200; height: 84; radius: 10\n    color: \"#E61F2630\"\n\n    Text {\n        id: time\n        anchors.centerIn: parent\n        color: \"white\"\n        font.pixelSize: 36\n        text: Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n\n    Timer {\n        interval: 1000; running: true; repeat: true\n        onTriggered: time.text = Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n}\n"
    }, {
        "name": qsTr("Color Block"),
        "code": "import QtQuick 2.12\n\nRectangle {\n    width: 180; height: 110; radius: 12\n    gradient: Gradient {\n        GradientStop { position: 0; color: \"#F1AA03\" }\n        GradientStop { position: 1; color: \"#F8BBD0\" }\n    }\n\n    Text {\n        anchors.centerIn: parent\n        text: \"MHCP001\"\n        color: \"white\"\n        font.pixelSize: 24\n        font.bold: true\n    }\n}\n"
    }, {
        "name": qsTr("Animation"),
        "code": "import QtQuick 2.12\n\nItem {\n    width: 140; height: 140\n\n    Rectangle {\n        anchors.centerIn: parent\n        width: 70; height: 70\n        color: \"#2CE67C\"\n        border.color: \"white\"; border.width: 2\n        RotationAnimation on rotation {\n            from: 0; to: 360; duration: 4000; loops: Animation.Infinite\n        }\n    }\n}\n"
    }, {
        "name": qsTr("Broken"),
        "code": "import QtQuick 2.12\n\nRectangle {\n    width: 120; height: 80\n    color: \"#D9473B\"\n\n    Text {\n        text: \"missing brace\"\n\n}\n"
    }, {
        "name": qsTr("Unsafe"),
        "code": "import QtQuick 2.12\nimport NERvGear 1.0 as NVG\n\nRectangle {\n    width: 120; height: 60\n    MouseArea {\n        anchors.fill: parent\n        onClicked: NVG.SystemCall.execute(\"cmd\")\n    }\n}\n"
    }]

    // Checks and renders the editor text into the preview; true when it is shown.
    function render() {
        if (preview) {
            preview.destroy();
            preview = null;
        }
        var code = editor.text;
        if (code.trim() === "") {
            result = "ok";
            status = qsTr("Write QML on the left, or pick an example in Option.");
            return false;
        }
        var problems = Safety.check(code, settings.allow_network === true);
        if (problems.length > 0) {
            result = "unsafe";
            status = qsTr("Not rendered, the safety check failed: %1").arg(problems.map(function(p) {
                return qsTr("line %1, %2").arg(p.line).arg(p.message);
            }).join("; "));
            return false;
        }
        try {
            preview = Qt.createQmlObject(code, previewArea, "Seedling");
            result = "ok";
            status = qsTr("Rendered, %1 × %2 · safety check passed").arg(Math.round(preview.width)).arg(Math.round(preview.height));
            return true;
        } catch (e) {
            result = "error";
            status = (e.qmlErrors || []).map(function(error) {
                return qsTr("Line %1, column %2: %3").arg(error.lineNumber).arg(error.columnNumber).arg(error.message);
            }).join("; ") || String(e);
            return false;
        }
    }

    // Saves the code to the widget, and as a new version when it changed.
    function save() {
        if (!render())
            return ;

        var code = editor.text;
        var list = versions.slice();
        if (list.length === 0 || list[list.length - 1].code !== code) {
            list.push({
                "code": code,
                "at": Date.now()
            });
            if (list.length > 20)
                list = list.slice(list.length - 20);

            settings.versions = list;
            versions = list;
        }
        versionIndex = versions.length - 1;
        var problem = targetWidget.apply(code);
        status = problem ? problem : qsTr("Saved to the widget (version %1).").arg(versionIndex + 1);
    }

    function loadVersion(index) {
        if (index < 0 || index >= versions.length)
            return ;

        versionIndex = index;
        editor.text = versions[index].code;
    }

    function tryOnDesktop() {
        if (!render())
            return ;

        var component = Qt.createComponent("TryView.qml");
        var view = component.createObject(null, {
            "code": editor.text
        });
        if (!view)
            console.log("Seedling: cannot try it:", component.errorString());

    }

    title: "Seedling"
    visible: true
    minimumWidth: 760
    minimumHeight: 520
    width: 900
    height: 620
    color: "#EDEDED"
    transientParent: targetWidget.NVG.View.window
    onClosing: {
        if (preview)
            preview.destroy();

        destroy();
    }
    Component.onCompleted: render()

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#FBFBFB"
            }

            GradientStop {
                position: 1
                color: "#EBEBEB"
            }

        }

    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // The ring menu, as the SAO main menu.
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 64
            Layout.leftMargin: 14
            Layout.rightMargin: 6
            spacing: 14

            SaoIcon {
                icon: "item/modify"
                caption: "EDIT"
                checked: bench.page === "preview"
                onClicked: bench.page = "preview"
            }

            SaoIcon {
                icon: "item/run"
                caption: "TRY"
                onClicked: bench.tryOnDesktop()
            }

            SaoIcon {
                icon: "item/items"
                caption: "VERSIONS"
                checked: bench.page === "versions"
                onClicked: bench.page = "versions"
            }

            SaoIcon {
                icon: "item/option"
                caption: "OPTION"
                checked: bench.page === "option"
                onClicked: bench.page = "option"
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Title, centered, with an orange line under it.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 50

                Text {
                    anchors.centerIn: parent
                    text: "SEEDLING"
                    font.family: "SAO UI"
                    font.pixelSize: 24
                    font.letterSpacing: 8
                    color: "#6A6A6A"
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#D4D4D4"
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 120
                    height: 2
                    color: bench.orange
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 12

                // Describe what you want and the AI writes it: comes in a later stage.
                SectionTitle {
                    Layout.fillWidth: true
                    text: "REQUEST"
                    note: qsTr("AI comes in a later stage")
                }

                RowLayout {
                    Layout.fillWidth: true
                    enabled: false
                    opacity: 0.6

                    TextField {
                        Layout.fillWidth: true
                        placeholderText: qsTr("Describe the widget you want...")
                    }

                    SaoIcon {
                        icon: "item/add"
                        size: 30
                    }

                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1

                        SectionTitle {
                            Layout.fillWidth: true
                            text: "CODE"
                            note: qsTr("renders as you type")
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            contentWidth: availableWidth

                            TextArea {
                                id: editor

                                selectByMouse: true
                                wrapMode: TextArea.Wrap
                                font.family: "Consolas"
                                font.pixelSize: 12
                                color: "#555555"
                                text: bench.settings.draft !== undefined ? bench.settings.draft : (bench.settings.code || "")
                                onTextChanged: {
                                    bench.settings.draft = text;
                                    renderTimer.restart();
                                }

                                background: Rectangle {
                                    color: "white"
                                    border.color: "#D4D4D4"
                                    radius: 4
                                }

                            }

                        }

                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1

                        SectionTitle {
                            Layout.fillWidth: true
                            text: bench.page === "versions" ? "VERSIONS" : bench.page === "option" ? "OPTION" : "PREVIEW"
                            note: bench.page === "preview" && bench.preview ? Math.round(bench.preview.width) + " × " + Math.round(bench.preview.height) : ""
                        }

                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: bench.page === "versions" ? 1 : bench.page === "option" ? 2 : 0

                            // Preview on a light grid.
                            Rectangle {
                                color: "#F4F6F8"
                                border.color: "#D4D4D4"
                                radius: 4
                                clip: true

                                Grid {
                                    id: grid

                                    anchors.fill: parent
                                    columns: Math.ceil(width / 20)

                                    Repeater {
                                        model: grid.columns * Math.ceil(grid.height / 20)

                                        Rectangle {
                                            width: 20
                                            height: 20
                                            color: "transparent"
                                            border.color: "#E6EAEE"
                                        }

                                    }

                                }

                                Item {
                                    id: previewArea

                                    anchors.fill: parent
                                    anchors.margins: 16
                                }

                            }

                            ListView {
                                clip: true
                                model: bench.versions.length
                                spacing: 4

                                delegate: Rectangle {
                                    readonly property int number: bench.versions.length - index - 1

                                    width: ListView.view.width
                                    height: 32
                                    radius: 4
                                    color: number === bench.versionIndex ? "#33F1AA03" : (versionArea.containsMouse ? "#FFFFFF" : "#F7F7F7")
                                    border.color: "#D4D4D4"

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 10
                                        text: "VER " + (parent.number + 1) + "   " + Qt.formatDateTime(new Date(bench.versions[parent.number].at), "yyyy-MM-dd hh:mm")
                                        font.family: "SAO UI"
                                        font.pixelSize: 13
                                        color: "#6A6A6A"
                                    }

                                    MouseArea {
                                        id: versionArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            bench.loadVersion(parent.number);
                                            bench.page = "preview";
                                        }
                                    }

                                }

                            }

                            ColumnLayout {
                                spacing: 10

                                CheckBox {
                                    text: qsTr("Network: let the widget go online (XMLHttpRequest, pictures from the Internet)")
                                    checked: bench.settings.allow_network === true
                                    onToggled: {
                                        bench.settings.allow_network = checked;
                                        bench.render();
                                    }
                                }

                                Label {
                                    text: qsTr("Examples")
                                    font.bold: true
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: bench.examples

                                        Button {
                                            text: modelData.name
                                            onClicked: {
                                                editor.text = modelData.code;
                                                bench.page = "preview";
                                            }
                                        }

                                    }

                                }

                                Item {
                                    Layout.fillHeight: true
                                }

                            }

                        }

                    }

                }

                // Status: a breathing dot (green rendered, red error, yellow refused) and what happened.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(28, statusText.implicitHeight + 10)
                    radius: 14
                    color: "white"
                    border.color: "#D4D4D4"

                    Rectangle {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9
                        height: 9
                        radius: 4.5
                        color: bench.result === "error" ? "#D9473B" : bench.result === "unsafe" ? bench.orange : "#2CE67C"

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite

                            NumberAnimation {
                                from: 0.3
                                to: 1
                                duration: 700
                            }

                            NumberAnimation {
                                from: 1
                                to: 0.3
                                duration: 700
                            }

                        }

                    }

                    Text {
                        id: statusText

                        anchors.verticalCenter: parent.verticalCenter
                        x: 28
                        width: parent.width - 40
                        wrapMode: Text.Wrap
                        text: bench.status
                        font.pixelSize: 12
                        color: "#5A5A5A"
                    }

                }

            }

            // Footer: versions, Save (ok) and Close (cancel).
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "#E9E9E9"

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#D4D4D4"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    SaoIcon {
                        icon: "misc/prev"
                        size: 28
                        enabled: bench.versionIndex > 0
                        onClicked: bench.loadVersion(bench.versionIndex - 1)
                    }

                    Text {
                        text: bench.versions.length ? "VER " + (bench.versionIndex + 1) + " / " + bench.versions.length : "VER -"
                        font.family: "SAO UI"
                        font.pixelSize: 14
                        color: "#8A8A8A"
                    }

                    SaoIcon {
                        icon: "misc/next"
                        size: 28
                        enabled: bench.versionIndex < bench.versions.length - 1
                        onClicked: bench.loadVersion(bench.versionIndex + 1)
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    SaoIcon {
                        icon: "misc/ok"
                        caption: "SAVE"
                        onClicked: bench.save()
                    }

                    SaoIcon {
                        icon: "misc/cancel"
                        caption: "CLOSE"
                        onClicked: bench.close()
                    }

                }

            }

        }

    }

    Timer {
        id: renderTimer

        interval: 400
        onTriggered: bench.render()
    }

}
