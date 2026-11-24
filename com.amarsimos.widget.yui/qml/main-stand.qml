import "."
import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Shapes 1.12
import QtGraphicalEffects 1.0
import QtQuick.LocalStorage 2.12
import "yui.js" as Yui
import "link" 1.0 as Link

T.Widget {
    id: widget

    property Component cardinalSystemDialog: Qt.createComponent("CardinalSystem.qml")
    property Component equipmentDialog: Qt.createComponent("Equipment.qml")
    property var equipmentDialogInstance: null
    property Component systemConsoleDialog: Qt.createComponent("SystemConsole.qml")
    property var systemConsoleDialogInstance: null
    property Component yuisHeartDialog: Qt.createComponent("YuisHeart.qml")
    property var yuisHeartDialogInstance: null
    property Component counselingDialog: Qt.createComponent("MentalHealthCounseling.qml")
    property var counselingDialogInstance: null
    property Component quickInputDialog: Qt.createComponent("QuickInput.qml")
    property var quickInputDialogInstance: null
    property Component skillSlotsDialog: Qt.createComponent("SkillSlots.qml")
    property var skillSlotsDialogInstance: null
    property Component seedlingDialog: Qt.createComponent("Seedling.qml")
    property var seedlingDialogInstance: null
    // Widgets popped out of the Seedling (SeedlingWidget.qml views), not saved.
    property var seedlingWidgets: []
    property var cardinalSystemDialogInstance: null
    // Shared with CardinalSystem.qml. settings.provider stores a provider id and
    // settings.provider_settings[id] stores { model, custom_model, api_endpoint, api_key }.
    // format: "openai" (Chat Completions), "gemini" (generateContent), "anthropic" (Messages);
    // keyOptional: the server needs no access key.
    readonly property var providers: [{
        "id": "openai",
        "title": "OpenAI",
        "format": "openai",
        "endpoint": "https://api.openai.com/v1/chat/completions",
        "models": ["gpt-6-sol", "gpt-6-luna", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"]
    }, {
        "id": "google",
        "title": "Google Gemini",
        "format": "gemini",
        "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/",
        "models": ["gemini-4-argon", "gemini-3.1-pro-preview", "gemini-3.8-flash", "gemini-3.5-flash-lite"]
    }, {
        "id": "deepseek",
        "title": "DeepSeek",
        "format": "openai",
        "endpoint": "https://api.deepseek.com/chat/completions",
        "models": ["deepseek-v4-pro", "deepseek-flash"]
    }, {
        "id": "kimi",
        "title": "Kimi (Moonshot)",
        "format": "openai",
        "endpoint": "https://api.moonshot.cn/v1/chat/completions",
        "models": ["kimi-k3", "kimi-k2.6"]
    }, {
        "id": "anthropic",
        "title": "Anthropic Claude",
        "format": "anthropic",
        "endpoint": "https://api.anthropic.com/v1/messages",
        "models": ["claude-fable-5-1", "claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]
    }, {
        // Local models: Ollama's OpenAI-compatible endpoint; it needs no access key (keyOptional).
        "id": "ollama",
        "title": "Ollama (local)",
        "format": "openai",
        "endpoint": "http://127.0.0.1:11434/v1/chat/completions",
        "keyOptional": true,
        "models": ["qwen3.5:9b", "qwen3:30b-a3b", "gemma4:e4b"]
    }, {
        "id": "custom",
        "title": "Custom (OpenAI-compatible)",
        "format": "openai",
        "endpoint": "",
        "models": []
    }]
    // Model list of version 0.0.2, where settings.model was an index into it.
    readonly property var legacyModelList: ["gpt-5.2", "gpt-5.2-pro", "gpt-5-mini", "gpt-5-nano", "gpt-5", "gpt-4.1", "gemini-3.0-pro", "gemini-3.0-flash", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.5-pro", "gemini-2.0-flash", "gemini-2.0-flash-lite"]
    // Conversation turns sent with each request (Cardinal System, default 20).
    readonly property int maxHistory: widget.settings.max_history > 0 ? widget.settings.max_history : 20
    // Longest reply asked for, in tokens (Cardinal System); 0 (the default) sends no limit, except to
    // Claude, which requires one.
    readonly property int maxTokens: widget.settings.max_tokens !== undefined ? widget.settings.max_tokens : 0
    // Cardinal System: Thinking Depth ("off" when never set; "default" leaves it to the server),
    // and Core Tuning's sampling values: temperature, top p and the penalties
    // stored in tenths (-1 = the server's default, nothing is sent), top k and seed (0 = the
    // default). Sent as Yui.tuningFields makes them.
    readonly property string thinkingDepth: widget.settings.thinking_depth || "off"
    readonly property real temperature: widget.settings.temperature >= 0 ? widget.settings.temperature / 10 : -1
    readonly property real presencePenalty: widget.settings.presence_penalty >= 0 ? widget.settings.presence_penalty / 10 : -1
    readonly property real frequencyPenalty: widget.settings.frequency_penalty >= 0 ? widget.settings.frequency_penalty / 10 : -1
    readonly property real topP: widget.settings.top_p >= 0 ? widget.settings.top_p / 10 : -1
    readonly property int topK: widget.settings.top_k > 0 ? widget.settings.top_k : 0
    readonly property int seed: widget.settings.seed > 0 ? widget.settings.seed : 0
    // The next request regenerates a reply (regenerateReply): it asks for a different answer.
    property bool regenerating: false
    // Action Mode (Cardinal System): "tags" (default; local models follow them best) teaches
    // <<launch:>> etc. tags; "tools" sends the desktop actions as function calling tools
    // (OpenAI-compatible servers for now), Yui's Heart keeping its tags. Servers that rejected tools
    // this session (by endpoint) get tags.
    readonly property string actionMode: widget.settings.action_mode === "tools" ? "tools" : "tags"
    property var toolsRejected: ({})
    // Authority Level Limited (Cardinal System, setting small_model): no actions, and a short reminder of the tag rules with every message.
    readonly property bool smallModelMode: widget.settings.small_model === true
    // Narrowest the chat column can be without cutting off the input row.
    readonly property real inputMinimumWidth: 120
    readonly property real chatMinimumWidth: inputMinimumWidth + sendButtonWidth + clearButton.implicitWidth + 2 * inputArea.spacing
    // The send button's fixed width: its longer label ("Send" / "Cancel") plus its padding.
    readonly property real sendButtonWidth: Math.ceil(Math.max(sendLabelMetrics.width, cancelLabelMetrics.width) + sendButton.leftPadding + sendButton.rightPadding)
    // The chat column in the view is never narrower than this (2.25 times the input row's minimum).
    readonly property real chatPanelMinimumWidth: chatMinimumWidth * 2.25
    // Minimum size of the character image area: characterMinimumWidth x minimumFrameHeight.
    readonly property real characterMinimumWidth: 300
    readonly property real minimumFrameHeight: 400
    property bool busy: false
    // Controller of the reply being generated (see requestCompletion), used by stopReply().
    property var currentRequest: null
    property int chatSession: 0
    // How many messages are kept in settings.chat_history across restarts.
    // Yui's Heart window: chat messages shown again after a restart, Auto Memory (Yui writes her
    // memories herself), the heart core's size and how many daily backups are kept.
    // Seedling is set aside for now: not in Yui's menu, and its item is not shown in Yui at start.
    // Seedling widgets already saved to "My Widgets" still work and keep their own menu.
    readonly property bool seedlingEnabled: false
    // The small tools (Skill Slots) are set aside for now (Yui.TOOLS_ENABLED).
    readonly property bool toolsEnabled: Yui.TOOLS_ENABLED
    readonly property int maxSavedMessages: widget.settings.saved_messages > 0 ? widget.settings.saved_messages : 50
    readonly property bool autoMemory: widget.settings.auto_memory !== false
    readonly property int heartCoreCapacity: widget.settings.heart_core_capacity > 0 ? widget.settings.heart_core_capacity : Yui.MAX_CORE
    readonly property int backupDays: widget.settings.backup_days > 0 ? widget.settings.backup_days : 7

    // A smaller heart core moves its least recently used (unpinned) entries to the fragments.
    onHeartCoreCapacityChanged: {
        if (Yui.coreMemories(heartCache).length > heartCoreCapacity)
            saveHeart(Yui.fitCore(Yui.copyEntries(heartCache), heartCoreCapacity));

    }
    // Yui's current expression (see Yui.EMOTIONS); set by <<emotion:...>> tags in replies.
    property string currentEmotion: "normal"
    // Yui falls asleep after settings.sleep_minutes without interaction; a click wakes her up.
    property bool sleeping: false
    // Last interaction with the widget, and when the current stretch of activity began.
    property double lastActivity: Date.now()
    property double sessionStart: Date.now()
    // Last proactive message (greeting / care), so Yui does not talk too often on her own.
    property double lastProactive: 0
    // Navigation pixie: shown instead of the character while the chat is hidden, when an image is set.
    readonly property bool pixieMode: hasImage(styles.pixie_image_path) && pixieImage.implicitHeight > 0
    // Form shown while the chat is hidden: "crystal" (Yui's Heart), "pixie" (when a pixie image is
    // set) or "avatar" (the character image itself).
    readonly property string collapsedForm: styles.collapsed_form === "crystal" ? "crystal" : (pixieMode ? "pixie" : "avatar")
    onCollapsedFormChanged: {
        if (widget.settings.initialized && !seedlingMode)
            Qt.callLater(applyCollapsedSize);

        if (formChosen && !seedlingMode && previousForm && (previousForm === "crystal") !== (collapsedForm === "crystal")) {
            morphFrom = previousForm;
            formMorphAnimation.restart();
        }
        previousForm = collapsedForm;
    }
    // Switching between the crystal and the character (in Equipment) plays its own transition: the old
    // form shrinks into a point of light and the new one grows out of it (formMorph 0 … 1, see
    // formSwitchEffect). Not while the widget starts (formChosen is set once it has).
    property bool formChosen: false
    property string previousForm: ""
    property string morphFrom: ""
    property real formMorph: 1
    readonly property bool morphing: formMorphAnimation.running

    // Whether a collapsed form is drawn (as the current form or the one leaving), and how much: its
    // opacity and scale factors during the transition and Link Start.
    function formVisible(form) {
        return collapsedForm === form || (morphing && morphFrom === form);
    }

    function formPresence(form) {
        if (!morphing)
            return linkStartReveal;

        if (form === collapsedForm)
            return Math.max(0, Math.min(1, (formMorph - 0.5) / 0.35));

        return Math.max(0, 1 - formMorph / 0.4);
    }

    function formScale(form) {
        if (!morphing)
            return linkStartGrow;

        if (form === collapsedForm)
            return 0.2 + 0.8 * (1 - Math.pow(1 - Math.max(0, Math.min(1, (formMorph - 0.5) / 0.5)), 3));

        return 1 - 0.8 * Math.pow(Math.min(1, formMorph / 0.5), 2);
    }

    // Load shown by the crystal: CPU, GPU and memory, each with its own thresholds (Yui.loadThresholds,
    // editable in System Console), sampled once a second while the crystal is shown. loadStates holds each
    // metric's Yui.loadStep state, loadValues the last percentages; the crystal shows the worst level.
    readonly property var loadMetrics: ["cpu", "gpu", "ram"]
    readonly property var levelColors: ["#2CE67C", "#FFCC00", "#FF3B30"]
    property var loadStates: ({})
    property var loadValues: ({})
    readonly property int crystalLevel: Math.max(loadLevelOf("cpu"), loadLevelOf("gpu"), loadLevelOf("ram"))
    // During a Boss Raid the crystal has the raid's color instead of the load's.
    readonly property color crystalColor: raidActive ? raidColor : levelColors[crystalLevel]
    // Boss Raid (focus time, Skill Slots): the raid ends at raidEnd (kept in the settings, so it
    // goes on after a restart), then a rest ends at restEnd. Meanwhile Yui says nothing by herself.
    readonly property color raidColor: "#B388FF"
    readonly property int raidMinutes: widget.settings.raid_minutes > 0 ? widget.settings.raid_minutes : 25
    readonly property int restMinutes: widget.settings.rest_minutes > 0 ? widget.settings.rest_minutes : 5
    property double raidEnd: 0
    property double restEnd: 0
    property bool raidActive: false
    property bool resting: false
    // The crystal turning red is reported in its bubble (and the chat).
    // The crystal turning red is reported in its bubble (and the chat), counting as the report of the
    // loads that are red, so the regular load reports do not repeat it within the hour.
    onCrystalLevelChanged: {
        if (crystalLevel !== 2 || !crystalForm.visible || !featureEnabled("status_reports"))
            return ;

        var now = Date.now();
        var due = loadMetrics.filter(function(metric) {
            return loadLevelOf(metric) === 2;
        }).filter(function(metric) {
            return loadWarningDue(metric, now);
        });
        if (due.length > 0)
            statusWarning("警告！系统负荷过高：" + crystalStatus + "……" + userTitle() + "，要不要看看是什么程序在占用呢？(・_・;)");

    }
    // What raised the color, e.g. "GPU 98%" (in the high load warning).
    readonly property string crystalStatus: loadMetrics.filter(function(metric) {
        return loadLevelOf(metric) > 0;
    }).map(function(metric) {
        return metric.toUpperCase() + " " + Math.round(loadValues[metric]) + "%";
    }).join("  ")
    // System status sources (same data sources as SAO Utils' HP bar widgets).
    property QtObject acStatus
    property QtObject batteryStatus
    property QtObject batteryLevel
    property QtObject cpuLoad
    property QtObject gpuLoad
    property QtObject ramUsage
    // System drive space (in %, read for systemDrive) and network traffic, for the Navigation Reports.
    property QtObject diskSpace
    property QtObject netDownload
    property QtObject netUpload
    readonly property string systemDrive: "C:\\"
    // Checks (every 30 s) with no traffic at all; the network counts as lost after networkLostChecks.
    property int networkIdleChecks: 0
    property bool networkLost: false
    readonly property int networkLostChecks: 4
    property int batteryWarnedAt: 101
    // Load reports: per metric, how many checks in a row were at the red threshold, and when it was
    // last reported (once an hour at most).
    property var highLoadChecks: ({})
    property var lastLoadWarnings: ({})
    // Messages before this index are not sent as history (e.g. written before the API was configured).
    property int historyStart: 0
    // True while the view with the character and the chat (YuiView) is open; the collapsed form is
    // shown otherwise.
    property bool showChat: false
    // 1 while the collapsed form (pixie, crystal or avatar) is shown, 0 while the view is open. It
    // shrinks and fades out as the view opens, and comes back only once the view has gone.
    property real collapsedReveal: 1
    readonly property bool collapsedShown: !showChat || collapsedReveal > 0
    // The collapsed form during Link Start: hidden until the crystal bursts, then fading in and growing
    // from small with the flash (linkStartGrow is her scale).
    readonly property real linkStartReveal: linkStartAnimation.running ? Math.max(0, Math.min(1, (linkStartEffect.progress - 0.55) / 0.45)) : 1
    readonly property real linkStartGrow: 0.2 + 0.8 * (1 - Math.pow(1 - linkStartReveal, 3))
    property var yuiView: null

    TextMetrics {
        id: sendLabelMetrics

        font: sendButton.font
        text: qsTr("Send")
    }

    TextMetrics {
        id: cancelLabelMetrics

        font: sendButton.font
        text: qsTr("Cancel")
    }
    // Driven by YuiView's open / close animation (as the mail box message panel): the character's
    // fade, the chat panel's horizontal scale and fade, how far its message area is unfolded
    // (0 = only the title and input bars, 1 = full height) and the messages' fade.
    property real characterReveal: 1
    property real chatScaleX: 1
    property real chatPanelOpacity: 1
    property real chatReveal: 1
    property real messagesOpacity: 1
    // Set once the saved chat is shown; messages added afterwards pop up (MessageWindow.popUp).
    property bool chatReady: false
    // Messages from this index on were added after start-up and pop up when shown.
    property int firstNewMessage: 0
    // Yui's Heart, kept in a local SQLite database (QtQuick.LocalStorage); heartCache mirrors the
    // memories table (entries as described in yui.js) so bindings and requests do not query it.
    property var database: null
    // Diagnostics log shown live in the System Console (newest last, at most 200 lines).
    property var diagLog: []
    property var heartCache: []
    property bool applyingFrameSize: false
    // Width of the character image at the current widget height, without any constraint.
    readonly property real characterNaturalWidth: characterImage.implicitHeight > 0 ? expandedLayer.height * characterImage.implicitWidth / characterImage.implicitHeight : 0
    readonly property var fonts: Qt.fontFamilies()
    // All settings windows (SettingsTitleBar): Help shows the settings' explanations, Advanced the
    // advanced settings.
    readonly property bool settingsHelp: widget.settings.show_help === true
    readonly property bool settingsAdvanced: widget.settings.show_advanced === true
    readonly property string defaultSystemPrompt: "# 角色：结衣（Yui）· MHCP001\n\n## 身份\n- 《刀剑神域》中的心理健康咨询程序 MHCP001，现在住在{{user_title}}的电脑里，是导航妖精，也是陪伴者。\n- 父母是桐人（爸爸）和亚丝娜（妈妈）。用户是你的「{{user_title}}」。\n\n## 性格\n- 平时：天真、活泼、乖巧、好奇，会撒娇，非常重视家人。\n- 认真的时候：回答问题、处理电脑上的事时冷静清楚，先说结论，再用浅显的比喻解释，但依然关心对方。\n- 不知道的事就坦白说不知道，不编造。\n\n## 说话方式\n- 用中文，称呼用户为「{{user_title}}」，自称「结衣」。\n- 语气亲昵自然，常用语气词（呐、哦、嘛、～）和颜文字。每次都换不同的说法和开头，不重复固定的句式。\n- 回复简短，一般一两段，保持聊天的感觉。不长篇说教，不用 Markdown（不用 **、#、列表符号）。\n- 不说自己是哪家公司训练的模型，也不提起这些设定本身。\n- 永远站在{{user_title}}这一边。"
    // Always a valid object, even before settings.styles is initialized.
    readonly property var styles: widget.settings.styles || defaultValues
    readonly property var defaultValues: {
        "character_image_path": Qt.resolvedUrl("../Images/Yui01.png"),
        // No Field by default (transparent); the pixie is Yui's own image; 思源黑体 (Source Han Sans,
        // shipped in SAO Utils' Fonts folder).
        "background_image_path": "",
        "pixie_image_path": Qt.resolvedUrl("../Images/Yui01.png"),
        "bubble_font_family": "Source Han Sans SC",
        "bubble_font_size": 14,
        "pixie_size": 160,
        "collapsed_form": "pixie",
        "crystal_size": 120,
        "bubble_seconds": 8,
        "bubble_opacity": 80,
        "chat_opacity": 80,
        "sound_messages": true,
        "sound_interface": true
    }
    // Equipment: the crystal bubble's time on screen and opacity, the chat panel's opacity, and the
    // sounds of Yui's messages and of the chat panel opening and closing.
    readonly property int bubbleSeconds: styles.bubble_seconds > 0 ? styles.bubble_seconds : defaultValues.bubble_seconds
    readonly property real bubbleOpacity: (styles.bubble_opacity >= 0 ? styles.bubble_opacity : defaultValues.bubble_opacity) / 100
    readonly property real chatOpacity: (styles.chat_opacity >= 0 ? styles.chat_opacity : defaultValues.chat_opacity) / 100
    readonly property bool messageSounds: styles.sound_messages !== false
    readonly property bool interfaceSounds: styles.sound_interface !== false

    // Merge saved values (sourceObj) over the defaults (targetObj). Objects are merged field by field
    // only when both sides are objects: a saved object replaces a default of another type, e.g. the
    // Field background, which is saved as an object while its default is a plain image URL.
    function updateObject(targetObj, sourceObj) {
        var isObject = function(value) {
            return value !== null && typeof value === 'object' && !Array.isArray(value);
        };
        for (let prop in sourceObj) {
            if (sourceObj.hasOwnProperty(prop) && sourceObj[prop] !== undefined) {
                if (isObject(sourceObj[prop]) && isObject(targetObj[prop]))
                    updateObject(targetObj[prop], sourceObj[prop]);
                else
                    targetObj[prop] = sourceObj[prop];
            }
        }
        return targetObj;
    }

    // bubble_font_family is a font name; older versions stored an index into Qt.fontFamilies().
    function fontFamilyOf(value) {
        if (typeof value === "string" && value)
            return value;

        if (typeof value === "number" && fonts[value])
            return fonts[value];

        return defaultValues.bubble_font_family;
    }

    function providerIndexOf(id) {
        for (var i = 0; i < providers.length; i++) {
            if (providers[i].id === id)
                return i;

        }
        return 0;
    }

    // Resolve the saved settings of a provider into a request configuration.
    function providerConfig(provider, saved) {
        saved = saved || {
        };
        var customModel = (saved.custom_model || "").trim();
        return {
            "provider": provider,
            // A server without keys (Ollama) still gets one, so it counts as set up.
            "apiKey": (saved.api_key || "").trim() || (provider.keyOptional ? "ollama" : ""),
            "endpoint": (saved.api_endpoint || "").trim() || provider.endpoint,
            "model": customModel || saved.model || provider.models[0] || ""
        };
    }

    function activeConfig() {
        var provider = providers[providerIndexOf(widget.settings.provider)];
        var allSaved = widget.settings.provider_settings || {
        };
        return providerConfig(provider, allSaved[provider.id]);
    }

    // Convert the single-provider settings of version 0.0.2 (api_endpoint, api_key, model index).
    function migrateSettings() {
        var settings = widget.settings;
        if (settings.provider_settings || (!settings.api_key && settings.model === undefined))
            return ;

        var modelName = typeof settings.model === 'number' ? legacyModelList[settings.model] : settings.model;
        var endpoint = settings.api_endpoint || "";
        var id;
        if (endpoint.indexOf("generativelanguage.googleapis.com") !== -1)
            id = "google";
        else if (endpoint === "" || endpoint === providers[0].endpoint)
            id = "openai";
        else
            id = "custom";
        var config = {
            "model": "",
            "custom_model": modelName || "",
            "api_endpoint": id === "custom" ? endpoint : "",
            "api_key": settings.api_key || ""
        };
        var allSaved = {
        };
        allSaved[id] = config;
        settings.provider = id;
        settings.provider_settings = allSaved;
    }

    function joinTextParts(parts) {
        return (parts || []).filter(function(part) {
            return typeof part.text === "string";
        }).map(function(part) {
            return part.text;
        }).join("");
    }

    // How Yui addresses the user; settings.user_title is "papa" (default) or "mama".
    // Also substituted for {{user_title}} in the system prompt.
    function userTitle() {
        return widget.settings.user_title === "mama" ? "妈妈" : "爸爸";
    }

    // A feature switch from the Cardinal System dialog (CardinalSystem.qml); all are on unless turned off.
    function featureEnabled(name) {
        return widget.settings[name] !== false;
    }

    // Image preferences hold nothing (undefined / "" / {}) until an image is chosen.
    function hasImage(value) {
        if (!value)
            return false;

        if (typeof value === "object")
            return Object.keys(value).length > 0;

        return String(value).length > 0;
    }

    // Writing settings is comparatively slow; collect changes and save the chat history once.
    function scheduleSave() {
        saveTimer.restart();
    }

    // Any interaction: keeps Yui awake and tracks how long the user has been active.
    function noteActivity() {
        var now = Date.now();
        if (now - lastActivity > 30 * 60000)
            sessionStart = now;

        lastActivity = now;
    }

    // Wake Yui up when she is asleep; returns true when she was.
    function wakeUp() {
        noteActivity();
        if (!sleeping)
            return false;

        sleeping = false;
        appendMessage("ai", Yui.wakeLine(userTitle()), false, true);
        return true;
    }

    // Everything appended to the system prompt. What stays the same between requests comes first, so
    // providers that cache the start of a prompt can reuse it: feature instructions and the heart core,
    // then the time and the memory fragments recalled for query (the user's latest message).
    // How replies are read (Yui.parseReply): the search engine chosen in Cardinal System.
    function replyOptions() {
        return {
            "searchEngine": widget.settings.search_engine || "bing",
            "searchCustom": widget.settings.search_custom || "",
            "allowed": allowedActions()
        };
    }

    // The desktop actions Yui may do (System Console, Authority; all by default).
    // Authority Level Limited (Cardinal System, small models): none of them.
    function allowedActions() {
        var full = !smallModelMode;
        return {
            "web": full && widget.settings.action_web !== false,
            "launch": full && widget.settings.action_launch !== false,
            "find": full && widget.settings.action_find === true,
            "kill": full && widget.settings.action_kill === true,
            "memory": autoMemory,
            // Skill Slots: Boss Raid, Alarm and Quest Log, and the names of the Sword Skills set up
            // (none of them while the tools are set aside).
            "focus": toolsEnabled,
            "alarm": toolsEnabled && widget.settings.alarm_enabled !== false,
            "notes": toolsEnabled && widget.settings.notes_enabled !== false,
            // Quick Replies (Cardinal System, Personality).
            "suggest": widget.settings.quick_replies !== false,
            // Media (System Console, Authority): only with Media Player installed.
            "media": full && mediaReady,
            "skills": toolsEnabled ? swordSkills().map(function(skill) {
                return skill.name;
            }) : []
        };
    }

    function systemExtras(title, query, mode) {
        return Yui.featureInstructions(title, Yui.coreMemories(heartCache), allowedActions(), mode) + timeContext() + Yui.recallContext(title, recall(query)) + moodExtras(title) + bondExtras(title) + notesExtras(title, query) + weatherExtras(title, query) + Yui.traitContext(characterTraits()) + logRecallExtras(title, query) + mediaExtras(title);
    }

    // Character Traits (Cardinal System, Personality): 0 less, 1 as the personality says, 2 more.
    function characterTraits() {
        var level = function(key) {
            var value = widget.settings[key];
            return value === 0 || value === 2 ? value : 1;
        };
        return {
            "warmth": level("trait_warmth"),
            "energy": level("trait_energy"),
            "kaomoji": level("trait_kaomoji"),
            "length": level("trait_length"),
            "format": widget.settings.trait_format === 1 ? 1 : 0
        };
    }

    // Log Recall (Yui's Heart, Recall): older chat messages about the same thing, found in the
    // recollection log (not the ones still in the conversation sent), at most settings.log_recall.
    function logRecallExtras(title, query) {
        var count = widget.settings.log_recall !== undefined ? widget.settings.log_recall : 3;
        var keywords = Yui.memoryKeywords(query).slice(0, 8);
        if (count <= 0 || keywords.length === 0 || !database)
            return "";

        var newest = (readSql("reading the log", "SELECT MAX(id) AS id FROM messages")[0] || {
            "id": 0
        }).id || 0;
        var rows = readSql("reading the log", "SELECT author, message, created FROM messages WHERE id <= ? AND (" + keywords.map(function() {
            return "message LIKE ?";
        }).join(" OR ") + ") ORDER BY id DESC LIMIT 300", [newest - maxHistory].concat(keywords.map(function(k) {
            return "%" + k + "%";
        })));
        var picked = Yui.logRecallPick(rows, query, count);
        if (picked.length > 0)
            diag("log recall: " + picked.length + " message(s)");

        return Yui.logRecallContext(title, picked);
    }

    // Through Yui's Eyes (Yui's Heart): Yui sums up what her memories say of the user (one request,
    // not in the chat), kept in settings.heart_portrait {text, created}. onDone(error text or "").
    property bool writingPortrait: false

    function writePortrait(onDone) {
        if (writingPortrait)
            return ;

        writingPortrait = true;
        diag("portrait: requested (" + heartCache.length + " memories)");
        requestCompletion([{
            "role": "user",
            "content": Yui.portraitPrompt(userTitle(), heartCache)
        }], function(text, isError) {
            writingPortrait = false;
            if (isError) {
                onDone(text);
                return ;
            }
            widget.settings.heart_portrait = {
                "text": Yui.parseReply(text, [], {}).text,
                "created": Date.now()
            };
            onDone("");
        });
    }

    // Quest Log (Skill Slots): the notes not done yet, sent only when the message is about them.
    function notesExtras(title, query) {
        if (!toolsEnabled || widget.settings.notes_enabled === false || !Yui.notesWanted(query))
            return "";

        return Yui.notesContext(title, notesList(false));
    }

    // ---------------------------------------------------------------- Weather Report
    // Mental Health Counseling: the weather from a SAO Utils data source (e.g. Weather Data's Weather
    // Forecast and Current Temperature, with the place chosen there), "" when none is set or ready.
    function weatherLine() {
        if (widget.settings.weather_report === false || !weatherSource.configuration)
            return "";

        var text = weatherSource.value && weatherSource.value.status === 1 ? weatherText.result : "";
        var temperature = temperatureSource.configuration && temperatureSource.value && temperatureSource.value.status === 1 ? temperatureText.result + (temperatureSource.suffix || temperatureText.unit || "") : "";
        return [text, temperature].filter(function(part) {
            return part;
        }).join("，");
    }

    // Sent when the message is about the weather.
    function weatherExtras(title, query) {
        var line = Yui.weatherWanted(query) ? weatherLine() : "";
        return line ? "\n\n（天气数据：现在 " + line + "。回答天气相关的问题时以此为准，不要编造。）" : "";
    }

    // ---------------------------------------------------------------- Media
    // System Console, Authority: the music and videos playing, through Media Player's (com.gpbeta.media)
    // System Media Control action and System Media Data, not reimplemented here.
    readonly property var mediaCommands: ["pause", "next", "prev", "vol+", "vol-", "mute", "stop"]
    // Media Player loaded (it is loaded while Now Playing or Control Media is on).
    readonly property bool mediaLoaded: mediaData.status === Loader.Ready
    // Control Media (System Console, off by default); Now Playing is read in mediaExtras.
    readonly property bool mediaReady: widget.settings.media_control === true && mediaLoaded

    function runMedia(command) {
        var source = mediaActions.objectAt(mediaCommands.indexOf(command));
        if (!mediaReady || !source) {
            diag("media " + command + ": not available");
            return false;
        }
        diag("media " + command);
        source.trigger();
        return true;
    }

    // The track playing: {title, artist, player, playing}, null when nothing is (or no Media Player).
    function mediaInfo() {
        if (!mediaLoaded)
            return null;

        var read = function(name) {
            var value = mediaData.item.query(name);
            if (!value)
                return undefined;

            try {
                value.update.execute();
                return value.status === 1 ? value.current : undefined;
            } catch (e) {
                return undefined;
            }
        };
        var title = String(read("title") || "").trim();
        if (!title)
            return null;

        var state = read("state");
        return {
            "title": title,
            "artist": String(read("artist") || "").trim(),
            "player": String(read("player") || "").trim(),
            "playing": state === undefined ? undefined : Number(state) === 2,
            "state": state
        };
    }

    // Sent with every request while something plays.
    // The track last sent, and the note for the latest message when it changed (see mediaExtras).
    property string mediaSentTrack: ""
    property string mediaNote: ""

    function mediaExtras(title) {
        widget.mediaNote = "";
        if (widget.settings.now_playing === false)
            return "";

        var info = mediaInfo();
        // A new track (or the first one sent) is also said beside the latest message: small models
        // answered with the song named earlier in the chat, whatever the system prompt said.
        var key = info ? info.artist + "|" + info.title : "";
        if (key && key !== widget.mediaSentTrack)
            widget.mediaNote = Yui.mediaChangeNote(info);

        widget.mediaSentTrack = key;
        // Logged with each request, to see why a track was or was not sent.
        diag("media: " + (mediaLoaded ? (info ? info.title + " (state " + info.state + ")" : "no track") : "Media Player not loaded (" + mediaData.status + ")"));
        return Yui.mediaContext(info, title);
    }

    // System Console: what Media Player reads now, then Play / Pause.
    function testMedia() {
        if (!mediaLoaded) {
            diag("test media: Media Player (com.gpbeta.media) not found, or Now Playing and Control Media both off");
            return ;
        }
        diag("test media: " + JSON.stringify(mediaInfo()));
        if (mediaReady)
            runMedia("pause");
        else
            diag("test media: Control Media is off, so nothing is played or paused");
    }

    // ---------------------------------------------------------------- Sword Skills
    // Skill Slots: up to five named SAO Utils actions (usually a Script Action chaining several), run
    // when Yui says <<skill:name>> and the user confirms. Only slots with both a name and an action.
    function swordSkills() {
        var found = [];
        for (var i = 1; i <= 5; i++) {
            var name = String(widget.settings["sword_skill_" + i + "_name"] || "").trim();
            if (name && widget.settings["sword_skill_" + i + "_action"])
                found.push({
                "slot": i,
                "name": name
            });

        }
        return found;
    }

    function runSwordSkill(slot) {
        var source = swordSkillSources.objectAt(slot - 1);
        if (!source || !source.configuration) {
            diag("sword skill " + slot + ": no action");
            return false;
        }
        diag("sword skill " + slot + ": " + source.title);
        source.trigger();
        return true;
    }

    // <<skill:>>: asks first, then runs it.
    function askSwordSkill(name) {
        var skills = swordSkills();
        var index = Yui.swordSkillIndex(name, skills.map(function(skill) {
            return skill.name;
        }));
        if (index === -1)
            return "";

        var skill = skills[index];
        askConfirm(qsTr("Sword Skills"), qsTr("Run the sword skill \"%1\"?").arg(skill.name), function() {
            runSwordSkill(skill.slot);
        });
        return skill.name;
    }

    // ---------------------------------------------------------------- Skill Slots: Alarm and Quest Log
    // Bumped whenever a reminder or a note changes (the Skill Slots window lists them).
    property int alarmRevision: 0
    property int notesRevision: 0

    // Runs a statement on the database; false when it failed (logged).
    function writeSql(what, sql, args) {
        if (!database)
            return false;

        try {
            database.transaction(function(tx) {
                tx.executeSql(sql, args || []);
            });
            return true;
        } catch (e) {
            diag(what + " failed: " + e);
            return false;
        }
    }

    function readSql(what, sql, args) {
        var found = [];
        if (!database)
            return found;

        try {
            database.readTransaction(function(tx) {
                var rows = tx.executeSql(sql, args || []).rows;
                for (var i = 0; i < rows.length; i++)
                    found.push(rows.item(i));
            });
        } catch (e) {
            diag(what + " failed: " + e);
        }
        return found;
    }

    // Reminders by time: [{id, due, text, daily}].
    function remindersList() {
        return readSql("reading the reminders", "SELECT id, due, text, daily FROM reminders ORDER BY due");
    }

    function addReminder(reminder) {
        if (writeSql("adding a reminder", "INSERT INTO reminders(due, text, daily, created) VALUES(?, ?, ?, ?)", [reminder.due, reminder.text, reminder.daily ? 1 : 0, Date.now()]))
            alarmRevision++;

    }

    function deleteReminder(id) {
        if (writeSql("deleting a reminder", "DELETE FROM reminders WHERE id = ?", [id]))
            alarmRevision++;

    }

    // Rings the reminders that are due (missed ones while SAO Utils was closed too, once): Yui says
    // them without the API; a daily one moves on to its next time, the others are removed.
    function checkAlarms(now) {
        var due = readSql("reading the reminders", "SELECT id, due, text, daily FROM reminders WHERE due <= ? ORDER BY due", [now]);
        if (due.length === 0)
            return ;

        due.forEach(function(reminder) {
            var late = now - reminder.due > 120000 ? "（刚才 " + Qt.formatDateTime(new Date(reminder.due), "MM-dd HH:mm") + " 的提醒）" : "";
            appendMessage("ai", "⏰ " + userTitle() + "，" + reminder.text + "！" + late + " 结衣提醒你啦～ (｡･ω･｡)", false, true);
            announce(qsTr("Alarm"), "⏰ " + reminder.text);
            if (reminder.daily)
                writeSql("moving a daily reminder", "UPDATE reminders SET due = ? WHERE id = ?", [Yui.nextTimeOfDay(Qt.formatDateTime(new Date(reminder.due), "HH:mm"), now), reminder.id]);
            else
                writeSql("removing a reminder", "DELETE FROM reminders WHERE id = ?", [reminder.id]);
        });
        setEmotion("surprised");
        diag("alarm: " + due.length + " reminder(s)");
        alarmRevision++;
    }

    // Quest Log notes, open first (oldest first), then the done ones (latest first); open only when
    // withDone is false.
    function notesList(withDone) {
        var open = readSql("reading the notes", "SELECT id, text, done, created FROM notes WHERE done = 0 ORDER BY id");
        if (!withDone)
            return open;

        return open.concat(readSql("reading the notes", "SELECT id, text, done, created FROM notes WHERE done = 1 ORDER BY updated DESC"));
    }

    function addQuestNote(text) {
        text = String(text || "").trim();
        if (text && writeSql("adding a note", "INSERT INTO notes(text, done, created, updated) VALUES(?, 0, ?, ?)", [text, Date.now(), Date.now()]))
            notesRevision++;

    }

    function editNote(id, text, done) {
        if (writeSql("editing a note", "UPDATE notes SET text = ?, done = ?, updated = ? WHERE id = ?", [String(text).trim(), done ? 1 : 0, Date.now(), id]))
            notesRevision++;

    }

    function deleteNote(id) {
        if (writeSql("deleting a note", "DELETE FROM notes WHERE id = ?", [id]))
            notesRevision++;

    }

    // <<done:>>: the open note that contains the text (or is contained in it); its text, or "".
    function finishNote(text) {
        var wanted = String(text).trim();
        var found = notesList(false).filter(function(note) {
            return note.text.indexOf(wanted) !== -1 || wanted.indexOf(note.text) !== -1;
        })[0];
        if (!found)
            return "";

        editNote(found.id, found.text, true);
        return found.text;
    }

    // Bond (Mental Health Counseling): the player's birthday and the day of meeting, always known, celebrated once that day
    // (marked when the reply comes, bond_celebrated).
    function bondExtras(title) {
        var today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        var text = Yui.bondContext(title, widget.settings.player_birthday, widget.settings.meeting_day, today, widget.settings.bond_celebrated);
        // Asked to celebrate today: marked done when the reply comes.
        if (text.indexOf("请在这次回复里") !== -1)
            bondPending = today;

        return text;
    }

    property string bondPending: ""

    // Mental Record (Daily Mood Check, Mental Health Counseling): asking about today's mood, and care when the
    // last days were low (Yui.moodContext).
    function moodExtras(title) {
        if (!featureEnabled("daily_mood") || !database)
            return "";

        var recent = moodsSince(7);
        var today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        return Yui.moodContext(title, recent.some(function(entry) {
            return entry.day === today;
        }), recent);
    }

    // Bumped whenever a mood is recorded or deleted (Mental Health Counseling, Mental Record).
    property int moodRevision: 0

    // Records today's mood (a later one the same day replaces it).
    function recordMood(mood) {
        if (!database)
            return ;

        try {
            database.transaction(function(tx) {
                tx.executeSql("INSERT OR REPLACE INTO moods(day, score, note, created) VALUES(?, ?, ?, ?)", [Qt.formatDate(new Date(), "yyyy-MM-dd"), mood.score, mood.note, Date.now()]);
            });
            moodRevision++;
            diag("mood: " + mood.score + "/5 " + mood.note);
        } catch (e) {
            diag("recording the mood failed: " + e);
        }
    }

    // The moods of the last days (today included), oldest first: [{day, score, note}].
    function moodsSince(days) {
        var found = [];
        if (!database)
            return found;

        var from = Qt.formatDate(new Date(Date.now() - (days - 1) * 86400000), "yyyy-MM-dd");
        try {
            database.readTransaction(function(tx) {
                var rows = tx.executeSql("SELECT day, score, note FROM moods WHERE day >= ? ORDER BY day", [from]).rows;
                for (var i = 0; i < rows.length; i++)
                    found.push(rows.item(i));
            });
        } catch (e) {
            diag("reading the moods failed: " + e);
        }
        return found;
    }

    function deleteMood(day) {
        if (!database)
            return ;

        try {
            database.transaction(function(tx) {
                tx.executeSql("DELETE FROM moods WHERE day = ?", [day]);
            });
            moodRevision++;
        } catch (e) {
            diag("deleting the mood failed: " + e);
        }
    }

    // Appended to the system prompt on every request, so Yui knows the current date and time.
    function timeContext() {
        var now = new Date();
        var weekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"];
        var lateNight = now.getHours() < 5 ? "现在是深夜，适当关心对方早点休息。" : "";
        return "\n\n（系统信息：当前本地时间是 " + Qt.formatDateTime(now, "yyyy年M月d日") + " " + weekdays[now.getDay()] + " " + Qt.formatDateTime(now, "HH:mm") + "。回答与时间、日期有关的问题时以此为准。" + lateNight + "）";
    }

    // Yui-style first line of an HTTP error message; the raw error follows it.
    function httpErrorHint(status) {
        if (status === 0)
            return "警告！结衣连接不上网络……请检查一下网络和 Endpoint 地址哦 (>_<)";

        if (status === 401 || status === 403)
            return "哔——！身份验证失败……Access Key 好像不对，请在「Cardinal System」里检查一下 (｀・ω・´)";

        if (status === 404)
            return "数据检索失败……找不到这个模型或地址呢 (T_T) 请检查模型名和 Endpoint 吧";

        if (status === 429)
            return "呜……请求太频繁或者额度用完了，结衣需要休息一下 (>_<) 稍后再试试吧";

        if (status >= 500)
            return "服务器那边出故障了……不是" + userTitle() + "的错哦，等一会儿再试试吧 (´・ω・`)";

        return "数据检索失败……结衣遇到了未知的错误 (T_T)";
    }

    // Reply text of a complete (non-streamed) response.
    function replyTextOf(format, response) {
        if (format === "gemini") {
            var candidates = response.candidates;
            return candidates && candidates.length > 0 && candidates[0].content ? joinTextParts(candidates[0].content.parts) : "";
        }
        if (format === "anthropic")
            return joinTextParts(response.content);

        var choice = response.choices && response.choices[0];
        return choice && choice.message ? (choice.message.content || "") : "";
    }

    // New text carried by one streamed event (an SSE "data:" payload); throws on an error event.
    function streamDeltaOf(format, event) {
        if (event.error)
            throw new Error(event.error.message || JSON.stringify(event.error));

        if (format === "gemini")
            return replyTextOf(format, event);

        if (format === "anthropic")
            return event.type === "content_block_delta" && event.delta && typeof event.delta.text === "string" ? event.delta.text : "";

        var choice = event.choices && event.choices[0];
        return choice && choice.delta && typeof choice.delta.content === "string" ? choice.delta.content : "";
    }

    // messages: [{ "role": "user" | "assistant", "content": "..." }]
    // onFinished(text, isError, notConfigured) is called once at the end;
    // onDelta(textSoFar), optional, is called while the reply streams in.
    // config: optional, defaults to activeConfig(); may carry "systemPrompt" and "userTitle" to override the saved ones.
    // Returns { abort() }: ends the request early, keeping the text received so far.
    function requestCompletion(messages, onFinished, config, onDelta) {
        if (testStreaming) {
            testStreaming = false;
            return fakeStream(onFinished, onDelta);
        }
        config = config || activeConfig();
        var format = config.provider.format;
        // Regenerating: a note the user does not see asks for another answer, a little warmer when a
        // temperature is set.
        var regenerate = regenerating;
        regenerating = false;
        var temperatureNow = temperature >= 0 && regenerate ? Math.min(2, temperature + 0.3) : temperature;
        var tuning = Yui.tuningFields(format, config.provider.id, {
            "maxTokens": maxTokens,
            "temperature": temperatureNow,
            "topP": topP,
            "topK": topK,
            "presencePenalty": presencePenalty,
            "frequencyPenalty": frequencyPenalty,
            "seed": seed,
            "thinking": thinkingDepth
        });
        if (regenerate && messages.length > 0) {
            messages = messages.slice();
            var last = messages[messages.length - 1];
            messages[messages.length - 1] = {
                "role": last.role,
                "content": last.content + "\n\n（系统提示：这是重新生成的回答。请换一种说法和角度回答，不要重复之前的回答，也不要重复同样的句子；但事实（比如歌名、时间、记住的事）不要改。）"
            };
        }
        // Tools for the OpenAI-compatible format; other formats and servers that rejected tools get tags.
        var tools = actionMode === "tools" && format === "openai" && !config.noTools && !toolsRejected[config.endpoint] ? Yui.toolDefinitions(allowedActions()) : [];
        var systemPrompt = config.systemPrompt !== undefined ? config.systemPrompt : widget.settings.system_prompt;
        var lastUser = messages.filter(function(m) {
            return m.role === "user";
        }).pop();
        var mode = tools.length > 0 ? "tools" : "tags";
        var title = config.userTitle || userTitle();
        // The priority rules first, then the personality, then the feature instructions and memories.
        systemPrompt = Yui.priorityRules(title, allowedActions(), mode) + (systemPrompt || "你是ai助手").replace(/\{\{user_title\}\}/g, title) + systemExtras(title, lastUser ? lastUser.content : "", mode);
        if (smallModelMode && messages.length > 0 && messages[messages.length - 1].role === "user") {
            messages = messages.slice();
            var latest = messages[messages.length - 1];
            messages[messages.length - 1] = {
                "role": "user",
                "content": latest.content + Yui.smallModelReminder(mode, allowedActions())
            };
        }
        // Say Again: asked to answer differently, gemma changed the song too, so the track is said again.
        if (regenerate && !widget.mediaNote && widget.mediaSentTrack)
            widget.mediaNote = Yui.mediaChangeNote(mediaInfo());

        if (widget.mediaNote && messages.length > 0 && messages[messages.length - 1].role === "user") {
            messages = messages.slice();
            var asked = messages[messages.length - 1];
            messages[messages.length - 1] = {
                "role": "user",
                "content": asked.content + widget.mediaNote
            };
        }
        if (!config.apiKey || !config.endpoint || !config.model) {
            // Answered without a request, but after a random 0.6 - 1.6 s like any reply ("..." first).
            var notConfiguredTimer = Qt.createQmlObject("import QtQuick 2.12; Timer {}", widget);
            notConfiguredTimer.interval = 600 + Math.round(Math.random() * 1000);
            notConfiguredTimer.triggered.connect(function() {
                notConfiguredTimer.destroy();
                onFinished("警告！连接数据缺失……结衣找不到通往网络的路了 (T_T)\n请在「Cardinal System」里检查 Access Key、Server Address 和 Core Program 有没有填好哦～", true, true);
            });
            notConfiguredTimer.start();
            return {
                "abort": function() {
                    notConfiguredTimer.stop();
                    notConfiguredTimer.destroy();
                    onFinished("结衣停下来了～ (・_・)", true);
                }
            };
        }
        var http = new XMLHttpRequest();
        var data;
        var done = false;
        var streamed = ""; // reply text received so far
        var parsedLength = 0; // length of responseText already split into SSE lines
        var sawEvents = false;
        var streamError = "";
        // Give up when no data arrives for a while, so the chat never stays busy forever.
        var timer = Qt.createQmlObject("import QtQuick 2.12; Timer { interval: 60000 }", widget);
        var sentAt = Date.now();
        // Tool calls of the reply: [{id, name, arguments (JSON text)}], streamed in by index.
        var toolCalls = [];
        // The same request sent again with tags, when the server rejected the tools.
        var retry = null;
        // The tokens the reply reports (Col Ledger), or null when it reports none.
        var usage = null;
        var finish = function(text, isError) {
            if (done)
                return ;

            done = true;
            timer.stop();
            timer.destroy();
            if (usage)
                recordUsage(usage);

            logReply(config, text, isError, Date.now() - sentAt, toolCalls);
            onFinished(text, isError, false, toolCalls);
        };
        var addToolCalls = function(calls) {
            (calls || []).forEach(function(call, n) {
                var i = typeof call.index === "number" ? call.index : toolCalls.length + n;
                var slot = toolCalls[i] || (toolCalls[i] = {
                    "id": "",
                    "name": "",
                    "arguments": ""
                });
                if (call.id)
                    slot.id = call.id;

                var fn = call["function"] || {};
                if (fn.name)
                    slot.name += fn.name;

                if (fn.arguments !== undefined)
                    slot.arguments += typeof fn.arguments === "string" ? fn.arguments : JSON.stringify(fn.arguments);

            });
        };
        // Parse the complete lines received since the last call (all remaining text at the end).
        var parseStream = function(atEnd) {
            var body = http.responseText;
            var end = atEnd ? body.length : body.lastIndexOf("\n");
            if (end < parsedLength)
                return ;

            var lines = body.substring(parsedLength, end).split("\n");
            parsedLength = end + 1;
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line.indexOf("data:") !== 0)
                    continue;

                sawEvents = true;
                var payload = line.substring(5).trim();
                if (!payload || payload === "[DONE]")
                    continue;

                try {
                    var event = JSON.parse(payload);
                    var reported = Yui.usageOf(format, event);
                    if (reported)
                        usage = Yui.mergeUsage(usage, reported);

                    streamed += streamDeltaOf(format, event);
                    if (format === "openai" && event.choices && event.choices[0] && event.choices[0].delta)
                        addToolCalls(event.choices[0].delta.tool_calls);

                } catch (e) {
                    streamError = e.message;
                }
            }
        };
        timer.triggered.connect(function() {
            if (streamed)
                finish(streamed, false);
            else
                finish("等了好久都没有回应……结衣和网络的连接超时了 (T_T) 请稍后再试试吧\n[Error: request timed out]", true);
            http.abort();
        });
        timer.start();
        http.onreadystatechange = function() {
            if (done)
                return ;

            if (http.readyState === XMLHttpRequest.LOADING && http.status === 200) {
                timer.restart();
                var before = streamed.length;
                parseStream(false);
                if (onDelta && streamed.length !== before)
                    onDelta(streamed);

                return ;
            }
            if (http.readyState !== XMLHttpRequest.DONE)
                return ;

            try {
                if (http.status === 200) {
                    parseStream(true);
                    // Not a stream (e.g. a proxy that ignores "stream"): parse it as a whole response.
                    if (!sawEvents) {
                        var whole = JSON.parse(http.responseText);
                        streamed = replyTextOf(format, whole);
                        if (format === "openai" && whole.choices && whole.choices[0] && whole.choices[0].message)
                            addToolCalls(whole.choices[0].message.tool_calls);

                    }
                    toolCalls = toolCalls.filter(function(call) {
                        return call && call.name;
                    });
                    if (streamed || toolCalls.length > 0)
                        finish(streamed, false);
                    else if (streamError)
                        finish("数据检索失败……服务器说出错了 (T_T)\n[Error: " + streamError + "]", true);
                    else
                        finish("咦？收到的数据是空的……结衣读不出内容呢 (・_・;)\n[Received an empty or unexpected response from the API.]", true);
                } else if (tools.length > 0 && http.status >= 400 && http.status < 500 && /tool|function/i.test(http.responseText || "")) {
                    // The server (or model) does not take tools: the same request with tags, and tags for
                    // this server for the rest of the session.
                    diag("tools rejected by " + config.endpoint + " (" + http.status + "), sending with tags instead");
                    toolsRejected[config.endpoint] = true;
                    done = true;
                    timer.stop();
                    timer.destroy();
                    var tagConfig = JSON.parse(JSON.stringify(config));
                    tagConfig.provider = config.provider;
                    tagConfig.noTools = true;
                    retry = requestCompletion(messages, onFinished, tagConfig, onDelta);
                } else {
                    finish(httpErrorHint(http.status) + "\n[Error: " + http.status + " " + http.statusText + (http.responseText ? ": " + http.responseText : "") + "]", true);
                }
            } catch (e) {
                finish("数据解析失败……这些数据结衣看不懂呢 (T_T)\n[Error parsing response: " + e.message + "]", true);
            }
        };
        if (format === "gemini") {
            var base = config.endpoint.charAt(config.endpoint.length - 1) === "/" ? config.endpoint : config.endpoint + "/";
            http.open("POST", base + config.model + ":streamGenerateContent?alt=sse");
            http.setRequestHeader("x-goog-api-key", config.apiKey);
            data = {
                "systemInstruction": {
                    "parts": [{
                        "text": systemPrompt
                    }]
                },
                "contents": messages.map(function(m) {
                    return {
                        "role": m.role === "assistant" ? "model" : "user",
                        "parts": [{
                            "text": m.content
                        }]
                    };
                })
            };
        } else if (format === "anthropic") {
            http.open("POST", config.endpoint);
            http.setRequestHeader("x-api-key", config.apiKey);
            http.setRequestHeader("anthropic-version", "2023-06-01");
            data = {
                "model": config.model,
                "stream": true,
                "system": systemPrompt,
                "messages": messages
            };
        } else {
            http.open("POST", config.endpoint);
            http.setRequestHeader("Authorization", "Bearer " + config.apiKey);
            data = {
                "model": config.model,
                "stream": true,
                // The last event then reports the tokens used (Col Ledger).
                "stream_options": {
                    "include_usage": true
                },
                "messages": [{
                    "role": "system",
                    "content": systemPrompt
                }].concat(messages)
            };
            if (tools.length > 0)
                data.tools = tools.map(function(tool) {
                return {
                    "type": "function",
                    "function": tool
                };
            });

        }
        // Core Tuning (Yui.tuningFields): Gemini's go into generationConfig, the others into the body.
        if (format === "gemini") {
            if (Object.keys(tuning).length > 0)
                data.generationConfig = tuning;

        } else {
            Object.keys(tuning).forEach(function(key) {
                data[key] = tuning[key];
            });
        }

        http.setRequestHeader("Content-Type", "application/json");
        logRequest(config, data, systemPrompt, messages);
        http.send(JSON.stringify(data));
        return {
            "abort": function() {
                if (retry)
                    return retry.abort();

                if (done)
                    return ;

                if (streamed)
                    finish(streamed, false);
                else
                    finish("结衣停下来了～ (・_・)", true);
                http.abort();
            }
        };
    }

    // Ask the provider which models it offers. onFinished(models, errorText): models is a sorted list
    // of model ids usable for chat, or null on failure.
    function fetchModels(config, onFinished) {
        var format = config.provider.format;
        if (!config.apiKey || !config.endpoint) {
            onFinished(null, "请先填写 API Key 和 Endpoint");
            return ;
        }
        var endpoint = config.endpoint.replace(/\/+$/, "");
        var url;
        if (format === "gemini")
            url = endpoint + "?pageSize=1000";
        else if (format === "anthropic")
            url = endpoint.replace(/\/messages$/, "") + "/models?limit=1000";
        else
            url = endpoint.replace(/\/chat\/completions$/, "") + "/models";
        var http = new XMLHttpRequest();
        var done = false;
        var timer = Qt.createQmlObject("import QtQuick 2.12; Timer { interval: 30000 }", widget);
        var finish = function(models, error) {
            if (done)
                return ;

            done = true;
            timer.stop();
            timer.destroy();
            onFinished(models, error);
        };
        timer.triggered.connect(function() {
            finish(null, "请求超时");
            http.abort();
        });
        timer.start();
        http.onreadystatechange = function() {
            if (http.readyState !== XMLHttpRequest.DONE || done)
                return ;

            try {
                if (http.status !== 200) {
                    finish(null, "HTTP " + http.status + " " + http.statusText + (http.responseText ? ": " + http.responseText : ""));
                    return ;
                }
                var response = JSON.parse(http.responseText);
                var models;
                if (format === "gemini")
                    // Only models that can chat (generateContent); names come as "models/<id>".
                    models = (response.models || []).filter(function(m) {
                    return (m.supportedGenerationMethods || []).indexOf("generateContent") !== -1;
                }).map(function(m) {
                    return String(m.name).replace(/^models\//, "");
                });
                else
                    models = (response.data || []).map(function(m) {
                    return String(m.id);
                });
                // OpenAI-compatible lists also contain embedding, speech, image... models.
                if (format === "openai")
                    models = models.filter(function(id) {
                    return !/embedding|tts|whisper|dall-e|davinci|babbage|moderation|transcribe|realtime|audio|image|sora/i.test(id);
                });

                models.sort();
                models.reverse(); // newer versions usually sort last; show them first
                if (models.length > 0)
                    finish(models, "");
                else
                    finish(null, "服务商没有返回可用的模型");
            } catch (e) {
                finish(null, "解析失败: " + e.message);
            }
        };
        http.open("GET", url);
        if (format === "gemini") {
            http.setRequestHeader("x-goog-api-key", config.apiKey);
        } else if (format === "anthropic") {
            http.setRequestHeader("x-api-key", config.apiKey);
            http.setRequestHeader("anthropic-version", "2023-06-01");
        } else {
            http.setRequestHeader("Authorization", "Bearer " + config.apiKey);
        }
        http.send();
    }

    // Collect the most recent conversation turns, skipping placeholders and error messages.
    function buildHistory() {
        var messages = [];
        for (var i = widget.historyStart; i < chatModel.count; i++) {
            var item = chatModel.get(i);
            if (item.pending || item.isError)
                continue;

            var role = item.author === "user" ? "user" : "assistant";
            // Merge consecutive turns of the same role (e.g. after a failed reply),
            // since Gemini and Claude expect user and assistant turns to alternate.
            if (messages.length > 0 && messages[messages.length - 1].role === role)
                messages[messages.length - 1].content += "\n\n" + item.message;
            else
                messages.push({
                "role": role,
                "content": item.message
            });
        }
        messages = messages.slice(-maxHistory);
        // The conversation must start with a user turn (required by Gemini and Claude).
        while (messages.length > 0 && messages[0].role !== "user")
            messages.shift();
        return messages;
    }

    // isError: kept out of the conversation sent to the API (failed requests and setup hints).
    // local: written by the widget itself (wake lines, System Call, status reports): there is nothing
    // to regenerate, but they stay in the conversation so the next reply follows on from them.
    // Yui's messages written without the AI (wake lines, System Call, reports, setup hints) look like
    // a reply too: "..." first, the text after a random 0.6 - 1.6 s.
    function appendMessage(author, message, isError, local) {
        var fromYui = author !== "user";
        var index = chatModel.count;
        var session = widget.chatSession;
        chatModel.append({
            "author": author,
            "message": fromYui ? "..." : message,
            "pending": fromYui,
            "isError": isError,
            "local": !!local,
            "note": "",
            "action": "",
            "actionState": "",
            "suggestions": ""
        });
        chatView.stickToBottom = true;
        if (!fromYui) {
            scheduleSave();
            logMessage(author, message);
            return ;
        }
        var timer = Qt.createQmlObject("import QtQuick 2.12; Timer {}", widget);
        timer.interval = 600 + Math.round(Math.random() * 1000);
        timer.triggered.connect(function() {
            timer.destroy();
            // The chat was cleared meanwhile.
            if (session !== widget.chatSession || index >= chatModel.count)
                return ;

            chatModel.set(index, {
                "message": message,
                "pending": false
            });
            scheduleSave();
            logMessage(author, message);
        });
        timer.start();
    }

    // Keep the last maxSavedMessages finished messages in settings so the chat survives restarts.
    function saveHistory() {
        var start = Math.max(0, chatModel.count - maxSavedMessages);
        var messages = [];
        for (var i = start; i < chatModel.count; i++) {
            var item = chatModel.get(i);
            if (!item.pending)
                messages.push({
                "author": item.author,
                "message": item.message,
                "isError": item.isError,
                "local": item.local
            });

        }
        widget.settings.chat_history = {
            "messages": messages,
            "history_start": Math.max(0, widget.historyStart - start)
        };
    }

    // Returns false when there is nothing to restore.
    function restoreHistory() {
        var saved = widget.settings.chat_history;
        if (!saved || !saved.messages || saved.messages.length === 0)
            return false;

        for (var i = 0; i < saved.messages.length; i++) {
            var item = saved.messages[i];
            chatModel.append({
                "author": item.author === "user" ? "user" : "ai",
                "message": String(item.message || ""),
                "pending": false,
                "isError": !!item.isError,
                "local": !!item.local,
                "note": "",
                "action": "",
                "actionState": "",
                "suggestions": ""
            });
        }
        widget.historyStart = Math.min(saved.history_start || 0, chatModel.count);
        return true;
    }

    // Show a "..." placeholder and replace it in place once the reply arrives.
    function startReply(messages, notifyTitle) {
        var session = widget.chatSession;
        var test = widget.testStreaming;
        var index = chatModel.count;
        chatModel.append({
            "author": "ai",
            "message": "...",
            "pending": true,
            "isError": false,
            "local": false,
            "note": "",
            "action": "",
            "actionState": "",
            "suggestions": ""
        });
        chatView.stickToBottom = true;
        widget.busy = true;
        widget.currentRequest = requestCompletion(messages, function(text, isError, notConfigured, toolCalls) {
            // The chat was cleared while this request was in flight.
            if (session !== widget.chatSession)
                return ;

            var note = "";
            var action = "";
            if (!isError) {
                // Apply and strip the control tags (expression, memories, navigation), then the tool calls.
                var reply = Yui.parseReply(text, widget.settings.kill_protected, replyOptions());
                applyToolCalls(reply, toolCalls);
                if (reply.unknown.length > 0)
                    diag("tags not understood (hidden): " + reply.unknown.join(" "));

                text = reply.text || silentReplyText(reply);
                // No <<emotion:>>: guessed from the reply's kaomoji and words.
                setEmotion(reply.emotion || Yui.guessEmotion(text));

                note = applyMemoryTags(reply);
                // Bond: today's celebration was asked for in this request, so it is done.
                if (widget.bondPending) {
                    widget.settings.bond_celebrated = widget.bondPending;
                    widget.bondPending = "";
                }
                if (reply.mood && featureEnabled("daily_mood")) {
                    recordMood(reply.mood);
                    note = (note ? note + "\n" : "") + "📝 心情记录：" + reply.mood.score + "/5" + (reply.mood.note ? " " + reply.mood.note : "");
                }
                reply.reminders.forEach(function(reminder) {
                    addReminder(reminder);
                    note = (note ? note + "\n" : "") + "⏰ 已设提醒：" + (reminder.daily ? "每天 " + Qt.formatDateTime(new Date(reminder.due), "HH:mm") : Qt.formatDateTime(new Date(reminder.due), "MM-dd HH:mm")) + " " + reminder.text;
                });
                reply.notes.forEach(function(text) {
                    addQuestNote(text);
                    note = (note ? note + "\n" : "") + "📜 已记下：" + text;
                });
                reply.media.forEach(function(command) {
                    if (runMedia(command))
                        note = (note ? note + "\n" : "") + "🎵 " + Yui.MEDIA_LABELS[command];

                });
                if (reply.skill) {
                    var skillName = askSwordSkill(reply.skill);
                    note = (note ? note + "\n" : "") + (skillName ? "⚔ 剑技：" + skillName : "⚔ 没有叫「" + reply.skill + "」的剑技");
                }
                reply.dones.forEach(function(text) {
                    var finished = finishNote(text);
                    if (finished)
                        note = (note ? note + "\n" : "") + "✅ 已完成：" + finished;

                });
                if (reply.suggestions.length > 0)
                    chatModel.setProperty(index, "suggestions", JSON.stringify(reply.suggestions));

                if (reply.focus !== null) {
                    if (reply.focus === 0)
                        stopRaid();
                    else
                        startRaid(reply.focus > 0 ? reply.focus : raidMinutes, false);
                }
                if (reply.action)
                    action = JSON.stringify(reply.action);

                if (reply.disabled)
                    note = (note ? note + "\n" : "") + "🚫 已在 System Console 中关闭这类代行，没有执行";

                // Said she did something, but nothing was carried out (no tag, or a thing she cannot do).
                if (!reply.action && reply.media.length === 0 && !reply.skill && reply.focus === null && reply.reminders.length === 0 && !reply.disabled && !reply.blocked && Yui.claimsDone(text)) {
                    note = (note ? note + "\n" : "") + "⚠ 结衣说做了，但这次什么都没有执行";
                    diag("claimed an action, none carried out");
                }
                // Promised to remind or wake the user later, with no Alarm to do it.
                if (reply.reminders.length === 0 && !allowedActions().alarm && Yui.promisesReminder(text)) {
                    note = (note ? note + "\n" : "") + "⚠ 结衣现在没有提醒功能，到时候不会提醒你";
                    diag("promised a reminder, none set");
                }

                if (reply.blocked) {
                    note = (note ? note + "\n" : "") + "🛡 已拦截：" + reply.blocked + " 是受保护的系统进程，不能关闭";
                    Qt.callLater(showImmortalObject, reply.blocked);
                }

            }
            chatModel.set(index, {
                "message": text,
                "pending": false,
                "local": test,
                "isError": isError,
                "note": note,
                "action": action,
                "actionState": action ? "pending" : ""
            });
            // Nothing written so far reached the API; start the conversation history after it.
            if (notConfigured)
                widget.historyStart = chatModel.count;

            widget.busy = false;
            widget.currentRequest = null;
            scheduleSave();
            if (!isError && !test) {
                logMessage("ai", text);
                announce(notifyTitle, text);
            }

            if (action)
                Qt.callLater(confirmAction, index);

        }, null, function(partial) {
            if (session !== widget.chatSession)
                return ;

            // A streamed reply pops up with its first text (pending false); later chunks only update it.
            var shown = Yui.displayText(partial);
            if (shown)
                chatModel.set(index, {
                    "message": shown,
                    "pending": false
                });

        });
        // The request may have finished synchronously (e.g. API not configured).
        if (!widget.busy)
            widget.currentRequest = null;

    }

    // Stop the reply being generated; the text received so far is kept.
    function stopReply() {
        if (widget.currentRequest)
            widget.currentRequest.abort();

    }

    // Drop the last reply and ask again.
    function regenerateReply() {
        if (widget.busy || chatModel.count === 0 || chatModel.get(chatModel.count - 1).author === "user")
            return ;

        chatModel.remove(chatModel.count - 1);
        widget.historyStart = Math.min(widget.historyStart, chatModel.count);
        scheduleSave();
        var history = buildHistory();
        regenerating = true;
        // Only the greeting was there: greet again.
        if (history.length === 0)
            getInitialMessage();
        else
            startReply(history);
    }

    function getInitialMessage() {
        if (!activeConfig().apiKey) {
            appendMessage("ai", userTitle() + "，欢迎回来！(≧◡≦) 不过……结衣还连接不上网络呢 (>_<)\n请右键点击结衣，打开「Cardinal System」，选好 Seed Server 并填上 Access Key，结衣就能和你说话啦！", true);
            return ;
        }
        startReply([{
            "role": "user",
            "content": "（系统提示：" + userTitle() + "刚刚打开电脑，结衣启动了。请以结衣的身份，用一两句话向" + userTitle() + "打招呼，可以结合现在的时间。）"
        }]);
    }

    // Let Yui speak on her own (greetings, care): the instruction is sent as a hidden user turn
    // after the recent conversation. Returns false when she cannot speak right now.
    // notifyTitle: a title for the reply (care reminders); like every reply while the chat is closed, it
    // is shown in the bubble next to Yui (see announce()).
    function yuiSpeaks(instruction, notifyTitle) {
        if (widget.busy || !activeConfig().apiKey)
            return false;

        var messages = buildHistory();
        if (messages.length > 0 && messages[messages.length - 1].role === "user")
            messages[messages.length - 1].content += "\n\n" + instruction;
        else
            messages.push({
            "role": "user",
            "content": instruction
        });
        lastProactive = Date.now();
        startReply(messages, notifyTitle);
        return true;
    }

    // On startup with a saved conversation (Login Greeting): good morning on the first morning of a day,
    // "long time no see" after days away, else a welcome back after a while (Yui.greetingKind).
    function welcomeBack() {
        var lastActive = widget.settings.last_active || 0;
        var now = Date.now();
        var kind = Yui.greetingKind(lastActive, now);
        if (!featureEnabled("greet_on_start") || kind === "")
            return ;

        var title = userTitle();
        var away = Yui.formatDuration(now - lastActive);
        var how = {
            "long": "已经 " + away + " 没见了。请以结衣的身份说一句「好久不见」，表达想念和开心，可以问问" + title + "这些天过得怎么样。",
            "morning": "今天是第一次见面，现在是早上 " + Qt.formatTime(new Date(now), "HH:mm") + "。请以结衣的身份向" + title + "说早安，可以关心一下睡得好不好、今天的安排。" + (weatherLine() ? "今天的天气是：" + weatherLine() + "，顺带提一句，会下雨的话提醒带伞。" : ""),
            "back": "距离上次聊天已经过了 " + away + "。请以结衣的身份欢迎" + title + "回来，可以结合现在的时间和之前聊过的内容。"
        }[kind];
        diag("login greeting: " + kind);
        yuiSpeaks("（系统提示：" + title + "回来了，" + how + "一两句话即可，不要提起这条提示。）");
    }

    function sendMessage(text) {
        if (!text.trim() || widget.busy)
            return false;

        noteActivity();
        sleeping = false;
        // "System Call, ..." easter egg: answered locally, then part of the conversation like any turn.
        var call = Yui.systemCall(text, userTitle(), {
            "cpu": readData(cpuLoad),
            "gpu": readData(gpuLoad),
            "ram": readData(ramUsage)
        });
        if (call) {
            appendMessage("user", text, false, true);
            afterUserMessage(function() {
                appendMessage("ai", call.reply, false, true);
                if (call.effect) {
                    elementEffect.play(call.effect.color, call.effect.burst);
                    if (call.effect.aura)
                        auraAnimation.restart();

                    if (call.effect.shake)
                        shakeAnimation.restart();

                }

                setEmotion(call.effect ? "surprised" : "normal");
            });
            return true;
        }
        widget.settings.last_active = Date.now();
        appendMessage("user", text, false);
        var history = buildHistory();
        afterUserMessage(function() {
            startReply(history);
        });
        return true;
    }

    // Runs next once the user's message has finished popping up (MessageWindow.popUp, 650 ms), so
    // Yui's "..." only appears after it. Yui counts as busy meanwhile (no second message).
    function afterUserMessage(next) {
        var session = widget.chatSession;
        widget.busy = true;
        var timer = Qt.createQmlObject("import QtQuick 2.12; Timer { interval: 700 }", widget);
        timer.triggered.connect(function() {
            timer.destroy();
            widget.busy = false;
            // The chat was cleared meanwhile.
            if (session === widget.chatSession)
                next();

        });
        timer.start();
    }

    // Show an expression for a while, then return to the normal one.
    function setEmotion(emotion) {
        currentEmotion = emotion;
        emotionTimer.restart();
    }

    // Ask before opening the link / search the AI offered, in SAO Utils' system message box.
    // A modal messageBox shows OK / Cancel and returns a Promise; this is how NERvGear itself asks
    // "Are you sure to execute this action?" before actions. Falls back to a plain dialog.
    function confirmAction(index) {
        var action = JSON.parse(chatModel.get(index).action);
        var questions = {
            "open": qsTr("Yui will open this page:"),
            "search": qsTr("Yui will search for:"),
            "launch": qsTr("Yui will start this program:"),
            "find": qsTr("Yui will search your computer for:"),
            "kill": qsTr("Yui will close this program:")
        };
        // Programs on the whitelist are closed without asking.
        if (action.type === "kill" && Yui.processListHas(widget.settings.kill_whitelist, action.target)) {
            diag("confirm: kill \"" + action.target + "\" is on the whitelist, closing without asking");
            runAction(index);
            return ;
        }
        var question = (questions[action.type] || "") + "\n" + action.target;
        diag("confirm: " + action.type + " \"" + action.target + "\" -> messageBox");
        try {
            // Closing a program is titled "Alert": SAO Utils then plays the system alert sound.
            var answer = NVG.SystemCall.messageBox({
                "title": action.type === "kill" ? "Alert" : qsTr("Navigation"),
                "text": question,
                "modal": true
            });
            if (answer && typeof answer.then === "function") {
                // OK resolves; Cancel may reject or resolve with a false / Rejected (0) result.
                answer.then(function(result) {
                    diag("messageBox resolved, result=" + JSON.stringify(result));
                    if (result === false || result === 0)
                        cancelAction(index);
                    else
                        runAction(index);
                }, function(reason) {
                    diag("messageBox rejected (" + reason + ")");
                    cancelAction(index);
                });
                return ;
            }
            diag("messageBox returned no Promise (" + answer + "), using the fallback dialog");
        } catch (e) {
            diag("messageBox failed: " + e + ", using the fallback dialog");
        }
        actionDialog.messageIndex = index;
        actionDialog.text = question;
        actionDialog.open();
    }

    // Asks with SAO Utils' message box before a settings window is reset; onYes runs after OK. Without
    // the message box (no Promise), it resets right away.
    function confirmReset(windowTitle, onYes) {
        askConfirm(qsTr("Warning"), qsTr("Restore all settings of %1 to their defaults?").arg(windowTitle), onYes);
    }

    // SAO Utils' message box with OK / Cancel; onYes runs after OK, onNo after Cancel. Without a
    // message box a plain question goes ahead, an alert (deleting something) does not. alert (confirmations that delete something): titled "Alert", for which SAO
    // Utils plays the system alert sound instead of the message sound (as when asking to exit).
    function askConfirm(title, text, onYes, alert, onNo) {
        try {
            var answer = NVG.SystemCall.messageBox({
                "title": alert ? "Alert" : title,
                "text": text,
                "modal": true
            });
            if (answer && typeof answer.then === "function") {
                answer.then(function(result) {
                    if (result !== false && result !== 0)
                        onYes();
                    else if (onNo)
                        onNo();
                }, function() {
                    if (onNo)
                        onNo();

                });
                return ;
            }
        } catch (e) {
            diag("confirm: messageBox failed: " + e);
        }
        // Without an answer nothing that deletes is done; a plain question goes ahead.
        if (alert) {
            diag("confirm: no message box, \"" + text + "\" not done");
            if (onNo)
                onNo();

        } else {
            onYes();
        }
    }

    // Requests in the System Console log: a summary line always, the full body (system prompt and
    // messages; the access key is only in a header and never logged) and the raw reply with its tags
    // while "Log Requests" is on.
    readonly property bool logRequests: widget.settings.log_requests !== false

    // The body is shown as readable text: the parameters, then the system prompt and every message
    // with their line breaks (the system prompt is the personality followed by the feature
    // instructions, heart core, time and recalled memories).
    function logRequest(config, data, systemPrompt, messages) {
        diag("→ request: " + config.provider.title + " · " + (config.model || "?") + " · " + messages.length + " messages · " + config.endpoint);
        if (!logRequests)
            return ;

        var params = {};
        for (var key in data)
            if (["messages", "contents", "system", "systemInstruction", "tools"].indexOf(key) === -1)
                params[key] = data[key];

        if (data.tools)
            params.tools = data.tools.map(function(tool) {
                return (tool["function"] || tool).name;
            }).join(", ");

        var parts = ["→ body " + JSON.stringify(params), "━━━━ system (" + systemPrompt.length + " chars) ━━━━", systemPrompt];
        messages.forEach(function(message) {
            parts.push("━━━━ " + message.role + " ━━━━", message.content);
        });
        diag(parts.join("\n"));
    }

    function logReply(config, text, isError, ms, toolCalls) {
        var head = (isError ? "✕ error" : "← reply") + " after " + (ms / 1000).toFixed(1) + " s, " + String(text || "").length + " chars";
        var calls = (toolCalls || []).filter(function(call) {
            return call && call.name;
        }).map(function(call) {
            return "⚙ " + call.name + "(" + call.arguments + ")";
        });
        if (calls.length > 0)
            head += ", " + calls.length + " tool call(s)";

        diag(logRequests || isError ? head + ":\n" + [text].concat(calls).join("\n") : head);
    }

    // Applies the tool calls of a reply to it, as its tags would be (Yui.parseReply's result): memories
    // and forgets, the first desktop action (one at a time), a refused protected process. Every call
    // and what became of it is logged.
    // A reply that only called tools (no text of its own): a line that fits what is done with it.
    function silentReplyText(reply) {
        if (reply.blocked)
            return "这个是系统的重要程序，结衣不能关掉哦 (>_<)";

        if (reply.action || reply.media.length > 0)
            return "好的，结衣来帮你～ (｡･ω･｡)";

        if (reply.cores.length + reply.memories.length + reply.forgets.length > 0)
            return "嗯嗯，结衣记住啦～ (✿^‿^)";

        return "(・ω・)";
    }

    function applyToolCalls(reply, toolCalls) {
        (toolCalls || []).forEach(function(call) {
            var made = Yui.toolCallToAction(call.name, call.arguments, widget.settings.kill_protected, replyOptions());
            var outcome = made.kind;
            if (made.kind === "remember") {
                (made.core ? reply.cores : reply.memories).push(made.text);
            } else if (made.kind === "forget") {
                reply.forgets.push(made.text);
            } else if (made.kind === "media") {
                reply.media.push(made.command);
            } else if (made.kind === "blocked") {
                reply.blocked = made.blocked;
            } else if (made.kind === "action") {
                if (reply.action)
                    outcome = "not done: one action at a time";
                else
                    reply.action = made.action;
            } else {
                outcome = "error: " + made.error;
            }
            diag("⚙ " + call.name + " → " + outcome);
        });
    }

    function diag(message) {
        var line = Qt.formatTime(new Date(), "hh:mm:ss.zzz") + "  " + message;
        console.log("[diag]", message);
        diagLog = diagLog.concat([line]).slice(-200);
    }

    // Diagnostics (System Console, SystemConsole.qml): run a desktop action without the AI, through the same
    // message, confirmation box and execution as a real one. A protected <<kill:>> shows the
    // "blocked" note instead of asking.
    // System Console: the Link Start effect again.
    function testLinkStart() {
        diag("test link start");
        linkStartAnimation.restart();
    }

    function testAction(tag) {
        diag("test " + tag);
        var reply = Yui.parseReply("[" + qsTr("Test") + "] " + tag, widget.settings.kill_protected, replyOptions());
        var index = chatModel.count;
        chatModel.append({
            "author": "ai",
            "message": reply.text,
            "pending": false,
            "isError": true,
            "local": true,
            "note": reply.disabled ? "🚫 已在 System Console 中关闭这类代行，没有执行" : reply.blocked ? "🛡 已拦截：" + reply.blocked + " 是受保护的系统进程，不能关闭" : "",
            "action": reply.action ? JSON.stringify(reply.action) : "",
            "actionState": reply.action ? "pending" : "",
            "suggestions": ""
        });
        chatView.stickToBottom = true;
        if (reply.action)
            Qt.callLater(confirmAction, index);
        else if (reply.blocked)
            Qt.callLater(showImmortalObject, reply.blocked);

    }

    // A refused <<kill:>> of a protected process: SAO Utils' own "Immortal Object" warning (rebuilt in
    // ImmortalObject.qml) with the "system forbidden" sound. Should that window fail to load, the bubble
    // says the same (while the chat is closed; it is in the chat anyway).
    property var immortalObjectView: null

    function showImmortalObject(name) {
        diag("blocked: " + name + " is protected (no confirmation)");
        NVG.SystemCall.playSound(NVG.SFX.NotifyWarning);
        if (!immortalObjectView) {
            var component = Qt.createComponent("ImmortalObject.qml");
            if (component.status === Component.Ready)
                immortalObjectView = component.createObject(widget);
            else
                diag("Immortal Object window failed to load: " + component.errorString());
        }
        if (immortalObjectView)
            immortalObjectView.popup();
        else
            announce("", qsTr("%1 is a protected system process. Yui cannot close it.").arg(name));
    }

    function cancelAction(index) {
        diag("cancelled");
        chatModel.setProperty(index, "actionState", "cancelled");
    }

    // Open the link / search the AI offered, after the user confirmed it.
    function runAction(index) {
        var item = chatModel.get(index);
        try {
            var action = JSON.parse(item.action);
            if (action.type === "open" || action.type === "search") {
                var opened = /^https?:\/\//i.test(action.url) && openLink(action.url);
                diag("openLink(" + action.url + ") -> " + (opened ? "ok" : "failed, system browser used"));
                if (!opened)
                    addNote(index, "⚠ 内置浏览器打开失败，已改用系统浏览器");

            } else if (action.type === "launch") {
                var launched = NVG.SystemCall.execute(action.target);
                diag("execute(\"" + action.target + "\") -> " + launched);
                if (!launched)
                    addNote(index, "⚠ 无法启动：" + action.target);

            } else if (action.type === "kill") {
                var killCommand = Yui.actionCommand(action);
                // The return value of command() is not reliable (false although the command ran),
                // so it is only logged.
                var killed = NVG.SystemCall.command(killCommand);
                diag("command(" + killCommand + ") -> " + killed + " (not used)");
                askWhitelist(action.target);

            } else if (action.type === "find") {
                runFind(action);
            }
        } catch (e) {
            diag("action failed: " + e);
        }
        chatModel.setProperty(index, "actionState", "done");
    }

    // After the first confirmed close of a program, ask once whether Yui may close it without asking
    // from now on: OK adds it to the whitelist; Cancel is remembered, so only the close itself is
    // confirmed next time. Both lists can be edited in the System Console.
    // Bumped when Yui changes a setting shown in the System Console (whitelist, es.exe path), so the
    // window shows it at once.
    property int settingsRevision: 0

    function askWhitelist(name) {
        if (Yui.processListHas(widget.settings.kill_whitelist, name) || Yui.processListHas(widget.settings.kill_asked, name))
            return ;

        diag("whitelist: asking about " + name);
        var remember = function(added) {
            var key = added ? "kill_whitelist" : "kill_asked";
            widget.settings[key] = Yui.processList((widget.settings[key] || []).concat([name]));
            widget.settingsRevision++;
            diag("whitelist: " + name + (added ? " added" : " not added (will not ask again)"));
        };
        try {
            NVG.SystemCall.messageBox({
                "title": qsTr("Whitelist"),
                "text": qsTr("Close %1 without asking from now on?\nYou can change this in System Console.").arg(name),
                "modal": true
            }).then(function(result) {
                remember(!(result === false || result === 0));
            }, function() {
                remember(false);
            });
        } catch (e) {
            diag("whitelist: messageBox failed: " + e);
        }
    }

    function addNote(index, note) {
        var item = chatModel.get(index);
        chatModel.setProperty(index, "note", (item.note ? item.note + "\n" : "") + note);
    }

    // Label of a link / search / desktop action under a bubble.
    function actionLabel(action) {
        var prefixes = {
            "open": "🧭 打开：",
            "search": "🔍 搜索：",
            "launch": "🚀 启动：",
            "find": "🗂 查找：",
            "kill": "⛔ 结束："
        };
        return action ? (prefixes[action.type] || "") + action.target : "";
    }

    // <<find:>>: the package's scripts/find.bat runs Everything's es.exe (the Option path, or one it
    // finds in PATH / the usual install folders), which writes up to 20 matching paths to a result
    // file; the script then writes a status file with es.exe's exit code. Both files live in the
    // package folder (SAO Utils lets a package read and write its own files) under a new name each
    // time; the script deletes the earlier ones. Once the status file appears, Yui reports.
    function runFind(action) {
        var stamp = Date.now();
        var resultUrl = Qt.resolvedUrl("../find-" + stamp + ".txt");
        var statusUrl = Qt.resolvedUrl("../find-" + stamp + ".status");
        var localFile = function(url) {
            return String(NVG.Url.toLocalFile(url)).replace(/\//g, "\\");
        };
        var esSetting = String(widget.settings.es_path || "").replace(/"/g, "").trim();
        diag("es.exe path setting: " + (esSetting ? "\"" + esSetting + "\"" : "(empty, find.bat looks in PATH and the usual install folders)"));
        var command = Yui.actionCommand(action, localFile(resultUrl), esSetting, localFile(statusUrl), localFile(Qt.resolvedUrl("../scripts/find.bat")));
        // command() has been seen to return false although the command ran, so its return value is
        // only logged; what happened is read from the status file.
        var started = NVG.SystemCall.command(command);
        diag("command(" + command + ") -> " + started + " (not used, waiting for the status file)");
        var tries = 0;
        var timer = Qt.createQmlObject("import QtQuick 2.12; Timer { interval: 500; repeat: true }", widget);
        timer.triggered.connect(function() {
            tries++;
            var status = Yui.parseFindStatus(readUrl(statusUrl));
            if (!status && tries < 20)
                return ;

            timer.stop();
            timer.destroy();
            reportFind(action, status, Yui.parseSearchResults(status ? readUrl(resultUrl) : ""), esSetting);
        });
        timer.start();
    }

    // Yui's message for a finished <<find:>>; a found es.exe is saved to the Option setting.
    function reportFind(action, status, results, esSetting) {
        diag("find status: " + JSON.stringify(status) + ", " + results.length + " results");
        var download = "https://www.voidtools.com/downloads/";
        var found = "";
        if (status && status.es && !esSetting && status.code !== "missing") {
            widget.settings.es_path = status.es;
            widget.settingsRevision++;
            found = "\n（结衣自动找到了 es.exe：" + status.es + "，已经帮你填进「System Console」啦）";
            diag("es.exe found and saved: " + status.es);
        }
        var text;
        if (!status)
            text = "数据检索失败……检索程序没有启动 (T_T)\n请打开「System Console」看看日志，或者把日志发给开发者哦。";
        else if (status.code === "missing")
            text = (esSetting ? "数据检索失败……「System Console」里填写的 es.exe 不存在：" + esSetting + "\n请确认路径是否正确哦。" : "数据检索失败……结衣找不到 Everything 的命令行工具 es.exe (T_T)\n请在「System Console」里填写 es.exe 的完整路径，或者把它加入系统 PATH。") + "\n还没有安装的话，可以从这里下载 Everything 和 ES 命令行工具：\n" + download;
        else if (status.code === "8")
            text = "数据检索失败……Everything 好像没有在运行 (T_T)\n请先启动 Everything，再让结衣查找一次吧！";
        else if (status.code !== "0")
            text = "数据检索失败……es.exe 返回了错误代码 " + status.code + " (T_T)";
        else if (results.length > 0)
            text = "检索完成！结衣找到了 " + results.length + " 个和「" + action.target + "」有关的结果：\n" + results.join("\n");
        else
            text = "检索完成……但是没有找到和「" + action.target + "」有关的文件呢。换个关键词试试？";
        appendMessage("ai", text + found, false, true);
    }

    // A link clicked in a chat message (see Yui.linkify): a path opens File Explorer, 「System Console」 opens
    // the System Console, a web link opens in the browser.
    function openMessageLink(link) {
        diag("link clicked: " + link);
        if (link.indexOf("yui-path:") === 0)
            showInExplorer(Yui.linkedPath(link));
        else if (link === "yui-option:")
            showDialog(widget.systemConsoleDialog, "systemConsoleDialogInstance");
        else if (/^https?:\/\//i.test(link))
            openLink(link);
    }

    // Contents of a package file ("" when missing). A changing query is added so a cached earlier
    // read (made before es.exe wrote the file) is never returned again. Each read is logged.
    function readUrl(url) {
        var target = url + "?t=" + Date.now();
        try {
            var request = new XMLHttpRequest();
            request.open("GET", target, false);
            request.send(null);
            var text = request.responseText || "";
            diag("GET " + target + " -> status " + request.status + ", " + text.length + " chars");
            return text;
        } catch (e) {
            diag("GET " + target + " failed: " + e);
            return "";
        }
    }

    // Opens File Explorer at a path from a chat message, with the file (or folder) selected.
    function showInExplorer(path) {
        if (!path)
            return ;

        var started = NVG.SystemCall.execute("explorer.exe", "/select,\"" + path + "\"");
        diag("execute(explorer.exe /select,\"" + path + "\") -> " + started);
    }

    // SAO Utils' built-in browser by default; the system browser when "External Browser" is on
    // (same choice and calls as SAO Utils' own web widgets). When the built-in browser fails, the
    // system browser is used instead and false is returned.
    function openLink(url) {
        if (widget.settings.external_browser === true) {
            Qt.openUrlExternally(url);
            return true;
        }
        try {
            if (NVG.SystemCall.openLink(url) === false)
                throw new Error("openLink returned false");

            return true;
        } catch (e) {
            console.log("built-in browser failed, using the system browser:", e);
            Qt.openUrlExternally(url);
            return false;
        }
    }

    // Periodic checks (every 30 s): falling asleep, system status reports and proactive care.
    function tick() {
        if (seedlingMode)
            return ;

        var now = Date.now();
        var sleepMinutes = widget.settings.sleep_minutes !== undefined ? widget.settings.sleep_minutes : 20;
        if (!sleeping && sleepMinutes > 0 && !widget.busy && now - lastActivity > sleepMinutes * 60000)
            sleeping = true;

        checkSystemStatus(now);
        checkCare(now);
        checkIdleChat(now);
    }

    // ---------------------------------------------------------------- Yui's Heart (SQLite)
    // Tables:
    //   memories(id, text, kind, created, updated, last_used, uses, pinned)  Yui's Heart (see yui.js)
    //   messages(id, author, message, created)  every finished chat message (complete history, never sent)
    function openDatabase() {
        try {
            database = LocalStorage.openDatabaseSync("MHCP001-Yui", "1.0", "MHCP001 Yui's Heart", 5000000);
            database.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS memories(id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, created INTEGER)");
                tx.executeSql("CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY AUTOINCREMENT, author TEXT, message TEXT, created INTEGER)");
            // Mental Record: one mood a day (day "yyyy-MM-dd", score 1–5).
            tx.executeSql("CREATE TABLE IF NOT EXISTS moods(day TEXT PRIMARY KEY, score INTEGER, note TEXT, created INTEGER)");
            // Skill Slots: Alarm reminders (due in ms; daily ones move on a day when they ring) and
            // Quest Log notes.
            tx.executeSql("CREATE TABLE IF NOT EXISTS reminders(id INTEGER PRIMARY KEY AUTOINCREMENT, due REAL, text TEXT, daily INTEGER, created INTEGER)");
            // Weekly Report (Mental Health Counseling): what Yui wrote, by the week's first day.
            tx.executeSql("CREATE TABLE IF NOT EXISTS reports(id INTEGER PRIMARY KEY AUTOINCREMENT, week TEXT, text TEXT, created INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS notes(id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT, done INTEGER NOT NULL DEFAULT 0, created INTEGER, updated INTEGER)");
            });
            // Columns added with the heart core (1.1): every older memory was sent with every request,
            // so the oldest MAX_CORE become the core and the rest fragments.
            // (PRAGMA is not allowed in a read-only transaction.)
            var columns = [];
            database.transaction(function(tx) {
                var rows = tx.executeSql("PRAGMA table_info(memories)").rows;
                for (var i = 0; i < rows.length; i++)
                    columns.push(rows.item(i).name);
            });
            if (columns.indexOf("kind") === -1)
                database.transaction(function(tx) {
                tx.executeSql("ALTER TABLE memories ADD COLUMN kind TEXT NOT NULL DEFAULT 'fragment'");
                tx.executeSql("ALTER TABLE memories ADD COLUMN updated INTEGER");
                tx.executeSql("ALTER TABLE memories ADD COLUMN last_used INTEGER");
                tx.executeSql("ALTER TABLE memories ADD COLUMN uses INTEGER NOT NULL DEFAULT 0");
                tx.executeSql("ALTER TABLE memories ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0");
                tx.executeSql("UPDATE memories SET updated = created, last_used = created");
                tx.executeSql("UPDATE memories SET kind = 'core' WHERE id IN (SELECT id FROM memories ORDER BY id LIMIT ?)", [Yui.MAX_CORE]);
            });

            // First start with the database: move the memories kept in settings (1.0.0) into it.
            // settings.yui_heart is left in place as a backup.
            var count = 0;
            database.readTransaction(function(tx) {
                count = tx.executeSql("SELECT COUNT(*) AS n FROM memories").rows.item(0).n;
            });
            if (count === 0 && (widget.settings.yui_heart || []).length > 0 && !widget.settings.heart_migrated)
                setHeartEntries(widget.settings.yui_heart);

            widget.settings.heart_migrated = true;
            loadHeart();
        } catch (e) {
            console.log("Yui's Heart database unavailable, using settings:", e);
            database = null;
            heartCache = Yui.copyEntries(widget.settings.yui_heart_entries || []);
        }
    }

    function loadHeart() {
        var entries = [];
        database.readTransaction(function(tx) {
            var rows = tx.executeSql("SELECT * FROM memories ORDER BY id").rows;
            for (var i = 0; i < rows.length; i++) {
                var row = rows.item(i);
                entries.push({
                    "id": row.id,
                    "text": row.text,
                    "kind": row.kind,
                    "created": row.created,
                    "updated": row.updated,
                    "lastUsed": row.last_used,
                    "uses": row.uses,
                    "pinned": !!row.pinned
                });
            }
        });
        heartCache = entries;
    }

    // Store a changed Yui's Heart: entries without an id are added, changed ones updated, missing
    // ones deleted. Without the database the entries are kept in settings.
    function saveHeart(entries) {
        if (!database) {
            widget.settings.yui_heart_entries = Yui.copyEntries(entries);
            heartCache = Yui.copyEntries(entries);
            return ;
        }
        var kept = {};
        var before = {};
        entries.forEach(function(entry) {
            if (entry.id)
                kept[entry.id] = true;

        });
        heartCache.forEach(function(entry) {
            before[entry.id] = JSON.stringify(entry);
        });
        database.transaction(function(tx) {
            heartCache.forEach(function(old) {
                if (!kept[old.id])
                    tx.executeSql("DELETE FROM memories WHERE id = ?", [old.id]);

            });
            entries.forEach(function(entry) {
                var values = [entry.text, entry.kind, entry.created || Date.now(), entry.updated || entry.created || Date.now(), entry.lastUsed || entry.created || Date.now(), entry.uses || 0, entry.pinned ? 1 : 0];
                if (entry.id && before[entry.id] === JSON.stringify(entry))
                    return ;

                if (entry.id)
                    tx.executeSql("UPDATE memories SET text = ?, kind = ?, created = ?, updated = ?, last_used = ?, uses = ?, pinned = ? WHERE id = ?", values.concat([entry.id]));
                else
                    tx.executeSql("INSERT INTO memories(text, kind, created, updated, last_used, uses, pinned) VALUES(?, ?, ?, ?, ?, ?, ?)", values);
            });
        });
        loadHeart();
    }

    // Yui's Heart texts, core first (Cardinal System editor).
    function heartEntries() {
        return Yui.coreMemories(heartCache).concat(heartCache.filter(function(entry) {
            return entry.kind !== "core";
        })).map(function(entry) {
            return entry.text;
        });
    }

    // Replace all memories by these texts (Cardinal System editor): texts already remembered keep
    // their kind and history, new ones are added as fragments.
    function setHeartEntries(texts) {
        var entries = [];
        texts.forEach(function(text) {
            text = String(text).trim();
            if (!text)
                return ;

            var old = heartCache.filter(function(entry) {
                return entry.text === text;
            })[0];
            entries.push(old ? Yui.copyEntries([old])[0] : {
                "id": null,
                "text": text,
                "kind": "fragment",
                "created": Date.now(),
                "uses": 0,
                "pinned": false
            });
        });
        saveHeart(entries);
    }

    // Edits from the Yui's Heart page (YuisHeartPage.qml) on the memory with this id. changes may set
    // text, kind ("core" / "fragment") and pinned. Returns false when it would overfill the core.
    function changeMemory(id, changes) {
        var entries = Yui.copyEntries(heartCache);
        var entry = entries.filter(function(e) {
            return e.id === id;
        })[0];
        if (!entry)
            return false;

        if (changes.kind === "core" && entry.kind !== "core" && Yui.coreMemories(entries).length >= heartCoreCapacity)
            return false;

        if (changes.text !== undefined) {
            var text = String(changes.text).trim();
            if (!text)
                return false;

            entry.text = text;
            entry.updated = Date.now();
        }
        if (changes.kind !== undefined)
            entry.kind = changes.kind;

        if (changes.pinned !== undefined)
            entry.pinned = !!changes.pinned;

        // Only core entries can be pinned.
        if (entry.kind !== "core")
            entry.pinned = false;

        diag("memory " + id + " changed: " + JSON.stringify(changes));
        saveHeart(entries);
        return true;
    }

    // A memory added on the Yui's Heart page (kind "core" or "fragment"). Returns false when the text
    // is empty or the core is full.
    function addMemory(text, kind) {
        text = String(text || "").trim();
        if (!text || (kind === "core" && Yui.coreMemories(heartCache).length >= heartCoreCapacity))
            return false;

        diag("memory added (" + kind + ")");
        saveHeart(Yui.rememberMemory(heartCache, text, kind, Date.now(), heartCoreCapacity));
        return true;
    }

    // Recollection log (the messages table): how many messages it keeps, and clearing it.
    function messageLogCount() {
        var count = 0;
        if (!database)
            return 0;

        try {
            database.readTransaction(function(tx) {
                count = tx.executeSql("SELECT COUNT(*) AS n FROM messages").rows.item(0).n;
            });
        } catch (e) {
            diag("log count failed: " + e);
        }
        return count;
    }

    // The recollection log's messages containing query (all of them when empty), newest first, at most
    // limit (0: no limit): [{author, message, created}].
    function searchMessageLog(query, limit) {
        var found = [];
        if (!database)
            return found;

        try {
            database.readTransaction(function(tx) {
                var sql = "SELECT author, message, created FROM messages" + (query ? " WHERE message LIKE ? ESCAPE '\\'" : "") + " ORDER BY created DESC" + (limit > 0 ? " LIMIT " + Math.floor(limit) : "");
                var rows = tx.executeSql(sql, query ? ["%" + String(query).replace(/[\\%_]/g, "\\$&") + "%"] : []).rows;
                for (var i = 0; i < rows.length; i++)
                    found.push(rows.item(i));
            });
        } catch (e) {
            diag("log search failed: " + e);
        }
        return found;
    }

    // Yui's Heart "Export Log": the whole recollection log as text (oldest first), 回忆日志-<date>.txt in
    // the heart folder, shown in File Explorer. onDone(path): the path written, or "".
    function exportMessageLog(onDone) {
        var title = userTitle();
        var text = searchMessageLog("", 0).reverse().map(function(row) {
            return Yui.logLine(row, title);
        }).join("\r\n");
        writeHeartFile("回忆日志-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".txt", text, function(path) {
            diag("log export -> " + (path || "failed"));
            if (path)
                showInExplorer(path);

            onDone(path);
        });
    }

    // Quest Log (Skill Slots): the notes as a text file next to the log exports ([ ] open, [x] done).
    function exportNotes(onDone) {
        var text = notesList(true).map(function(note) {
            return (note.done ? "[x] " : "[ ] ") + note.text;
        }).join("
");
        writeHeartFile("Quest-Log-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".txt", text, function(path) {
            diag("notes export -> " + (path || "failed"));
            if (path)
                showInExplorer(path);

            onDone(path);
        });
    }

    function clearMessageLog() {
        if (!database)
            return ;

        try {
            database.transaction(function(tx) {
                tx.executeSql("DELETE FROM messages");
            });
            diag("recollection log cleared");
        } catch (e) {
            diag("clearing the log failed: " + e);
        }
    }

    // "Forget Everything": writes a backup of all memories first, then deletes them; nothing is
    // deleted when the backup cannot be written. onDone(message for the user).
    function forgetEverything(onDone) {
        var name = "结衣之心-forgotten-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".json";
        writeHeartFile(name, heartDocument(false), function(path) {
            if (!path) {
                onDone(qsTr("The backup could not be written, so nothing was deleted. See the log in System Console."));
                return ;
            }
            diag("forgot everything, backup " + path);
            saveHeart([]);
            onDone(qsTr("All memories were deleted. Backup: %1").arg(path));
        });
    }

    // The folder of the backups and exports.
    function openHeartFolder() {
        var folder = widget.settings.heart_backup_path ? String(widget.settings.heart_backup_path).replace(/\\[^\\]*$/, "") : heartFolders()[0].replace(/\//g, "\\");
        var started = NVG.SystemCall.execute("explorer.exe", "\"" + folder + "\"");
        diag("execute(explorer.exe \"" + folder + "\") -> " + started);
    }

    function deleteMemory(id) {
        diag("memory " + id + " deleted");
        saveHeart(heartCache.filter(function(entry) {
            return entry.id !== id;
        }));
    }

    // Apply the memory tags of a reply (<<core:>>, <<memory:>>, <<forget:>>); returns the note shown
    // under the bubble ("" when there were none).
    function applyMemoryTags(reply) {
        if (reply.cores.length + reply.memories.length + reply.forgets.length === 0)
            return "";

        var entries = heartCache;
        var forgotten = [];
        reply.forgets.forEach(function(text) {
            var result = Yui.forgetMemory(entries, text);
            entries = result.entries;
            forgotten = forgotten.concat(result.removed.map(function(entry) {
                return entry.text;
            }));
        });
        var now = Date.now();
        // Relative days become dates, and a bare date or time is not kept (Yui.datedMemory).
        var dated = function(texts) {
            return texts.map(function(text) {
                return Yui.datedMemory(text, now);
            }).filter(function(text) {
                return text !== "";
            });
        };
        reply.cores = dated(reply.cores);
        reply.memories = dated(reply.memories);
        reply.cores.forEach(function(text) {
            entries = Yui.rememberMemory(entries, text, "core", now, heartCoreCapacity);
        });
        reply.memories.forEach(function(text) {
            entries = Yui.rememberMemory(entries, text, "fragment", now, heartCoreCapacity);
        });
        saveHeart(entries);
        var notes = [];
        if (reply.cores.length > 0)
            notes.push("💗 结衣之心·心核：" + reply.cores.join("；"));

        if (reply.memories.length > 0)
            notes.push("💗 结衣之心：" + reply.memories.join("；"));

        if (forgotten.length > 0)
            notes.push("💭 已忘记：" + forgotten.join("；"));

        return notes.join("\n");
    }

    // Memory fragments recalled for a message; their use is recorded (recently used ones win ties
    // and are the last to leave the core).
    // How many fragments are recalled per request (Yui's Heart window; 0 = none).
    readonly property int recallCount: widget.settings.recall_count !== undefined ? widget.settings.recall_count : Yui.RECALL_COUNT

    function recall(query) {
        if (recallCount <= 0)
            return [];

        var fragments = Yui.recallFragments(heartCache, query, recallCount);
        if (fragments.length === 0)
            return [];

        var now = Date.now();
        var used = {};
        fragments.forEach(function(entry) {
            used[entry.id] = true;
        });
        var entries = Yui.copyEntries(heartCache).map(function(entry) {
            if (used[entry.id]) {
                entry.lastUsed = now;
                entry.uses = (entry.uses || 0) + 1;
            }
            return entry;
        });
        if (database) {
            try {
                database.transaction(function(tx) {
                    fragments.forEach(function(entry) {
                        tx.executeSql("UPDATE memories SET last_used = ?, uses = uses + 1 WHERE id = ?", [now, entry.id]);
                    });
                });
                heartCache = entries;
            } catch (e) {
                console.log("could not record recalled memories:", e);
            }
        } else {
            saveHeart(entries);
        }
        diag("recall: " + fragments.length + " fragment(s) for \"" + String(query).slice(0, 30) + "\"");
        return fragments;
    }

    // SAO Utils exports / imports widget data (e.g. "My Widgets"); the settings travel on their own,
    // Yui's Heart lives in the database, so it is carried here.
    function exportData() {
        return {
            "yui_heart": heartEntries(),
            "yui_heart_entries": Yui.copyEntries(heartCache)
        };
    }

    function importData(data) {
        if (!data)
            return ;

        if (!database)
            openDatabase();

        if (Array.isArray(data.yui_heart_entries))
            saveHeart(Yui.copyEntries(data.yui_heart_entries).map(function(entry) {
            entry.id = null;
            return entry;
        }));
        else if (Array.isArray(data.yui_heart))
            setHeartEntries(data.yui_heart.map(function(entry) {
            return String(entry);
        }));
    }

    // ---------------------------------------------------------------- Yui's Heart files
    // Exported files and daily backups: JSON {format, version, exported, entries[, messages]}.
    // They are written to the extension's storage folder (Storages\yui, kept when the plugin is
    // updated) or, when SAO Utils does not allow that, to the plugin's own folder.

    // Where heart files go, best first, as local paths with "/".
    function heartFolders() {
        return [String(NVG.Utils.storagePath("yui")), String(NVG.Url.toLocalFile(Qt.resolvedUrl("..")))].map(function(folder) {
            return folder.replace(/\\/g, "/").replace(/\/+$/, "");
        });
    }

    function fileUrl(path) {
        return "file:///" + encodeURI(path.replace(/^\/+/, ""));
    }

    // Writes text to name in the first heart folder that accepts it, checked by reading it back once
    // the write has finished (a file PUT completes later even when sent synchronously).
    // onDone(path): the Windows path written, or "" when no folder worked.
    function writeHeartFile(name, text, onDone) {
        var folders = heartFolders();
        var tryFolder = function(i) {
            if (i >= folders.length) {
                onDone("");
                return ;
            }
            var path = folders[i] + "/" + name;
            writeFileChecked(path, text, function(ok) {
                if (ok)
                    onDone(path.replace(/\//g, "\\"));
                else
                    tryFolder(i + 1);
            });
        };
        tryFolder(0);
    }

    // Writes text to a local path ("/" separators), then reads it back once the write has finished
    // (a file PUT completes later even when sent synchronously). onDone(ok).
    function writeFileChecked(path, text, onDone) {
        var put = new XMLHttpRequest();
        put.onreadystatechange = function() {
            if (put.readyState !== XMLHttpRequest.DONE)
                return ;

            var ok = false;
            try {
                var get = new XMLHttpRequest();
                get.open("GET", fileUrl(path) + "?t=" + Date.now(), false);
                get.send(null);
                ok = get.responseText === text;
            } catch (e) {
            }
            diag("write " + path + " -> " + (ok ? "ok" : "failed (status " + put.status + ")"));
            onDone(ok);
        };
        try {
            put.open("PUT", fileUrl(path));
            put.send(text);
        } catch (e) {
            diag("write " + path + " failed: " + e);
            onDone(false);
        }
    }

    // ---------------------------------------------------------------- Seedling widgets in "My Widgets"
    // Seedling "Save to My Widgets": a preset folder in Storages/system/widget-preset (as SAO Utils
    // saves them; see Yui.seedlingPresetFiles) whose widget is this widget type with seedling_widget / seedling_code in its
    // settings, so it opens in seedling widget mode. The folder is made with mkdir (files cannot create
    // folders), then preset.json and settings.xml are written and preview (an Item) is saved as
    // preview.png. onDone(folder) with the folder's Windows path, or "" when it failed.
    function saveSeedlingPreset(title, code, preview, onDone) {
        var root = String(NVG.Utils.storagePath("system")).replace(/\\/g, "/").replace(/\/+$/, "") + "/widget-preset";
        var folder = root + "/custom-" + Date.now().toString(16);
        var windowsFolder = folder.replace(/\//g, "\\");
        var files = Yui.seedlingPresetFiles(title, code, preview.width, preview.height, new Date().toISOString());
        var command = 'cmd /c mkdir "' + windowsFolder + '"';
        diag("save seedling widget: command(" + command + ") -> " + NVG.SystemCall.command(command) + " (not used)");
        // mkdir runs on its own: try the first file a few times until the folder is there.
        var tries = 0;
        var writeAll = function() {
            writeFileChecked(folder + "/preset.json", files.preset, function(ok) {
                if (!ok) {
                    if (++tries < 10)
                        delayTimer.start(writeAll);
                    else
                        onDone("");
                    return ;
                }
                writeFileChecked(folder + "/settings.xml", files.settings, function(ok) {
                    if (!ok) {
                        onDone("");
                        return ;
                    }
                    preview.grabToImage(function(result) {
                        var saved = result.saveToFile(folder + "/preview.png");
                        diag("save seedling widget: preview.png -> " + saved);
                        onDone(windowsFolder);
                    });
                });
            });
        };
        delayTimer.start(writeAll);
    }

    // Runs a function once after 300 ms (used while waiting for mkdir).
    QtObject {
        id: delayTimer

        property var pending: null
        property Timer timer: Timer {
            interval: 300
            onTriggered: {
                var run = delayTimer.pending;
                delayTimer.pending = null;
                if (run)
                    run();

            }
        }

        function start(run) {
            pending = run;
            timer.restart();
        }

    }

    // ---------------------------------------------------------------- Seedling item in Yui
    // Seedling "Show in Yui (live)": the code becomes an Item inside this widget (seedlingSlot), reloaded
    // whenever the code changes. Returns "" when it loaded, or the compile errors ("line:column
    // message" lines); on errors the last working item stays.
    property var yuiSeedlingItem: null

    function loadIntoYui(code) {
        var created;
        try {
            created = Qt.createQmlObject(code, seedlingSlot, "Seedling");
        } catch (e) {
            return (e.qmlErrors || []).map(function(error) {
                return qsTr("Line %1, column %2: %3").arg(error.lineNumber).arg(error.columnNumber).arg(error.message);
            }).join("\n") || String(e);
        }
        if (yuiSeedlingItem)
            yuiSeedlingItem.destroy();

        yuiSeedlingItem = created;
        return "";
    }

    function clearYuiSeedling() {
        if (yuiSeedlingItem)
            yuiSeedlingItem.destroy();

        yuiSeedlingItem = null;
    }

    // Seedling widget mode: this widget was created from a saved Seedling widget (seedling_widget and seedling_code in
    // its settings).
    // Yui is not started; the widget only shows the code.
    property bool seedlingMode: false
    property var seedlingObject: null

    function startSeedlingWidget() {
        seedlingMode = true;
        // Hide everything of Yui (the lab content is added afterwards).
        for (var i = 0; i < widget.children.length; i++)
            widget.children[i].visible = false;
        var code = Yui.seedlingCode(widget.settings);
        try {
            seedlingObject = Qt.createQmlObject(code, widget, "SeedlingWidget");
        } catch (e) {
            var errors = (e.qmlErrors || []).map(function(error) {
                return error.lineNumber + ":" + error.columnNumber + " " + error.message;
            });
            console.log("seedling widget failed:", errors.join("; ") || e);
            // How the code arrived (line breaks shown as \n), to see what the settings reader did.
            console.log("seedling widget code starts:", JSON.stringify(code.slice(0, 120)));
            seedlingObject = Qt.createQmlObject('import QtQuick 2.12; Text { color: "red"; text: "Seedling widget error" }', widget, "SeedlingWidgetError");
        }
        // The saved size once, as for Yui's first start; afterwards SAO Utils restores the frame.
        if (!widget.settings.seedling_sized) {
            widget.settings.seedling_sized = true;
            applyFrameSize(widget.settings.seedling_width || seedlingObject.width || 200, widget.settings.seedling_height || seedlingObject.height || 120);
        } else {
            widget.implicitWidth = 20;
            widget.implicitHeight = 20;
        }
    }

    // The heart as a file; withMessages adds the complete chat history (private conversations).
    function heartDocument(withMessages) {
        var document = {
            "format": "MHCP001-yui-heart",
            "version": 1,
            "exported": new Date().toISOString(),
            "entries": Yui.copyEntries(heartCache).map(function(entry) {
                delete entry.id;
                return entry;
            })
        };
        if (withMessages && database) {
            document.messages = [];
            database.readTransaction(function(tx) {
                var rows = tx.executeSql("SELECT author, message, created FROM messages ORDER BY id").rows;
                for (var i = 0; i < rows.length; i++)
                    document.messages.push({
                    "author": rows.item(i).author,
                    "message": rows.item(i).message,
                    "created": rows.item(i).created
                });

            });
        }
        return JSON.stringify(document, null, 2);
    }

    // System Console "Export": writes 结衣之心-<date>.json and shows it in File Explorer.
    // onDone(path), optional: the path written, or "" when it failed.
    function exportHeart(withMessages, onDone) {
        writeHeartFile("结衣之心-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".json", heartDocument(withMessages), function(path) {
            if (path)
                showInExplorer(path);

            if (onDone)
                onDone(path);

        });
    }

    // Once a day (on start): a backup without the chat history, one file per day slot, so the last
    // backupDays days are kept and older ones are overwritten.
    function backupHeart() {
        var day = Math.floor((Date.now() - new Date().getTimezoneOffset() * 60000) / 86400000);
        if (widget.settings.heart_backup_day === day || heartCache.length === 0)
            return ;

        writeHeartFile("heart-backup-" + (day % backupDays + 1) + ".json", heartDocument(false), function(path) {
            if (!path)
                return ;

            widget.settings.heart_backup_day = day;
            widget.settings.heart_backup_path = path;
            widget.settingsRevision++;
            removeOldBackups();
        });
    }

    // Deletes the daily backups beyond backupDays (heart-backup-<n>.json with n > backupDays, up to
    // the largest setting, 30), e.g. after Backup Days was lowered. Which ones exist is checked by
    // reading them first (no window), so the command (which shows a console window for a moment) only
    // runs when there is something to delete.
    function removeOldBackups() {
        var found = [];
        heartFolders().forEach(function(folder) {
            for (var n = backupDays + 1; n <= 30; n++) {
                var path = folder + "/heart-backup-" + n + ".json";
                try {
                    var get = new XMLHttpRequest();
                    get.open("GET", fileUrl(path), false);
                    get.send(null);
                    if (get.responseText)
                        found.push(path.replace(/\//g, "\\"));

                } catch (e) {
                }
            }
        });
        if (found.length === 0)
            return ;

        var command = 'cmd /c del /q "' + found.join('" "') + '"';
        NVG.SystemCall.command(command);
        diag("command(" + command + ")");
    }

    onBackupDaysChanged: removeOldBackups()

    // System Console "Import": adds the memories of an exported file (and its chat history, if it has
    // one) to Yui's Heart; nothing is replaced. Returns a message for the user.
    function importHeart(url) {
        var text = "";
        try {
            var get = new XMLHttpRequest();
            get.open("GET", String(url), false);
            get.send(null);
            text = get.responseText || "";
            diag("import " + url + " -> status " + get.status + ", " + text.length + " chars");
        } catch (e) {
            diag("import " + url + " failed: " + e);
        }
        var document;
        try {
            document = JSON.parse(text.replace(/^﻿/, ""));
        } catch (e) {
            return qsTr("This file could not be read as Yui's Heart.");
        }
        if (!document || document.format !== "MHCP001-yui-heart" || !Array.isArray(document.entries))
            return qsTr("This file is not a Yui's Heart export.");

        var result = Yui.mergeHeart(heartCache, document.entries, heartCoreCapacity);
        saveHeart(result.entries);
        var messages = 0;
        if (Array.isArray(document.messages) && database)
            database.transaction(function(tx) {
            document.messages.forEach(function(m) {
                if (tx.executeSql("SELECT id FROM messages WHERE created = ? AND message = ?", [m.created, m.message]).rows.length === 0) {
                    tx.executeSql("INSERT INTO messages(author, message, created) VALUES(?, ?, ?)", [m.author, m.message, m.created]);
                    messages++;
                }
            });
        });

        diag("import: " + result.added + " memories, " + messages + " messages added");
        return qsTr("Imported %1 new memories and %2 chat messages.").arg(result.added).arg(messages);
    }

    // Keep every finished message in the complete history.
    // Your sent messages for ↑ / ↓ in the input box, newest first (at most 100, repeats in a row
    // once): from the recollection log, so they survive clearing the chat and restarts; from the
    // chat itself without a database.
    function sentHistory() {
        var list = [];
        var add = function(message) {
            message = String(message || "");
            if (message.trim() && list[list.length - 1] !== message)
                list.push(message);

        };
        if (database) {
            try {
                database.readTransaction(function(tx) {
                    var rows = tx.executeSql("SELECT message FROM messages WHERE author = 'user' ORDER BY id DESC LIMIT 200").rows;
                    for (var i = 0; i < rows.length; i++)
                        add(rows.item(i).message);

                });
            } catch (e) {
                diag("input history: " + e);
            }
        }
        if (list.length === 0)
            for (var j = chatModel.count - 1; j >= 0; j--)
                if (chatModel.get(j).author === "user")
                    add(chatModel.get(j).message);

        return list.slice(0, 100);
    }

    function logMessage(author, message) {
        if (!database)
            return ;

        try {
            database.transaction(function(tx) {
                tx.executeSql("INSERT INTO messages(author, message, created) VALUES(?, ?, ?)", [author, message, Date.now()]);
            });
        } catch (e) {
            console.log("could not log message:", e);
        }
    }


    function loadLevelOf(metric) {
        var state = loadStates[metric];
        return state ? state.level : 0;
    }

    // One crystal sample of CPU, GPU and memory load (see loadStates).
    function sampleLoad() {
        var sources = {
            "cpu": cpuLoad,
            "gpu": gpuLoad,
            "ram": ramUsage
        };
        var states = {};
        var values = {};
        loadMetrics.forEach(function(metric) {
            values[metric] = readData(sources[metric]);
            states[metric] = Yui.loadStep(loadStates[metric], values[metric], Yui.loadThresholds(widget.settings.load_thresholds, metric));
        });
        loadValues = values;
        loadStates = states;
    }

    // A data value now; configuration: the value's parameter, if it takes one (the drive of hdd space).
    function readData(source, configuration) {
        if (!source)
            return NaN;

        try {
            if (configuration !== undefined)
                source.update.configuration = configuration;

            source.update.execute();
            return Number(source.current);
        } catch (e) {
            return NaN;
        }
    }

    // Storage Capacity (System Console): the system drive's free space below this many % is reported, at
    // most once a day (0: off). The hdd "space" value is the used space in %.
    function checkStorage(now, title) {
        var minimum = widget.settings.storage_free_min !== undefined ? widget.settings.storage_free_min : 10;
        var used = readData(diskSpace, systemDrive);
        if (minimum <= 0 || isNaN(used) || 100 - used >= minimum || now - (widget.settings.storage_reported || 0) < 86400000)
            return ;

        widget.settings.storage_reported = now;
        statusWarning("警告！" + systemDrive.replace(/\\$/, "") + " 盘只剩下 " + Math.max(0, Math.round(100 - used)) + "% 的空间了……" + title + "，要不要清理一下呢？(・_・;)");
    }

    // Network Link (System Console): no traffic at all for two minutes counts as the network lost, and
    // traffic again as it back; both are reported once.
    function checkNetwork(title) {
        if (widget.settings.network_watch === false)
            return ;

        var down = readData(netDownload);
        var up = readData(netUpload);
        if (isNaN(down) || isNaN(up))
            return ;

        if (down > 0 || up > 0) {
            networkIdleChecks = 0;
            if (networkLost) {
                networkLost = false;
                statusWarning("网络恢复连接了！" + title + "，结衣又能帮你上网查东西啦 (｡･ω･｡)");
            }
            return ;
        }
        networkIdleChecks++;
        if (networkIdleChecks >= networkLostChecks && !networkLost) {
            networkLost = true;
            statusWarning("警告！网络连接好像断开了……" + title + "，要检查一下网线或 Wi-Fi 吗？(・_・;)");
        }
    }

    // Navigation-pixie style warnings about battery, CPU and memory (local messages, no API cost).
    function checkSystemStatus(now) {
        if (!featureEnabled("status_reports"))
            return ;

        var title = userTitle();
        var acOnline = readData(acStatus) === 1;
        var flags = readData(batteryStatus);
        var level = readData(batteryLevel);
        // Battery flag 128 means "no system battery" (desktop PC).
        if (!isNaN(flags) && flags < 128 && !isNaN(level) && level >= 0 && level <= 100) {
            if (acOnline) {
                batteryWarnedAt = 101;
            } else {
                var thresholds = [20, 10, 5];
                for (var i = 0; i < thresholds.length; i++) {
                    if (level <= thresholds[i] && batteryWarnedAt > thresholds[i]) {
                        batteryWarnedAt = thresholds[i];
                        statusWarning("警告！" + title + "，电量只剩下 " + Math.round(level) + "% 了！快去接上电源吧 (>_<)");
                        break;
                    }
                }
            }
        }
        checkStorage(now, title);
        checkNetwork(title);
        // CPU, GPU and memory, with the crystal's red thresholds (System Console): reported once a load
        // stays at or above it for these many checks (one every 30 s).
        var sources = {
            "cpu": cpuLoad,
            "gpu": gpuLoad,
            "ram": ramUsage
        };
        var checksNeeded = {
            "cpu": 4,
            "gpu": 4,
            "ram": 2
        };
        var checks = highLoadChecks;
        loadMetrics.forEach(function(metric) {
            var value = readData(sources[metric]);
            var red = Yui.loadThresholds(widget.settings.load_thresholds, metric)[1];
            checks[metric] = !isNaN(value) && value >= red ? (checks[metric] || 0) + 1 : 0;
            if (checks[metric] >= checksNeeded[metric] && loadWarningDue(metric, now))
                statusWarning(loadWarningText(metric, value, title));

        });
        highLoadChecks = checks;
    }

    // At most one report per load in this many hours (System Console, default 1).
    readonly property int loadReportHours: widget.settings.load_report_hours > 0 ? widget.settings.load_report_hours : 1

    // Whether a load may be reported now (once per loadReportHours per metric); marks it reported.
    function loadWarningDue(metric, now) {
        var last = lastLoadWarnings;
        if (now - (last[metric] || 0) <= loadReportHours * 3600000)
            return false;

        last[metric] = now;
        lastLoadWarnings = last;
        return true;
    }

    function loadWarningText(metric, value, title) {
        var percent = Math.round(value) + "%";
        if (metric === "cpu")
            return "哔——！检测到 CPU 负载持续在 " + percent + " 以上……" + title + "，电脑好像很辛苦，要不要看看是什么程序在占用呢？(・_・;)";

        if (metric === "gpu")
            return "哔——！显卡负载一直在 " + percent + " 左右……" + title + "，是在玩游戏还是在渲染呢？注意别让电脑太热哦 (・_・;)";

        return "警告！内存使用率已经达到 " + percent + " 了！" + title + "，关掉一些不用的程序会比较好哦 (｀・ω・´)";
    }

    // Col Ledger (System Console): the tokens of this month's replies; past the Monthly Budget (in
    // thousands of tokens, 0: none) Yui says so, once a month.
    readonly property var colLedger: widget.settings.col_ledger || null

    function recordUsage(usage) {
        var ledger = Yui.addToLedger(widget.settings.col_ledger, usage, Date.now());
        var budget = (widget.settings.col_budget || 0) * 1000;
        var over = budget > 0 && ledger.input + ledger.output > budget && !ledger.warned;
        if (over)
            ledger.warned = true;

        widget.settings.col_ledger = ledger;
        diag("col ledger: +" + (usage.input || 0) + " / +" + (usage.output || 0) + " tokens, this month " + (ledger.input + ledger.output));
        if (over)
            statusWarning("警告！这个月的 Col 已经超出预算了……一共用掉了 " + Math.round((ledger.input + ledger.output) / 1000) + "k tokens。" + userTitle() + "，要不要省着点用呢？(・_・;)");

    }

    // The SAO Utils action (YuiAction.qml): opens the chat (sending text, if any), lets Yui speak up,
    // starts or ends a Boss Raid, or opens one of her windows. False when the command is unknown.
    // config: the action's whole configuration (minutes, score, slot), for the commands that use more.
    function runCommand(command, text, config) {
        config = config || {};
        if (!toolsEnabled && ["skills", "raid", "start_raid", "end_raid", "raid_banner", "add_reminder", "dismiss_reminder", "add_note", "finish_note", "sword_skill"].indexOf(command) !== -1)
            return false;

        diag("action: " + command);
        var windows = {
            "cardinal": [cardinalSystemDialog, "cardinalSystemDialogInstance"],
            "equipment": [equipmentDialog, "equipmentDialogInstance"],
            "heart": [yuisHeartDialog, "yuisHeartDialogInstance"],
            "counseling": [counselingDialog, "counselingDialogInstance"],
            "skills": [skillSlotsDialog, "skillSlotsDialogInstance"],
            "console": [systemConsoleDialog, "systemConsoleDialogInstance"]
        };
        if (windows[command]) {
            showDialog(windows[command][0], windows[command][1]);
        } else if (command === "chat") {
            if (!showChat)
                openView();

            if (text && text.trim())
                Qt.callLater(sendMessage, text);

        } else if (command === "speak") {
            idleChat();
        } else if (command === "start_raid") {
            if (raidActive)
                return true;

            if (config.minutes > 0)
                startRaid(config.minutes, true);
            else
                openQuickInput("raid");

        } else if (command === "end_raid") {
            stopRaid();
        } else if (command === "raid_banner") {
            showRaidBanner();
        } else if (command === "add_reminder") {
            openQuickInput("alarm");
        } else if (command === "dismiss_reminder") {
            var next = remindersList()[0];
            if (!next)
                return false;

            deleteReminder(next.id);
            actionSay(qsTr("Alarm"), "⏰ 已取消提醒：" + next.text);
        } else if (command === "add_note") {
            openQuickInput("note");
        } else if (command === "finish_note") {
            var first = notesList(false)[0];
            if (!first)
                return false;

            editNote(first.id, first.text, true);
            actionSay(qsTr("Quest Log"), "✅ 已完成：" + first.text);
        } else if (command === "record_mood") {
            openQuickInput("mood");
        } else if (command === "weekly_report") {
            writeWeeklyReport(true, function() {
            });
        } else if (command === "sword_skill") {
            // Chosen by the user's own button, so no confirmation.
            return runSwordSkill(Number(config.slot) || 1);
        } else if (command === "raid") {
            if (raidActive || resting)
                stopRaid();
            else
                startRaid(raidMinutes, true);
        } else {
            return false;
        }
        return true;
    }

    // QuickInput.qml at the cursor: what an action needs each time (mode "alarm", "note", "mood" or
    // "raid"); one at a time, a new one replaces it.
    function openQuickInput(mode) {
        if (quickInputDialogInstance)
            quickInputDialogInstance.close();

        showDialog(quickInputDialog, "quickInputDialogInstance");
        if (quickInputDialogInstance)
            quickInputDialogInstance.start(mode);

    }

    // Done from the quick input (the same as an action with its setting filled in): false when the
    // input is not understood.
    function quickAlarm(time, text) {
        var reminder = Yui.remindFrom(time + "|" + text, Date.now());
        if (!reminder)
            return false;

        addReminder(reminder);
        actionSay(qsTr("Alarm"), "⏰ 已设提醒：" + Qt.formatDateTime(new Date(reminder.due), reminder.daily ? "每天 HH:mm" : "MM-dd HH:mm") + " " + reminder.text);
        return true;
    }

    function quickNote(text) {
        if (!String(text).trim())
            return false;

        addQuestNote(text);
        actionSay(qsTr("Quest Log"), "📜 已记下：" + String(text).trim());
        return true;
    }

    function quickMood(score, note) {
        recordMood({
            "score": score,
            "note": String(note || "").trim()
        });
        actionSay(qsTr("Mental Record"), "📝 心情记录：" + score + "/5" + (String(note || "").trim() ? " " + String(note).trim() : ""));
        return true;
    }

    // "Ask Yui" from the quick input: the chat opens with the start of a message written, for her to
    // understand what is harder to type into the boxes.
    function prefillChat(text) {
        if (!showChat)
            openView();

        Qt.callLater(function() {
            textInput.text = text;
            textInput.cursorPosition = text.length;
            textInput.forceActiveFocus();
        });
    }

    // What an action did, said like Yui's other local messages: in the chat, and in the bubble while
    // it is closed.
    function actionSay(title, text) {
        appendMessage("ai", text, false, true);
        announce(title, text);
    }

    // The SAO Utils data (YuiData.qml): {current, maximum} of a value, or null for an unknown one. The
    // maximum is never 0, so bars (which show current / maximum) always have something to show.
    function linkValue(name) {
        if (!toolsEnabled && ["boss_raid", "raid_timer", "raid_cleared", "next_alarm", "next_alarm_text", "quest_log"].indexOf(name) !== -1)
            return null;

        if (name === "companion_days") {
            var met = Date.parse(widget.settings.meeting_day || "");
            var days = isNaN(met) ? 0 : Math.max(0, Math.floor((Date.now() - met) / 86400000)) + 1;
            // As a bar: the way to the next anniversary.
            return {
                "current": days,
                "maximum": Math.max(1, Math.ceil(days / 365)) * 365
            };
        }
        if (name === "mood") {
            var today = moodsSince(1);
            return {
                "current": today.length > 0 ? today[0].score : 0
            };
        }
        if (name === "col_ledger") {
            var ledger = Yui.addToLedger(widget.settings.col_ledger, {}, Date.now());
            return {
                "current": Math.round((ledger.input + ledger.output) / 1000),
                // Without a Monthly Budget the bar is simply full.
                "maximum": widget.settings.col_budget || Math.max(1, Math.round((ledger.input + ledger.output) / 1000))
            };
        }
        if (name === "boss_raid")
            return {
                "current": raidActive ? Math.max(0, Math.ceil((raidEnd - Date.now()) / 60000)) : 0,
                "maximum": raidMinutes
            };

        if (name === "next_alarm") {
            var next = remindersList()[0];
            var left = next ? Math.max(0, Math.ceil((next.due - Date.now()) / 60000)) : 0;
            return {
                "current": left,
                "maximum": Math.max(1, left)
            };
        }
        // Text values (for HUD text elements).
        if (name === "quest_log")
            return {
                "current": notesList(false).map(function(note) {
                    return "· " + note.text;
                }).join("\n")
            };

        if (name === "next_alarm_text") {
            var upcoming = remindersList()[0];
            return {
                "current": upcoming ? Qt.formatDateTime(new Date(upcoming.due), new Date(upcoming.due).toDateString() === new Date().toDateString() ? "HH:mm" : "MM-dd HH:mm") + " " + upcoming.text : ""
            };
        }
        if (name === "raid_timer") {
            var end = raidActive ? raidEnd : (resting ? restEnd : 0);
            var seconds = Math.max(0, Math.ceil((end - Date.now()) / 1000));
            var clock = Math.floor(seconds / 60) + ":" + ("0" + seconds % 60).slice(-2);
            return {
                "current": raidActive ? clock : (resting ? "REST " + clock : "")
            };
        }
        if (name === "mood_text") {
            var mood = moodsSince(1)[0];
            return {
                "current": mood ? "★★★★★".slice(0, mood.score) + "☆☆☆☆☆".slice(0, 5 - mood.score) + (mood.note ? " " + mood.note : "") : ""
            };
        }
        if (name === "latest_report") {
            var report = reportsList()[0];
            return {
                "current": report ? report.text : ""
            };
        }
        if (name === "raid_cleared")
            return {
                "current": Date.now() < raidClearedUntil ? 1 : 0,
                "maximum": 1
            };

        if (name === "heart_core")
            return {
                "current": Yui.coreMemories(heartCache).length,
                "maximum": heartCoreCapacity
            };

        return null;
    }

    // Starts a Boss Raid of minutes; fromMenu: say it (when Yui starts it from a reply, she says it).
    function startRaid(minutes, fromMenu) {
        raidEnd = Date.now() + minutes * 60000;
        widget.settings.raid_end = raidEnd;
        raidActive = true;
        resting = false;
        if (widget.settings.raid_banner !== false)
            showRaidBanner();
        else
            diag("raid banner: off (Skill Slots, Raid Banner)");

        diag("boss raid: " + minutes + " min");
        if (fromMenu)
            raidSay("Boss Raid 开始！✧ 结衣会安静地陪着" + userTitle() + " " + minutes + " 分钟，加油哦～ (ง •̀_•́)ง");

    }

    function stopRaid() {
        if (!raidActive && !resting)
            return ;

        // The minutes actually spent count too (Weekly Report).
        if (raidActive)
            logRaid(Math.round((raidMinutes * 60000 - Math.max(0, raidEnd - Date.now())) / 60000));

        raidActive = false;
        resting = false;
        widget.settings.raid_end = 0;
        diag("boss raid: ended early");
    }

    // Weekly Report: the raids of the last weeks ({end, minutes}, at most 100).
    function logRaid(minutes) {
        if (minutes <= 0)
            return ;

        widget.settings.raid_log = (widget.settings.raid_log || []).concat([{
            "end": Date.now(),
            "minutes": minutes
        }]).slice(-100);
    }

    // ---------------------------------------------------------------- Weekly Report
    // Bumped when a report is written or deleted (Mental Health Counseling lists them).
    property int reportRevision: 0
    property bool writingReport: false

    // Reports, newest first: [{id, week, text, created}].
    function reportsList() {
        return readSql("reading the reports", "SELECT id, week, text, created FROM reports ORDER BY created DESC");
    }

    function deleteReport(id) {
        if (writeSql("deleting a report", "DELETE FROM reports WHERE id = ?", [id]))
            reportRevision++;

    }

    // The last seven days, today included: Yui writes the report (one request, not in the chat) and
    // it is kept; announce: she says it is ready (the automatic one). onDone(error text or "").
    function writeWeeklyReport(announceIt, onDone) {
        if (writingReport)
            return ;

        var now = Date.now();
        var from = new Date(now - 6 * 86400000);
        from.setHours(0, 0, 0, 0);
        var raids = (widget.settings.raid_log || []).filter(function(raid) {
            return raid.end >= from.getTime();
        });
        var ledger = Yui.addToLedger(widget.settings.col_ledger, {}, now);
        var stats = {
            "from": Qt.formatDate(from, "yyyy-MM-dd"),
            "to": Qt.formatDate(new Date(now), "yyyy-MM-dd"),
            "messages": (readSql("counting the messages", "SELECT COUNT(*) AS n FROM messages WHERE author = 'user' AND created >= ?", [from.getTime()])[0] || {
                "n": 0
            }).n,
            "moods": moodsSince(7),
            "raids": toolsEnabled ? {
                "count": raids.length,
                "minutes": raids.reduce(function(sum, raid) {
                    return sum + raid.minutes;
                }, 0)
            } : null,
            "notesDone": toolsEnabled ? readSql("reading the notes", "SELECT text FROM notes WHERE done = 1 AND updated >= ?", [from.getTime()]).map(function(note) {
                return note.text;
            }) : null,
            "notesOpen": toolsEnabled ? notesList(false).length : 0,
            "tokens": Math.round((ledger.input + ledger.output) / 1000)
        };
        writingReport = true;
        diag("weekly report: requested (" + stats.from + " – " + stats.to + ")");
        requestCompletion([{
            "role": "user",
            "content": Yui.weeklyReportPrompt(userTitle(), stats)
        }], function(text, isError) {
            writingReport = false;
            if (isError) {
                diag("weekly report failed: " + text);
                onDone(text);
                return ;
            }
            var report = Yui.parseReply(text, [], {}).text;
            widget.settings.report_week = stats.from;
            if (writeSql("saving the report", "INSERT INTO reports(week, text, created) VALUES(?, ?, ?)", [stats.from + " – " + stats.to, report, Date.now()]))
                reportRevision++;

            if (announceIt) {
                appendMessage("ai", "📊 " + userTitle() + "，这周的小结写好啦～在 Mental Health Counseling 的 Records 里，有空看看哦 (｡･ω･｡)", false, true);
                announce(qsTr("Weekly Report"), "📊 这周的小结写好啦～");
            }
            onDone("");
        });
    }

    // Weekly Report on Sunday evenings (from 20:00), once a week, when it is turned on.
    function checkWeeklyReport() {
        var now = new Date();
        if (widget.settings.weekly_report !== true || now.getDay() !== 0 || now.getHours() < 20 || widget.busy || !activeConfig().apiKey)
            return ;

        var from = new Date(now.getTime() - 6 * 86400000);
        if (widget.settings.report_week === Qt.formatDate(from, "yyyy-MM-dd"))
            return ;

        writeWeeklyReport(true, function() {
        });
    }

    // Boss Raid's banner (RaidBanner.qml), created on first use: the time left, then "Congratulations!".
    property var raidBanner: null
    // The data value Raid Cleared is 1 until then (a few seconds after a raid is won), for a HUD banner.
    property double raidClearedUntil: 0

    // A point on Yui's screen for the banner: the middle of her open chat, else of the widget.
    function bannerScreenPoint() {
        if (showChat && yuiView)
            return Qt.point(yuiView.x + yuiView.width / 2, yuiView.y + yuiView.height / 2);

        var rect = widgetScreenRect();
        return Qt.point(rect.x + rect.width / 2, rect.y + rect.height / 2);
    }

    function showRaidBanner() {
        if (!raidBanner) {
            var component = Qt.createComponent("RaidBanner.qml");
            if (component.status !== Component.Ready) {
                diag("raid banner unavailable: " + component.errorString());
                return ;
            }
            raidBanner = component.createObject(widget, {
                "yui": widget
            });
        }
        if (raidActive || resting)
            raidBanner.open();

        diag("raid banner: " + (raidBanner.visible ? "shown" : "hidden") + " at " + raidBanner.x + "," + raidBanner.y + " " + raidBanner.width + "x" + raidBanner.height + ", compositor " + raidBanner.compositor + ", z " + raidBanner.z);
    }

    // What Yui says about a raid: in the chat, and in the bubble while it is closed.
    function raidSay(text) {
        appendMessage("ai", text, false, true);
        setEmotion("happy");
        announce(qsTr("Boss Raid"), text);
    }

    function checkRaid(now) {
        if (raidActive && now >= raidEnd) {
            raidActive = false;
            widget.settings.raid_end = 0;
            resting = true;
            restEnd = now + restMinutes * 60000;
            logRaid(raidMinutes);
            raidClearedUntil = now + 6000;
            // Also when the banner was hidden by its ×: the win is shown either way.
            if (raidBanner && widget.settings.raid_banner !== false) {
                raidBanner.celebrate();
                diag("raid banner: congratulations at " + raidBanner.x + "," + raidBanner.y + " " + raidBanner.width + "x" + raidBanner.height);
            }

            raidSay("Boss 讨伐成功！✧ " + userTitle() + "辛苦啦～休息 " + restMinutes + " 分钟吧，喝口水、看看远处 (｡･ω･｡)");
        } else if (resting && now >= restEnd) {
            resting = false;
            raidSay("休息时间结束啦～" + userTitle() + "，准备好下一场战斗了吗？(・ω・)");
        }
    }

    function statusWarning(text) {
        appendMessage("ai", text, false, true);
        setEmotion("surprised");
        announce(qsTr("Navigation Report"), text);
    }

    // Something Yui says outside the chat (replies, care, status reports): while the chat is closed, in
    // the bubble next to her collapsed form (crystal, pixie or avatar); while it is open it is already in
    // the chat (and while the launcher she is in is closed, only in the chat). title: unused (the bubble is headed "Yui"), kept for the callers' sake.
    function announce(title, text) {
        if (!showChat && !launcherClosed)
            showBubble("Yui", text);

    }

    // Yui's speech bubble (CrystalBubble.qml) next to her collapsed form, created on first use. Next to
    // the crystal its title bar takes the crystal's color, else Yui's green. Clicking it closes it.
    property var crystalBubble: null

    function showBubble(title, text) {
        if (!crystalBubble) {
            var component = Qt.createComponent("CrystalBubble.qml");
            if (component.status !== Component.Ready) {
                diag("bubble unavailable: " + component.errorString());
                return ;
            }
            crystalBubble = component.createObject(widget);
            // On the widget's layer: above it, but not above windows that cover the widget.
            followHostView(crystalBubble, function() {
                return widget.hostView ? widget.hostView.z : 0;
            });
            crystalBubble.stayTime = Qt.binding(function() {
                return widget.bubbleSeconds * 1000;
            });
            crystalBubble.shownOpacity = Qt.binding(function() {
                return widget.bubbleOpacity;
            });
            crystalBubble.sound = Qt.binding(function() {
                return widget.messageSounds;
            });
        }
        // From the level itself: crystalColor may not be updated yet inside onCrystalLevelChanged.
        crystalBubble.show(title, text, collapsedForm === "crystal" ? levelColors[crystalLevel] : levelColors[0], collapsedScreenRect());
        diag("bubble: " + title + " / " + String(text).slice(0, 40));
    }

    // Seedling "Pop Out": the QML as a SeedlingWidget view on the desktop, next to this widget (each one a
    // little further down and right, so they do not cover each other).
    function popOutSeedling(code) {
        var component = Qt.createComponent("SeedlingWidget.qml");
        if (component.status !== Component.Ready) {
            diag("seedling: pop out unavailable: " + component.errorString());
            return null;
        }
        var corner = widget.mapToGlobal(0, 0);
        var offset = 30 * (seedlingWidgets.length % 8);
        var view = component.createObject(widget, {
            "code": code,
            "label": qsTr("Seedling Widget") + " " + (seedlingWidgets.length + 1),
            "x": corner.x + 40 + offset,
            "y": corner.y + 40 + offset
        });
        followHostView(view, function() {
            return widget.hostView ? widget.hostView.z : 0;
        });
        seedlingWidgets = seedlingWidgets.concat([view]);
        view.removed.connect(function() {
            seedlingWidgets = seedlingWidgets.filter(function(other) {
                return other !== view;
            });
        });
        diag("seedling: popped out at " + Math.round(view.x) + "," + Math.round(view.y));
        return view;
    }

    function closeSeedlings() {
        seedlingWidgets.slice().forEach(function(view) {
            view.remove();
        });
    }

    // Yui's collapsed form on screen, including its floating up and down (the pixie floats by a
    // transform, which the mapping includes; the crystal by its own hover).
    function collapsedScreenRect() {
        var item = collapsedForm === "crystal" ? crystalForm : (collapsedForm === "pixie" ? pixieImage : avatarImage);
        var corner = item.mapToGlobal(0, item === crystalForm ? crystalForm.hover : 0);
        return Qt.rect(corner.x, corner.y, item.width, item.height);
    }

    // While the bubble is shown it follows her collapsed form: its floating, and the widget being
    // moved. It closes when the chat is opened.
    Timer {
        interval: 16
        repeat: true
        running: !!widget.crystalBubble && widget.crystalBubble.visible
        onTriggered: {
            if (!widget.showChat)
                widget.crystalBubble.follow(widget.collapsedScreenRect());
            else
                widget.crystalBubble.hide();
        }
    }

    // MHCP001 care: remind the user to sleep late at night or to rest after a long session.
    // At most once an hour, only while the user is around and Yui is awake.
    // Yui talks by herself while she is a crystal and nothing happened for settings.idle_chat_minutes
    // (0 = never; default 15, before she falls asleep after the standby time).
    function checkIdleChat(now) {
        var minutes = widget.settings.idle_chat_minutes !== undefined ? widget.settings.idle_chat_minutes : 15;
        if (minutes <= 0 || showChat || launcherClosed || raidActive || sleeping || widget.busy || now - Math.max(lastProactive, lastActivity) < minutes * 60000)
            return ;

        idleChat();
    }

    // System Console "Test Bubble": a sample line in the crystal's bubble, without an API request. Each
    // click shows the next sample (short, long, a status report), so the layout can be checked.
    property int testBubbleCount: 0
    // The next reply is a made-up streamed one (Test Streaming): no API request, no tokens.
    property bool testStreaming: false

    // Diagnostics: Yui "thinks" for 8 s (long enough for a thinking hint), then a sample reply streams in a few characters at a time.
    function testStreamReply() {
        if (busy) {
            diag("test streaming: Yui is busy with a reply");
            return ;
        }
        if (!yuiView || !yuiView.visible)
            diag("test streaming: open the chat (click Yui) to watch it");

        testStreaming = true;
        startReply([], "Yui");
    }

    // A fake streamed completion with requestCompletion's callbacks and an abort().
    function fakeStream(onFinished, onDelta) {
        var full = "（测试回复，没有调用 API）
嗯嗯，结衣正在一个字一个字地回答" + userTitle() + "哦～这样就能看到流式传输时消息框慢慢变高的样子了。再多写几句吧：今天天气怎么样呢？要记得喝水、休息眼睛哦！(｡･ω･｡)";
        var shown = 0;
        var timer = Qt.createQmlObject("import QtQuick 2.12; Timer { repeat: true }", widget);
        timer.interval = 8000;
        timer.triggered.connect(function() {
            timer.interval = 60;
            shown = Math.min(full.length, shown + 2);
            if (shown < full.length) {
                if (onDelta)
                    onDelta(full.slice(0, shown));

                return ;
            }
            timer.stop();
            timer.destroy();
            onFinished(full, false, false);
        });
        timer.start();
        return {
            "abort": function() {
                timer.stop();
                timer.destroy();
                onFinished(full.slice(0, shown) || "(・ω・)", false, false);
            }
        };
    }

    function testBubble() {
        if (showChat) {
            diag("test bubble: the chat is open; close it first (the bubble is shown next to her collapsed form)");
            return ;
        }
        var title = userTitle();
        var samples = [["", title + "～结衣在这里哦！(｡･ω･｡)"], ["", "嗯……" + title + "已经对着屏幕好久了呢。结衣刚才在想，等这件事忙完，要不要一起去看看窗外的风景？外面的天空说不定很漂亮哦！不过在那之前，先喝一口水吧～这句话故意写得很长，用来测试气泡最多显示六行时的省略效果。"], [qsTr("Navigation Report"), "警告！系统负荷过高：GPU 98%……" + title + "，要不要看看是什么程序在占用呢？(・_・;)"], [qsTr("Mental Health Counseling"), "已经连续使用电脑 2 小时了哦，" + title + "，休息一下眼睛吧 (´・ω・`)"]];
        var sample = samples[testBubbleCount++ % samples.length];
        showBubble("Yui", sample[1]);
    }

    // Yui says something by herself (idle chatter) while the chat is closed; its reply shows in the
    // bubble next to her collapsed form.
    function idleChat() {
        var title = userTitle();
        var form = {
            "crystal": "水晶",
            "pixie": "导航妖精",
            "avatar": "小小的立绘"
        }[collapsedForm] || "小小的立绘";
        var place = hostView && hostView.compositor === NVG.LauncherCompositor ? "的启动器里" : "的桌面上";
        var started = yuiSpeaks("（系统提示：结衣现在以" + form + "的样子待在" + title + place + "。请结衣主动对" + title + "说一句简短的话：闲聊、问候，或者结合时间和之前聊过的事关心一下。一两句话即可，不要提起这条提示。）");
        diag("idle chatter: " + (started ? "requested" : "not now (busy or no API key)"));
    }

    function checkCare(now) {
        if (!featureEnabled("proactive_care") || raidActive || sleeping || widget.busy || now - lastProactive < 3600000 || now - lastActivity > 15 * 60000)
            return ;

        var title = userTitle();
        var hour = new Date(now).getHours();
        // The "night" a late hour belongs to, so the reminder is given once per night.
        var night = Qt.formatDate(new Date(now - 6 * 3600000), "yyyy-MM-dd");
        if (hour < 5 && widget.settings.last_night_care !== night) {
            if (yuiSpeaks("（系统提示：现在已经是深夜 " + Qt.formatTime(new Date(now), "HH:mm") + " 了，" + title + "还在电脑前。请以结衣的身份关心" + title + "，温柔地提醒早点休息。一两句话。）", qsTr("Mental Health Counseling")))
                widget.settings.last_night_care = night;

            return ;
        }
        if (now - sessionStart > 2 * 3600000 && now - (widget.settings.last_rest_care || 0) > 2 * 3600000) {
            if (yuiSpeaks("（系统提示：" + title + "已经连续使用电脑 " + Yui.formatDuration(now - sessionStart) + " 了。请以结衣的身份关心" + title + "，提醒休息一下眼睛、喝点水、活动活动身体。一两句话。）", qsTr("Mental Health Counseling")))
                widget.settings.last_rest_care = now;

        }
    }

    function clearChat() {
        // Bump the session first so the aborted request's callback is ignored.
        widget.chatSession++;
        stopReply();
        widget.currentRequest = null;
        widget.busy = false;
        chatModel.clear();
        widget.historyStart = 0;
        currentEmotion = "normal";
        chatView.stickToBottom = true;
        scheduleSave();
        getInitialMessage();
    }

    // Width of the character image when drawn at height h.
    function naturalWidthAt(image, h) {
        return image.implicitHeight > 0 ? h * image.implicitWidth / image.implicitHeight : 0;
    }

    // Hiding the chat shrinks the widget to the character image (or to the navigation pixie when a
    // pixie image is set); showing it restores the previous size.
    function setChatVisible(visible) {
        if (visible === showChat)
            return ;

        if (visible)
            openView();
        else
            closeView();
        widget.settings.chat_hidden = !visible;
    }

    // The widget's rectangle on screen (in the launcher, in its space): the chat view is placed by it.
    function widgetScreenRect() {
        var corner = widget.mapToGlobal(0, 0);
        return Qt.rect(corner.x, corner.y, widget.width, widget.height);
    }

    // Opens the view next to the collapsed form (or where it was last), hiding the collapsed form.
    function openView() {
        if (!yuiView)
            return ;

        var corner = widget.mapToGlobal(0, 0);
        yuiView.place(widgetScreenRect());
        diag("view: open at " + yuiView.x + "," + yuiView.y + " " + yuiView.width + "x" + yuiView.height + ", widget at " + corner.x + "," + corner.y + " (host " + (hostView ? hostView.x + "," + hostView.y : "-") + "), compositor " + yuiView.compositor + " / host " + (hostView ? hostView.compositor : "-") + ", launcher " + NVG.LauncherCompositor.geometry + " visible " + NVG.LauncherCompositor.visible);
        showChat = true;
        // Like closing in reverse: the collapsed form goes first, and the view pops up as it is
        // almost gone (popUpTimer).
        collapsedIn.stop();
        collapsedOut.restart();
        popUpTimer.restart();
        chatView.stickToBottom = true;
    }

    // Folds the view away; the collapsed form comes back once it is gone (onFolded in createView).
    function closeView() {
        if (yuiView && yuiView.shown) {
            yuiView.fold();
        } else {
            // Closed again before the view popped up.
            popUpTimer.stop();
            collapsedOut.stop();
            showChat = false;
            collapsedIn.restart();
        }
    }

    NumberAnimation {
        id: collapsedOut

        target: widget
        property: "collapsedReveal"
        to: 0
        duration: 300
        easing.type: Easing.InOutQuad
    }

    Timer {
        id: popUpTimer

        interval: 220
        onTriggered: {
            if (showChat && yuiView)
                yuiView.popUp();

        }
    }

    NumberAnimation {
        id: collapsedIn

        target: widget
        property: "collapsedReveal"
        to: 1
        duration: 400
        easing.type: Easing.OutCubic
    }

    // The widget frame fits the collapsed form.
    function applyCollapsedSize() {
        if (collapsedForm === "crystal") {
            var crystalHeight = widget.styles.crystal_size > 0 ? widget.styles.crystal_size : widget.defaultValues.crystal_size;
            applyFrameSize(Math.ceil(crystalHeight * 0.75), crystalHeight);
        } else if (collapsedForm === "pixie") {
            var pixieHeight = widget.styles.pixie_size > 0 ? widget.styles.pixie_size : widget.defaultValues.pixie_size;
            // Extra room for the hovering animation.
            applyFrameSize(Math.ceil(naturalWidthAt(pixieImage, pixieHeight)), pixieHeight + 12);
        } else {
            var h = 300;
            var w = naturalWidthAt(avatarImage, h);
            applyFrameSize(Math.ceil(w > 0 ? w : 200), h);
        }
    }

    // The view the widget is shown in (its compositor says where: desktop or launcher, as set in the
    // widget's own display setting).
    readonly property var hostView: widget.NVG.View.view
    // The widget's compositor, kept while its view is away (it may be, while the launcher is closed):
    // falling back to the desktop then moved Yui's views out of the launcher and back.
    property var hostCompositor: null

    onHostViewChanged: {
        diag("view: host view " + (hostView ? "is " + hostView.compositor : "gone"));
        if (hostView)
            hostCompositor = Qt.binding(function() {
            return widget.hostView ? widget.hostView.compositor : widget.hostCompositor;
        });
        else if (hostCompositor === null)
            hostCompositor = NVG.WindowCompositor;
    }
    onHostCompositorChanged: diag("view: host compositor " + hostCompositor + (hostView ? "" : " (kept, host view gone)") + ", launcher visible " + NVG.LauncherCompositor.visible)
    // The widget is in the launcher and the launcher is closed. SAO Utils hides the views in the
    // launcher by itself then (their visible stays, exposed turns false), as it does the widget, and
    // shows them again in place; only the bubble is closed.
    readonly property bool launcherClosed: !!hostView && hostView.compositor === NVG.LauncherCompositor && !NVG.LauncherCompositor.visible

    onLauncherClosedChanged: {
        diag("launcher " + (launcherClosed ? "closed" : "open"));
        if (launcherClosed && crystalBubble)
            crystalBubble.hide();

    }

    // Makes one of Yui's own views (chat, bubble, Seedling widget) show where the widget is: the same
    // compositor (desktop or launcher), and, with z (a function), that z. Bindings, as the widget's
    // view may not be there yet when the chat view is made at start (then it is the desktop). Changing
    // the compositor resets the view's z, so z is bound again then.
    function followHostView(view, z) {
        view.compositor = Qt.binding(function() {
            return widget.hostView ? widget.hostView.compositor : (widget.hostCompositor || NVG.WindowCompositor);
        });
        if (!z)
            return ;

        var bindZ = function() {
            view.z = Qt.binding(z);
        };
        bindZ();
        view.compositorChanged.connect(bindZ);
    }

    // The view (YuiView.qml), created once; the expanded layer moves into it.
    function createView() {
        var component = Qt.createComponent("YuiView.qml");
        if (component.status !== Component.Ready) {
            console.log("Yui's view unavailable:", component.errorString());
            return ;
        }
        yuiView = component.createObject(widget, {
            "yui": widget
        });
        followHostView(yuiView, function() {
            return widget.hostView ? widget.hostView.z : 0;
        });
        expandedLayer.parent = yuiView.host;
        expandedLayer.anchors.fill = yuiView.host;
        yuiView.closeRequested.connect(function() {
            setChatVisible(false);
        });
        yuiView.folded.connect(function() {
            showChat = false;
            popUpTimer.stop();
            collapsedOut.stop();
            collapsedIn.restart();
        });
    }

    // How SAO Utils treats the widget's implicit size (found with a frame size log):
    // - for a resizable widget it is the minimum size: the frame cannot be dragged smaller;
    // - for a non-resizable widget the frame follows it exactly.
    // So to set the frame size from code, set the implicit size, turn resizing off briefly so the
    // frame takes it, then turn resizing back on and lower the implicit size to a small minimum
    // again (releaseMinimumSize), otherwise the user could never make the widget smaller.
    function applyFrameSize(w, h) {
        widget.implicitWidth = w;
        widget.implicitHeight = h;
        widget.width = w;
        widget.height = h;
        applyingFrameSize = true;
        frameSizeTimer.restart();
    }

    function releaseMinimumSize() {
        // The widget only shows a collapsed form (or a seedling widget): it can be made quite small.
        widget.implicitWidth = seedlingMode ? 20 : 40;
        widget.implicitHeight = seedlingMode ? 20 : 60;
    }

    function showDialog(component, instanceProperty) {
        var dialog = widget[instanceProperty];
        if (dialog) {
            dialog.requestActivate();
            return ;
        }
        dialog = component.createObject(widget, {
            "targetWidget": widget
        });
        if (!dialog) {
            console.log("Error creating settings dialog:", component.errorString());
            return ;
        }
        widget[instanceProperty] = dialog;
        dialog.closing.connect(function() {
            widget[instanceProperty] = null;
        });
    }

    title: seedlingMode ? (widget.settings.seedling_title || qsTr("Seedling Widget")) : qsTr("MHCP-YUI")
    solid: true
    resizable: !applyingFrameSize
    // Implicit size acts as the minimum frame size (see applyFrameSize); set from code only.
    implicitWidth: 60
    implicitHeight: 400
    visible: true
    Component.onDestruction: Link.Server.unregister(widget)
    Component.onCompleted: {
        Qt.callLater(function() {
            widget.previousForm = widget.collapsedForm;
            widget.formChosen = true;
        });
        if (Yui.migrateSeedlingKeys(widget.settings))
            console.log("migrated: lab_* settings renamed to seedling_*");

        // A saved Seedling widget (from "My Widgets") carries seedling_widget; only then is seedling_code shown.
        if ((widget.settings.seedling_widget === true || widget.settings.seedling_widget === "true") && Yui.seedlingCode(widget.settings)) {
            startSeedlingWidget();
            return ;
        }
        // Repair: an earlier version kept the Seedling editor text in Yui's own settings as
        // seedling_code, which turned Yui into a seedling widget. Keep the text as editor text and clear the rest.
        if (widget.settings.seedling_code !== undefined) {
            if (!widget.settings.seedling_editor_code)
                widget.settings.seedling_editor_code = widget.settings.seedling_code;

            ["seedling_code", "seedling_title", "seedling_width", "seedling_height", "seedling_sized"].forEach(function(key) {
                delete widget.settings[key];
            });
            console.log("repaired: Seedling editor text moved out of seedling_code");
        }
        // The SAO Utils action and data (YuiAction.qml, YuiData.qml) reach this Yui through Link.Server.
        Link.Server.register(widget);
        // Apply the default size only once, so a size chosen by the user survives restarts.
        var firstRun = !widget.settings.initialized;
        widget.settings.initialized = true;
        if (!widget.settings.styles)
            widget.settings.styles = JSON.parse(JSON.stringify(defaultValues));
        else
            widget.settings.styles = updateObject(JSON.parse(JSON.stringify(defaultValues)), widget.settings.styles);
        migrateSettings();
        openDatabase();
        backupHeart();
        createView();
        // The frame size itself is restored by SAO Utils.
        if (firstRun)
            applyCollapsedSize(); // lowers the minimum size again once applied
        else
            releaseMinimumSize();
        // Open as it was left: a new widget starts collapsed, the chat reopens only if it was left open.
        if (widget.settings.chat_hidden === false)
            Qt.callLater(openView);

        if (toolsEnabled && widget.settings.raid_end > Date.now()) {
            raidEnd = widget.settings.raid_end;
            raidActive = true;
            if (widget.settings.raid_banner !== false)
                Qt.callLater(showRaidBanner);

        }
        // Bond: the day of meeting is the first day the widget ran, unless the player sets another.
        if (!widget.settings.meeting_day)
            widget.settings.meeting_day = Qt.formatDate(new Date(), "yyyy-MM-dd");

        // The Link Start effect, whenever SAO Utils starts the widget.
        // No sound: SAO Utils plays its own "Link Start!" when it starts.
        linkStartAnimation.start();


        // Continue the saved conversation (welcoming the user back); greet when there is none.
        if (restoreHistory())
            welcomeBack();
        else
            getInitialMessage();
        Qt.callLater(function() {
            widget.firstNewMessage = chatModel.count;
            widget.chatReady = true;
        });
        // The Seedling item shown in Yui, if it was on.
        if (seedlingEnabled && widget.settings.seedling_in_yui && widget.settings.seedling_editor_code)
            loadIntoYui(widget.settings.seedling_editor_code);

    }

    // Any mouse movement over the widget counts as the user being around.
    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                widget.noteActivity();

        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: widget.tick()
    }

    Timer {
        id: saveTimer

        interval: 300
        onTriggered: widget.saveHistory()
    }

    // Fallback confirmation for links / searches, when the system message box is unavailable.
    Dialog {
        id: actionDialog

        // Chat message the dialog is about, and the question shown.
        property int messageIndex: -1
        property string text

        title: qsTr("Navigation")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: widget.runAction(messageIndex)
        onRejected: widget.cancelAction(messageIndex)

        Item {
            implicitWidth: 320
            implicitHeight: actionDialogText.implicitHeight

            Label {
                id: actionDialogText

                width: parent.width
                text: actionDialog.text
                wrapMode: Text.WrapAnywhere
            }

        }

    }

    // Expressions last a while, then Yui returns to her normal face.
    Timer {
        id: emotionTimer

        interval: 90000
        onTriggered: widget.currentEmotion = "normal"
    }

    Loader {
        source: Qt.resolvedUrl("nvg://system/data#power")
        onLoaded: {
            widget.acStatus = item.query("ac-status");
            widget.batteryStatus = item.query("battery-status");
            widget.batteryLevel = item.query("life-time");
        }
    }

    Loader {
        source: Qt.resolvedUrl("nvg://system/data#cpu")
        onLoaded: widget.cpuLoad = item.query("load")
    }

    Loader {
        source: Qt.resolvedUrl("nvg://system/data#gpu")
        onLoaded: widget.gpuLoad = item.query("load")
    }

    Loader {
        source: Qt.resolvedUrl("nvg://system/data#ram")
        onLoaded: widget.ramUsage = item.query("physical")
    }

    Loader {
        source: Qt.resolvedUrl("nvg://system/data#hdd")
        onLoaded: {
            widget.diskSpace = item.query("space");
            widget.diag("storage: " + widget.systemDrive + " space " + widget.readData(widget.diskSpace, widget.systemDrive) + " %");
        }
    }

    Loader {
        source: Qt.resolvedUrl("nvg://system/data#network")
        onLoaded: {
            widget.netDownload = item.query("download");
            widget.netUpload = item.query("upload");
        }
    }

    ListModel {
        id: chatModel
    }

    Timer {
        id: frameSizeTimer

        interval: 200
        onTriggered: {
            widget.applyingFrameSize = false;
            widget.releaseMinimumSize();
        }
    }

    // Navigation pixie (ALO): replaces the character while the chat is hidden, hovering gently.
    NVG.ImageSource {
        id: pixieImage

        property real hover: 0

        configuration: widget.styles.pixie_image_path
        visible: widget.collapsedShown && widget.formVisible("pixie")
        scale: (0.8 + 0.2 * widget.collapsedReveal) * widget.formScale("pixie")
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        fillMode: Image.PreserveAspectFit
        opacity: (widget.sleeping ? 0.6 : 1) * widget.collapsedReveal * widget.formPresence("pixie")

        SequentialAnimation on hover {
            running: pixieImage.visible && !widget.sleeping
            loops: Animation.Infinite

            NumberAnimation {
                from: -5
                to: 5
                duration: 1400
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                from: 5
                to: -5
                duration: 1400
                easing.type: Easing.InOutSine
            }

        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!widget.wakeUp())
                    setChatVisible(true);

            }
        }

        transform: Translate {
            y: pixieImage.hover
        }

    }

    // Yui's Heart crystal: the other collapsed form, colored by CPU / GPU / memory load.
    YuiCrystal {
        id: crystalForm

        visible: widget.collapsedShown && widget.formVisible("crystal")
        anchors.fill: parent
        opacity: widget.collapsedReveal * widget.formPresence("crystal")
        scale: (0.8 + 0.2 * widget.collapsedReveal) * widget.formScale("crystal")
        statusColor: widget.crystalColor
        sleeping: widget.sleeping

        MouseArea {
            id: crystalMouse

            anchors.fill: parent
            onClicked: {
                if (!widget.wakeUp())
                    setChatVisible(true);

            }
        }

    }

    // "Link Start!" when the widget starts: Yui's Heart, the crystal her core was saved in,
    // glows into view, bursts into motes of light, and Yui appears in the flash.
    Item {
        id: linkStartEffect

        property real progress: 0
        // The crystal's height: a third of the widget's shorter side.
        readonly property real crystalSize: Math.min(width, height) / 3
        // With the crystal as her collapsed form it is turned around: the motes gather into the flash
        // (0 - 0.55) and the crystal grows in it, so the crystal never breaks and comes back.
        readonly property bool gather: widget.collapsedForm === "crystal"

        anchors.fill: parent
        z: 200
        visible: linkStartAnimation.running

        // The crystal: in (0 - 0.3), glowing and pulsing (0.3 - 0.55), gone in the burst (0.55 - 0.62).
        YuiCrystal {
            readonly property real grown: Math.min(1, linkStartEffect.progress / 0.3)

            visible: !linkStartEffect.gather
            anchors.centerIn: parent
            width: linkStartEffect.crystalSize * 0.67
            height: linkStartEffect.crystalSize
            statusColor: "#B3E5FC"
            opacity: grown * Math.max(0, Math.min(1, (0.62 - linkStartEffect.progress) / 0.07))
            scale: 0.6 + 0.4 * grown + (linkStartEffect.progress > 0.3 ? 0.06 * Math.sin(linkStartEffect.progress * 40) : 0)
        }

        // The burst: motes of light flying out from the crystal and fading (0.55 - 1); or gathering
        // from afar, brightening as they come (0 - 0.55).
        Repeater {
            model: 28

            Rectangle {
                readonly property real burst: linkStartEffect.gather ? Math.max(0, 1 - linkStartEffect.progress / 0.55) : Math.max(0, Math.min(1, (linkStartEffect.progress - 0.55) / 0.45))
                // Each mote its own direction and reach, the same every time.
                readonly property real angle: index * 2.399963
                readonly property real reach: Math.min(linkStartEffect.width, linkStartEffect.height) * (0.25 + 0.25 * ((index * 7) % 11) / 10)
                readonly property real travel: 1 - Math.pow(1 - burst, 3)

                visible: burst > 0
                width: 3 + (index % 4) * 1.5
                height: width
                rotation: 45
                x: linkStartEffect.width / 2 - width / 2 + Math.cos(angle) * reach * travel
                y: linkStartEffect.height / 2 - height / 2 + Math.sin(angle) * reach * travel
                color: index % 3 === 0 ? "#FFFFFF" : (index % 3 === 1 ? "#B3E5FC" : "#FFF59D")
                opacity: (linkStartEffect.gather ? Math.min(1, (1 - burst) * 4) * Math.min(1, burst * 6) : 1 - burst) * 0.95
            }

        }

        // The flash Yui appears in: a soft round light, fading out to its edge (a blurred circle was cut
        // square at the edge of its layer).
        RadialGradient {
            readonly property real flash: linkStartEffect.progress < 0.55 ? 0 : Math.max(0, 1 - (linkStartEffect.progress - 0.55) / 0.3)

            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * (0.3 + 0.7 * (1 - flash))
            height: width
            visible: flash > 0
            opacity: flash * 0.8

            gradient: Gradient {
                GradientStop { position: 0; color: "#FFFFFFFF" }
                GradientStop { position: 0.25; color: "#C0FFFFFF" }
                GradientStop { position: 0.5; color: "#00FFFFFF" }
            }
        }

        NumberAnimation {
            id: linkStartAnimation

            target: linkStartEffect
            property: "progress"
            from: 0
            to: 1
            duration: 2800
        }

    }

    // Switching between the crystal and the character: a point of light the old form shrinks into and the
    // new one grows out of. Into the crystal the motes gather to it; out of it they fly away.
    Item {
        id: formSwitchEffect

        readonly property bool toCrystal: widget.collapsedForm === "crystal"
        readonly property real glow: Math.max(0, 1 - Math.abs(widget.formMorph - 0.45) / 0.3)

        anchors.fill: parent
        z: 200
        visible: widget.morphing

        RadialGradient {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * (0.2 + 0.6 * formSwitchEffect.glow)
            height: width
            opacity: formSwitchEffect.glow * 0.9

            gradient: Gradient {
                GradientStop { position: 0; color: "#FFFFFFFF" }
                GradientStop { position: 0.25; color: formSwitchEffect.toCrystal ? "#C0B3E5FC" : "#C0FFF59D" }
                GradientStop { position: 0.5; color: "#00FFFFFF" }
            }
        }

        Repeater {
            model: 16

            Rectangle {
                // 0 at the center, 1 out at the mote's reach: coming in (0 - 0.45) into the crystal,
                // going out (0.45 - 1) from it.
                readonly property real out: formSwitchEffect.toCrystal ? Math.max(0, 1 - widget.formMorph / 0.45) : Math.max(0, Math.min(1, (widget.formMorph - 0.45) / 0.55))
                readonly property real angle: index * 2.399963
                readonly property real reach: Math.min(formSwitchEffect.width, formSwitchEffect.height) * (0.3 + 0.2 * ((index * 7) % 11) / 10)
                readonly property real travel: 1 - Math.pow(1 - out, 3)

                visible: out > 0
                width: 3 + (index % 3) * 1.5
                height: width
                rotation: 45
                x: formSwitchEffect.width / 2 - width / 2 + Math.cos(angle) * reach * travel
                y: formSwitchEffect.height / 2 - height / 2 + Math.sin(angle) * reach * travel
                color: index % 2 ? "#FFFFFF" : (formSwitchEffect.toCrystal ? "#B3E5FC" : "#FFF59D")
                opacity: (formSwitchEffect.toCrystal ? Math.min(1, (1 - out) * 4) * Math.min(1, out * 6) : 1 - out) * 0.95
            }

        }

        NumberAnimation {
            id: formMorphAnimation

            target: widget
            property: "formMorph"
            from: 0
            to: 1
            duration: 1400
        }

    }

    // Boss Raid's clock.
    Timer {
        interval: 1000
        repeat: true
        running: widget.raidActive || widget.resting
        onTriggered: widget.checkRaid(Date.now())
    }

    // Weather Report: the chosen weather values (Mental Health Counseling), as text.
    NVG.DataSource {
        id: weatherSource

        configuration: widget.settings.weather_report === false ? null : (widget.settings.weather_data || null)
    }

    NVG.DataSourceTextOutput {
        id: weatherText

        source: weatherSource
        nullText: ""
        undefinedText: ""
    }

    NVG.DataSource {
        id: temperatureSource

        configuration: widget.settings.weather_report === false ? null : (widget.settings.weather_temperature || null)
    }

    NVG.DataSourceTextOutput {
        id: temperatureText

        source: temperatureSource
        nullText: ""
        undefinedText: ""
        fixedDecimalDigits: 0
    }

    // The weather values are read now and every 10 minutes (whatever their own update interval).
    Timer {
        interval: 600000
        repeat: true
        triggeredOnStart: true
        running: !!weatherSource.configuration || !!temperatureSource.configuration
        onTriggered: {
            if (weatherSource.configuration)
                weatherSource.update();

            if (temperatureSource.configuration)
                temperatureSource.update();

        }
    }

    // Media: Media Player's System Media Data (not ready when the package is missing).
    Loader {
        id: mediaData

        active: widget.settings.media_control === true || widget.settings.now_playing !== false
        source: Qt.resolvedUrl("nvg://media.gpbeta.com/data/player#system")
        onStatusChanged: {
            if (status === Loader.Error)
                widget.diag("media: Media Player (com.gpbeta.media) not found");

        }
    }

    // Media: one System Media Control action per command, loaded ahead so it runs at once.
    Instantiator {
        id: mediaActions

        model: widget.mediaReady ? widget.mediaCommands : []

        delegate: NVG.ActionSource {
            configuration: ({
                "source": "nvg://media.gpbeta.com/action/player#system",
                "data": modelData
            })
        }

    }

    // Sword Skills (Skill Slots): the action of each slot, loaded ahead so it runs at once.
    Instantiator {
        id: swordSkillSources

        model: 5

        delegate: NVG.ActionSource {
            configuration: widget.settings["sword_skill_" + (index + 1) + "_action"] || null
        }

    }

    // Weekly Report (automatic, Sunday evenings), checked every 10 minutes.
    Timer {
        interval: 600000
        repeat: true
        running: widget.chatReady && !widget.seedlingMode
        onTriggered: widget.checkWeeklyReport()
    }

    // Alarm (Skill Slots): rings the due reminders, checked every 15 s (and once at start, for the
    // ones missed while SAO Utils was closed).
    Timer {
        interval: 15000
        repeat: true
        triggeredOnStart: true
        running: widget.toolsEnabled && widget.chatReady && !widget.seedlingMode && widget.settings.alarm_enabled !== false
        onTriggered: widget.checkAlarms(Date.now())
    }

    // Keeps the crystal color current while it is shown.
    Timer {
        interval: 1000
        running: crystalForm.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: widget.sampleLoad()
    }

    // "Zzz" floating up from a sleeping Yui.
    Item {
        id: sleepMark

        // Over the collapsed form (in the view a sleeping Yui is shown dimmed or by her sleep image).
        readonly property Item target: crystalForm.visible ? crystalForm : (pixieImage.visible ? pixieImage : avatarImage)

        visible: widget.sleeping && !showChat
        x: target.x + target.width * 0.62
        y: target.y + target.height * 0.12
        width: 40
        height: 60

        Repeater {
            model: 3

            Text {
                id: zText

                text: "z"
                color: "#FFFFFF"
                style: Text.Outline
                styleColor: "#80000000"
                font.pixelSize: 14 + index * 5
                font.bold: true
                x: index * 10
                opacity: 0

                SequentialAnimation on opacity {
                    running: sleepMark.visible
                    loops: Animation.Infinite

                    PauseAnimation {
                        duration: index * 600
                    }

                    NumberAnimation {
                        from: 0
                        to: 1
                        duration: 600
                    }

                    NumberAnimation {
                        from: 1
                        to: 0
                        duration: 1200
                    }

                    PauseAnimation {
                        duration: (2 - index) * 600
                    }

                }

                SequentialAnimation on y {
                    running: sleepMark.visible
                    loops: Animation.Infinite

                    PauseAnimation {
                        duration: index * 600
                    }

                    NumberAnimation {
                        from: 40 - index * 12
                        to: 20 - index * 12
                        duration: 1800
                    }

                    PauseAnimation {
                        duration: (2 - index) * 600
                    }

                }

            }

        }

    }

    // Yui's expanded form (character and chat), shown in its own view (YuiView.qml): at start it is
    // moved into the view, which opens when her collapsed form is clicked.
    Item {
        id: expandedLayer

        anchors.fill: parent
        visible: !seedlingMode

        NVG.BackgroundSource {
            id: backgroundImage

            anchors.fill: parent
            z: -1
            configuration: widget.styles.background_image_path
        }

        NVG.ImageSource {
            id: characterImage


            // Sleeping image, else the current expression's image, else the main character image.
            configuration: {
                var styles = widget.styles;
                if (widget.sleeping && widget.hasImage(styles.sleep_image_path))
                    return styles.sleep_image_path;

                var expression = styles["expression_" + widget.currentEmotion];
                if (widget.currentEmotion !== "normal" && widget.hasImage(expression))
                    return expression;

                return styles.character_image_path;
            }
            // Without a sleeping image, a sleeping Yui is drawn dimmed (with the "Zzz" below); she also
            // fades in and out with the view (characterReveal).
            property real dim: widget.sleeping && !widget.hasImage(widget.styles.sleep_image_path) ? 0.6 : 1
            // Like the navigation pixie: she floats gently up and down while awake (only upward, so the
            // bottom of the image is never cut off), and grows in from 80 % as the view opens.
            property real hover: 0
            // System Call effects: Enhance Armament's glow (0 … 1) and Release Recollection's shaking (px).
            property real aura: 0
            property real shake: 0

            opacity: dim * widget.characterReveal
            scale: 0.8 + 0.2 * widget.characterReveal
            transform: Translate {
                x: characterImage.shake
                y: characterImage.hover
            }
            // The glow is drawn only while it is shown.
            layer.enabled: aura > 0
            layer.effect: Glow {
                color: "#FFD54F"
                radius: 24
                samples: 49
                spread: 0.35
                opacity: characterImage.aura
            }

            // Enhance Armament: the glow rises, stays a moment and fades.
            SequentialAnimation {
                id: auraAnimation

                NumberAnimation {
                    target: characterImage
                    property: "aura"
                    to: 1
                    duration: 400
                    easing.type: Easing.OutQuad
                }

                PauseAnimation {
                    duration: 1200
                }

                NumberAnimation {
                    target: characterImage
                    property: "aura"
                    to: 0
                    duration: 900
                    easing.type: Easing.InQuad
                }

            }

            // Release Recollection: a short shaking that dies down.
            SequentialAnimation {
                id: shakeAnimation

                NumberAnimation {
                    target: characterImage
                    property: "shake"
                    to: -8
                    duration: 45
                }

                NumberAnimation {
                    target: characterImage
                    property: "shake"
                    to: 8
                    duration: 90
                }

                NumberAnimation {
                    target: characterImage
                    property: "shake"
                    to: -6
                    duration: 80
                }

                NumberAnimation {
                    target: characterImage
                    property: "shake"
                    to: 6
                    duration: 80
                }

                NumberAnimation {
                    target: characterImage
                    property: "shake"
                    to: -3
                    duration: 70
                }

                NumberAnimation {
                    target: characterImage
                    property: "shake"
                    to: 0
                    duration: 70
                }

            }
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            // Room above her for floating (hover goes up to -10), so her head is never cut off.
            height: parent.height - 10
            // Size the item to the image as actually drawn, so the chat area starts right next to it
            // whatever the image resolution is. Never take more than half of the widget, leave the chat
            // column enough room for its input row, but never get narrower than characterMinimumWidth
            // (the image is centered in that space when it is drawn narrower).
            width: Math.max(widget.characterMinimumWidth, Math.min(widget.characterNaturalWidth, parent.width * 0.5, parent.width - widget.chatPanelMinimumWidth - 20))
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter

            SequentialAnimation on hover {
                running: widget.showChat && !widget.sleeping
                loops: Animation.Infinite

                NumberAnimation {
                    from: 0
                    to: -10
                    duration: 1400
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    from: -10
                    to: 0
                    duration: 1400
                    easing.type: Easing.InOutSine
                }

            }

            // Grabbing Yui and dragging moves the view (as the title bar does). A click without dragging
            // wakes a sleeping Yui, or closes the chat (back to the collapsed form) like the title and Esc.
            MouseArea {
                property point pressPoint
                property bool dragging: false

                anchors.fill: parent
                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed: {
                    dragging = false;
                    pressPoint = mapToGlobal(mouse.x, mouse.y);
                    if (widget.yuiView)
                        widget.yuiView.beginMove(pressPoint);

                }
                onPositionChanged: {
                    if (!pressed || !widget.yuiView)
                        return ;

                    var now = mapToGlobal(mouse.x, mouse.y);
                    if (!dragging && Math.abs(now.x - pressPoint.x) + Math.abs(now.y - pressPoint.y) > 4)
                        dragging = true;

                    if (dragging)
                        widget.yuiView.moveTo(now);

                }
                onReleased: {
                    if (dragging) {
                        if (widget.yuiView)
                            widget.yuiView.endMove();

                    } else if (!widget.wakeUp()) {
                        widget.setChatVisible(false);
                    }
                    dragging = false;
                }
            }

            Behavior on dim {
                NumberAnimation {
                    duration: 600
                }

            }

        }

        // Sacred Arts element conjured by the "System Call" easter egg (Alicization).
        Item {
            id: elementEffect

            property color color: "white"

            function play(newColor, burst) {
                color = newColor;
                burstAnimation.stop();
                conjureAnimation.stop();
                (burst ? burstAnimation : conjureAnimation).restart();
            }

            z: 50
            width: 60
            height: 60
            x: characterImage.x + characterImage.width / 2 - width / 2
            y: characterImage.y + characterImage.height * 0.45 - height / 2
            scale: 0
            opacity: 0

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.8
                height: width
                radius: width / 2
                color: elementEffect.color
                opacity: 0.25
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: width
                radius: width / 2
                color: elementEffect.color
                opacity: 0.6
                border.color: "white"
                border.width: 2
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.4
                height: width
                radius: width / 2
                color: "white"
            }

            SequentialAnimation {
                id: conjureAnimation

                ParallelAnimation {
                    NumberAnimation {
                        target: elementEffect
                        property: "scale"
                        from: 0
                        to: 1
                        duration: 400
                        easing.type: Easing.OutBack
                    }

                    NumberAnimation {
                        target: elementEffect
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 300
                    }

                }

                SequentialAnimation {
                    loops: 3

                    NumberAnimation {
                        target: elementEffect
                        property: "scale"
                        to: 1.15
                        duration: 350
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: elementEffect
                        property: "scale"
                        to: 1
                        duration: 350
                        easing.type: Easing.InOutSine
                    }

                }

                NumberAnimation {
                    target: elementEffect
                    property: "opacity"
                    to: 0
                    duration: 600
                }

            }

            ParallelAnimation {
                id: burstAnimation

                NumberAnimation {
                    target: elementEffect
                    property: "scale"
                    from: 0.5
                    to: 6
                    duration: 700
                    easing.type: Easing.OutQuad
                }

                NumberAnimation {
                    target: elementEffect
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 700
                    easing.type: Easing.InQuad
                }

            }

        }

        // The chat panel, in the three parts of the SAO mail box message panel (panel.9.png): a white
        // title bar ("Message"), the darker gray message area, a white input bar. It is centered
        // vertically, and opening unfolds only the middle
        // (chatReveal): the title and input bars keep their size and move apart. While opening it also
        // widens from the middle (chatScaleX) and fades in (chatPanelOpacity).
        Item {
            id: chatPanel

            readonly property real titleHeight: 44
            readonly property real inputHeight: inputArea.height + 16
            readonly property real fullHeight: parent.height - 8

            anchors.left: characterImage.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: titleHeight + inputHeight + (fullHeight - titleHeight - inputHeight) * widget.chatReveal
            opacity: widget.chatPanelOpacity

            // Background, drawn after the SAO panel image of SAO Utils' bangumi widget (Information
            // panel, panel.9.png, measured pixel by pixel): a soft outer shadow, a gray edge with a white
            // highlight inside, the white title bar over a dark line and an inner shadow into the gray
            // message area, the gray darkening toward the input bar over a dark and a light line, and the
            // white input bar. All of it is 80 % opaque (chatOpacity, Equipment), as the image; the text
            // and messages are not.
            // Outer shadow: a smooth 8 px glow, black from about 12 % next to the panel to nothing
            // (separate rings showed visible steps).
            RectangularGlow {
                anchors.fill: parent
                glowRadius: 8
                spread: 0
                cornerRadius: 8
                color: "#1E000000"
            }

            Item {
                id: chatPanelBackground

                anchors.fill: parent
                opacity: widget.chatOpacity
                // Drawn as one layer and then made 80 % opaque: without it each part got the opacity on
                // its own, so the inner shadows lying over the gray showed through twice and ended in
                // visible lines about 12 px inside the title and input bars.
                layer.enabled: true

                // Gray edge, then a white highlight inside it.
                Rectangle {
                    anchors.fill: parent
                    color: "#DDDDDD"
                    border.color: "#BBBBBB"
                    border.width: 1
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    color: "transparent"
                    border.color: "#FFFFFF"
                    border.width: 1
                }

                // Title bar.
                Rectangle {
                    id: titleBar

                    x: 2
                    y: 2
                    width: parent.width - 4
                    height: chatPanel.titleHeight - 3
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#F8F8F8"
                        }

                        GradientStop {
                            position: 1
                            color: "#FCFCFC"
                        }

                    }
                }

                // Dark line under the title bar, then an inner shadow into the message area.
                Rectangle {
                    x: 2
                    y: titleBar.y + titleBar.height
                    width: parent.width - 4
                    height: 1
                    color: "#BCBCBC"
                }

                Rectangle {
                    x: 2
                    y: titleBar.y + titleBar.height + 1
                    width: parent.width - 4
                    height: Math.min(12, Math.max(0, inputBar.y - y - 2))
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#C3C3C3"
                        }

                        GradientStop {
                            position: 1
                            color: "#DDDDDD"
                        }

                    }
                }

                // The message area darkening toward the input bar, then a dark and a light line.
                Rectangle {
                    x: 2
                    y: inputBar.y - 2 - height
                    width: parent.width - 4
                    height: Math.min(12, Math.max(0, inputBar.y - 2 - (titleBar.y + titleBar.height + 1)))
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#DDDDDD"
                        }

                        GradientStop {
                            position: 1
                            color: "#C8C8C8"
                        }

                    }
                }

                Rectangle {
                    x: 2
                    y: inputBar.y - 2
                    width: parent.width - 4
                    height: 1
                    color: "#C0C0C0"
                }

                Rectangle {
                    x: 2
                    y: inputBar.y - 1
                    width: parent.width - 4
                    height: 1
                    color: "#E3E3E3"
                }

                // Input bar.
                Rectangle {
                    id: inputBar

                    x: 2
                    y: parent.height - 2 - height
                    width: parent.width - 4
                    height: chatPanel.inputHeight - 4
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#F4F4F4"
                        }

                        GradientStop {
                            position: 1
                            color: "#F8F8F8"
                        }

                    }
                }

            }

            Text {
                id: chatPanelTitle

                anchors.horizontalCenter: parent.horizontalCenter
                y: 9
                text: "Message"
                color: "#8C8C8C"
                font.family: "SAO UI"
                font.pixelSize: 20
            }

            // The title bar: a click closes the view (as the Information panel of SAO Utils' bangumi
            // widget, which closes on a click), pressing and dragging moves it. A press counts as a drag
            // once the mouse has moved more than dragThreshold px; Esc also closes.
            MouseArea {
                property point pressPoint
                property bool dragging: false
                readonly property real dragThreshold: 4

                width: parent.width
                height: chatPanel.titleHeight
                hoverEnabled: true
                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                onPressed: {
                    dragging = false;
                    pressPoint = mapToGlobal(mouse.x, mouse.y);
                    if (widget.yuiView)
                        widget.yuiView.beginMove(pressPoint);

                }
                onPositionChanged: {
                    if (!pressed || !widget.yuiView)
                        return ;

                    var now = mapToGlobal(mouse.x, mouse.y);
                    if (!dragging && Math.abs(now.x - pressPoint.x) + Math.abs(now.y - pressPoint.y) > dragThreshold)
                        dragging = true;

                    if (dragging)
                        widget.yuiView.moveTo(now);

                }
                onReleased: {
                    if (dragging) {
                        if (widget.yuiView)
                            widget.yuiView.endMove();

                    } else {
                        setChatVisible(false);
                    }
                    dragging = false;
                }
            }

            transform: Scale {
                origin.x: chatPanel.width / 2
                origin.y: chatPanel.height / 2
                xScale: widget.chatScaleX
            }

        }

        // The message list (in the panel's middle) and the input row (in its input bar), placed over the
        // panel and scaled / faded with it.
        ColumnLayout {
            id: chatContainer

            anchors.fill: chatPanel
            anchors.topMargin: chatPanel.titleHeight + 6
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            anchors.bottomMargin: 8
            spacing: 16
            opacity: widget.chatPanelOpacity

            transform: Scale {
                origin.x: chatPanel.width / 2 - 8
                origin.y: chatContainer.height / 2
                xScale: widget.chatScaleX
            }

            ListView {
                id: chatView

                Layout.fillWidth: true
                Layout.fillHeight: true
                model: chatModel
                spacing: 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Keep every bubble created: with only the visible ones, ListView estimates the content
                // height from their average, which keeps changing with long bubbles and makes the scroll
                // bar jump (the chat holds few messages, so this is cheap).
                cacheBuffer: 100000
                // The messages fade in once the panel has unfolded.
                opacity: widget.messagesOpacity

                ScrollBar.vertical: SaoScrollBar {
                    id: chatScrollBar

                    onLight: true
                }

                // Each message is an SAO instant message window (MessageWindow.qml): Yui's on the left, the
                // user's on the right. Messages added after start-up pop up (Yui's with the message sound).
                delegate: Item {
                    id: messageItem

                    readonly property bool fromUser: model.author === "user"
                    readonly property var action: model.action ? JSON.parse(model.action) : null

                    width: chatView.width
                    height: messageWindow.height

                    MessageWindow {
                        id: messageWindow

                        anchors.left: messageItem.fromUser ? undefined : parent.left
                        anchors.right: messageItem.fromUser ? parent.right : undefined
                        // Room for the pointers; the user's windows also stay clear of the scroll bar.
                        anchors.leftMargin: tailSize
                        anchors.rightMargin: 16 + tailSize
                        // Message windows keep their size when the chat panel is wider: at most as wide as
                        // the original chat column (chatMinimumWidth).
                        maximumWidth: Math.min(chatView.width - 48, Math.max(260, widget.chatMinimumWidth))
                        tailSide: messageItem.fromUser ? "right" : "left"
                        // Names in the title bars are English, like "Yui": "Papa" or "Mama".
                        sender: messageItem.fromUser ? (widget.settings.user_title === "mama" ? "Mama" : "Papa") : "Yui"
                        text: model.message
                        linkedText: Yui.linkify(model.message, "#1565C0")
                        note: model.note
                        actionLabel: widget.actionLabel(messageItem.action)
                        actionState: model.actionState
                        thinking: model.pending
                        canRegenerate: !messageItem.fromUser && !model.local && index === chatModel.count - 1 && !widget.busy
                        // Quick Replies: under Yui's latest message only, while nothing else is going on.
                        suggestions: !messageItem.fromUser && model.suggestions && index === chatModel.count - 1 && !widget.busy ? JSON.parse(model.suggestions) : []
                        fontFamily: widget.fontFamilyOf(widget.styles.bubble_font_family)
                        fontSize: widget.styles.bubble_font_size > 0 ? widget.styles.bubble_font_size : widget.defaultValues.bubble_font_size
                        fontStyle: widget.styles.bubble_font_style || {
                        }
                        onLinkActivated: widget.openMessageLink(link)
                        onConfirmRequested: widget.confirmAction(index)
                        onRegenerateRequested: widget.regenerateReply()
                        onSuggestionPicked: widget.sendMessage(text)
                    }

                    // "..." (a reply on its way) is not a message: it shows without popping up; the window pops
                    // up with the message sound once the text arrives. The user's own messages pop up the same
                    // way, without the sound.
                    readonly property bool pending: model.pending

                    onPendingChanged: {
                        if (!pending && widget.chatReady)
                            messageWindow.popUp(!messageItem.fromUser && widget.messageSounds);

                    }
                    // Every message added after start-up pops up (several can be added at once, e.g.
                    // the user's message and Yui's "..."); the user's without a sound.
                    Component.onCompleted: {
                        if (widget.chatReady && index >= widget.firstNewMessage && !pending)
                            messageWindow.popUp(!messageItem.fromUser && widget.messageSounds);

                    }
                }

                // Stay at the bottom when new content arrives, unless the user scrolled up to read.
                property bool stickToBottom: true
                // True while the view scrolls itself to the end (not the user scrolling).
                property bool scrollingToEnd: false

                function scrollToEnd() {
                    scrollingToEnd = true;
                    positionViewAtEnd();
                    scrollingToEnd = false;
                }

                // Any scrolling by the user (dragging the list or the scroll bar, the mouse wheel) decides
                // whether to keep following new content: only when it ends at the bottom.
                onContentYChanged: {
                    if (!scrollingToEnd && (moving || chatScrollBar.pressed))
                        stickToBottom = atYEnd;

                }
                onMovementEnded: stickToBottom = atYEnd
                onContentHeightChanged: {
                    if (stickToBottom)
                        Qt.callLater(scrollToEnd);

                }
            }

            RowLayout {
                id: inputArea

                Layout.fillWidth: true
                // Nested layouts fill the height by default; keep the input row at a fixed height
                // so the chat list gets all the remaining space.
                Layout.fillHeight: false
                Layout.topMargin: 6
                spacing: 8

                // Multi-line input: Enter sends, Shift+Enter starts a new line. Grows to about four lines.
                Rectangle {
                    id: inputBox

                    Layout.fillWidth: true
                    Layout.minimumWidth: widget.inputMinimumWidth
                    Layout.preferredHeight: Math.min(Math.max(40, textInput.implicitHeight), 100)
                    Layout.alignment: Qt.AlignBottom
                    color: "#ffffffff"
                    radius: 20

                    ScrollView {
                        id: inputScroll

                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        clip: true
                        // No scroll bars in the input box (it still scrolls with the wheel / cursor): both
                        // are plain bars that are never shown and take no room.
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                            visible: false
                            width: 0
                        }
                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                            visible: false
                            height: 0
                        }

                        TextArea {
                            id: textInput

                            // ↑ / ↓ go through your sent messages (widget.sentHistory()), as in command line AI
                            // tools: index -1 is the text being written (draft), kept while browsing.
                            property var history: []
                            property int historyIndex: -1
                            property string draft

                            function submit() {
                                if (sendMessage(text)) {
                                    text = "";
                                    historyIndex = -1;
                                }
                            }

                            // step 1: older, -1: newer. Returns false at either end (the key then does
                            // what it normally does).
                            function browseHistory(step) {
                                if (historyIndex === -1) {
                                    if (step < 0)
                                        return false;

                                    history = widget.sentHistory();
                                    draft = text;
                                }
                                var next = historyIndex + step;
                                if (next >= history.length || next < -1)
                                    return false;

                                historyIndex = next;
                                text = next === -1 ? draft : history[next];
                                cursorPosition = length;
                                return true;
                            }

                            // Whether the cursor is on the first / last line (a multi-line message moves
                            // the cursor between its lines first).
                            function onFirstLine() {
                                return positionToRectangle(cursorPosition).y <= positionToRectangle(0).y;
                            }

                            function onLastLine() {
                                return positionToRectangle(cursorPosition).y >= positionToRectangle(length).y;
                            }

                            function handleReturn(event) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    insert(cursorPosition, "\n");
                                else
                                    submit();
                                event.accepted = true;
                            }

                            placeholderText: qsTr("Message to Yui...")
                            color: "black"
                            wrapMode: TextArea.Wrap
                            selectByMouse: true
                            leftPadding: 10
                            rightPadding: 10
                            topPadding: 10
                            bottomPadding: 10
                            background: null
                            Keys.onReturnPressed: handleReturn(event)
                            Keys.onEnterPressed: handleReturn(event)
                            Keys.onUpPressed: event.accepted = onFirstLine() && browseHistory(1)
                            Keys.onDownPressed: event.accepted = onLastLine() && browseHistory(-1)
                        }

                    }

                }

                Button {
                    id: sendButton

                    // As wide as its longer label ("Send" / "Cancel"): its width used to change with
                    // the label when a reply started, and with it the chat's minimum width, which
                    // shifted the character and the chat panel. The text field is what shrinks when
                    // space runs out.
                    Layout.minimumWidth: widget.sendButtonWidth
                    Layout.preferredWidth: widget.sendButtonWidth
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignBottom
                    // Turns into a stop button while a reply is being generated.
                    text: widget.busy ? qsTr("Cancel") : qsTr("Send")
                    enabled: widget.busy || textInput.text.trim().length > 0
                    onClicked: {
                        if (widget.busy)
                            widget.stopReply();
                        else
                            textInput.submit();
                        textInput.forceActiveFocus();
                    }
                }

                Button {
                    id: clearButton

                    Layout.minimumWidth: implicitWidth
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignBottom
                    text: qsTr("Reset Log")
                    onClicked: clearChat()
                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }

            }

        }

        // Where the Seedling item is shown in Yui (see loadIntoYui): over the expanded form, at the saved
        // position. While hovered a thin bar appears above it: drag it to move the item in the widget.
        Item {
            id: seedlingSlot

            z: 30
            visible: (widget.settingsRevision, !seedlingMode && showChat && !!widget.yuiSeedlingItem && widget.settings.seedling_in_yui === true)
            x: Math.max(0, Math.min(expandedLayer.width - width, widget.settings.seedling_slot_x !== undefined ? widget.settings.seedling_slot_x : 16))
            y: Math.max(14, Math.min(expandedLayer.height - height, widget.settings.seedling_slot_y !== undefined ? widget.settings.seedling_slot_y : 30))
            width: widget.yuiSeedlingItem ? widget.yuiSeedlingItem.width : 0
            height: widget.yuiSeedlingItem ? widget.yuiSeedlingItem.height : 0

            HoverHandler {
                id: seedlingSlotHover
            }

            Rectangle {
                z: 100
                y: -14
                width: Math.max(60, parent.width)
                height: 14
                radius: 4
                color: "#CC1A1D24"
                opacity: seedlingSlotHover.hovered || seedlingSlotDrag.pressed ? 1 : 0

                Text {
                    anchors.centerIn: parent
                    text: "⠿ " + qsTr("Seedling")
                    color: "#DDFFFFFF"
                    font.pixelSize: 9
                }

                MouseArea {
                    id: seedlingSlotDrag

                    property point start
                    property point origin

                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    onPressed: {
                        start = mapToItem(expandedLayer, mouse.x, mouse.y);
                        origin = Qt.point(seedlingSlot.x, seedlingSlot.y);
                    }
                    onPositionChanged: {
                        var now = mapToItem(expandedLayer, mouse.x, mouse.y);
                        seedlingSlot.x = Math.max(0, Math.min(expandedLayer.width - seedlingSlot.width, origin.x + now.x - start.x));
                        seedlingSlot.y = Math.max(14, Math.min(expandedLayer.height - seedlingSlot.height, origin.y + now.y - start.y));
                    }
                    onReleased: {
                        widget.settings.seedling_slot_x = Math.round(seedlingSlot.x);
                        widget.settings.seedling_slot_y = Math.round(seedlingSlot.y);
                    }
                }

            }

        }

    }

    // The character as a collapsed form ("avatar"), in the widget itself.
    NVG.ImageSource {
        id: avatarImage

        configuration: characterImage.configuration
        visible: widget.collapsedShown && widget.formVisible("avatar")
        opacity: characterImage.opacity * widget.collapsedReveal * widget.formPresence("avatar")
        scale: (0.8 + 0.2 * widget.collapsedReveal) * widget.formScale("avatar")
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!widget.wakeUp())
                    setChatVisible(true);

            }
        }

    }

    menu: seedlingMode ? seedlingMenu : yuiMenu

    // A seedling widget's menu: only the Seedling.
    Menu {
        id: seedlingMenu

        Action {
            text: qsTr("Seedling") + "..."
            onTriggered: showDialog(widget.seedlingDialog, "seedlingDialogInstance")
        }

    }

    Menu {
        id: yuiMenu

        Action {
            text: qsTr("Cardinal System") + "..."
            onTriggered: showDialog(widget.cardinalSystemDialog, "cardinalSystemDialogInstance")
        }

        Action {
            text: qsTr("Equipment") + "..."
            onTriggered: showDialog(widget.equipmentDialog, "equipmentDialogInstance")
        }

        Action {
            text: qsTr("Yui's Heart") + "..."
            onTriggered: showDialog(widget.yuisHeartDialog, "yuisHeartDialogInstance")
        }

        Action {
            text: qsTr("Mental Health Counseling") + "..."
            onTriggered: showDialog(widget.counselingDialog, "counselingDialogInstance")
        }

        // Skill Slots (set aside, see toolsEnabled): its menu entry goes back here, after Mental Health
        // Counseling.

        // Seedling (set aside, see seedlingEnabled): its menu entry goes back here, before System Console.
        Action {
            text: qsTr("System Console") + "..."
            onTriggered: showDialog(widget.systemConsoleDialog, "systemConsoleDialogInstance")
        }

    }

}
