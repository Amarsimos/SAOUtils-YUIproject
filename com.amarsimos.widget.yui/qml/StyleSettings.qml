import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

NVG.Window {
    id: styleSettingsWindow

    property var targetWidget

    // The font is saved by name (font indexes shift when fonts are installed or removed),
    // but SelectPreference works with indexes, so convert on load and save.
    function fontIndexOf(value) {
        var index = targetWidget.fonts.indexOf(targetWidget.fontFamilyOf(value));
        return index >= 0 ? index : 0;
    }

    function toPreferences(styles) {
        var values = JSON.parse(JSON.stringify(styles));
        values.bubble_font_family = fontIndexOf(styles.bubble_font_family);
        return values;
    }

    function fromPreferences(values) {
        values.bubble_font_family = targetWidget.fonts[values.bubble_font_family] || targetWidget.defaultValues.bubble_font_family;
        return values;
    }

    function saveStyles() {
        targetWidget.settings.styles = fromPreferences(rootPreference.save());
    }

    title: qsTr("Style Settings")
    visible: true
    minimumWidth: 480
    minimumHeight: 480
    width: minimumWidth
    height: 640
    transientParent: widget.NVG.View.window
    onClosing: {
        destroy();
    }

    Page {
        id: cfg_page

        anchors.fill: parent

        ScrollView {
            id: scrollView

            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 0
            clip: true

            ColumnLayout {
                id: preferenceLayout

                width: scrollView.width

                P.PreferenceGroup {
                    id: rootPreference

                    Layout.fillWidth: true
                    spacing: 10
                    Component.onCompleted: {
                        rootPreference.load(toPreferences(targetWidget.styles));
                    }

                    Heading {
                        text: qsTr("Style Configuration")
                    }

                    P.ImagePreference {
                        name: "character_image_path"
                        label: qsTr("Character Image")
                        defaultValue: targetWidget.defaultValues.character_image_path
                    }

                    P.BackgroundPreference {
                        name: "background_image_path"
                        label: qsTr("Background Image")
                        defaultValue: targetWidget.defaultValues.background_image_path
                    }

                    P.ColorPreference {
                        name: "user_bubble_color"
                        label: qsTr("User Bubble Color")
                        defaultValue: targetWidget.defaultValues.user_bubble_color
                    }

                    P.ColorPreference {
                        name: "ai_bubble_color"
                        label: qsTr("AI Bubble Color")
                        defaultValue: targetWidget.defaultValues.ai_bubble_color
                    }

                    P.SelectPreference {
                        name: "bubble_font_family"
                        label: qsTr("Bubble Font")
                        model: targetWidget.fonts
                        defaultValue: fontIndexOf(targetWidget.defaultValues.bubble_font_family)
                    }

                    P.SliderPreference {
                        name: "bubble_font_size"
                        label: qsTr("Bubble Font Size")
                        from: 10
                        to: 32
                        stepSize: 1
                        defaultValue: targetWidget.defaultValues.bubble_font_size
                        displayValue: value + " px"
                    }

                    P.ColorPreference {
                        name: "bubble_font_color"
                        label: qsTr("Bubble Font Color")
                        defaultValue: targetWidget.defaultValues.bubble_font_color
                    }

                }

            }

        }

        header: TitleBar {
            text: qsTr("Style Settings")
            standardButtons: Dialog.Save | Dialog.Reset
            onAccepted: {
                saveStyles();
                styleSettingsWindow.close();
            }
            onReset: {
                rootPreference.load(); // 这会自动加载所有 defaultValue
                // 立即保存重置后的状态
                saveStyles();
            }
        }

    }

}
