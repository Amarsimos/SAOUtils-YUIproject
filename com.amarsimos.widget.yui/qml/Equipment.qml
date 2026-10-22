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
    // (Filtered: a preference that does not exist yet is skipped.)
    function entries() {
        return entryList().filter(function(entry) {
            return !!entry.preference;
        });
    }

    function entryList() {
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
                "defaultValue": targetWidget.defaultValues.pixie_image_path
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

    // The settings of each tab, for its Reset This Tab button.
    readonly property var avatarTabPreferences: [avatarPreference, fieldPreference, standbyImagePreference, happyPreference, sadPreference, surprisedPreference, angryPreference, shyPreference]
    readonly property var formsTabPreferences: [formPreference, crystalSizePreference, pixieImagePreference, pixieSizePreference]
    readonly property var interfaceTabPreferences: [fontPreference, fontSizePreference, chatOpacityPreference, bubbleSecondsPreference, bubbleOpacityPreference, messageSoundsPreference, interfaceSoundsPreference]

    function anyChanged(preferences) {
        return preferences.some(function(preference) {
            return preference && JSON.stringify(preference.value) !== JSON.stringify(preference.defaultValue);
        });
    }

    // Restores a tab's settings to their defaults (Preference.load() takes each one's defaultValue),
    // after asking; each change is saved at once as usual.
    function resetTab(tabTitle, preferences) {
        targetWidget.confirmReset(qsTr("Equipment") + " · " + tabTitle, function() {
            preferences.forEach(function(preference) {
                if (preference)
                    preference.load();

            });
        });
    }

    // True while values are put into the preferences (not changes by the user).
    property bool loading: true

    function loadStyles(styles) {
        loading = true;
        var values = toPreferences(styles);
        entries().forEach(function(entry) {
            entry.preference.value = values[entry.key] !== undefined ? values[entry.key] : entry.defaultValue;
        });
        loading = false;
    }

    // Changes take effect at once (no Save button), so the look can be tried out live.
    function styleChanged() {
        if (!loading)
            saveStyles();

    }

    function saveStyles() {
        var values = JSON.parse(JSON.stringify(targetWidget.styles));
        entries().forEach(function(entry) {
            values[entry.key] = entry.preference.value;
        });
        targetWidget.settings.styles = fromPreferences(values);
    }

    function resetStyles() {
        loading = true;
        entries().forEach(function(entry) {
            entry.preference.value = entry.defaultValue;
        });
        loading = false;
    }

    Component.onCompleted: {
        loadStyles(targetWidget.styles);
        entries().forEach(function(entry) {
            entry.preference.valueChanged.connect(styleChanged);
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

        // Three tabs (as Yui's Heart): Avatar (her images), Forms (collapsed forms), Interface (message
        // window, bubble, sounds). The last tab shown is remembered.
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 0
            spacing: 10

            TabBar {
                id: tabs

                Layout.fillWidth: true
                currentIndex: Math.max(0, Math.min(2, targetWidget.settings.equipment_tab || 0))
                onCurrentIndexChanged: targetWidget.settings.equipment_tab = currentIndex

                TabButton {
                    text: qsTr("Avatar")
                }

                TabButton {
                    text: qsTr("Forms")
                }

                TabButton {
                    text: qsTr("Interface")
                }

            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabs.currentIndex

                // ---------------------------------------------------------------- Avatar
                ScrollView {
                    id: avatarScroll

                    clip: true
                    // Only vertical scrolling: the page is as wide as the window, minus the vertical scroll
                    // bar (which is drawn over the page and covered the values at the right edge).
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: avatarScroll.availableWidth - avatarScroll.ScrollBar.vertical.width - 4

                        P.PreferenceGroup {
                            Layout.fillWidth: true
                            spacing: 10

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
                                    preference: avatarPreference
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
                                    preference: fieldPreference
                                }

                            }

                            SettingNote {
                                text: qsTr("The background behind the whole widget.")
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                P.ImagePreference {
                                    id: standbyImagePreference

                                    Layout.fillWidth: true
                                    name: "sleep_image_path"
                                    label: qsTr("Standby Form")
                                    defaultValue: ""
                                }

                                ResetButton {
                                    preference: standbyImagePreference
                                }

                            }

                            SettingNote {
                                text: qsTr("Shown while Yui is asleep. Without it, the avatar is dimmed instead.")
                            }

                            // ---------------------------------------------------------------- Emotion display
                            // The five expression images, in a dialog of their own (they are set once and take room); ↺
                            // restores all five.
                            RowLayout {
                                Layout.fillWidth: true

                                P.DialogPreference {
                                    Layout.fillWidth: true
                                    label: qsTr("Emotion Display")
                                    live: true
                                    displayValue: qsTr("%1 / 5 set").arg([happyPreference, sadPreference, surprisedPreference, angryPreference, shyPreference].filter(function(preference) {
                                        return preference && targetWidget.hasImage(preference.value);
                                    }).length)

                                    P.ImagePreference {
                                        id: happyPreference

                                        name: "expression_happy"
                                        label: qsTr("Happy")
                                        defaultValue: ""
                                    }

                                    P.ImagePreference {
                                        id: sadPreference

                                        name: "expression_sad"
                                        label: qsTr("Sad")
                                        defaultValue: ""
                                    }

                                    P.ImagePreference {
                                        id: surprisedPreference

                                        name: "expression_surprised"
                                        label: qsTr("Surprised")
                                        defaultValue: ""
                                    }

                                    P.ImagePreference {
                                        id: angryPreference

                                        name: "expression_angry"
                                        label: qsTr("Angry")
                                        defaultValue: ""
                                    }

                                    P.ImagePreference {
                                        id: shyPreference

                                        name: "expression_shy"
                                        label: qsTr("Shy")
                                        defaultValue: ""
                                    }
                                }

                                ResetButton {
                                    preferences: [happyPreference, sadPreference, surprisedPreference, angryPreference, shyPreference]
                                }

                            }

                            SettingNote {
                                text: qsTr("Yui changes her expression with the mood of each reply. Empty slots use the avatar.")
                            }
                        }

                        // Restores every setting of this tab (after asking).
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.topMargin: 8
                            flat: true
                            text: qsTr("Reset This Tab")
                            enabled: styleSettingsWindow.anyChanged(styleSettingsWindow.avatarTabPreferences)
                            onClicked: styleSettingsWindow.resetTab(qsTr("Avatar"), styleSettingsWindow.avatarTabPreferences)
                        }

                    }

                }

                // ---------------------------------------------------------------- Forms
                ScrollView {
                    id: formsScroll

                    clip: true
                    // Only vertical scrolling: the page is as wide as the window, minus the vertical scroll
                    // bar (which is drawn over the page and covered the values at the right edge).
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: formsScroll.availableWidth - formsScroll.ScrollBar.vertical.width - 4

                        P.PreferenceGroup {
                            Layout.fillWidth: true
                            spacing: 10

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
                                    preference: formPreference
                                }

                            }

                            RowLayout {
                                Layout.fillWidth: true

                                P.SliderPreference {
                                    id: crystalSizePreference

                                    // Updates (and shows its value) while being dragged.
                                    live: true
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
                                    preference: crystalSizePreference
                                }

                            }

                            SettingNote {
                                text: qsTr("What Yui turns into while the message window is hidden. The crystal glows green, yellow or red with the CPU load; the pixie needs a Navigation Pixie Form image, otherwise the avatar is shown.")
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                P.ImagePreference {
                                    id: pixieImagePreference

                                    Layout.fillWidth: true
                                    name: "pixie_image_path"
                                    label: qsTr("Navigation Pixie Form")
                                    defaultValue: targetWidget.defaultValues.pixie_image_path
                                }

                                ResetButton {
                                    preference: pixieImagePreference
                                }

                            }

                            RowLayout {
                                Layout.fillWidth: true

                                P.SliderPreference {
                                    id: pixieSizePreference

                                    // Updates (and shows its value) while being dragged.
                                    live: true
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
                                    preference: pixieSizePreference
                                }

                            }

                            SettingNote {
                                text: qsTr("When set, Yui turns into a small pixie while the message window is hidden. Pixie Size is its height.")
                            }
                        }

                        // Restores every setting of this tab (after asking).
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.topMargin: 8
                            flat: true
                            text: qsTr("Reset This Tab")
                            enabled: styleSettingsWindow.anyChanged(styleSettingsWindow.formsTabPreferences)
                            onClicked: styleSettingsWindow.resetTab(qsTr("Forms"), styleSettingsWindow.formsTabPreferences)
                        }

                    }

                }

                // ---------------------------------------------------------------- Interface
                ScrollView {
                    id: interfaceScroll

                    clip: true
                    // Only vertical scrolling: the page is as wide as the window, minus the vertical scroll
                    // bar (which is drawn over the page and covered the values at the right edge).
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: interfaceScroll.availableWidth - interfaceScroll.ScrollBar.vertical.width - 4

                        P.PreferenceGroup {
                            Layout.fillWidth: true
                            spacing: 10

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
                                    preference: fontPreference
                                }

                            }

                            RowLayout {
                                Layout.fillWidth: true

                                P.SliderPreference {
                                    id: fontSizePreference

                                    // Updates (and shows its value) while being dragged.
                                    live: true
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
                                    preference: fontSizePreference
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

                                    // Updates (and shows its value) while being dragged.
                                    live: true
                                    Layout.fillWidth: true

                                    name: "chat_opacity"
                                    label: qsTr("Chat Panel Opacity")
                                    from: 0
                                    to: 100
                                    stepSize: 1
                                    defaultValue: targetWidget.defaultValues.chat_opacity
                                    displayValue: qsTr("%1 %").arg(value)
                                }

                                ResetButton {
                                    preference: chatOpacityPreference
                                }

                            }

                            // ---------------------------------------------------------------- Speech bubble
                            Heading {
                                text: qsTr("Speech Bubble")
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                P.SliderPreference {
                                    id: bubbleSecondsPreference

                                    // Updates (and shows its value) while being dragged.
                                    live: true
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
                                    preference: bubbleSecondsPreference
                                }

                            }

                            RowLayout {
                                Layout.fillWidth: true

                                P.SliderPreference {
                                    id: bubbleOpacityPreference

                                    // Updates (and shows its value) while being dragged.
                                    live: true
                                    Layout.fillWidth: true

                                    name: "bubble_opacity"
                                    label: qsTr("Bubble Opacity")
                                    from: 0
                                    to: 100
                                    stepSize: 1
                                    defaultValue: targetWidget.defaultValues.bubble_opacity
                                    displayValue: qsTr("%1 %").arg(value)
                                }

                                ResetButton {
                                    preference: bubbleOpacityPreference
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
                                    message: qsTr("The sound of Yui's messages in the chat and in her speech bubble.")
                                    defaultValue: true
                                }

                                ResetButton {
                                    preference: messageSoundsPreference
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
                                    preference: interfaceSoundsPreference
                                }

                            }
                        }

                        // Restores every setting of this tab (after asking).
                        Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.topMargin: 8
                            flat: true
                            text: qsTr("Reset This Tab")
                            enabled: styleSettingsWindow.anyChanged(styleSettingsWindow.interfaceTabPreferences)
                            onClicked: styleSettingsWindow.resetTab(qsTr("Interface"), styleSettingsWindow.interfaceTabPreferences)
                        }

                    }

                }

            }

        }

        header: TitleBar {
            // Every settings window has the same light title bar (as SAO Utils' own dialogs, e.g. the
            // mail box composer); without this some came out in the theme's blue.
            Style.primary: styleSettingsWindow.Style.dialogColor
            text: qsTr("Equipment")
            standardButtons: Dialog.Reset
            onReset: targetWidget.confirmReset(qsTr("Equipment"), function() {
                resetStyles();
                // and saves the reset state right away
                saveStyles();
            })
        }

    }

}
