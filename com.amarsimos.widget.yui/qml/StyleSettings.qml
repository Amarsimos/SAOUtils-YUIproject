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

    title: qsTr("Equipment")
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

                    // ---------------------------------------------------------------- Avatar
                    Heading {
                        text: qsTr("Avatar")
                    }

                    P.ImagePreference {
                        name: "character_image_path"
                        label: qsTr("Avatar")
                        defaultValue: targetWidget.defaultValues.character_image_path
                    }

                    SettingNote {
                        text: qsTr("Yui's main image, shown next to the message window.")
                    }

                    P.BackgroundPreference {
                        name: "background_image_path"
                        label: qsTr("Field")
                        defaultValue: targetWidget.defaultValues.background_image_path
                    }

                    SettingNote {
                        text: qsTr("The background behind the whole widget.")
                    }

                    // ---------------------------------------------------------------- Message window
                    Heading {
                        text: qsTr("Message Window")
                    }

                    P.ColorPreference {
                        name: "user_bubble_color"
                        label: qsTr("Player Message Color")
                        defaultValue: targetWidget.defaultValues.user_bubble_color
                    }

                    P.ColorPreference {
                        name: "ai_bubble_color"
                        label: qsTr("Yui Message Color")
                        defaultValue: targetWidget.defaultValues.ai_bubble_color
                    }

                    SettingNote {
                        text: qsTr("Bubble colors of your messages and of Yui's replies.")
                    }

                    P.SelectPreference {
                        name: "bubble_font_family"
                        label: qsTr("Message Font")
                        model: targetWidget.fonts
                        defaultValue: fontIndexOf(targetWidget.defaultValues.bubble_font_family)
                    }

                    P.SliderPreference {
                        name: "bubble_font_size"
                        label: qsTr("Message Size")
                        from: 10
                        to: 32
                        stepSize: 1
                        defaultValue: targetWidget.defaultValues.bubble_font_size
                        displayValue: qsTr("%1 px").arg(value)
                    }

                    P.ColorPreference {
                        name: "bubble_font_color"
                        label: qsTr("Message Color")
                        defaultValue: targetWidget.defaultValues.bubble_font_color
                    }

                    SettingNote {
                        text: qsTr("Font, size and color of the text in the bubbles.")
                    }

                    // ---------------------------------------------------------------- Forms
                    Heading {
                        text: qsTr("Forms")
                    }

                    P.ImagePreference {
                        name: "pixie_image_path"
                        label: qsTr("Navigation Pixie Form")
                    }

                    P.SliderPreference {
                        name: "pixie_size"
                        label: qsTr("Pixie Size")
                        from: 80
                        to: 400
                        stepSize: 10
                        defaultValue: targetWidget.defaultValues.pixie_size
                        displayValue: qsTr("%1 px").arg(value)
                    }

                    SettingNote {
                        text: qsTr("When set, Yui turns into a small pixie while the message window is hidden. Pixie Size is its height.")
                    }

                    P.ImagePreference {
                        name: "sleep_image_path"
                        label: qsTr("Standby Form")
                    }

                    SettingNote {
                        text: qsTr("Shown while Yui is asleep. Without it, the avatar is dimmed instead.")
                    }

                    // ---------------------------------------------------------------- Emotion display
                    Heading {
                        text: qsTr("Emotion Display")
                    }

                    SettingNote {
                        text: qsTr("Yui changes her expression with the mood of each reply. Empty slots use the avatar.")
                    }

                    P.ImagePreference {
                        name: "expression_happy"
                        label: qsTr("Happy")
                    }

                    P.ImagePreference {
                        name: "expression_sad"
                        label: qsTr("Sad")
                    }

                    P.ImagePreference {
                        name: "expression_surprised"
                        label: qsTr("Surprised")
                    }

                    P.ImagePreference {
                        name: "expression_angry"
                        label: qsTr("Angry")
                    }

                    P.ImagePreference {
                        name: "expression_shy"
                        label: qsTr("Shy")
                    }

                }

            }

        }

        header: TitleBar {
            text: qsTr("Equipment")
            standardButtons: Dialog.Save | Dialog.Reset
            onAccepted: {
                saveStyles();
                styleSettingsWindow.close();
            }
            onReset: {
                rootPreference.load(); // loads every defaultValue
                // and saves the reset state right away
                saveStyles();
            }
        }

    }

}
