import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// "↺" next to a setting: shown only while the setting differs from its default (changed), and a click
// restores that one setting (clicked). It always keeps its place, so rows stay aligned.
ToolButton {
    property bool changed: false

    Layout.preferredWidth: 28
    Layout.preferredHeight: 28
    Layout.alignment: Qt.AlignVCenter
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
}
