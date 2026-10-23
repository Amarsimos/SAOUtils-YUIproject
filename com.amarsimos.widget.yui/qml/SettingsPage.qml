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

    ColumnLayout {
        id: column

        width: page.availableWidth - page.ScrollBar.vertical.width - 4
        spacing: 10
    }

}
