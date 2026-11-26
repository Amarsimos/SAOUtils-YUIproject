import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// A tab bar that wraps: the theme's tab buttons share each row equally as in a TabBar, and when the
// window is too narrow for all of them they go on in a second row (a TabBar squeezes or scrolls
// them instead). model: the tab titles; currentIndex: the tab chosen; hiddenTabs: indexes of tabs
// not shown; shownIndex: the tab to show (the chosen one, or the first shown one while it is hidden;
// currentIndex keeps the choice, so it comes back when the tab does).
Flow {
    id: bar

    property var model: []
    property int currentIndex: 0
    property var hiddenTabs: []
    readonly property var shownTabs: model.map(function(title, index) {
        return index;
    }).filter(function(index) {
        return hiddenTabs.indexOf(index) === -1;
    })
    // The widest title's button, so every button of a row gets the same width.
    property real widestButton: 0
    readonly property int perRow: Math.max(1, Math.min(shownTabs.length, Math.floor(width / Math.max(1, widestButton))))

    readonly property int shownIndex: shownTabs.indexOf(currentIndex) !== -1 || shownTabs.length === 0 ? currentIndex : shownTabs[0]

    Layout.fillWidth: true
    spacing: 0

    Repeater {
        model: bar.model

        TabButton {
            // Its place among the shown tabs (-1: hidden).
            readonly property int place: bar.shownTabs.indexOf(index)

            visible: place !== -1
            text: modelData
            // Checked follows shownIndex (a click sets currentIndex), never the button's own toggling.
            checkable: false
            checked: index === bar.shownIndex
            // The buttons of each row (the last one may have fewer) fill it.
            width: bar.width / Math.max(1, Math.min(bar.perRow, bar.shownTabs.length - Math.floor(Math.max(0, place) / bar.perRow) * bar.perRow))
            onClicked: bar.currentIndex = index
            onImplicitWidthChanged: bar.widestButton = Math.max(bar.widestButton, implicitWidth)
            Component.onCompleted: bar.widestButton = Math.max(bar.widestButton, implicitWidth)
        }

    }

}
