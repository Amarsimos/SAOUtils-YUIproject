import QtQuick 2.12
import QtQuick.Shapes 1.12

// "Yui's Heart": the prism crystal Yui's core was saved in (SAO S1E16), used as a collapsed form.
// An octahedron seen from the front, its glow colored by status and gently breathing / floating.
Item {
    id: crystal

    // Status color (green / yellow / red), see main-stand.qml crystalColor.
    property color statusColor: "#2CE67C"
    property bool sleeping: false
    // Vertical float offset, animated while awake.
    property real hover: 0

    implicitWidth: 80
    implicitHeight: 120

    // Glow behind the crystal, breathing.
    Rectangle {
        id: glow

        anchors.centerIn: body
        width: Math.min(body.width * 1.3, crystal.width)
        height: width
        radius: width / 2
        color: crystal.statusColor
        opacity: 0.25

        SequentialAnimation on opacity {
            running: !crystal.sleeping
            loops: Animation.Infinite

            NumberAnimation {
                from: 0.12
                to: 0.38
                duration: 1600
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                from: 0.38
                to: 0.12
                duration: 1600
                easing.type: Easing.InOutSine
            }

        }

    }

    Shape {
        id: body

        // Leave room for the float animation.
        readonly property real w: Math.min(crystal.width, crystal.height * 0.62)
        readonly property real h: w / 0.62 - 8

        anchors.horizontalCenter: parent.horizontalCenter
        y: (crystal.height - h) / 2 + crystal.hover
        width: w
        height: h
        layer.enabled: true
        layer.samples: 4
        opacity: crystal.sleeping ? 0.55 : 1

        // Outline with a light-to-color gradient.
        ShapePath {
            strokeColor: "#CCFFFFFF"
            strokeWidth: 1.5
            joinStyle: ShapePath.MiterJoin
            startX: body.w / 2
            startY: 0
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: body.w
                y2: body.h

                GradientStop {
                    position: 0
                    color: "#F0FFFFFF"
                }

                GradientStop {
                    position: 0.45
                    color: Qt.lighter(crystal.statusColor, 1.4)
                }

                GradientStop {
                    position: 1
                    color: Qt.darker(crystal.statusColor, 1.3)
                }

            }

            PathLine {
                x: body.w
                y: body.h * 0.42
            }

            PathLine {
                x: body.w / 2
                y: body.h
            }

            PathLine {
                x: 0
                y: body.h * 0.42
            }

            PathLine {
                x: body.w / 2
                y: 0
            }

        }

        // Facets: the girdle and the edges to the front vertex.
        ShapePath {
            strokeColor: "#88FFFFFF"
            strokeWidth: 1
            fillColor: "transparent"
            startX: 0
            startY: body.h * 0.42

            PathLine {
                x: body.w * 0.42
                y: body.h * 0.5
            }

            PathLine {
                x: body.w
                y: body.h * 0.42
            }

            PathMove {
                x: body.w / 2
                y: 0
            }

            PathLine {
                x: body.w * 0.42
                y: body.h * 0.5
            }

            PathLine {
                x: body.w / 2
                y: body.h
            }

        }

        // Highlight on the upper-left facet.
        ShapePath {
            strokeColor: "transparent"
            fillColor: "#55FFFFFF"
            startX: body.w / 2
            startY: 0

            PathLine {
                x: body.w * 0.42
                y: body.h * 0.5
            }

            PathLine {
                x: 0
                y: body.h * 0.42
            }

            PathLine {
                x: body.w / 2
                y: 0
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 600
            }

        }

    }

    SequentialAnimation on hover {
        running: crystal.visible && !crystal.sleeping
        loops: Animation.Infinite

        NumberAnimation {
            from: -4
            to: 4
            duration: 1800
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            from: 4
            to: -4
            duration: 1800
            easing.type: Easing.InOutSine
        }

    }

}
