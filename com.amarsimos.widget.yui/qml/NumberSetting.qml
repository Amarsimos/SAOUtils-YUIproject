import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// A number setting in a row: its title, a spin box and the "↺" that restores defaultValue.
// value is shown; edited(value) is emitted when the user (or ↺) changes it, to be saved.
RowLayout {
    id: row

    property alias label: title.text
    property int value
    property int defaultValue
    property int from: 0
    property int to: 100
    property int stepSize: 1

    signal edited(int value)

    // Shows and saves a value (↺, or a window's Reset).
    function set(newValue) {
        box.value = newValue;
        edited(newValue);
    }

    Layout.fillWidth: true

    Label {
        id: title

        Layout.fillWidth: true
    }

    SpinBox {
        id: box

        Layout.preferredWidth: 140
        from: row.from
        to: row.to
        stepSize: row.stepSize
        editable: true
        value: row.value
        onValueModified: row.edited(value)
    }

    ResetButton {
        changed: box.value !== row.defaultValue
        onClicked: row.set(row.defaultValue)
    }

}
