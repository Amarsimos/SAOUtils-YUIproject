import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// "Reset This Tab" at the bottom of a settings tab, centered as every button of the settings: grey while none of the tab's shown settings
// differs from its default (changed); a click asks first, then restores those preferences with
// Preference.load() (each takes its own defaultValue), saves the ObjectPreferenceGroups they are in
// (groups: load() is no edit, so a synced group would not write the defaults to the settings by
// itself), and emits reset() for anything else the tab restores itself. aboutToReset() comes right
// before, after the confirmation. Settings hidden while Advanced is off are left alone.
Button {
    id: button

    // The widget (main-stand.qml), and the window and tab titles for the confirmation.
    property var yui
    property string windowTitle
    property string tabTitle
    property var preferences: []
    property var groups: []
    readonly property var shownPreferences: preferences.filter(function(preference) {
        return preference && preference.visible;
    })
    property bool changed: Yui.anyChanged(shownPreferences)

    signal aboutToReset()
    signal reset()

    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: 8
    text: qsTr("Reset This Tab")
    enabled: changed
    onClicked: yui.confirmReset(windowTitle + " · " + tabTitle, function() {
        button.aboutToReset();
        button.shownPreferences.forEach(function(preference) {
            preference.load();
        });
        button.groups.forEach(function(group) {
            group.save();
        });
        button.reset();
    })
}
