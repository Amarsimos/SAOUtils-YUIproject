import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

NVG.Window {
    id: styleSettingsWindow

    property var targetWidget
    property var configuration

    title: qsTr("Style Settings")
    visible: true
    minimumWidth: 480
    minimumHeight: 640
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

                    // width: scrollView.width
                    Layout.fillWidth: true
                    spacing: 10
                    Component.onCompleted: {
                        if (targetWidget) {
                            rootPreference.load(targetWidget.settings.styles);
                            configuration = targetWidget.settings.styles;
                        }
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
                        defaultValue: targetWidget.defaultValues.bubble_font_family
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
                configuration = rootPreference.save();
                widget.settings.styles = configuration;
                styleSettingsWindow.close();
            }
            onRejected: {
                styleSettingsWindow.close();
            }
            onReset: {
                rootPreference.load(); // 这会自动加载所有 defaultValue
                // 立即保存重置后的状态
                configuration = rootPreference.save();
                widget.settings.styles = configuration;
            }
        }

    }

}
