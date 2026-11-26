import QtQuick 2.12

// Four right-angle marks in the corners, as the target frame of the original's interface (the
// preview). Laid over the area; they take no input.
Item {
    id: marks

    property int inset: 6
    property int length: 12
    property int thickness: 2
    property color color: "#B0B0B0"

    Repeater {
        model: 4

        Item {
            readonly property bool atRight: index === 1 || index === 2
            readonly property bool atBottom: index >= 2

            x: atRight ? marks.width - marks.inset - marks.length : marks.inset
            y: atBottom ? marks.height - marks.inset - marks.length : marks.inset
            width: marks.length
            height: marks.length

            Rectangle {
                y: parent.atBottom ? parent.height - marks.thickness : 0
                width: parent.width
                height: marks.thickness
                color: marks.color
            }

            Rectangle {
                x: parent.atRight ? parent.width - marks.thickness : 0
                width: marks.thickness
                height: parent.height
                color: marks.color
            }

        }

    }

}
