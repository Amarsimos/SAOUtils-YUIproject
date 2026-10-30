import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

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

    // Every change takes effect without a Save button: written shortly after the last change (so
    // typing an access key or the personality is not written on every key) and when the window closes.
    function applySettings() {
        applyTimer.stop();
        stashShownProvider();
        targetWidget.settings.provider = targetWidget.providers[shownProvider].id;
        targetWidget.settings.provider_settings = JSON.parse(JSON.stringify(providerSettings));
        targetWidget.settings.system_prompt = systemPromptPreference.value;
        targetWidget.settings.persona = profileNames[shownProfile] || builtInProfile;
        targetWidget.settings.user_title = userTitlePreference.ids[userTitlePreference.value] || "papa";
        targetWidget.settings.max_tokens = maxTokensPreference.value;
        targetWidget.settings.thinking_depth = thinkingPreference.ids[thinkingPreference.value] || "default";
        targetWidget.settings.temperature = temperaturePreference.value;
        targetWidget.settings.presence_penalty = penaltyPreference.value;
        targetWidget.settings.top_p = topPPreference.value;
        targetWidget.settings.top_k = topKPreference.value;
        targetWidget.settings.frequency_penalty = frequencyPreference.value;
        targetWidget.settings.seed = seedPreference.value;
        targetWidget.settings.action_mode = actionModePreference.ids[actionModePreference.value] || "tags";
        targetWidget.settings.small_model = !!smallModelPreference.value;
    }

    // The settings of each tab that Reset This Tab (and the title bar's Reset, all three) restore; the
    // connection (Link) is never reset.
    // Core Tuning's sampling values, in the Sampling Parameters dialog.
    readonly property var samplingPreferences: [temperaturePreference, topPPreference, topKPreference, seedPreference, penaltyPreference, frequencyPreference]
    readonly property var coreTabPreferences: [maxTokensPreference, thinkingPreference, temperaturePreference, penaltyPreference, topPPreference, topKPreference, frequencyPreference, seedPreference, actionModePreference, smallModelPreference]
    // (The profile goes back to MHCP001; saved profiles are kept.)
    // Personality's fine-tuning, in the Fine-Tuning dialog.
    readonly property var traitPreferences: [warmthPreference, energyPreference, kaomojiPreference, lengthPreference, formatPreference]
    readonly property var personaTabPreferences: [userTitlePreference, profilePreference, systemPromptPreference, warmthPreference, energyPreference, kaomojiPreference, lengthPreference, formatPreference, quickRepliesPreference]

    readonly property string builtInProfile: "MHCP001"
    property var personas: []
    // The profile shown (0: MHCP001); the editor holds its prompt, perhaps with unsaved edits.
    property int shownProfile: 0
    readonly property var profileNames: [builtInProfile].concat(personas.map(function(persona) {
        return persona.name;
    }))
    readonly property bool profileEdited: systemPromptPreference.value !== profileText(shownProfile)
    // While Reset restores the tab (already confirmed): unsaved edits go without asking.
    property bool discardEdits: false
    // While the profile list itself changes (the dropdown's model): its value changes are not switches.
    property bool updatingProfiles: false

    function profileText(index) {
        if (index <= 0)
            return targetWidget.defaultSystemPrompt;

        return personas[index - 1] ? personas[index - 1].prompt : "";
    }

    // Shows a profile: the dropdown and its prompt in the editor (taking effect as any change).
    function showProfile(index) {
        shownProfile = index;
        profilePreference.value = index;
        systemPromptPreference.value = profileText(index);
        profileStatus.text = "";
        scheduleApply();
    }

    // Another profile chosen (or, with again, the shown one reloaded): with unsaved edits, asks first;
    // Cancel keeps the shown profile and the edits.
    function switchProfile(index, again) {
        if (index === shownProfile && !again)
            return ;

        if (!profileEdited || discardEdits) {
            showProfile(index);
            return ;
        }
        var back = shownProfile;
        targetWidget.askConfirm(qsTr("Warning"), qsTr("Discard the unsaved changes to %1?").arg(profileNames[back]), function() {
            showProfile(index);
        }, false, function() {
            updatingProfiles = true;
            profilePreference.value = back;
            updatingProfiles = false;
        });
    }

    // Stores a new profile list and shows the profile at index.
    function setPersonas(list, index) {
        updatingProfiles = true;
        personas = list;
        targetWidget.settings.personas = JSON.parse(JSON.stringify(list));
        profilePreference.value = index;
        updatingProfiles = false;
        showProfile(index);
    }

    // A name for a saved profile, or "" (with the reason shown) when it cannot be used.
    function profileName(text, except) {
        var name = String(text || "").trim();
        if (name === "") {
            profileStatus.text = qsTr("Enter a name.");
            return "";
        }
        if (name.toLowerCase() === builtInProfile.toLowerCase() || (name !== except && profileNames.indexOf(name) > 0 && except !== undefined)) {
            profileStatus.text = qsTr("%1 is already taken.").arg(name);
            return "";
        }
        return name;
    }

    function saveProfile() {
        if (shownProfile <= 0)
            return ;

        var list = personas.slice();
        list[shownProfile - 1] = {
            "name": list[shownProfile - 1].name,
            "prompt": systemPromptPreference.value
        };
        setPersonas(list, shownProfile);
        profileStatus.text = qsTr("Saved.");
    }

    // Saves the editor's prompt as a new profile (or over the one of that name, after asking).
    function saveProfileAs(text) {
        var name = profileName(text);
        if (name === "")
            return ;

        var prompt = systemPromptPreference.value;
        var existing = profileNames.indexOf(name);
        var store = function() {
            var list = personas.slice();
            var item = {
                "name": name,
                "prompt": prompt
            };
            if (existing > 0)
                list[existing - 1] = item;
            else
                list.push(item);
            setPersonas(list, existing > 0 ? existing : list.length);
            profileStatus.text = qsTr("Saved.");
        };
        if (existing > 0)
            targetWidget.askConfirm(qsTr("Warning"), qsTr("Replace the profile %1?").arg(name), store);
        else
            store();
    }

    function renameProfile(text) {
        if (shownProfile <= 0)
            return ;

        var name = profileName(text, profileNames[shownProfile]);
        if (name === "" || name === profileNames[shownProfile])
            return ;

        var edited = systemPromptPreference.value;
        var list = personas.slice();
        list[shownProfile - 1] = {
            "name": name,
            "prompt": list[shownProfile - 1].prompt
        };
        setPersonas(list, shownProfile);
        // Renaming keeps the editor's unsaved edits.
        systemPromptPreference.value = edited;
    }

    function deleteProfile() {
        if (shownProfile <= 0)
            return ;

        var index = shownProfile;
        targetWidget.askConfirm(qsTr("Warning"), qsTr("Delete the profile %1?").arg(profileNames[index]), function() {
            var list = personas.slice();
            list.splice(index - 1, 1);
            setPersonas(list, 0);
        }, true);
    }

    function scheduleApply() {
        if (!loading)
            applyTimer.restart();

    }

    function stashShownProvider() {
        if (shownProvider >= 0)
            providerSettings[targetWidget.providers[shownProvider].id] = shownSettings();

    }

    Component.onCompleted: {
        var settings = targetWidget.settings;
        providerSettings = JSON.parse(JSON.stringify(settings.provider_settings || {
        }));
        var index = targetWidget.providerIndexOf(settings.provider);
        providerPreference.value = index;
        showProvider(index, providerSettings[targetWidget.providers[index].id]);
        var prompt = settings.system_prompt !== undefined ? settings.system_prompt : targetWidget.defaultSystemPrompt;
        var saved = settings.personas || [];
        var active = settings.persona;
        // From before MHCP Profile: an edited prompt becomes the profile "Custom".
        if (active === undefined && prompt !== targetWidget.defaultSystemPrompt) {
            saved = saved.concat([{
                "name": "Custom",
                "prompt": prompt
            }]);
            active = "Custom";
            settings.personas = saved;
            settings.persona = active;
        }
        personas = saved;
        shownProfile = Math.max(0, profileNames.indexOf(active || builtInProfile));
        profilePreference.value = shownProfile;
        systemPromptPreference.value = prompt;
        userTitlePreference.value = Math.max(0, userTitlePreference.ids.indexOf(settings.user_title));
        maxTokensPreference.value = settings.max_tokens !== undefined ? settings.max_tokens : 0;
        // Off when never set (the older Thinking switch is not read any more).
        thinkingPreference.value = Math.max(0, thinkingPreference.ids.indexOf(settings.thinking_depth || "off"));
        temperaturePreference.value = settings.temperature !== undefined ? settings.temperature : -1;
        penaltyPreference.value = settings.presence_penalty !== undefined ? settings.presence_penalty : -1;
        topPPreference.value = settings.top_p !== undefined ? settings.top_p : -1;
        topKPreference.value = settings.top_k > 0 ? settings.top_k : 0;
        frequencyPreference.value = settings.frequency_penalty !== undefined ? settings.frequency_penalty : -1;
        seedPreference.value = settings.seed > 0 ? settings.seed : 0;
        actionModePreference.value = settings.action_mode === "tools" ? 1 : 0;
        smallModelPreference.value = settings.small_model === true;
        loading = false;
        [providerPreference, modelPreference, customModelPreference, apiEndpointPreference, apiKeyPreference, maxTokensPreference, thinkingPreference, temperaturePreference, penaltyPreference, topPPreference, topKPreference, frequencyPreference, seedPreference, actionModePreference, smallModelPreference, userTitlePreference, systemPromptPreference].forEach(function(preference) {
            preference.valueChanged.connect(scheduleApply);
        });
    }
    title: qsTr("Cardinal System")
    visible: true
    minimumWidth: 480
    // Content scrolls, so keep the window usable on small screens.
    minimumHeight: 480
    width: minimumWidth
    height: 930
    transientParent: widget.NVG.View.window
    onShownFetchedModelsChanged: scheduleApply()
    onClosing: {
        if (applyTimer.running)
            applySettings();

        // When the window is closed, destroy the object to free up resources.
        // A new one is created every time the settings action is triggered.
        destroy();
    }

    Timer {
        id: applyTimer

        interval: 600
        onTriggered: applySettings()
    }

    Page {
        id: cfg_page

        anchors.fill: parent

        // Three tabs, the AI itself: Link (the server), Core Tuning (how the model answers),
        // Personality. The last tab shown is remembered. (Standby Mode is in Mental Health Counseling,
        // the browser and search engine in System Console.)
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
                currentIndex: Math.max(0, Math.min(2, targetWidget.settings.cardinal_tab || 0))
                onCurrentIndexChanged: targetWidget.settings.cardinal_tab = currentIndex
                model: [qsTr("Link"), qsTr("Core Tuning"), qsTr("Personality")]
                // Core Tuning holds advanced settings only.
                hiddenTabs: targetWidget.settingsAdvanced ? [] : [1]
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabs.shownIndex

                // ---------------------------------------------------------------- Link
                // The API settings only, under headings: the server, the core (model), the connection test.
                SettingsPage {
                    Heading {
                        text: qsTr("Server")
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

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
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("The AI service Yui connects to. Each server keeps its own core, address and access key.")
                        }

                        P.TextFieldPreference {
                            id: apiEndpointPreference
                            visible: targetWidget.settingsAdvanced

                            name: "api_endpoint"
                            label: qsTr("Server Address")
                            display: P.TextFieldPreference.ExpandAll
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp && (targetWidget.settingsAdvanced)
                            besidePreferences: true
                            text: qsTr("The API endpoint URL. Change it only when using a proxy or a self-hosted service.")
                        }

                        P.TextFieldPreference {
                            id: apiKeyPreference

                            name: "api_key"
                            label: qsTr("Access Key")
                            display: P.TextFieldPreference.ExpandAll
                            echoMode: TextInput.Password
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("The API key of this server. Each server keeps its own key.")
                        }
                    }


                    Heading {
                        text: qsTr("Core")
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        P.SelectPreference {
                            id: modelPreference

                            name: "model"
                            label: qsTr("Core Program")
                            visible: model.length > 0
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("The AI model that runs Yui.")
                        }

                        RowLayout {
                            visible: targetWidget.settingsAdvanced
                            spacing: 12
                            Layout.alignment: Qt.AlignHCenter

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

                        }

                        // What Scan Cores found (or why it failed), under the buttons.
                        Label {
                            id: modelStatus

                            Layout.alignment: Qt.AlignHCenter
                            visible: targetWidget.settingsAdvanced && text !== ""
                            elide: Text.ElideRight
                        }

                        SettingNote {
                            visible: targetWidget.settingsAdvanced && targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Scan Cores asks the server for its current model list; Restore Registry goes back to the built-in list.")
                        }

                        P.TextFieldPreference {
                            id: customModelPreference
                            visible: targetWidget.settingsAdvanced

                            name: "custom_model"
                            label: qsTr("Manual Core ID")
                            display: P.TextFieldPreference.ExpandAll
                            hint: qsTr("model id, e.g. gpt-6-sol")
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp && (targetWidget.settingsAdvanced)
                            besidePreferences: true
                            text: qsTr("When filled in, this model id is used instead of the Core Program selected above.")
                        }
                    }


                    Heading {
                        text: qsTr("Connection Test")
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

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
                            font.family: targetWidget.defaultValues.bubble_font_family
                            Layout.fillWidth: true
                            Layout.minimumHeight: 20
                        }
                    }

                    // Resets the shown server's core and address (the scanned list, Manual Core ID);
                    // the server chosen and its access key are kept.
                    ResetTabButton {
                        yui: coreSettings.targetWidget
                        windowTitle: coreSettings.title
                        tabTitle: qsTr("Link")
                        changed: shownProvider >= 0 && (modelPreference.value !== 0 || shownFetchedModels !== null || customModelPreference.value !== "" || apiEndpointPreference.value !== targetWidget.providers[shownProvider].endpoint)
                        onReset: {
                            showProvider(shownProvider, {
                                "api_key": apiKeyPreference.value
                            });
                            scheduleApply();
                        }
                    }

                }

                // ---------------------------------------------------------------- Core Tuning
                // How the model answers, under headings: Reply, Sampling (its values in a dialog), Behavior.
                SettingsPage {
                    Heading {
                        text: qsTr("Reply")
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        P.SelectPreference {
                            id: thinkingPreference

                            readonly property var ids: ["off", "default", "low", "medium", "high"]

                            name: "thinking_depth"
                            defaultValue: 0
                            label: qsTr("Thinking Depth")
                            model: [qsTr("Off"), qsTr("Default"), qsTr("Low"), qsTr("Medium"), qsTr("High")]
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("How much thinking models think before answering. Off makes them much faster; Default leaves it to the server; Low, Medium and High ask for more (reasoning effort, or a thinking budget of about 1k / 4k / 16k tokens for Claude and Gemini). Not every model can turn it off or change it.")
                        }

                        // A number typed in (or stepped with the arrows), like the precise values in SAO Utils' own settings.
                        P.SpinPreference {
                            id: maxTokensPreference

                            name: "max_tokens"
                            defaultValue: 0
                            label: qsTr("Reply Length Limit")
                            display: P.TextFieldPreference.ExpandLabel
                            editable: true
                            from: 0
                            to: 1000000
                            stepSize: 256
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("The longest reply Yui may give, in tokens, which also caps its cost. 0 (the default) sets no limit (Claude always gets 1024 then). Thinking models count their thinking too, so a low limit can cut their replies short.")
                        }
                    }

                    Heading {
                        text: qsTr("Sampling")
                    }

                    // The sampling values in a dialog of their own (they are rarely changed and take room),
                    // live as the rest of the window; the row tells how many differ from the default.
                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        P.DialogPreference {
                            label: qsTr("Sampling Parameters")
                            live: true
                            displayValue: {
                                var changed = coreSettings.samplingPreferences.filter(Yui.preferenceChanged).length;
                                return changed ? qsTr("%1 changed").arg(changed) : qsTr("All default");
                            }

                            Heading {
                                text: qsTr("Randomness")
                            }

                            P.SliderPreference {
                                id: temperaturePreference

                                // Updates (and shows its value) while being dragged.
                                live: true
                                name: "temperature"
                                defaultValue: -1
                                label: qsTr("Temperature")
                                from: -1
                                to: 20
                                stepSize: 1
                                displayValue: value < 0 ? qsTr("Default") : (value / 10).toFixed(1)
                            }

                            SettingNote {
                                visible: targetWidget.settingsHelp
                                besidePreferences: true
                                // The dialog takes its size from its content: wrapped at a set width.
                                wrapWidth: 360
                                text: qsTr("Higher gives more varied replies, lower more predictable ones. Default leaves it to the server.")
                            }

                            P.SliderPreference {
                                id: topPPreference

                                // Updates (and shows its value) while being dragged.
                                live: true
                                name: "top_p"
                                defaultValue: -1
                                label: qsTr("Top P")
                                from: -1
                                to: 10
                                stepSize: 1
                                displayValue: value < 0 ? qsTr("Default") : (value / 10).toFixed(1)
                            }

                            SettingNote {
                                visible: targetWidget.settingsHelp
                                besidePreferences: true
                                // The dialog takes its size from its content: wrapped at a set width.
                                wrapWidth: 360
                                text: qsTr("Only the most likely words, up to this share of probability, are chosen from; lower is more focused. Use it or Temperature, rarely both. Default leaves it to the server.")
                            }

                            // A number typed in (or stepped with the arrows), like the precise values in SAO Utils' own settings.
                            P.SpinPreference {
                                id: topKPreference

                                name: "top_k"
                                defaultValue: 0
                                label: qsTr("Top K")
                                display: P.TextFieldPreference.ExpandLabel
                                editable: true
                                from: 0
                                to: 500
                                stepSize: 1
                            }

                            SettingNote {
                                visible: targetWidget.settingsHelp
                                besidePreferences: true
                                // The dialog takes its size from its content: wrapped at a set width.
                                wrapWidth: 360
                                text: qsTr("Only the K most likely words are chosen from. 0 (the default) sends nothing. For Claude, Gemini and custom servers such as Ollama (OpenAI and similar servers do not take it).")
                            }

                            // A number typed in (or stepped with the arrows), like the precise values in SAO Utils' own settings.
                            P.SpinPreference {
                                id: seedPreference

                                name: "seed"
                                defaultValue: 0
                                label: qsTr("Seed")
                                display: P.TextFieldPreference.ExpandLabel
                                editable: true
                                from: 0
                                to: 999999999
                                stepSize: 1
                            }

                            SettingNote {
                                visible: targetWidget.settingsHelp
                                besidePreferences: true
                                // The dialog takes its size from its content: wrapped at a set width.
                                wrapWidth: 360
                                text: qsTr("The same seed gives the same reply to the same message, for trying out a personality. 0 (the default) is random. Not for Claude; not every server keeps to it.")
                            }

                            Heading {
                                text: qsTr("Repetition")
                            }

                            P.SliderPreference {
                                id: penaltyPreference

                                // Updates (and shows its value) while being dragged.
                                live: true
                                name: "presence_penalty"
                                defaultValue: -1
                                label: qsTr("Repetition Penalty")
                                from: -1
                                to: 20
                                stepSize: 1
                                displayValue: value < 0 ? qsTr("Default") : (value / 10).toFixed(1)
                            }

                            SettingNote {
                                visible: targetWidget.settingsHelp
                                besidePreferences: true
                                // The dialog takes its size from its content: wrapped at a set width.
                                wrapWidth: 360
                                text: qsTr("Higher makes Yui repeat herself less (presence penalty). Default leaves it to the server.")
                            }

                            P.SliderPreference {
                                id: frequencyPreference

                                // Updates (and shows its value) while being dragged.
                                live: true
                                name: "frequency_penalty"
                                defaultValue: -1
                                label: qsTr("Frequency Penalty")
                                from: -1
                                to: 20
                                stepSize: 1
                                displayValue: value < 0 ? qsTr("Default") : (value / 10).toFixed(1)
                            }

                            SettingNote {
                                visible: targetWidget.settingsHelp
                                besidePreferences: true
                                // The dialog takes its size from its content: wrapped at a set width.
                                wrapWidth: 360
                                text: qsTr("Higher makes Yui use the same words less often (each repetition counts). Default leaves it to the server. Not for Claude.")
                            }
                        }

                    }

                    Heading {
                        text: qsTr("Behavior")
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        P.SelectPreference {
                            id: actionModePreference

                            readonly property var ids: ["tags", "tools"]

                            name: "action_mode"
                            defaultValue: 0
                            label: qsTr("Action Mode")
                            model: ["Tags", "Tools"]
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("How Yui operates the computer. Tags (the default) writes the actions into her reply, which local models follow best; Tools uses the server's function calling, for large models that are good at it (for now only OpenAI-compatible servers; others keep Tags). Memories always use tags. A server that rejects tools is switched to Tags automatically.")
                        }

                        P.SwitchPreference {
                            id: smallModelPreference

                            name: "small_model"
                            defaultValue: false
                            label: qsTr("Small Model Mode")
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("For small local models: every message carries a short reminder of the expression tag and of using tools (or tags), which they otherwise often forget. Not needed for large models.")
                        }
                    }

                    ResetTabButton {
                        yui: coreSettings.targetWidget
                        windowTitle: coreSettings.title
                        tabTitle: qsTr("Core Tuning")
                        preferences: coreSettings.coreTabPreferences
                        // The values in the dialog count (and are reset) whether it is open or not.
                        changed: Yui.anyChanged(shownPreferences.concat(coreSettings.samplingPreferences))
                        onAboutToReset: coreSettings.discardEdits = true
                        onReset: {
                            coreSettings.samplingPreferences.forEach(function(preference) {
                                preference.load();
                            });
                            coreSettings.discardEdits = false;
                        }
                    }

                }

                // ---------------------------------------------------------------- Personality
                // Under headings: Identity, MHCP Profile, Character Traits.
                SettingsPage {
                    Heading {
                        text: qsTr("Identity")
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        P.SelectPreference {
                            id: userTitlePreference

                            readonly property var ids: ["papa", "mama"]

                            name: "user_title"
                            defaultValue: 0
                            label: qsTr("Registered Parent")
                            model: [qsTr("Papa (Kirito)"), qsTr("Mama (Asuna)")]
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("How Yui calls you. Replaces {{user_title}} in the personality data.")
                        }
                    }

                    Heading {
                        text: qsTr("MHCP Profile")
                    }

                    P.PreferenceGroup {
                        Layout.fillWidth: true
                        spacing: 10

                        P.SelectPreference {
                            id: profilePreference

                            defaultValue: 0
                            label: qsTr("MHCP Profile")
                            model: coreSettings.profileNames
                            warning: coreSettings.profileEdited ? qsTr("Unsaved changes") : ""
                            onValueChanged: {
                                if (!loading && !coreSettings.updatingProfiles && value >= 0)
                                    coreSettings.switchProfile(value);

                            }
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Yui's personality. MHCP001 is the built-in one; edit the prompt below and keep it with Save As…, then switch between your profiles here.")
                        }

                        P.TextAreaPreference {
                            id: systemPromptPreference

                            wrapMode: Text.Wrap

                            label: qsTr("Personality Data")
                            name: "system_prompt"
                            defaultValue: targetWidget.defaultSystemPrompt
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("The system prompt that defines Yui's personality. {{user_title}} is replaced with the registered parent.")
                        }

                        // The four buttons share the settings' width (as the notes, see SettingNote).
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            spacing: 8

                            Button {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                text: qsTr("Save")
                                enabled: coreSettings.shownProfile > 0 && coreSettings.profileEdited
                                onClicked: coreSettings.saveProfile()
                            }

                            Button {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                text: qsTr("Save As…")
                                onClicked: profileNameDialog.ask("saveAs")
                            }

                            Button {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                text: qsTr("Rename…")
                                enabled: coreSettings.shownProfile > 0
                                onClicked: profileNameDialog.ask("rename")
                            }

                            Button {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                text: qsTr("Delete")
                                enabled: coreSettings.shownProfile > 0
                                onClicked: coreSettings.deleteProfile()
                            }

                        }

                        Label {
                            id: profileStatus

                            Layout.alignment: Qt.AlignHCenter
                            visible: text !== ""
                        }

                    }

                    // Character Traits: the style on top of the personality (Yui.traitContext), and the
                    // Quick Replies offered under her messages.
                    Heading {
                        text: qsTr("Character Traits")
                    }

                    P.ObjectPreferenceGroup {
                        id: traitsGroup

                        Layout.fillWidth: true
                        defaultValue: coreSettings.targetWidget.settings
                        syncProperties: true

                        // The fine-tuning in a dialog of its own; passthrough keeps its values in this
                        // group's object (the settings), as before. The row tells how many are changed.
                        P.DialogPreference {
                            label: qsTr("Fine-Tuning")
                            live: true
                            passthrough: true
                            displayValue: {
                                var changed = coreSettings.traitPreferences.filter(Yui.preferenceChanged).length;
                                return changed ? qsTr("%1 changed").arg(changed) : qsTr("All default");
                            }

                            P.SelectPreference {
                                id: warmthPreference

                                name: "trait_warmth"
                                label: qsTr("Warmth")
                                defaultValue: 1
                                model: [qsTr("Less"), qsTr("Default"), qsTr("More")]
                            }

                            P.SelectPreference {
                                id: energyPreference

                                name: "trait_energy"
                                label: qsTr("Energy")
                                defaultValue: 1
                                model: [qsTr("Less"), qsTr("Default"), qsTr("More")]
                            }

                            P.SelectPreference {
                                id: kaomojiPreference

                                name: "trait_kaomoji"
                                label: qsTr("Kaomoji")
                                defaultValue: 1
                                model: [qsTr("Less"), qsTr("Default"), qsTr("More")]
                            }

                            P.SelectPreference {
                                id: lengthPreference

                                name: "trait_length"
                                label: qsTr("Reply Length")
                                defaultValue: 1
                                model: [qsTr("Less"), qsTr("Default"), qsTr("More")]
                            }

                            P.SelectPreference {
                                id: formatPreference

                                name: "trait_format"
                                label: qsTr("Format")
                                defaultValue: 0
                                model: [qsTr("Chat"), qsTr("Lists")]
                            }

                            SettingNote {
                                visible: targetWidget.settingsHelp
                                besidePreferences: true
                                // The dialog takes its size from its content: wrapped at a set width.
                                wrapWidth: 360
                                text: qsTr("Fine-tune how Yui talks without editing the personality: a little more or less of each, or Default to leave it to the personality. Lists lets her use simple lists when it helps.")
                            }
                        }

                        P.SwitchPreference {
                            id: quickRepliesPreference

                            name: "quick_replies"
                            label: qsTr("Quick Replies")
                            defaultValue: true
                        }

                        SettingNote {
                            visible: targetWidget.settingsHelp
                            besidePreferences: true
                            text: qsTr("Under her latest message Yui offers two or three short replies you might say next; click one to send it.")
                        }

                    }

                    ResetTabButton {
                        yui: coreSettings.targetWidget
                        windowTitle: coreSettings.title
                        tabTitle: qsTr("Personality")
                        preferences: coreSettings.personaTabPreferences
                        groups: [traitsGroup]
                        // The values in the dialog count (and are reset) whether it is open or not.
                        changed: Yui.anyChanged(shownPreferences.concat(coreSettings.traitPreferences))
                        onAboutToReset: {
                            coreSettings.discardEdits = true;
                            coreSettings.traitPreferences.forEach(function(preference) {
                                preference.load();
                            });
                        }
                        onReset: coreSettings.discardEdits = false
                    }

                }

            }

        }

        // The name for Save As… and Rename… of an MHCP Profile.
        Dialog {
            id: profileNameDialog

            property string mode: "saveAs"

            function ask(newMode) {
                mode = newMode;
                open();
            }

            x: (cfg_page.width - width) / 2
            y: (cfg_page.height - height) / 3
            modal: true
            title: mode === "rename" ? qsTr("Rename Profile") : qsTr("Save Profile As")
            standardButtons: Dialog.Ok | Dialog.Cancel
            onAboutToShow: {
                profileNameField.text = mode === "rename" ? coreSettings.profileNames[coreSettings.shownProfile] : "";
                profileNameField.forceActiveFocus();
                profileNameField.selectAll();
            }
            onAccepted: {
                if (mode === "rename")
                    coreSettings.renameProfile(profileNameField.text);
                else
                    coreSettings.saveProfileAs(profileNameField.text);
            }

            TextField {
                id: profileNameField

                implicitWidth: 280
                placeholderText: qsTr("Profile name")
                onAccepted: profileNameDialog.accept()
            }

        }

        header: SettingsTitleBar {
            yui: coreSettings.targetWidget
            settingsWindow: coreSettings
            hasAdvanced: true
            onResetRequested: {
                // Everything but the connection (server, core, address, access key).
                coreSettings.discardEdits = true;
                coreSettings.coreTabPreferences.concat(coreSettings.personaTabPreferences).forEach(function(preference) {
                    preference.load();
                });
                // load() is no edit, so the synced group writes the defaults to the settings by save().
                traitsGroup.save();
                coreSettings.discardEdits = false;
            }
        }

    }

}
