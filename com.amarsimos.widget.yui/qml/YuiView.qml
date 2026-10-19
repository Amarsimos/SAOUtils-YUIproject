import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Shapes 1.12
import QtQuick.Window 2.12

// Yui's expanded form (character and chat) in its own desktop view, opened by clicking her collapsed
// form (crystal, pixie or avatar) and closed with ✕ or Esc. The widget keeps all the logic; it puts
// its expanded layer into host, and moves the view by its chat panel's "Message" title (beginMove /
// moveTo / endMove). The grip at the bottom-right resizes it; the geometry is remembered.
// It is a plain frameless Window opened and closed like the SAO Utils mail box message panel
// (com.gpbeta.mail-box MessagePanel.qml), which is also a Window: with an NVG.View, SAO Utils' own
// handling of the view's appearing delayed it and covered the open animation.
Window {
    id: view

    // The widget (main-stand.qml).
    property var yui
    // Where the widget's expanded layer goes.
    readonly property Item host: hostItem
    readonly property int minimumViewWidth: Math.ceil(yui.characterMinimumWidth * 0.6 + yui.chatPanelMinimumWidth + 40)
    readonly property int minimumViewHeight: 320
    property point moveStart
    property point moveOrigin

    // popUp is about to start the open animation (next frame).
    property bool openPending: false
    // Open (popUp) or closed (fold, the window is then hidden).
    property bool shown: false

    signal closeRequested()
    // The close animation has finished and the view is hidden.
    signal folded()

    // Opens as the mail box message panel (the widget's chat panel, see main-stand.qml chatPanel):
    // the character fades in while the panel widens from 10 % (200 ms) and fades in (250 ms); then the
    // message sound, the panel's middle message area unfolds (250 ms; its title and input bars keep
    // their size and move apart) and the messages fade in (250 ms).
    function popUp() {
        aniClose.stop();
        hideTimer.stop();
        warmUpTimer.stop();
        yui.characterReveal = 0;
        yui.chatScaleX = 0.1;
        yui.chatPanelOpacity = 0;
        yui.chatReveal = 0;
        yui.messagesOpacity = 0;
        shown = true;
        // As MessagePanel: the window is shown at the start of the animation (its content still
        // invisible), and the animation runs right after.
        visible = true;
        requestActivate();
        openPending = true;
        startTimer.restart();
    }

    // Closes as the message panel: the close sound, narrows back to 10 % while fading out (250 ms),
    // then folded().
    function fold() {
        if (!shown || aniClose.running || hideTimer.running)
            return ;

        openPending = false;
        aniOpen.stop();
        aniClose.start();
    }

    // Moving by the chat panel's title: global mouse positions.
    function beginMove(point) {
        moveStart = point;
        moveOrigin = Qt.point(x, y);
    }

    function moveTo(point) {
        x = Math.round(moveOrigin.x + point.x - moveStart.x);
        y = Math.round(moveOrigin.y + point.y - moveStart.y);
    }

    function endMove() {
        saveGeometry();
    }

    // Remembers the geometry (after moving / resizing).
    function saveGeometry() {
        yui.settings.view_geometry = {
            "x": Math.round(x),
            "y": Math.round(y),
            "width": Math.round(width),
            "height": Math.round(height)
        };
    }

    // The screen containing a point, or null.
    function screenAt(px, py) {
        var screens = Qt.application.screens;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            if (px >= s.virtualX && px < s.virtualX + s.width && py >= s.virtualY && py < s.virtualY + s.height)
                return s;

        }
        return null;
    }

    // Where to open: the remembered geometry while it is on a screen; otherwise (first time, or the
    // screen is gone) next to the collapsed form, on the side with more room, on its screen.
    // anchor: the collapsed form's rectangle on screen.
    function place(anchor) {
        var saved = yui.settings.view_geometry;
        width = Math.max(minimumViewWidth, saved ? saved.width : (yui.settings.expanded_width || 800));
        height = Math.max(minimumViewHeight, saved ? saved.height : (yui.settings.expanded_height || 420));
        if (saved && screenAt(saved.x + 40, saved.y + 10)) {
            x = saved.x;
            y = saved.y;
            return ;
        }
        var s = screenAt(anchor.x + anchor.width / 2, anchor.y + anchor.height / 2) || Qt.application.screens[0];
        var left = s.virtualX, top = s.virtualY, right = left + s.width, bottom = top + s.height;
        var roomRight = right - (anchor.x + anchor.width);
        var roomLeft = anchor.x - left;
        x = roomRight >= width || roomRight >= roomLeft ? anchor.x + anchor.width : anchor.x - width;
        y = anchor.y + anchor.height / 2 - height / 2;
        x = Math.round(Math.max(left, Math.min(right - width, x)));
        y = Math.round(Math.max(top, Math.min(bottom - height, y)));
    }

    color: "transparent"
    // Frameless, always on top of every other window, no taskbar button.
    flags: Qt.FramelessWindowHint | Qt.Tool | Qt.WindowStaysOnTopHint
    visible: false

    // The content (the animation acts on the widget's character and chat panel inside it).
    Item {
        id: panelClip

        anchors.fill: parent

        Item {
            id: inner

            anchors.fill: parent

            Item {
                id: hostItem

                anchors.fill: parent
            }

            // Any mouse movement over the view counts as the user being around.
            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        view.yui.noteActivity();

                }
            }

            // Resize grip: a triangle filling the bottom-right corner, orange while hovered; only a drag
            // with the button held resizes.
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 18
                height: 18
                z: 100

                Shape {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 4

                    ShapePath {
                        fillColor: resizeArea.containsMouse || resizeArea.pressed ? "#F59B00" : "#99707070"
                        strokeColor: "transparent"
                        startX: 18
                        startY: 0

                        PathLine {
                            x: 18
                            y: 18
                        }

                        PathLine {
                            x: 0
                            y: 18
                        }

                        PathLine {
                            x: 18
                            y: 0
                        }

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
                        start = mapToGlobal(mouse.x, mouse.y);
                        origin = Qt.size(view.width, view.height);
                    }
                    onPositionChanged: {
                        if (!pressed)
                            return ;

                        var now = mapToGlobal(mouse.x, mouse.y);
                        view.width = Math.round(Math.max(view.minimumViewWidth, origin.width + now.x - start.x));
                        view.height = Math.round(Math.max(view.minimumViewHeight, origin.height + now.y - start.y));
                    }
                    onReleased: view.saveGeometry()
                }

            }

        }

    }

    ParallelAnimation {
        id: aniOpen

        NumberAnimation {
            target: view.yui
            property: "characterReveal"
            from: 0
            to: 1
            duration: 450
        }

        NumberAnimation {
            target: view.yui
            property: "chatScaleX"
            from: 0.1
            to: 1
            duration: 200
            easing.type: Easing.OutQuart
        }

        SequentialAnimation {
            NumberAnimation {
                target: view.yui
                property: "chatPanelOpacity"
                from: 0
                to: 1
                duration: 250
            }

            ScriptAction {
                script: NVG.SystemCall.playSound(NVG.SFX.PopupMessage)
            }

            NumberAnimation {
                target: view.yui
                property: "chatReveal"
                from: 0
                to: 1
                duration: 250
                easing.type: Easing.OutQuart
            }

            NumberAnimation {
                target: view.yui
                property: "messagesOpacity"
                from: 0
                to: 1
                duration: 250
            }

        }

    }

    SequentialAnimation {
        id: aniClose

        ScriptAction {
            script: NVG.SystemCall.playSound(NVG.SFX.DismissMessage)
        }

        ParallelAnimation {
            NumberAnimation {
                target: view.yui
                property: "chatScaleX"
                to: 0.1
                duration: 250
                easing.type: Easing.OutQuart
            }

            NumberAnimation {
                target: view.yui
                property: "chatPanelOpacity"
                to: 0
                duration: 250
            }

            NumberAnimation {
                target: view.yui
                property: "characterReveal"
                to: 0
                duration: 250
            }

        }

        ScriptAction {
            script: hideTimer.restart()
        }

    }

    // Hides the window one frame after the close animation, once its last (transparent) frame has
    // been drawn; hidden earlier, that last visible frame flashed when the window was shown again.
    Timer {
        id: hideTimer

        interval: 30
        onTriggered: {
            view.shown = false;
            view.visible = false;
            view.folded();
        }
    }

    // A transparent window's very first showing can draw one frame before its transparency takes
    // effect: it is shown once off screen at start, so that frame is never seen.
    Component.onCompleted: {
        x = -10000;
        y = -10000;
        visible = true;
        warmUpTimer.start();
    }

    Timer {
        id: warmUpTimer

        interval: 100
        onTriggered: {
            if (!view.shown)
                view.visible = false;

        }
    }

    Timer {
        id: startTimer

        interval: 30
        onTriggered: {
            if (!view.openPending)
                return ;

            view.openPending = false;
            aniOpen.restart();
        }
    }

    Shortcut {
        sequence: "Esc"
        onActivated: view.closeRequested()
    }

}
