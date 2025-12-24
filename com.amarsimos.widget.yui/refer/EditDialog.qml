import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Window 2.12

import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P

NVG.Window {
    id: dialog

    readonly property var names: [
        "Asuna","Egil","Kayaba","Kirito","Klein","Leafa","Rizbet","Sachi","Shinon","Silica","Sterben","Yui","Yuuki"
    ]

    title: widget.title
    visible: true
    minimumWidth: 360
    minimumHeight: 640
    transientParent: widget.NVG.View.window

    onClosing: titleBar.forceActiveFocus()

    Page {
        anchors.fill: parent

        header: TitleBar { id: titleBar; text: dialog.title }

        Column {
            id: preferenceLayout
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            P.ObjectPreferenceGroup {
                width: parent.width
                label: qsTr("Widget Settings")

                defaultValue: widget.settings
                syncProperties: true

                P.SwitchPreference {
                    name: "animation"
                    label: qsTr("Enable Animation")
                    defaultValue: true
                }

                P.SelectPreference {
                    id: pStyle
                    name: "style"
                    label: qsTr("Style")
                    textRole: "label"
                    defaultValue: 0

                    model: {
                        const files = [ { label: "ALO", url: "StyleALO.qml" } ];
                        const resources = NVG.Resources.filter(/.*/, /com.gpbeta.hp-bar(?:$|\/.+)/);
                        resources.forEach(function (resource) {
                            resource.files().forEach(function (file) {
                                files.push({ label: file.title || file.name, url: file.url });
                            });
                        });
                        return files;
                    }

                    load: function (newValue) {
                        if (newValue === undefined) {
                            value = defaultValue;
                            return;
                        }

                        let index = -1;
                        for (let i = 0; i < model.length; ++i) {
                            const file = model[i];
                            // comparing between url object and string types
                            if (file.url == newValue) {
                                index = i;
                                break;
                            }
                        }
                        value = index;
                    }

                    save: ()=>model[value].url
                }
            }

            P.ObjectPreferenceGroup {
                width: parent.width
                label: qsTr("Item Settings")

                defaultValue: widget.currentIndex < 0 ? widget.settings.main :
                                                          view.ctx_extraItems.get(widget.currentIndex)
                syncProperties: true

                P.TextFieldPreference {
                    name: "label"
                    label: qsTr("Name")
                    display: P.TextFieldPreference.ExpandLabel
                }

                P.IconPreference {
                    name: "icon"
                    label: qsTr("Icon")

                    availableFilter: view.item?.iconAvailableFilter ?? null
                    preferableFilter: view.item?.iconPreferableFilter ?? defaultIconPreferableFilter

                    NVG.ResourceFilter {
                        id: defaultIconPreferableFilter
                        packagePattern: /com.gpbeta.widget.hp-bar/
                    }
                }

                P.DataPreference {
                    name: "data"
                    label: qsTr("Data 1")
                }

                P.DataPreference {
                    name: "data2"
                    label: qsTr("Data 2")
                    enabled: view.item?.secondaryData > 0
                }

                P.ActionPreference {
                    name: "action"
                    label: qsTr("Action")
                }

                P.ItemPreference {
                    label: qsTr("Order")
                    background.enabled: false

                    actionItem: Row {
                        rightPadding: -12

                        ToolButton {
                            enabled: widget.currentIndex > 0
                            icon.name: "regular:\uf106"

                            onClicked: {
                                const index = widget.currentIndex;
                                view.ctx_extraItems.move(index, index - 1, 1);
                                --widget.currentIndex;
                            }
                        }

                        ToolButton {
                            enabled: widget.currentIndex >= 0 &&
                                     widget.currentIndex + 1 < view.ctx_extraItems.count
                            icon.name: "regular:\uf107"

                            onClicked: {
                                const index = widget.currentIndex;
                                view.ctx_extraItems.move(index, index + 1, 1);
                                ++widget.currentIndex;
                            }
                        }

                    }
                }

                P.Separator {}

                Button {
                    text: qsTr("Add Item")
                    flat: true

                    onClicked: {
                        const settings = NVG.Settings.createMap(view.ctx_extraItems);
                        settings.label = names[Math.floor(Math.random() * names.length)];
                        view.ctx_extraItems.insert(widget.currentIndex + 1, settings);
                        ++widget.currentIndex;
                    }
                }

                Button {
                    text: qsTr("Remove Item")
                    highlighted: true
                    enabled: widget.currentIndex >= 0

                    onClicked: {
                        const index = widget.currentIndex;
                        if (index + 1 < view.ctx_extraItems.count)
                            ++widget.currentIndex;
                        else
                            --widget.currentIndex;
                        view.ctx_extraItems.remove(index);
                        if (widget.currentIndex > index)
                            --widget.currentIndex; // force rebinding settings
                    }
                }
            }
        }
    }
}
