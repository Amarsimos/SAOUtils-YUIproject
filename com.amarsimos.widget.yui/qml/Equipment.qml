import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

NVG.Window {
    id: styleSettingsWindow

    property var targetWidget

    // Message Font is SAO Utils' own font preference (a whole font); the styles keep it apart as before
    // (bubble_font_family, a name, and bubble_font_size, in px) and the rest in bubble_font_style
    // ({weight, italic, underline, strikeout}), read by the widget.
    readonly property font defaultMessageFont: Qt.font({
        "family": targetWidget.defaultValues.bubble_font_family,
        "pixelSize": targetWidget.defaultValues.bubble_font_size
    })

    function messageFontOf(styles) {
        var style = styles.bubble_font_style || {};
        return Qt.font({
            "family": targetWidget.fontFamilyOf(styles.bubble_font_family),
            "pixelSize": styles.bubble_font_size > 0 ? styles.bubble_font_size : targetWidget.defaultValues.bubble_font_size,
            "weight": style.weight !== undefined ? style.weight : Font.Normal,
            "italic": !!style.italic,
            "underline": !!style.underline,
            "strikeout": !!style.strikeout
        });
    }

    // Collapsed forms, stored by id; the SelectPreference works with indexes.
    readonly property var collapsedFormIds: ["pixie", "crystal"]

    function toPreferences(styles) {
        var values = JSON.parse(JSON.stringify(styles));
        values.message_font = messageFontOf(styles);
        values.collapsed_form = Math.max(0, collapsedFormIds.indexOf(styles.collapsed_form));
        return values;
    }

    function fromPreferences(values) {
        var font = values.message_font;
        delete values.message_font;
        if (font && font.family) {
            values.bubble_font_family = font.family;
            values.bubble_font_size = Yui.fontPixels(font);
            values.bubble_font_style = {
                "weight": font.weight,
                "italic": font.italic,
                "underline": font.underline,
                "strikeout": font.strikeout
            };
        }
        values.collapsed_form = collapsedFormIds[values.collapsed_form] || "pixie";
        return values;
    }

    // Every preference of this window with its style key and default (in preference terms). They are
    // loaded and saved one by one.
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
                "key": "message_font",
                "preference": fontPreference,
                "defaultValue": defaultMessageFont
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
                "key": "link_start",
                "preference": linkStartPreference,
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
    readonly property var interfaceTabPreferences: [fontPreference, chatOpacityPreference, bubbleSecondsPreference, bubbleOpacityPreference, messageSoundsPreference, interfaceSoundsPreference, linkStartPreference]

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
            // Little room at the sides: the settings have their own 16 px padding.
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.bottomMargin: 16
            spacing: 10

            // Wraps into a second row when the window is narrow (see WrapTabBar.qml).
            WrapTabBar {
                id: tabs

                Layout.fillWidth: true
                currentIndex: Math.max(0, Math.min(2, targetWidget.settings.equipment_tab || 0))
                onCurrentIndexChanged: targetWidget.settings.equipment_tab = currentIndex
                model: [qsTr("Avatar"), qsTr("Forms"), qsTr("Interface")]
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabs.shownIndex

                // ---------------------------------------------------------------- Avatar
                SettingsPage {
                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        P.ImagePreference {
                            id: avatarPreference

                            name: "character_image_path"
                            label: qsTr("Avatar")
                            defaultValue: targetWidget.defaultValues.character_image_path
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui's main image, shown next to the message window.")
                        }

                        P.BackgroundPreference {
                            id: fieldPreference

                            visible: targetWidget.settingsAdvanced

                            name: "background_image_path"
                            label: qsTr("Field")
                            defaultValue: targetWidget.defaultValues.background_image_path
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp && (targetWidget.settingsAdvanced)
                            besidePreferences: true
                            text: qsTr("The background behind the whole widget.")
                        }

                        P.ImagePreference {
                            id: standbyImagePreference

                            name: "sleep_image_path"
                            label: qsTr("Standby Form")
                            defaultValue: ""
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Shown while Yui is asleep. Without it, the avatar is dimmed instead.")
                        }

                        // ---------------------------------------------------------------- Emotion display
                        // The five expression images, in a dialog of their own (they are set once and take room).
                        P.DialogPreference {
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

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui changes her expression with the mood of each reply. Empty slots use the avatar.")
                        }

                    }

                    ResetTabButton {
                        yui: styleSettingsWindow.targetWidget
                        windowTitle: styleSettingsWindow.title
                        tabTitle: qsTr("Avatar")
                        preferences: styleSettingsWindow.avatarTabPreferences
                    }

                }

                // ---------------------------------------------------------------- Forms
                SettingsPage {
                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        P.SelectPreference {
                            id: formPreference

                            name: "collapsed_form"
                            label: qsTr("Collapsed Form")
                            model: [qsTr("Navigation Pixie"), qsTr("Yui's Heart Crystal")]
                            defaultValue: 0
                            // Switching keeps her height: the new form takes the size of the one shown
                            // (the avatar is 300 px high), within its slider's range.
                            onValueChanged: {
                                if (styleSettingsWindow.loading)
                                    return;

                                var shown = targetWidget.collapsedForm === "avatar" ? 300 : (value === 1 ? pixieSizePreference.value : crystalSizePreference.value);
                                var size = value === 1 ? crystalSizePreference : pixieSizePreference;
                                size.value = Math.max(size.from, Math.min(size.to, Math.round(shown / 10) * 10));
                            }
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("What Yui turns into while the message window is hidden. The crystal glows green, yellow or red with the CPU, GPU and memory load; the pixie needs a Navigation Pixie Form image, otherwise the avatar is shown.")
                        }

                        P.SliderPreference {
                            id: crystalSizePreference

                            // Updates (and shows its value) while being dragged.
                            live: true

                            name: "crystal_size"
                            label: qsTr("Crystal Size")
                            from: 60
                            to: 300
                            stepSize: 10
                            defaultValue: targetWidget.defaultValues.crystal_size
                            displayValue: qsTr("%1 px").arg(value)
                        }

                        P.ImagePreference {
                            id: pixieImagePreference

                            name: "pixie_image_path"
                            label: qsTr("Navigation Pixie Form")
                            defaultValue: targetWidget.defaultValues.pixie_image_path
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("When set, Yui turns into a small pixie while the message window is hidden. Pixie Size is its height.")
                        }

                        P.SliderPreference {
                            id: pixieSizePreference

                            // Updates (and shows its value) while being dragged.
                            live: true

                            name: "pixie_size"
                            label: qsTr("Pixie Size")
                            from: 80
                            to: 400
                            stepSize: 10
                            defaultValue: targetWidget.defaultValues.pixie_size
                            displayValue: qsTr("%1 px").arg(value)
                        }
                    }

                    ResetTabButton {
                        yui: styleSettingsWindow.targetWidget
                        windowTitle: styleSettingsWindow.title
                        tabTitle: qsTr("Forms")
                        preferences: styleSettingsWindow.formsTabPreferences
                    }

                }

                // ---------------------------------------------------------------- Interface
                SettingsPage {
                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        // ---------------------------------------------------------------- Message window
                        Heading {
                            text: qsTr("Message Window")
                        }

                        // SAO Utils' own font preference (family and size in one).
                        P.FontPreference {
                            id: fontPreference

                            label: qsTr("Message Font")
                            defaultValue: styleSettingsWindow.defaultMessageFont
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Font and size of the text in the message windows.")
                        }

                        P.SliderPreference {
                            id: chatOpacityPreference

                            visible: targetWidget.settingsAdvanced
                            // Updates (and shows its value) while being dragged.
                            live: true

                            name: "chat_opacity"
                            label: qsTr("Chat Panel Opacity")
                            from: 0
                            to: 100
                            stepSize: 1
                            defaultValue: targetWidget.defaultValues.chat_opacity
                            displayValue: qsTr("%1 %").arg(value)
                        }

                        // ---------------------------------------------------------------- Speech bubble
                        Heading {
                            visible: targetWidget.settingsAdvanced
                            text: qsTr("Speech Bubble")
                        }

                        P.SliderPreference {
                            id: bubbleSecondsPreference

                            visible: targetWidget.settingsAdvanced
                            // Updates (and shows its value) while being dragged.
                            live: true

                            name: "bubble_seconds"
                            label: qsTr("Bubble Duration")
                            from: 3
                            to: 30
                            stepSize: 1
                            defaultValue: targetWidget.defaultValues.bubble_seconds
                            displayValue: qsTr("%1 s").arg(value)
                        }

                        P.SliderPreference {
                            id: bubbleOpacityPreference

                            visible: targetWidget.settingsAdvanced
                            // Updates (and shows its value) while being dragged.
                            live: true

                            name: "bubble_opacity"
                            label: qsTr("Bubble Opacity")
                            from: 0
                            to: 100
                            stepSize: 1
                            defaultValue: targetWidget.defaultValues.bubble_opacity
                            displayValue: qsTr("%1 %").arg(value)
                        }

                        // ---------------------------------------------------------------- Sound
                        Heading {
                            text: qsTr("Sound")
                        }

                        P.SwitchPreference {
                            id: messageSoundsPreference

                            name: "sound_messages"
                            label: qsTr("Message Sounds")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("The sound of Yui's messages in the chat and in her speech bubble.")
                        }

                        P.SwitchPreference {
                            id: interfaceSoundsPreference

                            name: "sound_interface"
                            label: qsTr("Interface Sounds")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("The sounds of the chat panel opening and closing.")
                        }

                        P.SwitchPreference {
                            id: linkStartPreference

                            name: "link_start"
                            label: qsTr("Link Start")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("When SAO Utils starts, Yui appears from her heart crystal.")
                        }
                    }

                    ResetTabButton {
                        yui: styleSettingsWindow.targetWidget
                        windowTitle: styleSettingsWindow.title
                        tabTitle: qsTr("Interface")
                        preferences: styleSettingsWindow.interfaceTabPreferences
                    }

                }

            }

        }

        header: SettingsTitleBar {
            yui: styleSettingsWindow.targetWidget
            settingsWindow: styleSettingsWindow
            hasAdvanced: true
            onResetRequested: {
                resetStyles();
                // and saves the reset state right away
                saveStyles();
            }
        }

    }

}
