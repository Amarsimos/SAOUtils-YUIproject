import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// "↺" next to a setting: shown only while the setting differs from its default (changed), and a click
// restores it. It always keeps its place, so rows stay aligned, and sits at the top of its row, level
// with the setting's label (rows with a note or an image preview are taller).
// Give it the setting (preference) or several (preferences): it then knows by itself whether they
// changed, and restores them with Preference.load(), which takes the preference's own defaultValue.
// Older uses set changed and handle onClicked themselves.
ToolButton {
    property var preference: null
    property var preferences: preference ? [preference] : []
    property bool changed: preferences.some(function(item) {
        return item && JSON.stringify(item.value) !== JSON.stringify(item.defaultValue);
    })

    Layout.preferredWidth: 28
    Layout.preferredHeight: 28
    Layout.alignment: Qt.AlignTop
    Layout.topMargin: 6
    implicitWidth: 28
    implicitHeight: 28
    padding: 0
    text: "↺"
    font.pixelSize: 16
    opacity: changed ? 1 : 0
    enabled: changed
    hoverEnabled: true
    ToolTip.visible: hovered
    ToolTip.delay: 500
    ToolTip.text: qsTr("Restore default")
    onClicked: preferences.forEach(function(item) {
        if (item)
            item.load();

    })
}
