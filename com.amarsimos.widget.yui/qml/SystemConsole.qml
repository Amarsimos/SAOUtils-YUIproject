import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.0
// For Qt.application.screens, used to keep the panel on a screen.
import QtQuick.Window 2.12

// System Console: Yui's status panel, what she sees of you and the computer. No settings (they are in
// System Authority and the other settings windows), only what is shown and kept: Status (loads,
// network, storage, Col, the crystal), Records (moods, weekly reports), Memories (Yui's Heart, follow-
// ups, the recollection log), Quests (Boss Raid, reminders, the Quest Log) and Operations (the desktop
// actions and how they ended). Drawn as SAO_UI-Window (as Seedling's workbench): a title band, the
// code wall (CodeRain.qml) with the round page buttons at the left and the page on a light panel, and
// an empty white band. A view of its own: the title band moves it (a click closes), the bottom-right
// corner resizes it; placed beside the widget the first time, then at the remembered offset.
NVG.View {
    id: consoleView

    property var targetWidget
    readonly property var settings: targetWidget.settings
    readonly property color ink: "#4D4D4D"
    // Translucent as her chat (Chat Opacity in Equipment).
    readonly property real panelAlpha: targetWidget.chatOpacity !== undefined ? targetWidget.chatOpacity : 0.8
    readonly property int leastWidth: 560
    readonly property int leastHeight: 460
    readonly property int titleHeight: 64
    readonly property int bottomHeight: 40
    // Room around the panel for its shadow (the view is this much larger on every side).
    readonly property int shadowMargin: 10
    // Open / close animation, as Yui's chat: the panel widens from 10 % and fades in, then its content.
    property real scaleX: 0.1
    property real panelOpacity: 0
    property real contentOpacity: 0
    // The pages, in the order of the buttons: [title, theme icon (item group), one of the small tools
    // (Quests: shown only while they are not set aside, see toolsEnabled)].
    readonly property var pages: [[qsTr("Status"), "System/HW_info"], [qsTr("Records"), "Communicate/calendar"], [qsTr("Memories"), "Other/Favs1"], [qsTr("Quests"), "Communicate/tasks", true], [qsTr("Operations"), "Communicate/clock1"]]
    property int page: {
        var saved = Math.max(0, Math.min(pages.length - 1, settings.console_page || 0));
        return pages[saved][2] && !targetWidget.toolsEnabled ? 0 : saved;
    }
    // ---- Placed and layered as the workbench: where its widget is (desktop or launcher), at its z.
    readonly property var hostView: targetWidget.NVG.View.view
    readonly property bool inLauncher: compositor === NVG.LauncherCompositor
    property rect anchorRect
    property bool placing: false
    property bool moving: false

    // The close animation has finished and the view is gone (for showDialog).
    signal dismissed()

    function widgetRect() {
        var corner = targetWidget.mapToGlobal(0, 0);
        return Qt.rect(corner.x, corner.y, targetWidget.width, targetWidget.height);
    }

    function saveGeometry() {
        settings.console_offset = {
            "dx": Math.round(x - anchorRect.x),
            "dy": Math.round(y - anchorRect.y),
            "width": Math.round(width),
            "height": Math.round(height)
        };
    }

    // The area containing a point: in the launcher its space, on the desktop the screen there.
    function areaAt(px, py) {
        if (inLauncher) {
            var g = NVG.LauncherCompositor.geometry;
            return {
                "virtualX": g.x,
                "virtualY": g.y,
                "width": g.width > 0 ? g.width : 1920,
                "height": g.height > 0 ? g.height : 1080
            };
        }
        var screens = Qt.application.screens;
        for (var i = 0; i < screens.length; i++) {
            var screen = screens[i];
            if (px >= screen.virtualX && px < screen.virtualX + screen.width && py >= screen.virtualY && py < screen.virtualY + screen.height)
                return screen;

        }
        return null;
    }

    function place(anchor) {
        placing = true;
        anchorRect = anchor;
        var saved = settings.console_offset;
        width = Math.max(leastWidth, saved ? saved.width : 760);
        height = Math.max(leastHeight, saved ? saved.height : 600);
        var area = areaAt(anchor.x + anchor.width / 2, anchor.y + anchor.height / 2) || areaAt(0, 0) || Qt.application.screens[0];
        var left = area.virtualX, top = area.virtualY, right = left + area.width, bottom = top + area.height;
        if (saved) {
            x = anchor.x + saved.dx;
            y = anchor.y + saved.dy;
        } else {
            var roomRight = right - (anchor.x + anchor.width);
            var roomLeft = anchor.x - left;
            x = roomRight >= width || roomRight >= roomLeft ? anchor.x + anchor.width : anchor.x - width;
            y = anchor.y + anchor.height / 2 - height / 2;
        }
        x = Math.round(Math.max(left, Math.min(right - width, x)));
        y = Math.round(Math.max(top, Math.min(bottom - height, y)));
        placing = false;
    }

    function dismiss() {
        if (aniClose.running)
            return ;

        aniOpen.stop();
        aniClose.start();
    }

    color: "transparent"
    compositor: hostView ? hostView.compositor : NVG.WindowCompositor
    z: hostView ? hostView.z : 0
    acceptFocus: true
    acceptInput: true
    visible: true
    onPageChanged: settings.console_page = page
    Component.onCompleted: {
        place(widgetRect());
        requestActivate();
        aniOpen.start();
    }

    Shortcut {
        sequence: "Esc"
        onActivated: consoleView.dismiss()
    }

    SequentialAnimation {
        id: aniOpen

        ParallelAnimation {
            NumberAnimation {
                target: consoleView
                property: "scaleX"
                from: 0.1
                to: 1
                duration: 200
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: consoleView
                property: "panelOpacity"
                from: 0
                to: 1
                duration: 250
            }

        }

        ScriptAction {
            script: NVG.SystemCall.playSound(NVG.SFX.PopupMessage)
        }

        NumberAnimation {
            target: consoleView
            property: "contentOpacity"
            from: 0
            to: 1
            duration: 250
        }

    }

    SequentialAnimation {
        id: aniClose

        ScriptAction {
            script: NVG.SystemCall.playSound(NVG.SFX.DismissMessage)
        }

        ParallelAnimation {
            NumberAnimation {
                target: consoleView
                property: "scaleX"
                to: 0.1
                duration: 250
                easing.type: Easing.InQuad
            }

            NumberAnimation {
                target: consoleView
                property: "panelOpacity"
                to: 0
                duration: 250
            }

        }

        ScriptAction {
            script: {
                consoleView.visible = false;
                consoleView.dismissed();
                consoleView.destroy();
            }
        }

    }

    Item {
        id: shadowArea

        anchors.fill: parent
        anchors.margins: consoleView.shadowMargin
    }

    RectangularGlow {
        anchors.fill: shadowArea
        glowRadius: 8
        spread: 0
        cornerRadius: 8
        color: "#1E000000"
        opacity: Math.min(consoleView.panelOpacity, consoleView.contentOpacity)
    }

    Item {
        id: panel

        anchors.fill: shadowArea
        opacity: consoleView.panelOpacity
        clip: true

        transform: Scale {
            origin.x: panel.width / 2
            origin.y: panel.height / 2
            xScale: consoleView.scaleX
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Title band: a click closes, pressing and dragging moves.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: consoleView.titleHeight

                Text {
                    anchors.centerIn: parent
                    text: "System Console"
                    font.family: "SAO UI"
                    font.pixelSize: 30
                    color: consoleView.ink
                }

                MouseArea {
                    property point grab
                    property bool dragging: false

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    onPressed: {
                        grab = Qt.point(mouse.x, mouse.y);
                        dragging = false;
                        consoleView.moving = true;
                    }
                    onPositionChanged: {
                        if (!pressed)
                            return ;

                        if (!dragging && Math.abs(mouse.x - grab.x) + Math.abs(mouse.y - grab.y) <= 4)
                            return ;

                        dragging = true;
                        consoleView.x += mouse.x - grab.x;
                        consoleView.y += mouse.y - grab.y;
                    }
                    onReleased: {
                        consoleView.moving = false;
                        if (dragging)
                            consoleView.saveGeometry();
                        else if (containsMouse)
                            consoleView.dismiss();
                        dragging = false;
                    }
                }

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(0.894, 0.894, 0.894, consoleView.panelAlpha)
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(0.976, 0.976, 0.976, consoleView.panelAlpha)
                    }

                }

            }

            // The code wall, the page buttons and the page.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                CodeRain {
                    anchors.fill: parent
                    running: consoleView.visible && !aniClose.running
                }

                // Shaded at its top and bottom (black 20 % to 0, as the original's grey band).
                Rectangle {
                    width: parent.width
                    height: 11

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#33040404"
                        }

                        GradientStop {
                            position: 1
                            color: "#00040404"
                        }

                    }

                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 11

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#00040404"
                        }

                        GradientStop {
                            position: 1
                            color: "#33040404"
                        }

                    }

                }

                RowLayout {
                    anchors.fill: parent
                    anchors.topMargin: 18
                    anchors.bottomMargin: 18
                    anchors.rightMargin: 18
                    spacing: 0
                    opacity: consoleView.contentOpacity

                    // The SAO main menu's round buttons, a line joining them.
                    Item {
                        Layout.preferredWidth: 96
                        Layout.fillHeight: true

                        Rectangle {
                            x: parent.width / 2 - 1
                            y: 30
                            width: 2
                            height: Math.max(0, navColumn.height - 60)
                            color: "#66FFFFFF"
                        }

                        Column {
                            id: navColumn

                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            spacing: 18

                            Repeater {
                                model: consoleView.pages

                                ConsoleNavButton {
                                    visible: !modelData[2] || consoleView.targetWidget.toolsEnabled
                                    icon: modelData[1]
                                    caption: modelData[0]
                                    checked: consoleView.page === index
                                    onClicked: consoleView.page = index
                                }

                            }

                        }

                    }

                    // The page on a light panel.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#EBF9F9F9"

                        StackLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            currentIndex: consoleView.page

                            ConsoleStatus {
                                yui: consoleView.targetWidget
                                active: consoleView.page === 0
                            }

                            ConsoleRecords {
                                yui: consoleView.targetWidget
                            }

                            ConsoleMemories {
                                yui: consoleView.targetWidget
                            }

                            ConsoleQuests {
                                yui: consoleView.targetWidget
                            }

                            ConsoleOperations {
                                yui: consoleView.targetWidget
                            }

                        }

                    }

                }

            }

            // The white band, empty.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: consoleView.bottomHeight
                color: Qt.rgba(1, 1, 1, consoleView.panelAlpha)
            }

        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#B9B9B9"
        }

    }

    // Resize grip: the bottom-right corner, orange while hovered.
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: consoleView.shadowMargin
        anchors.bottomMargin: consoleView.shadowMargin
        width: 18
        height: 18
        z: 100

        Canvas {
            property bool lit: resizeArea.containsMouse || resizeArea.pressed

            anchors.fill: parent
            onLitChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = lit ? "#F59B00" : "#99707070";
                ctx.beginPath();
                ctx.moveTo(18, 0);
                ctx.lineTo(18, 18);
                ctx.lineTo(0, 18);
                ctx.closePath();
                ctx.fill();
            }
        }

        MouseArea {
            id: resizeArea

            property point start
            property size origin

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            onPressed: {
                start = mapToItem(null, mouse.x, mouse.y);
                origin = Qt.size(consoleView.width, consoleView.height);
            }
            onPositionChanged: {
                if (!pressed)
                    return ;

                var now = mapToItem(null, mouse.x, mouse.y);
                consoleView.width = Math.round(Math.max(consoleView.leastWidth, origin.width + now.x - start.x));
                consoleView.height = Math.round(Math.max(consoleView.leastHeight, origin.height + now.y - start.y));
            }
            onReleased: consoleView.saveGeometry()
        }

    }

}
