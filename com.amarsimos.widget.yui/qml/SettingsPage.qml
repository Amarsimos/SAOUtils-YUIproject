import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// One tab of a settings window: its items in a column that scrolls vertically only, as wide as the
// window minus the vertical scroll bar (drawn over the page, it covered the values at the right edge).
ScrollView {
    id: page

    default property alias content: column.data

    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    contentWidth: availableWidth
    // Bound to the column, so the page scrolls to its end at any window height (left to itself the
    // ScrollView kept a height from before the wrapped items were laid out).
    contentHeight: column.implicitHeight

    ColumnLayout {
        id: column

        width: page.availableWidth - page.ScrollBar.vertical.width - 4
        spacing: 10
    }

}
