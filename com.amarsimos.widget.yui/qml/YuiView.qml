import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Shapes 1.12

// Yui's expanded form (character and chat) in its own desktop view, opened by clicking her collapsed
// form (crystal, pixie or avatar) and closed with ✕ or Esc. The widget keeps all the logic; it puts
// its expanded layer into host, and moves the view by its chat panel's "Message" title (beginMove /
// moveTo / endMove). The grip at the bottom-right resizes it; the geometry is remembered.
// It is an NVG.View so that it is shown where the widget is (desktop or launcher, see compositor),
// opened and closed like the SAO Utils mail box message panel (com.gpbeta.mail-box MessagePanel.qml).
NVG.View {
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
    // Waiting to hide until a blank frame is on screen (see hideTimer).
    property bool hidePending: false
    // Frames put on screen since the window was made transparent; the first may still be an older one.
    property int blankFrames: 0
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
        hideFallback.stop();
        hidePending = false;
        warmUpTimer.stop();
        contentItem.opacity = 1;
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

    // Just after a compositor change (the widget moves between the launcher and the desktop, as SAO
    // Utils does when the launcher opens and closes): SAO Utils resets the view's position, and the
    // widget's position settles, after the change is announced; any such move puts the view back at
    // once (onXChanged / onYChanged, and the widget's view moving), in the same frame.
    property bool settling: false
    // place() is moving the view (not SAO Utils).
    property bool placing: false

    function follow() {
        if (shown && !hidePending)
            place(yui.widgetScreenRect());

    }

    onXChanged: {
        if (settling && !placing)
            follow();

    }
    onYChanged: {
        if (settling && !placing)
            follow();

    }

    Connections {
        target: view.settling ? view.yui.hostView : null
        ignoreUnknownSignals: true
        onXChanged: view.follow()
        onYChanged: view.follow()
    }

    Timer {
        id: settleTimer

        interval: 400
        onTriggered: {
            view.settling = false;
            if (view.shown)
                view.yui.diag("view: settled at " + view.x + "," + view.y + " (" + (view.inLauncher ? "launcher" : "desktop") + ")");

        }
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

    // In the launcher (rather than on the desktop): it has coordinates of its own (the launcher's
    // space, see LauncherCompositor), and the widget has a place of its own there.
    readonly property bool inLauncher: compositor === NVG.LauncherCompositor
    // The widget's rectangle the view was last placed by (place()).
    property rect anchorRect

    // Remembers where the view is (after moving / resizing) relative to the widget, and its size: the
    // same for the desktop and the launcher, so the chat opens at the same place next to Yui in both.
    function saveGeometry() {
        yui.settings.view_offset = {
            "dx": Math.round(x - anchorRect.x),
            "dy": Math.round(y - anchorRect.y),
            "width": Math.round(width),
            "height": Math.round(height)
        };
    }

    // The area containing a point, as {virtualX, virtualY, width, height}, or null: in the launcher
    // its space, on the desktop the screen there.
    function areaAt(px, py) {
        if (inLauncher) {
            var g = NVG.LauncherCompositor.geometry;
            if (g.width <= 0 || (px >= g.x && px < g.x + g.width && py >= g.y && py < g.y + g.height))
                return {
                "virtualX": g.x,
                "virtualY": g.y,
                "width": g.width > 0 ? g.width : 1920,
                "height": g.height > 0 ? g.height : 1080
            };

            return null;
        }
        var screens = Qt.application.screens;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            if (px >= s.virtualX && px < s.virtualX + s.width && py >= s.virtualY && py < s.virtualY + s.height)
                return s;

        }
        return null;
    }

    // Where to open: at the remembered offset from the widget (anchor: its rectangle, in the view's
    // coordinates), kept in its area (screen or launcher); the first time next to it, on the side with
    // more room. An old remembered desktop position (view_geometry) becomes the offset.
    function place(anchor) {
        placing = true;
        anchorRect = anchor;
        var saved = yui.settings.view_offset;
        var old = yui.settings.view_geometry;
        if (!saved && old && !inLauncher)
            saved = {
            "dx": old.x - anchor.x,
            "dy": old.y - anchor.y,
            "width": old.width,
            "height": old.height
        };

        width = Math.max(minimumViewWidth, saved ? saved.width : (yui.settings.expanded_width || 800));
        height = Math.max(minimumViewHeight, saved ? saved.height : (yui.settings.expanded_height || 420));
        var s = areaAt(anchor.x + anchor.width / 2, anchor.y + anchor.height / 2) || areaAt(0, 0) || Qt.application.screens[0];
        var left = s.virtualX, top = s.virtualY, right = left + s.width, bottom = top + s.height;
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

    // Where the widget is shown (desktop or launcher) and its z (on top, normal, at the bottom) are
    // followed (main-stand.qml followHostView). Changing the compositor resets x and y, so an open view
    // is placed again at once, and kept there while things settle.
    onCompositorChanged: {
        if (!shown || hidePending)
            return ;

        settling = true;
        settleTimer.restart();
        follow();
    }
    color: "transparent"
    // It takes the keyboard for the input box.
    acceptFocus: true
    acceptInput: true
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
                script: if (yui.interfaceSounds) NVG.SystemCall.playSound(NVG.SFX.PopupMessage)
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
            script: if (yui.interfaceSounds) NVG.SystemCall.playSound(NVG.SFX.DismissMessage)
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

    // After the close animation: the whole window is made transparent, and it is hidden only once
    // that blank frame has been put on screen (frameSwapped). Windows keeps a hidden window's last
    // frame and shows it again for a moment when the window comes back, so that frame must be blank;
    // a fixed delay was not always enough when the chat was opened and closed quickly.
    Timer {
        id: hideTimer

        interval: 30
        onTriggered: {
            view.contentItem.opacity = 0;
            view.blankFrames = 0;
            view.hidePending = true;
            hideFallback.restart();
        }
    }

    // In case no frame is drawn (e.g. the window is covered), hide anyway.
    Timer {
        id: hideFallback

        interval: 200
        onTriggered: view.finishHide()
    }

    function finishHide() {
        if (!hidePending)
            return ;

        hidePending = false;
        hideFallback.stop();
        shown = false;
        visible = false;
        folded();
    }

    // Two frames drawn since then (so the blank one is on screen): hide on the next turn of the event loop (frameSwapped comes from
    // the render thread).
    Connections {
        target: view.window
        ignoreUnknownSignals: true
        onFrameSwapped: {
            if (!view.hidePending)
                return ;

            // A still window draws no more frames by itself: ask for one more.
            if (++view.blankFrames >= 2)
                Qt.callLater(view.finishHide);
            else if (view.window)
                Qt.callLater(view.window.update);
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
