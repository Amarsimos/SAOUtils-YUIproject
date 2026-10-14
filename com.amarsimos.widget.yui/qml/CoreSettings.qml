import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

NVG.Window {
    id: coreSettings

    property var targetWidget
    // Working copy of settings.provider_settings, keyed by provider id.
    property var providerSettings: ({
    })
    // Index of the provider whose fields are currently shown.
    property int shownProvider: -1
    property bool loading: true

    function open() {
        visible = true;
    }

    // Fill the model/endpoint/key fields with the saved values of a provider.
    function showProvider(index, saved) {
        var provider = targetWidget.providers[index];
        saved = saved || {
        };
        shownProvider = index;
        modelPreference.model = provider.models;
        var modelIndex = provider.models.indexOf(saved.model);
        modelPreference.value = modelIndex >= 0 ? modelIndex : 0;
        customModelPreference.value = saved.custom_model || "";
        apiEndpointPreference.value = saved.api_endpoint || provider.endpoint;
        apiKeyPreference.value = saved.api_key || "";
    }

    // Read the shown fields back into a provider_settings entry.
    function shownSettings() {
        var provider = targetWidget.providers[shownProvider];
        return {
            "model": provider.models[modelPreference.value] || "",
            "custom_model": customModelPreference.value || "",
            "api_endpoint": apiEndpointPreference.value || "",
            "api_key": apiKeyPreference.value || ""
        };
    }

    function stashShownProvider() {
        if (shownProvider >= 0)
            providerSettings[targetWidget.providers[shownProvider].id] = shownSettings();

    }

    title: qsTr("Core Settings")
    visible: true
    minimumWidth: 480
    // Content scrolls, so keep the window usable on small screens.
    minimumHeight: 480
    width: minimumWidth
    height: 930
    transientParent: widget.NVG.View.window
    onClosing: {
        // When the window is closed, destroy the object to free up resources.
        // A new one is created every time the settings action is triggered.
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
                        var settings = targetWidget.settings;
                        providerSettings = JSON.parse(JSON.stringify(settings.provider_settings || {
                        }));
                        var index = targetWidget.providerIndexOf(settings.provider);
                        providerPreference.value = index;
                        showProvider(index, providerSettings[targetWidget.providers[index].id]);
                        systemPromptPreference.value = settings.system_prompt !== undefined ? settings.system_prompt : targetWidget.defaultSystemPrompt;
                        userTitlePreference.value = Math.max(0, userTitlePreference.ids.indexOf(settings.user_title));
                        loading = false;
                    }

                    Heading {
                        text: qsTr("Model")
                    }

                    P.SelectPreference {
                        id: providerPreference

                        name: "provider"
                        label: qsTr("Provider")
                        model: targetWidget.providers.map(function(provider) {
                            return provider.title;
                        })
                        onValueChanged: {
                            if (loading || value < 0 || value === shownProvider)
                                return ;

                            stashShownProvider();
                            showProvider(value, providerSettings[targetWidget.providers[value].id]);
                        }
                    }

                    P.SelectPreference {
                        id: modelPreference

                        name: "model"
                        label: qsTr("Model")
                        visible: model.length > 0
                    }

                    P.TextFieldPreference {
                        id: customModelPreference

                        name: "custom_model"
                        label: qsTr("Custom Model")
                        display: P.TextFieldPreference.ExpandControl
                        hint: qsTr("Overrides the model selected above when not empty.")
                    }

                    Heading {
                        text: qsTr("API Configuration")
                    }

                    P.TextFieldPreference {
                        id: apiEndpointPreference

                        name: "api_endpoint"
                        label: qsTr("API Endpoint")
                        display: P.TextFieldPreference.ExpandControl
                    }

                    P.TextFieldPreference {
                        id: apiKeyPreference

                        name: "api_key"
                        label: qsTr("API Key")
                        display: P.TextFieldPreference.ExpandControl
                        echoMode: TextInput.Password
                        hint: qsTr("Each provider keeps its own API key.")
                    }

                    RowLayout {
                        spacing: 20
                        Layout.alignment: Qt.AlignHCenter

                        Button {
                            text: qsTr("Test API")
                            onClicked: {
                                apiResponseArea.value = "Testing...";
                                var config = targetWidget.providerConfig(targetWidget.providers[shownProvider], shownSettings());
                                config.systemPrompt = systemPromptPreference.value;
                                config.userTitle = userTitlePreference.model[userTitlePreference.value].split(" ")[0];
                                targetWidget.requestCompletion([{
                                    "role": "user",
                                    "content": "Hello"
                                }], function(text, isError) {
                                    apiResponseArea.value = (isError ? "" : "OK (" + config.model + "):\n") + text;
                                }, config);
                            }
                        }

                        Button {
                            text: qsTr("Clear Response")
                            onClicked: {
                                apiResponseArea.value = "";
                            }
                        }

                    }

                    P.TextAreaPreference {
                        id: apiResponseArea

                        name: "api_response_text"
                        label: qsTr("API Response")
                        readOnly: true
                        hint: qsTr("API response will be shown here.")
                        wrapMode: Text.Wrap
                        font.family: "Microsoft YaHei"
                        Layout.fillWidth: true
                        Layout.minimumHeight: 20
                    }

                    Heading {
                        text: qsTr("System Prompt")
                    }

                    P.SelectPreference {
                        id: userTitlePreference

                        readonly property var ids: ["papa", "mama"]

                        name: "user_title"
                        label: qsTr("Yui calls you")
                        model: ["爸爸 (Papa)", "妈妈 (Mama)"]
                    }

                    P.TextAreaPreference {
                        id: systemPromptPreference

                        // No label: the "System Prompt" heading above already names it.
                        name: "system_prompt"
                        hint: qsTr("{{user_title}} is replaced with how Yui calls you.")
                        // The box grows with its text up to maximumHeight; make it 0.75x the default.
                        Component.onCompleted: {
                            if (isFinite(maximumHeight) && maximumHeight > 0)
                                maximumHeight = maximumHeight * 0.75;

                        }
                    }

                    RowLayout {
                        spacing: 20
                        Layout.alignment: Qt.AlignHCenter

                        Button {
                            text: qsTr("Default Prompt")
                            onClicked: {
                                systemPromptPreference.value = targetWidget.defaultSystemPrompt;
                            }
                        }

                        Button {
                            text: qsTr("Clear Prompt")
                            onClicked: {
                                systemPromptPreference.value = "";
                            }
                        }

                    }

                }

            }

        }

        header: TitleBar {
            text: qsTr("MHCP-YUI")
            standardButtons: Dialog.Save | Dialog.Reset
            onAccepted: {
                stashShownProvider();
                targetWidget.settings.provider = targetWidget.providers[shownProvider].id;
                targetWidget.settings.provider_settings = JSON.parse(JSON.stringify(providerSettings));
                targetWidget.settings.system_prompt = systemPromptPreference.value;
                targetWidget.settings.user_title = userTitlePreference.ids[userTitlePreference.value] || "papa";
                coreSettings.close();
            }
            onReset: {
                // Reset the shown provider to its defaults; other providers keep their settings.
                showProvider(shownProvider, null);
                systemPromptPreference.value = targetWidget.defaultSystemPrompt;
                userTitlePreference.value = 0;
            }
        }

    }

}
