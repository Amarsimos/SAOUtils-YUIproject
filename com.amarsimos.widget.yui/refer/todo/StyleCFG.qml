import QtQuick 2.12

import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P

NVG.Window {
    id: window
    title: qsTr("Settings")
    visible: true
    minimumWidth: 400
    minimumHeight: 625
    width: minimumWidth
    height: minimumHeight

    transientParent: widget.NVG.View.window

    property var configuration

    Page {
        id: cfg_page
        anchors.fill: parent

        header: TitleBar {
            text: qsTr("Settings")

            standardButtons: Dialog.Save | Dialog.Reset

            onAccepted: {
                configuration = rootPreference.save();
                widget.settings.styles = configuration;
                styleDialog.active = false;
            }

            onReset: {
                rootPreference.load();
                let cfg = rootPreference.save();
                widget.settings.styles = cfg;
            }
        }

        ColumnLayout {
            id: root
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 0

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                contentWidth: preferenceLayout.implicitWidth
                contentHeight: preferenceLayout.implicitHeight

                ColumnLayout {
                    id: preferenceLayout
                    width: root.width

                    P.PreferenceGroup {
                        id: rootPreference
                        Layout.fillWidth: true

                        label: qsTr("Configuration")

                        onPreferenceEdited: {
                            widget.settings.styles = rootPreference.save();
                            widget.settings.index_font_style = fonts[widget.settings.styles["Index Settings"]["Font Style"]];
                            widget.settings.content_font_style = fonts[widget.settings.styles["Content Settings"]["Font Style"]];
                        }

                        P.DialogPreference {
                            name: "Index Settings"
                            label: qsTr("Index Settings")
                            live: true

                            P.TextFieldPreference {
                                name: "Text"
                                label: qsTr("Text")
                                defaultValue: defaultValues["Index Settings"]["Text"]
                            }

                            P.SelectPreference {
                                name: "Font Style"
                                label: qsTr("Font Style")
                                defaultValue: defaultValues["Index Settings"]["Font Style"]
                                model: fonts
                            }

                            P.SliderPreference {
                                name: "Font Size"
                                label: qsTr("Font Size")
                                from: 10
                                to: 100
                                stepSize: 1
                                defaultValue: defaultValues["Index Settings"]["Font Size"]
                                displayValue: value
                            }

                            P.SelectPreference {
                                name: "Font Weight"
                                label: qsTr("Font Weight")
                                defaultValue: defaultValues["Index Settings"]["Font Weight"]
                                model: sfontweight
                            }

                            P.ColorPreference {
                                name: "Color"
                                label: qsTr("Color")
                                defaultValue: defaultValues["Index Settings"]["Color"]
                            }

                            P.ColorPreference {
                                name: "Shadow Color"
                                label: qsTr("Shadow Color")
                                defaultValue: defaultValues["Index Settings"]["Shadow Color"]
                            }

                            P.SliderPreference {
                                name: "Shadow Size"
                                label: qsTr("Shadow Size")
                                from: 0
                                to: 100
                                stepSize: 1
                                defaultValue: defaultValues["Index Settings"]["Shadow Size"]
                                displayValue: value + "%"
                            }

                            P.SliderPreference {
                                name: "X Offset"
                                label: qsTr("X Offset")
                                from: 0
                                to: 100
                                stepSize: 1
                                defaultValue: defaultValues["Index Settings"]["X Offset"]
                                displayValue: value + "%"
                            }
                        }

                        P.DialogPreference {
                            name: "Content Settings"
                            label: qsTr("Content Settings")
                            live: true

                            P.SelectPreference {
                                name: "Font Style"
                                label: qsTr("Font Style")
                                defaultValue: defaultValues["Content Settings"]["Font Style"]
                                model: fonts
                            }

                            P.SliderPreference {
                                name: "Font Size"
                                label: qsTr("Font Size")
                                from: 15
                                to: 50
                                stepSize: 1
                                defaultValue: defaultValues["Content Settings"]["Font Size"]
                                displayValue: value
                            }

                            P.SelectPreference {
                                name: "Font Weight"
                                label: qsTr("Font Weight")
                                defaultValue: defaultValues["Content Settings"]["Font Weight"]
                                model: sfontweight
                            }

                            P.ColorPreference {
                                name: "Todo Color"
                                label: qsTr("Todo Color")
                                defaultValue: defaultValues["Content Settings"]["Todo Color"]
                            }

                            P.ColorPreference {
                                name: "Done Color"
                                label: qsTr("Done Color")
                                defaultValue: defaultValues["Content Settings"]["Done Color"]
                            }

                            P.ColorPreference {
                                name: "Shadow Color"
                                label: qsTr("Shadow Color")
                                defaultValue: defaultValues["Content Settings"]["Shadow Color"]
                            }

                            P.SliderPreference {
                                name: "Shadow Size"
                                label: qsTr("Shadow Size")
                                from: 0
                                to: 100
                                stepSize: 1
                                defaultValue: defaultValues["Content Settings"]["Shadow Size"]
                                displayValue: value + "%"
                            }

                            P.SwitchPreference {
                                id: _cfg_show_priority
                                name: "Show Priority Flag"
                                label: qsTr("Show Priority Flag")
                                defaultValue: defaultValues["Content Settings"]["Show Priority Flag"]
                            }

                            P.ColorPreference {
                                name: "Priority Low Color"
                                label: qsTr("Priority Low Color")
                                defaultValue: defaultValues["Content Settings"]["Priority Low Color"]
                                enabled: _cfg_show_priority.value
                            }

                            P.ColorPreference {
                                name: "Priority Normal Color"
                                label: qsTr("Priority Normal Color")
                                defaultValue: defaultValues["Content Settings"]["Priority Normal Color"]
                                enabled: _cfg_show_priority.value
                            }

                            P.ColorPreference {
                                name: "Priority Medium Color"
                                label: qsTr("Priority Medium Color")
                                defaultValue: defaultValues["Content Settings"]["Priority Medium Color"]
                                enabled: _cfg_show_priority.value
                            }

                            P.ColorPreference {
                                name: "Priority High Color"
                                label: qsTr("Priority High Color")
                                defaultValue: defaultValues["Content Settings"]["Priority High Color"]
                                enabled: _cfg_show_priority.value
                            }

                            P.ColorPreference {
                                name: "Button Color"
                                label: qsTr("Button Color")
                                defaultValue: defaultValues["Content Settings"]["Button Color"]
                            }

                            P.SliderPreference {
                                name: "X Offset"
                                label: qsTr("X Offset")
                                from: 0
                                to: 100
                                stepSize: 1
                                defaultValue: defaultValues["Content Settings"]["X Offset"]
                                displayValue: value + "%"
                            }

                            P.SliderPreference {
                                name: "Y Offset"
                                label: qsTr("Y Offset")
                                from: 0
                                to: 100
                                stepSize: 1
                                defaultValue: defaultValues["Content Settings"]["Y Offset"]
                                displayValue: value + "%"
                            }
                        }

                        P.ColorPreference {
                            name: "Hover Color"
                            label: qsTr("Hover Color")
                            defaultValue: defaultValues["Hover Color"]
                        }

                        P.SwitchPreference {
                            name: "Confirm Before Delete"
                            label: qsTr("Confirm Before Delete")
                            defaultValue: defaultValues["Confirm Before Delete"]
                        }


                        Component.onCompleted: {
                            rootPreference.load(widget.settings.styles);
                            configuration = widget.settings.styles;
                        }
                    }
                }
            }
        }
    }

    onClosing: {
        widget.settings.styles = configuration;
        widget.settings.index_font_style = fonts[widget.settings.styles["Index Settings"]["Font Style"]];
        widget.settings.content_font_style = fonts[widget.settings.styles["Content Settings"]["Font Style"]];
        styleDialog.active = false;
    }
}
