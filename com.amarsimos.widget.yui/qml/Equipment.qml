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

                    // Message windows have the SAO colors; only the text's font and size are settings.
                    SettingNote {
                        text: qsTr("Font and size of the text in the message windows.")
                    }

                    P.SliderPreference {
                        name: "chat_opacity"
                        label: qsTr("Chat Panel Opacity")
                        from: 30
                        to: 100
                        stepSize: 5
                        defaultValue: targetWidget.defaultValues.chat_opacity
                        displayValue: qsTr("%1 %").arg(value)
                    }

                    // ---------------------------------------------------------------- Crystal bubble
                    Heading {
                        text: qsTr("Crystal Bubble")
                    }

                    P.SliderPreference {
                        name: "bubble_seconds"
                        label: qsTr("Bubble Duration")
                        from: 3
                        to: 30
                        stepSize: 1
                        defaultValue: targetWidget.defaultValues.bubble_seconds
                        displayValue: qsTr("%1 s").arg(value)
                    }

                    P.SliderPreference {
                        name: "bubble_opacity"
                        label: qsTr("Bubble Opacity")
                        from: 30
                        to: 100
                        stepSize: 5
                        defaultValue: targetWidget.defaultValues.bubble_opacity
                        displayValue: qsTr("%1 %").arg(value)
                    }

                    // ---------------------------------------------------------------- Sound
                    Heading {
                        text: qsTr("Sound")
                    }

                    P.SwitchPreference {
                        name: "sound_messages"
                        label: qsTr("Message Sounds")
                        message: qsTr("The sound of Yui's messages in the chat and in the crystal's bubble.")
                        defaultValue: true
                    }

                    P.SwitchPreference {
                        name: "sound_interface"
                        label: qsTr("Interface Sounds")
                        message: qsTr("The sounds of the chat panel opening and closing.")
                        defaultValue: true
                    }

                    // ---------------------------------------------------------------- Forms
                    Heading {
                        text: qsTr("Forms")
                    }

                    P.SelectPreference {
                        name: "collapsed_form"
                        label: qsTr("Collapsed Form")
                        model: [qsTr("Navigation Pixie"), qsTr("Yui's Heart Crystal")]
                        defaultValue: 0
                    }

                    P.SliderPreference {
                        name: "crystal_size"
                        label: qsTr("Crystal Size")
                        from: 60
                        to: 300
                        stepSize: 10
                        defaultValue: targetWidget.defaultValues.crystal_size
                        displayValue: qsTr("%1 px").arg(value)
                    }

                    SettingNote {
                        text: qsTr("What Yui turns into while the message window is hidden. The crystal glows green, yellow or red with the CPU load; the pixie needs a Navigation Pixie Form image, otherwise the avatar is shown.")
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
                rootPreference.load(); // loads every defaultValue
                // and saves the reset state right away
                saveStyles();
            })
        }

    }

}
