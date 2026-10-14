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
    // Models in the model dropdown: the list fetched from the provider, or its preset list.
    property var shownModels: []
    // List fetched with "Refresh Model List" for the shown provider (null: use the preset list).
    property var shownFetchedModels: null
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
        shownFetchedModels = saved.fetched_models && saved.fetched_models.length > 0 ? saved.fetched_models : null;
        setModelList(shownFetchedModels || provider.models, saved.model);
        modelStatus.text = "";
        customModelPreference.value = saved.custom_model || "";
        apiEndpointPreference.value = saved.api_endpoint || provider.endpoint;
        apiKeyPreference.value = saved.api_key || "";
    }

    // Fill the model dropdown, keeping the given model selected when it is in the list.
    function setModelList(models, selected) {
        shownModels = models;
        modelPreference.model = models;
        var modelIndex = models.indexOf(selected);
        modelPreference.value = modelIndex >= 0 ? modelIndex : 0;
    }

    function refreshModelList() {
        var provider = targetWidget.providers[shownProvider];
        var current = shownModels[modelPreference.value];
        modelStatus.text = qsTr("Scanning...");
        targetWidget.fetchModels(targetWidget.providerConfig(provider, shownSettings()), function(models, error) {
            // The user switched to another provider meanwhile.
            if (targetWidget.providers[shownProvider] !== provider)
                return ;

            if (!models) {
                modelStatus.text = qsTr("Scan failed: %1").arg(error);
                return ;
            }
            shownFetchedModels = models;
            setModelList(models, current);
            modelStatus.text = qsTr("%1 cores found").arg(models.length);
        });
    }

    // Read the shown fields back into a provider_settings entry.
    function shownSettings() {
        return {
            "model": shownModels[modelPreference.value] || "",
            "fetched_models": shownFetchedModels,
            "custom_model": customModelPreference.value || "",
            "api_endpoint": apiEndpointPreference.value || "",
            "api_key": apiKeyPreference.value || ""
        };
    }

    function stashShownProvider() {
        if (shownProvider >= 0)
            providerSettings[targetWidget.providers[shownProvider].id] = shownSettings();

    }

    title: qsTr("Cardinal System")
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
                        greetPreference.value = settings.greet_on_start !== false;
                        carePreference.value = settings.proactive_care !== false;
                        statusPreference.value = settings.status_reports !== false;
                        externalBrowserPreference.value = settings.external_browser === true;
                        sleepPreference.value = settings.sleep_minutes !== undefined ? settings.sleep_minutes : 20;
                        heartPreference.value = (settings.yui_heart || []).join("\n");
                        loading = false;
                    }

                    // ---------------------------------------------------------------- Link Start
                    Heading {
                        text: qsTr("Link Start")
                    }

                    P.SelectPreference {
                        id: providerPreference

                        name: "provider"
                        label: qsTr("Seed Server")
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

                    SettingNote {
                        text: qsTr("The AI service Yui connects to. Each server keeps its own core, address and access key.")
                    }

                    P.SelectPreference {
                        id: modelPreference

                        name: "model"
                        label: qsTr("Core Program")
                        visible: model.length > 0
                    }

                    SettingNote {
                        visible: modelPreference.visible
                        text: qsTr("The AI model that runs Yui.")
                    }

                    RowLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        Button {
                            text: qsTr("Scan Cores")
                            onClicked: refreshModelList()
                        }

                        Button {
                            text: qsTr("Restore Registry")
                            visible: shownFetchedModels !== null
                            onClicked: {
                                var current = shownModels[modelPreference.value];
                                shownFetchedModels = null;
                                setModelList(targetWidget.providers[shownProvider].models, current);
                                modelStatus.text = "";
                            }
                        }

                        Label {
                            id: modelStatus

                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                    }

                    SettingNote {
                        text: qsTr("Scan Cores asks the server for its current model list; Restore Registry goes back to the built-in list.")
                    }

                    P.TextFieldPreference {
                        id: customModelPreference

                        name: "custom_model"
                        label: qsTr("Manual Core ID")
                        display: P.TextFieldPreference.ExpandControl
                        hint: qsTr("model id, e.g. gpt-6-sol")
                        message: qsTr("When filled in, this model id is used instead of the Core Program selected above.")
                    }

                    P.TextFieldPreference {
                        id: apiEndpointPreference

                        name: "api_endpoint"
                        label: qsTr("Server Address")
                        display: P.TextFieldPreference.ExpandControl
                        message: qsTr("The API endpoint URL. Change it only when using a proxy or a self-hosted service.")
                    }

                    P.TextFieldPreference {
                        id: apiKeyPreference

                        name: "api_key"
                        label: qsTr("Access Key")
                        display: P.TextFieldPreference.ExpandControl
                        echoMode: TextInput.Password
                        message: qsTr("The API key of this server. Each server keeps its own key.")
                    }

                    RowLayout {
                        spacing: 20
                        Layout.alignment: Qt.AlignHCenter

                        Button {
                            text: qsTr("Link Start!")
                            onClicked: {
                                apiResponseArea.value = qsTr("Linking...");
                                var config = targetWidget.providerConfig(targetWidget.providers[shownProvider], shownSettings());
                                config.systemPrompt = systemPromptPreference.value;
                                config.userTitle = userTitlePreference.ids[userTitlePreference.value] === "mama" ? "妈妈" : "爸爸";
                                targetWidget.requestCompletion([{
                                    "role": "user",
                                    "content": "Hello"
                                }], function(text, isError) {
                                    apiResponseArea.value = (isError ? "" : qsTr("Link established") + " (" + config.model + "):\n") + text;
                                }, config);
                            }
                        }

                        Button {
                            text: qsTr("Clear Log")
                            onClicked: {
                                apiResponseArea.value = "";
                            }
                        }

                    }

                    P.TextAreaPreference {
                        id: apiResponseArea

                        name: "api_response_text"
                        label: qsTr("Connection Log")
                        readOnly: true
                        hint: qsTr("Press Link Start! to test the connection.")
                        wrapMode: Text.Wrap
                        font.family: "Microsoft YaHei"
                        Layout.fillWidth: true
                        Layout.minimumHeight: 20
                    }

                    // ---------------------------------------------------------------- MHCP001 personality
                    Heading {
                        text: qsTr("MHCP001 Personality")
                    }

                    P.SelectPreference {
                        id: userTitlePreference

                        readonly property var ids: ["papa", "mama"]

                        name: "user_title"
                        label: qsTr("Registered Parent")
                        model: [qsTr("Papa (Kirito)"), qsTr("Mama (Asuna)")]
                    }

                    SettingNote {
                        text: qsTr("How Yui calls you. Replaces {{user_title}} in the personality data.")
                    }

                    P.TextAreaPreference {
                        id: systemPromptPreference

                        // No label: the "MHCP001 Personality" heading above already names it.
                        name: "system_prompt"
                        message:qsTr("The system prompt that defines Yui's personality. {{user_title}} is replaced with the registered parent.")
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
                            text: qsTr("Restore MHCP001")
                            onClicked: {
                                systemPromptPreference.value = targetWidget.defaultSystemPrompt;
                            }
                        }

                        Button {
                            text: qsTr("Wipe Data")
                            onClicked: {
                                systemPromptPreference.value = "";
                            }
                        }

                    }

                    // ---------------------------------------------------------------- Pixie functions
                    Heading {
                        text: qsTr("Pixie Functions")
                    }

                    P.SwitchPreference {
                        id: greetPreference

                        name: "greet_on_start"
                        label: qsTr("Login Greeting")
                        message: qsTr("Yui welcomes you back when you return after a while.")
                    }

                    P.SwitchPreference {
                        id: carePreference

                        name: "proactive_care"
                        label: qsTr("Mental Health Counseling")
                        message: qsTr("Yui reminds you to sleep late at night and to rest after long sessions (at most once an hour).")
                    }

                    P.SwitchPreference {
                        id: statusPreference

                        name: "status_reports"
                        label: qsTr("Navigation Reports")
                        message: qsTr("Yui warns you about low battery and high CPU or memory usage.")
                    }

                    P.SwitchPreference {
                        id: externalBrowserPreference

                        name: "external_browser"
                        label: qsTr("External Browser")
                        message: qsTr("Open the links and searches Yui offers in the system's default browser instead of SAO Utils' built-in browser.")
                    }

                    P.SliderPreference {
                        id: sleepPreference

                        name: "sleep_minutes"
                        label: qsTr("Standby Mode")
                        from: 0
                        to: 120
                        stepSize: 5
                        displayValue: value === 0 ? qsTr("Always Active") : qsTr("%1 min").arg(value)
                    }

                    SettingNote {
                        text: qsTr("Yui goes to sleep after this long without interaction; click her to wake her up.")
                    }

                    // ---------------------------------------------------------------- Yui's Heart
                    Heading {
                        text: qsTr("Yui's Heart")
                    }

                    // Long-term memories, one per line. Yui adds to them herself; edit or delete freely.
                    P.TextAreaPreference {
                        id: heartPreference

                        name: "yui_heart"
                        hint: qsTr("No memories yet")
                        message: qsTr("What Yui remembers about you, one memory per line. She adds memories herself when you tell her something worth remembering; edit or delete them freely.")
                    }

                }

            }

        }

        header: TitleBar {
            text: qsTr("Cardinal System")
            standardButtons: Dialog.Save | Dialog.Reset
            onAccepted: {
                stashShownProvider();
                targetWidget.settings.provider = targetWidget.providers[shownProvider].id;
                targetWidget.settings.provider_settings = JSON.parse(JSON.stringify(providerSettings));
                targetWidget.settings.system_prompt = systemPromptPreference.value;
                targetWidget.settings.user_title = userTitlePreference.ids[userTitlePreference.value] || "papa";
                targetWidget.settings.greet_on_start = !!greetPreference.value;
                targetWidget.settings.proactive_care = !!carePreference.value;
                targetWidget.settings.status_reports = !!statusPreference.value;
                targetWidget.settings.external_browser = !!externalBrowserPreference.value;
                targetWidget.settings.sleep_minutes = sleepPreference.value;
                targetWidget.settings.yui_heart = String(heartPreference.value || "").split("\n").map(function(line) {
                    return line.trim();
                }).filter(function(line) {
                    return line.length > 0;
                });
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
