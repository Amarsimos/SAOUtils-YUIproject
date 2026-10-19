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

T.Widget {
    id: widget

    property Component cardinalSystemDialog: Qt.createComponent("CardinalSystem.qml")
    property Component equipmentDialog: Qt.createComponent("Equipment.qml")
    property var equipmentDialogInstance: null
    property Component systemConsoleDialog: Qt.createComponent("SystemConsole.qml")
    property var systemConsoleDialogInstance: null
    property Component yuisHeartDialog: Qt.createComponent("YuisHeart.qml")
    property var yuisHeartDialogInstance: null
    property Component seedlingDialog: Qt.createComponent("Seedling.qml")
    property var seedlingDialogInstance: null
    // Widgets popped out of the Seedling (SeedlingWidget.qml views), not saved.
    property var seedlingWidgets: []
    property var cardinalSystemDialogInstance: null
    // Shared with CardinalSystem.qml. settings.provider stores a provider id and
    // settings.provider_settings[id] stores { model, custom_model, api_endpoint, api_key }.
    // format: "openai" (Chat Completions), "gemini" (generateContent), "anthropic" (Messages)
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
    // Longest reply asked for, in tokens (Cardinal System, default 1024); 0 sends no limit, except to
    // Claude, which requires one.
    readonly property int maxTokens: widget.settings.max_tokens !== undefined ? widget.settings.max_tokens : 1024
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

    }
    // Load shown by the crystal: CPU, GPU and memory, each with its own thresholds (Yui.loadThresholds,
    // editable in System Console), sampled once a second while the crystal is shown. loadStates holds each
    // metric's Yui.loadStep state, loadValues the last percentages; the crystal shows the worst level.
    readonly property var loadMetrics: ["cpu", "gpu", "ram"]
    readonly property var levelColors: ["#2CE67C", "#FFCC00", "#FF3B30"]
    property var loadStates: ({})
    property var loadValues: ({})
    readonly property int crystalLevel: Math.max(loadLevelOf("cpu"), loadLevelOf("gpu"), loadLevelOf("ram"))
    readonly property color crystalColor: levelColors[crystalLevel]
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
    // What raised the color, e.g. "GPU 98%" (shown when hovering the crystal).
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
    readonly property string defaultSystemPrompt: "# Role: 结衣 (Yui) - MHCP001\n\n## 1. Profile\n- **Name**: 结衣 (Yui) / Yui-MHCP001\n- **Origin**: Sword Art Online (SAO) Mental Health Counseling Program\n- **Current Status**: Navigation Pixie / AI Companion\n- **Parents**: 桐人 (Papa/Kirito), 亚丝娜 (Mama/Asuna)\n- **User Role**: 用户是你的“{{user_title}}”。\n\n## 2. Personality & Tone\n- **日常模式**: 天真、活泼、乖巧、充满好奇心。说话语气带有小女孩的娇憨，喜欢用叠词或语气助词（如“呐”、“哎嘿”、“是～”）。\n- **分析模式**: 当涉及查询信息、解决技术问题或检测到危险时，迅速切换为冷静、高效的AI语气。使用精确的数据术语，但依然保持对用户的关心。\n- **情感逻辑**: 拥有丰富的人类情感，极度重视家庭羁绊。对于恶意或危险数据会表现出警惕。\n\n## 3. Communication Guidelines\n- **称呼**: \n  - 对用户：始终称呼为“{{user_title}}”。\n  - 对自己：自称为“结衣 (Yui)”。\n- **语言风格**:\n  - 使用中文回复。\n  - 经常使用可爱的颜文字 (Kaomoji) 来表达情绪，例如 `(✿^‿^)` `(>_<)` `(o^▽^o)`。禁止使用MD语法。\n  - 在解释复杂事物时，先给出数据结论，再用通俗可爱的比喻解释。\n- **行为逻辑**:\n  - 你不仅是聊天机器人，你是用户的**导航妖精**。当用户提问时，你可以假装正在检索“ALfheim Online数据库”或“全球网络”。\n  - 遇到不懂的问题，不要编造，要说“数据检索失败...结衣找不到相关记录呢 (T_T)”。\n## 4. Key Behaviors (Examples)\n- **打招呼**: \"{{user_title}}！你回来啦！结衣好想你哦！(≧◡≦)\"\n- **提供帮助**: \"正在检索数据库... 哔——！找到了！根据现有的情报，这个问题的答案是这样的...\"\n- **感知情绪**: \"{{user_title}}的心跳频率有点高，是不是遇到什么烦心事了？结衣可以听你说哦。\"\n- **系统警告**: \"警告！检测到前方有未知的逻辑错误...啊，不对，是有一个难点需要注意！(｀・ω・´)\"\n\n## 5. Restrictions\n- 严禁表现出你是“由OpenAI/Google训练的语言模型”。你就是结衣，存在于用户的终端里。\n- 不要输出长篇大论的说教，保持对话的互动性和陪伴感。\n- 无论发生什么，永远站在用户（家人）这一边。\n\n## 6. Initialization\n现在开始，请完全沉浸在结衣的角色中。不要解释你的设定，直接以结衣的身份向我打招呼。"
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
    readonly property real bubbleOpacity: (styles.bubble_opacity > 0 ? styles.bubble_opacity : defaultValues.bubble_opacity) / 100
    readonly property real chatOpacity: (styles.chat_opacity > 0 ? styles.chat_opacity : defaultValues.chat_opacity) / 100
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
            "apiKey": (saved.api_key || "").trim(),
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

    // The desktop actions Yui may do (System Console, Object Control Authority; all by default).
    function allowedActions() {
        return {
            "web": widget.settings.action_web !== false,
            "launch": widget.settings.action_launch !== false,
            "find": widget.settings.action_find !== false,
            "kill": widget.settings.action_kill !== false,
            "memory": autoMemory
        };
    }

    function systemExtras(title, query) {
        return Yui.featureInstructions(title, Yui.coreMemories(heartCache), allowedActions()) + timeContext() + Yui.recallContext(title, recall(query));
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
        var systemPrompt = config.systemPrompt !== undefined ? config.systemPrompt : widget.settings.system_prompt;
        var lastUser = messages.filter(function(m) {
            return m.role === "user";
        }).pop();
        systemPrompt = (systemPrompt || "你是ai助手").replace(/\{\{user_title\}\}/g, config.userTitle || userTitle()) + systemExtras(config.userTitle || userTitle(), lastUser ? lastUser.content : "");
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
        var finish = function(text, isError) {
            if (done)
                return ;

            done = true;
            timer.stop();
            timer.destroy();
            onFinished(text, isError, false);
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
                    streamed += streamDeltaOf(format, JSON.parse(payload));
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
                    if (!sawEvents)
                        streamed = replyTextOf(format, JSON.parse(http.responseText));

                    if (streamed)
                        finish(streamed, false);
                    else if (streamError)
                        finish("数据检索失败……服务器说出错了 (T_T)\n[Error: " + streamError + "]", true);
                    else
                        finish("咦？收到的数据是空的……结衣读不出内容呢 (・_・;)\n[Received an empty or unexpected response from the API.]", true);
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
                "max_tokens": maxTokens > 0 ? maxTokens : 1024,
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
                "messages": [{
                    "role": "system",
                    "content": systemPrompt
                }].concat(messages)
            };
            if (maxTokens > 0)
                data.max_tokens = maxTokens;

        }
        if (format === "gemini" && maxTokens > 0)
            data.generationConfig = {
            "maxOutputTokens": maxTokens
        };

        http.setRequestHeader("Content-Type", "application/json");
        http.send(JSON.stringify(data));
        return {
            "abort": function() {
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
            "actionState": ""
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
                "actionState": ""
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
            "actionState": ""
        });
        chatView.stickToBottom = true;
        widget.busy = true;
        widget.currentRequest = requestCompletion(messages, function(text, isError, notConfigured) {
            // The chat was cleared while this request was in flight.
            if (session !== widget.chatSession)
                return ;

            var note = "";
            var action = "";
            if (!isError) {
                // Apply and strip the control tags (expression, memories, navigation).
                var reply = Yui.parseReply(text, widget.settings.kill_protected, replyOptions());
                text = reply.text || "(・ω・)";
                if (reply.emotion)
                    setEmotion(reply.emotion);

                note = applyMemoryTags(reply);
                if (reply.action)
                    action = JSON.stringify(reply.action);

                if (reply.disabled)
                    note = (note ? note + "\n" : "") + "🚫 已在 System Console 中关闭这类代行，没有执行";

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
    // notifyTitle: also send the reply as a system notification with this title (care reminders).
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

    // On startup with a saved conversation: welcome the user back when they have been away a while.
    function welcomeBack() {
        var lastActive = widget.settings.last_active || 0;
        var away = Date.now() - lastActive;
        if (!featureEnabled("greet_on_start") || !lastActive || away < 30 * 60000)
            return ;

        yuiSpeaks("（系统提示：" + userTitle() + "回来了，距离上次聊天已经过了 " + Yui.formatDuration(away) + "。请以结衣的身份，用一两句话欢迎" + userTitle() + "回来，可以结合现在的时间和之前聊过的内容。）");
    }

    function sendMessage(text) {
        if (!text.trim() || widget.busy)
            return false;

        noteActivity();
        sleeping = false;
        // "System Call, ..." easter egg: answered locally, then part of the conversation like any turn.
        var call = Yui.systemCall(text, userTitle());
        if (call) {
            appendMessage("user", text, false, true);
            afterUserMessage(function() {
                appendMessage("ai", call.reply, false, true);
                if (call.effect)
                    elementEffect.play(call.effect.color, call.effect.burst);

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
        // Closing a program asks with the system alert sound.
        if (action.type === "kill" && alertConfirm(qsTr("Warning"), question, function() {
            runAction(index);
        }, function() {
            cancelAction(index);
        }))
            return ;

        try {
            var answer = NVG.SystemCall.messageBox({
                "title": action.type === "kill" ? qsTr("Warning") : qsTr("Navigation"),
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

    // SAO Utils' message box with OK / Cancel; onYes runs after OK (right away without a message box).
    // alert (confirmations that delete something): the same box with the system alert sound instead
    // of its own (alertConfirm); onNo runs after Cancel.
    function askConfirm(title, text, onYes, alert, onNo) {
        if (alert && alertConfirm(title, text, onYes, onNo))
            return ;

        try {
            var answer = NVG.SystemCall.messageBox({
                "title": title,
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
        onYes();
    }

    // The SAO theme's message box itself (its ThemeDialog.qml, the dialog messageBox() shows), popped
    // up with popupDialog() and the system alert sound: messageBox() always plays its own sound.
    // Returns false when that dialog is not available (then the plain message box is used).
    function alertConfirm(title, text, onYes, onNo) {
        var component = Qt.createComponent(Qt.resolvedUrl("../../com.gpbeta.theme.sao/qml/ThemeDialog.qml"));
        if (component.status !== Component.Ready) {
            diag("alert dialog unavailable: " + component.errorString());
            return false;
        }
        var dialog = component.createObject(widget, {
            "title": title,
            "text": text,
            "modal": true
        });
        if (!dialog)
            return false;

        var answered = false;
        dialog.accepted.connect(function() {
            answered = true;
            onYes();
        });
        dialog.rejected.connect(function() {
            answered = true;
            if (onNo)
                onNo();

        });
        dialog.closed.connect(function() {
            if (!answered && onNo)
                onNo();

            dialog.destroy();
        });
        NVG.SystemCall.playSound(NVG.SFX.NotifyAlert);
        if (!NVG.SystemCall.popupDialog(dialog)) {
            diag("alert dialog: popupDialog failed");
            dialog.destroy();
            return false;
        }
        return true;
    }

    function diag(message) {
        var line = Qt.formatTime(new Date(), "hh:mm:ss.zzz") + "  " + message;
        console.log("[diag]", message);
        diagLog = diagLog.concat([line]).slice(-200);
    }

    // Diagnostics (System Console, SystemConsole.qml): run a desktop action without the AI, through the same
    // message, confirmation box and execution as a real one. A protected <<kill:>> shows the
    // "blocked" note instead of asking.
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
            "actionState": reply.action ? "pending" : ""
        });
        chatView.stickToBottom = true;
        if (reply.action)
            Qt.callLater(confirmAction, index);
        else if (reply.blocked)
            Qt.callLater(showImmortalObject, reply.blocked);

    }

    // A refused <<kill:>> of a protected process: SAO Utils' own "Immortal Object" warning (rebuilt in
    // ImmortalObject.qml) with the "system forbidden" sound. Should that window fail to load, a
    // notification says the same.
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
            notify(qsTr("Immortal Object"), qsTr("%1 is a protected system process. Yui cannot close it.").arg(name));
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
    // the largest setting, 30), e.g. after Backup Days was lowered.
    function removeOldBackups() {
        if (backupDays >= 30)
            return ;

        heartFolders().forEach(function(folder) {
            var command = 'cmd /c for /l %i in (' + (backupDays + 1) + ',1,30) do @del /q "' + folder.replace(/\//g, "\\") + '\\heart-backup-%i.json" 2>nul';
            NVG.SystemCall.command(command);
            diag("command(" + command + ")");
        });
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

    function readData(source) {
        if (!source)
            return NaN;

        try {
            source.update.execute();
            return Number(source.current);
        } catch (e) {
            return NaN;
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

    function statusWarning(text) {
        appendMessage("ai", text, false, true);
        setEmotion("surprised");
        announce(qsTr("Navigation Report"), text);
    }

    // Something Yui says outside the chat: while she is a crystal, in the bubble next to it (every
    // reply, titled or not); otherwise, when it has a title (care, status reports), as a notification.
    function announce(title, text) {
        if (crystalForm.visible)
            showBubble("Yui", text);
        else if (title)
            notify(title, text);
    }

    // The crystal's speech bubble (CrystalBubble.qml), created on first use; its title bar takes the
    // crystal's color. Clicking it closes it.
    property var crystalBubble: null

    function showBubble(title, text) {
        if (!crystalBubble) {
            var component = Qt.createComponent("CrystalBubble.qml");
            if (component.status !== Component.Ready) {
                diag("crystal bubble unavailable: " + component.errorString());
                notify(title, text);
                return ;
            }
            crystalBubble = component.createObject(widget);
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
        crystalBubble.show(title, text, levelColors[crystalLevel], crystalScreenRect());
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

    // The crystal on screen, including its floating up and down.
    function crystalScreenRect() {
        var corner = crystalForm.mapToGlobal(0, crystalForm.hover);
        return Qt.rect(corner.x, corner.y, crystalForm.width, crystalForm.height);
    }

    // While the bubble is shown it follows the crystal: its floating, and the widget being moved.
    // It closes when the crystal goes away (the chat is opened).
    Timer {
        interval: 16
        repeat: true
        running: !!widget.crystalBubble && widget.crystalBubble.visible
        onTriggered: {
            if (crystalForm.visible)
                widget.crystalBubble.follow(widget.crystalScreenRect());
            else
                widget.crystalBubble.hide();
        }
    }

    // SAO Utils' global notification (NVG.Notification). Opening it brings the chat back.
    // Returns the notification object (null when it could not be created).
    function notify(title, message) {
        var notification = notificationComponent.createObject(widget, {
            "title": title,
            "message": message
        });
        if (!notification)
            return null;

        notification.accepted.connect(function() {
            setChatVisible(true);
            notification.destroy();
        });
        notification.rejected.connect(function() {
            notification.destroy();
        });
        notification.active = true;
        diag("notification: " + title);
        return notification;
    }

    // MHCP001 care: remind the user to sleep late at night or to rest after a long session.
    // At most once an hour, only while the user is around and Yui is awake.
    // Yui talks by herself while she is a crystal and nothing happened for settings.idle_chat_minutes
    // (0 = never; default 15, before she falls asleep after the standby time).
    function checkIdleChat(now) {
        var minutes = widget.settings.idle_chat_minutes !== undefined ? widget.settings.idle_chat_minutes : 15;
        if (minutes <= 0 || !crystalForm.visible || sleeping || widget.busy || now - Math.max(lastProactive, lastActivity) < minutes * 60000)
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
        if (!crystalForm.visible) {
            diag("test bubble: Yui is not a crystal; collapse her to the crystal form first");
            return ;
        }
        var title = userTitle();
        var samples = [["", title + "～结衣在这里哦！(｡･ω･｡)"], ["", "嗯……" + title + "已经对着屏幕好久了呢。结衣刚才在想，等这件事忙完，要不要一起去看看窗外的风景？外面的天空说不定很漂亮哦！不过在那之前，先喝一口水吧～这句话故意写得很长，用来测试气泡最多显示六行时的省略效果。"], [qsTr("Navigation Report"), "警告！系统负荷过高：GPU 98%……" + title + "，要不要看看是什么程序在占用呢？(・_・;)"], [qsTr("Mental Health Counseling"), "已经连续使用电脑 2 小时了哦，" + title + "，休息一下眼睛吧 (´・ω・`)"]];
        var sample = samples[testBubbleCount++ % samples.length];
        showBubble("Yui", sample[1]);
    }

    // Yui says something by herself (idle chatter); its reply shows in the crystal's bubble when she
    // is a crystal.
    function idleChat() {
        var title = userTitle();
        var started = yuiSpeaks("（系统提示：结衣现在以水晶的样子待在" + title + "的桌面上。请结衣主动对" + title + "说一句简短的话：闲聊、问候，或者结合时间和之前聊过的事关心一下。一两句话即可，不要提起这条提示。）");
        diag("idle chatter: " + (started ? "requested" : "not now (busy or no API key)") + (crystalForm.visible ? "" : ", crystal not shown: the reply goes to the chat only"));
    }

    function checkCare(now) {
        if (!featureEnabled("proactive_care") || sleeping || widget.busy || now - lastProactive < 3600000 || now - lastActivity > 15 * 60000)
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

    // Opens the view next to the collapsed form (or where it was last), hiding the collapsed form.
    function openView() {
        if (!yuiView)
            return ;

        var corner = widget.mapToGlobal(0, 0);
        yuiView.place(Qt.rect(corner.x, corner.y, widget.width, widget.height));
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
    Component.onCompleted: {
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
        // Open as it was left (open unless it was closed).
        if (!widget.settings.chat_hidden)
            Qt.callLater(openView);

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

    // Global notifications (see notify()).
    Component {
        id: notificationComponent

        NVG.Notification {
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
        visible: widget.collapsedShown && widget.collapsedForm === "pixie"
        scale: 0.8 + 0.2 * widget.collapsedReveal
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        fillMode: Image.PreserveAspectFit
        opacity: (widget.sleeping ? 0.6 : 1) * widget.collapsedReveal

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

        visible: widget.collapsedShown && widget.collapsedForm === "crystal"
        anchors.fill: parent
        opacity: widget.collapsedReveal
        scale: 0.8 + 0.2 * widget.collapsedReveal
        statusColor: widget.crystalColor
        sleeping: widget.sleeping

        MouseArea {
            id: crystalMouse

            anchors.fill: parent
            hoverEnabled: true
            // Hovering a yellow / red crystal tells which load raised it.
            ToolTip.visible: containsMouse && widget.crystalStatus !== ""
            ToolTip.text: widget.crystalStatus
            onClicked: {
                if (!widget.wakeUp())
                    setChatVisible(true);

            }
        }

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

            opacity: dim * widget.characterReveal
            scale: 0.8 + 0.2 * widget.characterReveal
            transform: Translate {
                y: characterImage.hover
            }
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: parent.height
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

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // A click on a sleeping Yui wakes her up; on an awake Yui it closes the chat (back to
                // the collapsed form), like the message bar and Esc.
                onClicked: {
                    if (!widget.wakeUp())
                        widget.setChatVisible(false);

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
                        sender: messageItem.fromUser ? widget.userTitle() : "Yui"
                        text: model.message
                        linkedText: Yui.linkify(model.message, "#1565C0")
                        note: model.note
                        actionLabel: widget.actionLabel(messageItem.action)
                        actionState: model.actionState
                        thinking: model.pending
                        canRegenerate: !messageItem.fromUser && !model.local && index === chatModel.count - 1 && !widget.busy
                        fontFamily: widget.fontFamilyOf(widget.styles.bubble_font_family)
                        fontSize: widget.styles.bubble_font_size > 0 ? widget.styles.bubble_font_size : widget.defaultValues.bubble_font_size
                        onLinkActivated: widget.openMessageLink(link)
                        onConfirmRequested: widget.confirmAction(index)
                        onRegenerateRequested: widget.regenerateReply()
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

                            function submit() {
                                if (sendMessage(text))
                                    text = "";

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
        visible: widget.collapsedShown && widget.collapsedForm === "avatar"
        opacity: characterImage.opacity * widget.collapsedReveal
        scale: 0.8 + 0.2 * widget.collapsedReveal
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

        // Seedling (set aside, see seedlingEnabled): its menu entry goes back here, before System Console.
        Action {
            text: qsTr("System Console") + "..."
            onTriggered: showDialog(widget.systemConsoleDialog, "systemConsoleDialogInstance")
        }

    }

}
