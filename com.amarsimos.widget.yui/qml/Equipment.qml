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

    // Collapsed forms, stored by id; the SelectPreference works with indexes.
    readonly property var collapsedFormIds: ["pixie", "crystal"]

    function toPreferences(styles) {
        var values = JSON.parse(JSON.stringify(styles));
        values.bubble_font_family = fontIndexOf(styles.bubble_font_family);
        values.collapsed_form = Math.max(0, collapsedFormIds.indexOf(styles.collapsed_form));
        return values;
    }

    function fromPreferences(values) {
        values.bubble_font_family = targetWidget.fonts[values.bubble_font_family] || targetWidget.defaultValues.bubble_font_family;
        values.collapsed_form = collapsedFormIds[values.collapsed_form] || "pixie";
        return values;
    }

    // Every preference of this window with its style key and default (in preference terms). They are
    // loaded and saved one by one, so a preference can sit in a row with its ↺ button.
    function entries() {
        return [
            {
                "key": "character_image_path",
                "preference": avatarPreference,
                "defaultValue": targetWidget.defaultValues.character_image_path
            },
            {
                "key": "background_image_path",
                "preference": fieldPreference,
                "defaultValue": targetWidget.defaultValues.background_image_path
            },
            {
                "key": "bubble_font_family",
                "preference": fontPreference,
                "defaultValue": fontIndexOf(targetWidget.defaultValues.bubble_font_family)
            },
            {
                "key": "bubble_font_size",
                "preference": fontSizePreference,
                "defaultValue": targetWidget.defaultValues.bubble_font_size
            },
            {
                "key": "chat_opacity",
                "preference": chatOpacityPreference,
                "defaultValue": targetWidget.defaultValues.chat_opacity
            },
            {
                "key": "bubble_seconds",
                "preference": bubbleSecondsPreference,
                "defaultValue": targetWidget.defaultValues.bubble_seconds
            },
            {
                "key": "bubble_opacity",
                "preference": bubbleOpacityPreference,
                "defaultValue": targetWidget.defaultValues.bubble_opacity
            },
            {
                "key": "sound_messages",
                "preference": messageSoundsPreference,
                "defaultValue": true
            },
            {
                "key": "sound_interface",
                "preference": interfaceSoundsPreference,
                "defaultValue": true
            },
            {
                "key": "collapsed_form",
                "preference": formPreference,
                "defaultValue": 0
            },
            {
                "key": "crystal_size",
                "preference": crystalSizePreference,
                "defaultValue": targetWidget.defaultValues.crystal_size
            },
            {
                "key": "pixie_image_path",
                "preference": pixieImagePreference,
                "defaultValue": ""
            },
            {
                "key": "pixie_size",
                "preference": pixieSizePreference,
                "defaultValue": targetWidget.defaultValues.pixie_size
            },
            {
                "key": "sleep_image_path",
                "preference": standbyImagePreference,
                "defaultValue": ""
            },
            {
                "key": "expression_happy",
                "preference": happyPreference,
                "defaultValue": ""
            },
            {
                "key": "expression_sad",
                "preference": sadPreference,
                "defaultValue": ""
            },
            {
                "key": "expression_surprised",
                "preference": surprisedPreference,
                "defaultValue": ""
            },
            {
                "key": "expression_angry",
                "preference": angryPreference,
                "defaultValue": ""
            },
            {
                "key": "expression_shy",
                "preference": shyPreference,
                "defaultValue": ""
            }
        ];
    }

    function loadStyles(styles) {
        var values = toPreferences(styles);
        entries().forEach(function(entry) {
            entry.preference.value = values[entry.key] !== undefined ? values[entry.key] : entry.defaultValue;
        });
    }

    function saveStyles() {
        var values = JSON.parse(JSON.stringify(targetWidget.styles));
        entries().forEach(function(entry) {
            values[entry.key] = entry.preference.value;
        });
        targetWidget.settings.styles = fromPreferences(values);
    }

    function resetStyles() {
        entries().forEach(function(entry) {
            entry.preference.value = entry.defaultValue;
        });
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
            // Only vertical scrolling: the page is as wide as the window, minus the vertical scroll bar
            // (which is drawn over the page and covered the values at the right edge).
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            contentWidth: availableWidth

            ColumnLayout {
                id: preferenceLayout

                width: scrollView.availableWidth - scrollView.ScrollBar.vertical.width - 4

                P.PreferenceGroup {
                    id: rootPreference

                    Layout.fillWidth: true
                    spacing: 10
                    Component.onCompleted: {
                        loadStyles(targetWidget.styles);
                    }

                    // ---------------------------------------------------------------- Avatar
                    Heading {
                        text: qsTr("Avatar")
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.ImagePreference {
                            id: avatarPreference

                            Layout.fillWidth: true

                            name: "character_image_path"
                            label: qsTr("Avatar")
                            defaultValue: targetWidget.defaultValues.character_image_path
                        }

                        ResetButton {
                            changed: JSON.stringify(avatarPreference.value) !== JSON.stringify(targetWidget.defaultValues.character_image_path)
                            onClicked: avatarPreference.value = targetWidget.defaultValues.character_image_path
                        }

                    }

                    SettingNote {
                        text: qsTr("Yui's main image, shown next to the message window.")
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.BackgroundPreference {
                            id: fieldPreference

                            Layout.fillWidth: true

                            name: "background_image_path"
                            label: qsTr("Field")
                            defaultValue: targetWidget.defaultValues.background_image_path
                        }

                        ResetButton {
                            changed: JSON.stringify(fieldPreference.value) !== JSON.stringify(targetWidget.defaultValues.background_image_path)
                            onClicked: fieldPreference.value = targetWidget.defaultValues.background_image_path
                        }

                    }

                    SettingNote {
                        text: qsTr("The background behind the whole widget.")
                    }

                    // ---------------------------------------------------------------- Message window
                    Heading {
                        text: qsTr("Message Window")
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.SelectPreference {
                            id: fontPreference

                            Layout.fillWidth: true

                            name: "bubble_font_family"
                            label: qsTr("Message Font")
                            model: targetWidget.fonts
                            defaultValue: fontIndexOf(targetWidget.defaultValues.bubble_font_family)
                        }

                        ResetButton {
                            changed: fontPreference.value !== fontIndexOf(targetWidget.defaultValues.bubble_font_family)
                            onClicked: fontPreference.value = fontIndexOf(targetWidget.defaultValues.bubble_font_family)
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.SliderPreference {
                            id: fontSizePreference

                            Layout.fillWidth: true

                            name: "bubble_font_size"
                            label: qsTr("Message Size")
                            from: 10
                            to: 32
                            stepSize: 1
                            defaultValue: targetWidget.defaultValues.bubble_font_size
                            displayValue: qsTr("%1 px").arg(value)
                        }

                        ResetButton {
                            changed: fontSizePreference.value !== targetWidget.defaultValues.bubble_font_size
                            onClicked: fontSizePreference.value = targetWidget.defaultValues.bubble_font_size
                        }

                    }

                    // Message windows have the SAO colors; only the text's font and size are settings.
                    SettingNote {
                        text: qsTr("Font and size of the text in the message windows.")
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.SliderPreference {
                            id: chatOpacityPreference

                            Layout.fillWidth: true

                            name: "chat_opacity"
                            label: qsTr("Chat Panel Opacity")
                            from: 30
                            to: 100
                            stepSize: 5
                            defaultValue: targetWidget.defaultValues.chat_opacity
                            displayValue: qsTr("%1 %").arg(value)
                        }

                        ResetButton {
                            changed: chatOpacityPreference.value !== targetWidget.defaultValues.chat_opacity
                            onClicked: chatOpacityPreference.value = targetWidget.defaultValues.chat_opacity
                        }

                    }

                    // ---------------------------------------------------------------- Crystal bubble
                    Heading {
                        text: qsTr("Crystal Bubble")
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.SliderPreference {
                            id: bubbleSecondsPreference

                            Layout.fillWidth: true

                            name: "bubble_seconds"
                            label: qsTr("Bubble Duration")
                            from: 3
                            to: 30
                            stepSize: 1
                            defaultValue: targetWidget.defaultValues.bubble_seconds
                            displayValue: qsTr("%1 s").arg(value)
                        }

                        ResetButton {
                            changed: bubbleSecondsPreference.value !== targetWidget.defaultValues.bubble_seconds
                            onClicked: bubbleSecondsPreference.value = targetWidget.defaultValues.bubble_seconds
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.SliderPreference {
                            id: bubbleOpacityPreference

                            Layout.fillWidth: true

                            name: "bubble_opacity"
                            label: qsTr("Bubble Opacity")
                            from: 30
                            to: 100
                            stepSize: 5
                            defaultValue: targetWidget.defaultValues.bubble_opacity
                            displayValue: qsTr("%1 %").arg(value)
                        }

                        ResetButton {
                            changed: bubbleOpacityPreference.value !== targetWidget.defaultValues.bubble_opacity
                            onClicked: bubbleOpacityPreference.value = targetWidget.defaultValues.bubble_opacity
                        }

                    }

                    // ---------------------------------------------------------------- Sound
                    Heading {
                        text: qsTr("Sound")
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.SwitchPreference {
                            id: messageSoundsPreference

                            Layout.fillWidth: true

                            name: "sound_messages"
                            label: qsTr("Message Sounds")
                            message: qsTr("The sound of Yui's messages in the chat and in the crystal's bubble.")
                            defaultValue: true
                        }

                        ResetButton {
                            changed: !!messageSoundsPreference.value !== true
                            onClicked: messageSoundsPreference.value = true
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.SwitchPreference {
                            id: interfaceSoundsPreference

                            Layout.fillWidth: true

                            name: "sound_interface"
                            label: qsTr("Interface Sounds")
                            message: qsTr("The sounds of the chat panel opening and closing.")
                            defaultValue: true
                        }

                        ResetButton {
                            changed: !!interfaceSoundsPreference.value !== true
                            onClicked: interfaceSoundsPreference.value = true
                        }

                    }

                    // ---------------------------------------------------------------- Forms
                    Heading {
                        text: qsTr("Forms")
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.SelectPreference {
                            id: formPreference

                            Layout.fillWidth: true

                            name: "collapsed_form"
                            label: qsTr("Collapsed Form")
                            model: [qsTr("Navigation Pixie"), qsTr("Yui's Heart Crystal")]
                            defaultValue: 0
                        }

                        ResetButton {
                            changed: formPreference.value !== 0
                            onClicked: formPreference.value = 0
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.SliderPreference {
                            id: crystalSizePreference

                            Layout.fillWidth: true

                            name: "crystal_size"
                            label: qsTr("Crystal Size")
                            from: 60
                            to: 300
                            stepSize: 10
                            defaultValue: targetWidget.defaultValues.crystal_size
                            displayValue: qsTr("%1 px").arg(value)
                        }

                        ResetButton {
                            changed: crystalSizePreference.value !== targetWidget.defaultValues.crystal_size
                            onClicked: crystalSizePreference.value = targetWidget.defaultValues.crystal_size
                        }

                    }

                    SettingNote {
                        text: qsTr("What Yui turns into while the message window is hidden. The crystal glows green, yellow or red with the CPU load; the pixie needs a Navigation Pixie Form image, otherwise the avatar is shown.")
                    }

                    P.ImagePreference {
                        id: pixieImagePreference

                        name: "pixie_image_path"
                        label: qsTr("Navigation Pixie Form")
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        P.SliderPreference {
                            id: pixieSizePreference

                            Layout.fillWidth: true

                            name: "pixie_size"
                            label: qsTr("Pixie Size")
                            from: 80
                            to: 400
                            stepSize: 10
                            defaultValue: targetWidget.defaultValues.pixie_size
                            displayValue: qsTr("%1 px").arg(value)
                        }

                        ResetButton {
                            changed: pixieSizePreference.value !== targetWidget.defaultValues.pixie_size
                            onClicked: pixieSizePreference.value = targetWidget.defaultValues.pixie_size
                        }

                    }

                    SettingNote {
                        text: qsTr("When set, Yui turns into a small pixie while the message window is hidden. Pixie Size is its height.")
                    }

                    P.ImagePreference {
                        id: standbyImagePreference

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
                        id: happyPreference

                        name: "expression_happy"
                        label: qsTr("Happy")
                    }

                    P.ImagePreference {
                        id: sadPreference

                        name: "expression_sad"
                        label: qsTr("Sad")
                    }

                    P.ImagePreference {
                        id: surprisedPreference

                        name: "expression_surprised"
                        label: qsTr("Surprised")
                    }

                    P.ImagePreference {
                        id: angryPreference

                        name: "expression_angry"
                        label: qsTr("Angry")
                    }

                    P.ImagePreference {
                        id: shyPreference

                        name: "expression_shy"
                        label: qsTr("Shy")
                    }

                }

            }

        }

        header: TitleBar {
            // Every settings window has the same light title bar (as SAO Utils' own dialogs, e.g. the
            // mail box composer); without this some came out in the theme's blue.
            Style.primary: styleSettingsWindow.Style.dialogColor
            text: qsTr("Equipment")
            standardButtons: Dialog.Save | Dialog.Reset
            onAccepted: {
                saveStyles();
                styleSettingsWindow.close();
            }
            onReset: targetWidget.confirmReset(qsTr("Equipment"), function() {
                resetStyles();
                // and saves the reset state right away
                saveStyles();
            })
        }

    }

}
