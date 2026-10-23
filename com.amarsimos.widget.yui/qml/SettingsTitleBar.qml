import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12

// The title bar of every settings window (Cardinal System, Equipment, System Console, Yui's Heart):
// the light title bar of SAO Utils' own dialogs, and in English, left to right, Advanced (when the
// window has advanced settings), Help and Reset. All three have one role, so they keep this order.
// Help and Advanced are shared by all the windows (the widget's settingsHelp / settingsAdvanced);
// Reset asks first (yui.confirmReset), then resetRequested() does the window's own reset.
TitleBar {
    id: bar

    // The widget (main-stand.qml).
    property var yui
    // The window, for its title and dialog color.
    property var settingsWindow
    property bool hasAdvanced: false

    signal resetRequested()

    // Without this some windows came out in the theme's blue.
    Style.primary: settingsWindow.Style.dialogColor
    text: settingsWindow.title

    // Shows the advanced settings too.
    Button {
        visible: bar.hasAdvanced
        text: "Advanced"
        flat: true
        checkable: true
        checked: bar.yui.settingsAdvanced
        onToggled: bar.yui.settings.show_advanced = checked
        DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
    }

    // Shows or hides the explanations under the settings (marked while shown, as Advanced).
    Button {
        text: "Help"
        flat: true
        checkable: true
        checked: bar.yui.settingsHelp
        onToggled: bar.yui.settings.show_help = checked
        DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
    }

    Button {
        text: "Reset"
        flat: true
        onClicked: bar.yui.confirmReset(bar.settingsWindow.title, function() {
            bar.resetRequested();
        })
        DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
    }

}
