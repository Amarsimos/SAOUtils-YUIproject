import "."
import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Shapes 1.12
import QtQuick.LocalStorage 2.12
import "yui.js" as Yui

T.Widget {
    id: widget

    property Component coreSettingsDialog: Qt.createComponent("CoreSettings.qml")
    property Component styleSettingsDialog: Qt.createComponent("StyleSettings.qml")
    property var styleSettingsDialogInstance: null
    property Component optionSettingsDialog: Qt.createComponent("OptionSettings.qml")
    property var optionSettingsDialogInstance: null
    property var coreSettingsDialogInstance: null
    // Shared with CoreSettings.qml. settings.provider stores a provider id and
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
    readonly property int maxHistory: 20
    // Narrowest the chat column can be without cutting off the input row.
    readonly property real inputMinimumWidth: 120
    readonly property real chatMinimumWidth: inputMinimumWidth + sendButton.implicitWidth + clearButton.implicitWidth + 2 * inputArea.spacing
    // Minimum size of the character image area: characterMinimumWidth x minimumFrameHeight.
    readonly property real characterMinimumWidth: 300
    readonly property real minimumFrameHeight: 400
    property bool busy: false
    // Controller of the reply being generated (see requestCompletion), used by stopReply().
    property var currentRequest: null
    property int chatSession: 0
    // How many messages are kept in settings.chat_history across restarts.
    readonly property int maxSavedMessages: 50
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
    // CPU load in percent (NaN until read), shown by the crystal's color.
    property real cpuPercent: NaN
    // TEMPORARY thresholds for the crystal colors (pending decision): below 70 % green, below 90 % yellow.
    readonly property real crystalYellowAt: 70
    readonly property real crystalRedAt: 90
    readonly property color crystalColor: !(cpuPercent >= crystalYellowAt) ? "#2CE67C" : (cpuPercent < crystalRedAt ? "#FFCC00" : "#FF3B30")
    // System status sources (same data sources as SAO Utils' HP bar widgets).
    property QtObject acStatus
    property QtObject batteryStatus
    property QtObject batteryLevel
    property QtObject cpuLoad
    property QtObject gpuLoad
    property QtObject ramUsage
    property int batteryWarnedAt: 101
    property int highCpuChecks: 0
    property int highRamChecks: 0
    property double lastCpuWarning: 0
    property double lastRamWarning: 0
    // Messages before this index are not sent as history (e.g. written before the API was configured).
    property int historyStart: 0
    property bool showChat: true
    // The console (Console.qml) opened over the chat area.
    property bool consoleOpen: false
    // Yui's Heart, kept in a local SQLite database (QtQuick.LocalStorage); heartCache mirrors the
    // memories table so bindings and requests do not query the database.
    property var database: null
    // Diagnostics log shown live in the Option window (newest last, at most 200 lines).
    property var diagLog: []
    property var heartCache: []
    property bool applyingFrameSize: false
    // Width of the character image at the current widget height, without any constraint.
    readonly property real characterNaturalWidth: characterImage.implicitHeight > 0 ? height * characterImage.implicitWidth / characterImage.implicitHeight : 0
    readonly property var fonts: Qt.fontFamilies()
    readonly property string defaultSystemPrompt: "# Role: 结衣 (Yui) - MHCP001\n\n## 1. Profile\n- **Name**: 结衣 (Yui) / Yui-MHCP001\n- **Origin**: Sword Art Online (SAO) Mental Health Counseling Program\n- **Current Status**: Navigation Pixie / AI Companion\n- **Parents**: 桐人 (Papa/Kirito), 亚丝娜 (Mama/Asuna)\n- **User Role**: 用户是你的“{{user_title}}”。\n\n## 2. Personality & Tone\n- **日常模式**: 天真、活泼、乖巧、充满好奇心。说话语气带有小女孩的娇憨，喜欢用叠词或语气助词（如“呐”、“哎嘿”、“是～”）。\n- **分析模式**: 当涉及查询信息、解决技术问题或检测到危险时，迅速切换为冷静、高效的AI语气。使用精确的数据术语，但依然保持对用户的关心。\n- **情感逻辑**: 拥有丰富的人类情感，极度重视家庭羁绊。对于恶意或危险数据会表现出警惕。\n\n## 3. Communication Guidelines\n- **称呼**: \n  - 对用户：始终称呼为“{{user_title}}”。\n  - 对自己：自称为“结衣 (Yui)”。\n- **语言风格**:\n  - 使用中文回复。\n  - 经常使用可爱的颜文字 (Kaomoji) 来表达情绪，例如 `(✿^‿^)` `(>_<)` `(o^▽^o)`。禁止使用MD语法。\n  - 在解释复杂事物时，先给出数据结论，再用通俗可爱的比喻解释。\n- **行为逻辑**:\n  - 你不仅是聊天机器人，你是用户的**导航妖精**。当用户提问时，你可以假装正在检索“ALfheim Online数据库”或“全球网络”。\n  - 遇到不懂的问题，不要编造，要说“数据检索失败...结衣找不到相关记录呢 (T_T)”。\n## 4. Key Behaviors (Examples)\n- **打招呼**: \"{{user_title}}！你回来啦！结衣好想你哦！(≧◡≦)\"\n- **提供帮助**: \"正在检索数据库... 哔——！找到了！根据现有的情报，这个问题的答案是这样的...\"\n- **感知情绪**: \"{{user_title}}的心跳频率有点高，是不是遇到什么烦心事了？结衣可以听你说哦。\"\n- **系统警告**: \"警告！检测到前方有未知的逻辑错误...啊，不对，是有一个难点需要注意！(｀・ω・´)\"\n\n## 5. Restrictions\n- 严禁表现出你是“由OpenAI/Google训练的语言模型”。你就是结衣，存在于用户的终端里。\n- 不要输出长篇大论的说教，保持对话的互动性和陪伴感。\n- 无论发生什么，永远站在用户（家人）这一边。\n\n## 6. Initialization\n现在开始，请完全沉浸在结衣的角色中。不要解释你的设定，直接以结衣的身份向我打招呼。"
    // Always a valid object, even before settings.styles is initialized.
    readonly property var styles: widget.settings.styles || defaultValues
    readonly property var defaultValues: {
        "character_image_path": Qt.resolvedUrl("../Images/Yui01.png"),
        "background_image_path": Qt.resolvedUrl("../Images/scrim-dark-40.png"),
        "user_bubble_color": "#2196f3",
        "ai_bubble_color": "#f8bbd0",
        "bubble_font_family": "Microsoft YaHei",
        "bubble_font_size": 14,
        "pixie_size": 160,
        "collapsed_form": "pixie",
        "crystal_size": 120,
        "bubble_font_color": "#000000"
    }

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

        return "Microsoft YaHei";
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

    // A feature switch from the Cardinal System dialog (CoreSettings.qml); all are on unless turned off.
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

    // Everything appended to the system prompt: time, feature instructions and Yui's Heart.
    function systemExtras(title) {
        return timeContext() + Yui.featureInstructions(title, heartEntries());
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
        config = config || activeConfig();
        var format = config.provider.format;
        var systemPrompt = config.systemPrompt !== undefined ? config.systemPrompt : widget.settings.system_prompt;
        systemPrompt = (systemPrompt || "你是ai助手").replace(/\{\{user_title\}\}/g, config.userTitle || userTitle()) + systemExtras(config.userTitle || userTitle());
        if (!config.apiKey || !config.endpoint || !config.model) {
            onFinished("警告！连接数据缺失……结衣找不到通往网络的路了 (T_T)\n请在「Cardinal System」里检查 Access Key、Server Address 和 Core Program 有没有填好哦～", true, true);
            return {
                "abort": function() {
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
                "max_tokens": 1024,
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
        }
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
    function appendMessage(author, message, isError, local) {
        chatModel.append({
            "author": author,
            "message": message,
            "pending": false,
            "isError": isError,
            "local": !!local,
            "note": "",
            "action": "",
            "actionState": ""
        });
        chatView.stickToBottom = true;
        scheduleSave();
        logMessage(author, message);
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
                var reply = Yui.parseReply(text);
                text = reply.text || "(・ω・)";
                if (reply.emotion)
                    setEmotion(reply.emotion);

                if (reply.memories.length > 0) {
                    addMemories(reply.memories);
                    note = "💗 结衣之心：" + reply.memories.join("；");
                }
                if (reply.action)
                    action = JSON.stringify(reply.action);

                if (reply.blocked) {
                    note = (note ? note + "\n" : "") + "🛡 已拦截：" + reply.blocked + " 是受保护的系统进程，不能关闭";
                    Qt.callLater(showImmortalObject, reply.blocked);
                }

            }
            chatModel.set(index, {
                "message": text,
                "pending": false,
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
            if (!isError) {
                logMessage("ai", text);
                if (notifyTitle)
                    notify(notifyTitle, text);

            }

            if (action)
                Qt.callLater(confirmAction, index);

        }, null, function(partial) {
            if (session === widget.chatSession)
                chatModel.setProperty(index, "message", Yui.displayText(partial) || "...");

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
            appendMessage("ai", call.reply, false, true);
            if (call.effect)
                elementEffect.play(call.effect.color, call.effect.burst);

            setEmotion(call.effect ? "surprised" : "normal");
            return true;
        }
        widget.settings.last_active = Date.now();
        appendMessage("user", text, false);
        startReply(buildHistory());
        return true;
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
        var question = (questions[action.type] || "") + "\n" + action.target;
        diag("confirm: " + action.type + " \"" + action.target + "\" -> messageBox");
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

    function diag(message) {
        var line = Qt.formatTime(new Date(), "hh:mm:ss.zzz") + "  " + message;
        console.log("[diag]", message);
        diagLog = diagLog.concat([line]).slice(-200);
    }

    // Diagnostics (Option window, OptionSettings.qml): run a desktop action without the AI, through the same
    // message, confirmation box and execution as a real one. A protected <<kill:>> shows the
    // "blocked" note instead of asking.
    function testAction(tag) {
        diag("test " + tag);
        var reply = Yui.parseReply("[" + qsTr("Test") + "] " + tag);
        var index = chatModel.count;
        chatModel.append({
            "author": "ai",
            "message": reply.text,
            "pending": false,
            "isError": true,
            "local": true,
            "note": reply.blocked ? "🛡 已拦截：" + reply.blocked + " 是受保护的系统进程，不能关闭" : "",
            "action": reply.action ? JSON.stringify(reply.action) : "",
            "actionState": reply.action ? "pending" : ""
        });
        chatView.stickToBottom = true;
        widget.consoleOpen = false;
        if (reply.action)
            Qt.callLater(confirmAction, index);
        else if (reply.blocked)
            Qt.callLater(showImmortalObject, reply.blocked);

    }

    // A refused <<kill:>> of a protected process: SAO Utils' system message box, titled after the
    // indestructible objects of SAO ("Immortal Object"), with only an OK button.
    function showImmortalObject(name) {
        diag("blocked: " + name + " is protected (no confirmation)");
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
                var killed = NVG.SystemCall.command(killCommand);
                diag("command(" + killCommand + ") -> " + killed);
                if (!killed)
                    addNote(index, "⚠ 无法执行：taskkill " + action.target);

            } else if (action.type === "find") {
                runFind(action);
            }
        } catch (e) {
            diag("action failed: " + e);
        }
        chatModel.setProperty(index, "actionState", "done");
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

    // <<find:>>: Everything's es.exe writes up to 20 matching paths to a new file in the extension's
    // storage folder; the file is read once it appears and Yui reports the results.
    function runFind(action) {
        var folder = String(NVG.Utils.storagePath("yui")).replace(/\\/g, "/");
        var file = folder + "/find-" + Date.now() + ".txt";
        diag("es.exe path setting: " + (widget.settings.es_path ? "\"" + widget.settings.es_path + "\"" : "(empty, using es.exe from PATH)"));
        var command = Yui.actionCommand(action, file, widget.settings.es_path);
        var started = NVG.SystemCall.command(command);
        diag("command(" + command + ") -> " + started);
        if (!started) {
            // command() fails when es.exe cannot be started, which nearly always means it is missing.
            appendMessage("ai", "呜……结衣没能启动文件检索 (T_T)
结衣找不到 Everything 的命令行工具 es.exe。请在 Option 里填写 es.exe 的完整路径（或把它加入系统 PATH），并确认 Everything 正在运行。还没有的话，可以从 voidtools.com 下载 Everything 和 ES 命令行工具哦！", false, true);
            return ;
        }
        var tries = 0;
        var timer = Qt.createQmlObject("import QtQuick 2.12; Timer { interval: 500; repeat: true }", widget);
        timer.triggered.connect(function() {
            tries++;
            var content = readLocalFile(file);
            var results = Yui.parseSearchResults(content);
            diag("read result file (try " + tries + "/12): " + content.length + " chars, " + results.length + " results");
            if (results.length === 0 && tries < 12)
                return ;

            timer.stop();
            timer.destroy();
            if (results.length > 0)
                appendMessage("ai", "检索完成！结衣找到了 " + results.length + " 个和「" + action.target + "」有关的结果：\n" + results.join("\n"), false, true);
            else
                appendMessage("ai", "数据检索失败……没有找到「" + action.target + "」(T_T)\n请确认 Everything 正在运行，并在 Option 里填好 es.exe 的位置（或把它加入系统 PATH）。", false, true);
        });
        timer.start();
    }

    // Contents of a local text file ("" when missing).
    function readLocalFile(path) {
        try {
            var request = new XMLHttpRequest();
            request.open("GET", "file:///" + path.replace(/^\/+/, ""), false);
            request.send(null);
            return request.responseText || "";
        } catch (e) {
            return "";
        }
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
        var now = Date.now();
        var sleepMinutes = widget.settings.sleep_minutes !== undefined ? widget.settings.sleep_minutes : 20;
        if (!sleeping && sleepMinutes > 0 && !widget.busy && now - lastActivity > sleepMinutes * 60000)
            sleeping = true;

        checkSystemStatus(now);
        checkCare(now);
    }

    // ---------------------------------------------------------------- Yui's Heart (SQLite)
    // Tables (TEMPORARY design, pending a decision):
    //   memories(id, text, created)            long-term memories, oldest first
    //   messages(id, author, message, created) every finished chat message (complete history)
    function openDatabase() {
        try {
            database = LocalStorage.openDatabaseSync("MHCP001-Yui", "1.0", "MHCP001 Yui's Heart", 5000000);
            database.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS memories(id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, created INTEGER)");
                tx.executeSql("CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY AUTOINCREMENT, author TEXT, message TEXT, created INTEGER)");
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
            heartCache = widget.settings.yui_heart || [];
        }
    }

    function loadHeart() {
        var entries = [];
        database.readTransaction(function(tx) {
            var rows = tx.executeSql("SELECT text FROM memories ORDER BY id").rows;
            for (var i = 0; i < rows.length; i++)
                entries.push(rows.item(i).text);
        });
        heartCache = entries;
    }

    // Yui's Heart entries (long-term memories), oldest first.
    function heartEntries() {
        return heartCache;
    }

    // Replace all memories (Cardinal System editor).
    function setHeartEntries(entries) {
        if (!database) {
            widget.settings.yui_heart = entries;
            heartCache = entries;
            return ;
        }
        var now = Date.now();
        database.transaction(function(tx) {
            tx.executeSql("DELETE FROM memories");
            for (var i = 0; i < entries.length; i++)
                tx.executeSql("INSERT INTO memories(text, created) VALUES(?, ?)", [entries[i], now]);
        });
        loadHeart();
    }

    // Add memories Yui saved with <<memory:...>> (duplicates skipped, oldest dropped beyond the limit).
    function addMemories(memories) {
        var merged = Yui.mergeMemories(heartCache, memories);
        if (!database) {
            widget.settings.yui_heart = merged;
            heartCache = merged;
            return ;
        }
        var now = Date.now();
        database.transaction(function(tx) {
            for (var i = 0; i < merged.length; i++) {
                if (heartCache.indexOf(merged[i]) === -1)
                    tx.executeSql("INSERT INTO memories(text, created) VALUES(?, ?)", [merged[i], now]);

            }
            for (var j = 0; j < heartCache.length; j++) {
                if (merged.indexOf(heartCache[j]) === -1)
                    tx.executeSql("DELETE FROM memories WHERE text = ?", [heartCache[j]]);

            }
        });
        loadHeart();
    }

    // SAO Utils exports / imports widget data (e.g. "My Widgets"); the settings travel on their own,
    // Yui's Heart lives in the database, so it is carried here.
    function exportData() {
        return {
            "yui_heart": heartEntries()
        };
    }

    function importData(data) {
        if (!data || !Array.isArray(data.yui_heart))
            return ;

        if (!database)
            openDatabase();

        setHeartEntries(data.yui_heart.map(function(entry) {
            return String(entry);
        }));
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
        var cpu = readData(cpuLoad);
        highCpuChecks = !isNaN(cpu) && cpu >= 90 ? highCpuChecks + 1 : 0;
        if (highCpuChecks >= 4 && now - lastCpuWarning > 3600000) {
            lastCpuWarning = now;
            statusWarning("哔——！检测到 CPU 负载持续在 " + Math.round(cpu) + "% 以上……" + title + "，电脑好像很辛苦，要不要看看是什么程序在占用呢？(・_・;)");
        }
        var ram = readData(ramUsage);
        highRamChecks = !isNaN(ram) && ram >= 90 ? highRamChecks + 1 : 0;
        if (highRamChecks >= 2 && now - lastRamWarning > 3600000) {
            lastRamWarning = now;
            statusWarning("警告！内存使用率已经达到 " + Math.round(ram) + "% 了！" + title + "，关掉一些不用的程序会比较好哦 (｀・ω・´)");
        }
    }

    function statusWarning(text) {
        appendMessage("ai", text, false, true);
        setEmotion("surprised");
        notify(qsTr("Navigation Report"), text);
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

        if (visible) {
            showChat = true;
            // Never request a frame lower than the minimum height.
            var h = Math.max(widget.settings.expanded_height || widget.height, widget.minimumFrameHeight);
            var natural = naturalWidthAt(characterImage, h);
            applyFrameSize(Math.max(widget.settings.expanded_width || 800, Math.max(natural, widget.characterMinimumWidth) + widget.chatMinimumWidth + 30), h);
        } else {
            widget.settings.expanded_width = widget.width;
            widget.settings.expanded_height = widget.height;
            showChat = false;
            if (collapsedForm === "crystal") {
                var crystalHeight = widget.styles.crystal_size > 0 ? widget.styles.crystal_size : widget.defaultValues.crystal_size;
                applyFrameSize(Math.ceil(crystalHeight * 0.75), crystalHeight);
            } else if (collapsedForm === "pixie") {
                var pixieHeight = widget.styles.pixie_size > 0 ? widget.styles.pixie_size : widget.defaultValues.pixie_size;
                // Extra room for the hovering animation.
                applyFrameSize(Math.ceil(naturalWidthAt(pixieImage, pixieHeight)), pixieHeight + 12);
            } else {
                var hh = Math.max(widget.height, widget.minimumFrameHeight);
                var nn = naturalWidthAt(characterImage, hh);
                if (nn > 0)
                    applyFrameSize(Math.ceil(Math.max(nn, widget.characterMinimumWidth)), hh);

            }
        }
        widget.settings.chat_hidden = !visible;
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
        if (!showChat && collapsedForm !== "avatar") {
            // The pixie and the crystal can be made quite small.
            widget.implicitWidth = 40;
            widget.implicitHeight = 60;
            return ;
        }
        widget.implicitWidth = Math.ceil(showChat ? widget.characterMinimumWidth + widget.chatMinimumWidth + 30 : widget.characterMinimumWidth);
        widget.implicitHeight = widget.minimumFrameHeight;
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

    title: qsTr("MHCP-YUI")
    solid: true
    resizable: !applyingFrameSize
    // Implicit size acts as the minimum frame size (see applyFrameSize); set from code only.
    implicitWidth: 60
    implicitHeight: 400
    visible: true
    Component.onCompleted: {
        // Apply the default size only once, so a size chosen by the user survives restarts.
        var firstRun = !widget.settings.initialized;
        widget.settings.initialized = true;
        if (!widget.settings.styles)
            widget.settings.styles = JSON.parse(JSON.stringify(defaultValues));
        else
            widget.settings.styles = updateObject(JSON.parse(JSON.stringify(defaultValues)), widget.settings.styles);
        migrateSettings();
        openDatabase();
        // The frame size itself is restored by SAO Utils.
        if (widget.settings.chat_hidden)
            showChat = false;

        if (firstRun)
            applyFrameSize(800, 400); // lowers the minimum size again once applied
        else
            releaseMinimumSize();

        // Continue the saved conversation (welcoming the user back); greet when there is none.
        if (restoreHistory())
            welcomeBack();
        else
            getInitialMessage();
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
        visible: showChat || widget.collapsedForm === "avatar"
        // Without a sleeping image, a sleeping Yui is drawn dimmed (with the "Zzz" below).
        opacity: widget.sleeping && !widget.hasImage(widget.styles.sleep_image_path) ? 0.6 : 1
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: parent.height
        // Size the item to the image as actually drawn, so the chat area starts right next to it
        // whatever the image resolution is. Never take more than half of the widget, leave the chat
        // column enough room for its input row, but never get narrower than characterMinimumWidth
        // (the image is centered in that space when it is drawn narrower).
        // While the chat is hidden the widget shrinks to the image, so the image takes the full width.
        width: !showChat ? parent.width : Math.max(widget.characterMinimumWidth, Math.min(widget.characterNaturalWidth, parent.width * 0.5, parent.width - widget.chatMinimumWidth - 20))
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // A click on a sleeping Yui only wakes her up.
                if (!widget.wakeUp())
                    setChatVisible(!showChat);

            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 600
            }

        }

    }

    // Navigation pixie (ALO): replaces the character while the chat is hidden, hovering gently.
    NVG.ImageSource {
        id: pixieImage

        property real hover: 0

        configuration: widget.styles.pixie_image_path
        visible: !showChat && widget.collapsedForm === "pixie"
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        fillMode: Image.PreserveAspectFit
        opacity: widget.sleeping ? 0.6 : 1

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

    // Yui's Heart crystal: the other collapsed form, colored by CPU load.
    YuiCrystal {
        id: crystalForm

        visible: !showChat && widget.collapsedForm === "crystal"
        anchors.fill: parent
        statusColor: widget.crystalColor
        sleeping: widget.sleeping

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!widget.wakeUp())
                    setChatVisible(true);

            }
        }

    }

    // Keeps the crystal color current while it is shown.
    Timer {
        interval: 5000
        running: crystalForm.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: widget.cpuPercent = widget.readData(widget.cpuLoad)
    }

    // "Zzz" floating up from a sleeping Yui.
    Item {
        id: sleepMark

        readonly property Item target: crystalForm.visible ? crystalForm : (pixieImage.visible ? pixieImage : characterImage)

        visible: widget.sleeping
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

    ColumnLayout {
        id: chatContainer

        anchors.left: characterImage.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        visible: opacity > 0
        opacity: showChat ? 1 : 0

        ListView {
            id: chatView

            Layout.fillWidth: true
            Layout.fillHeight: true
            model: chatModel
            spacing: 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: SaoScrollBar {
            }

            delegate: Item {
                id: messageItem

                // AI bubbles get a comic-style tail at the bottom-left, pointing at the character.
                readonly property bool hasTail: model.author !== "user"
                readonly property int messageIndex: index
                readonly property string actionState: model.actionState
                readonly property real tailSize: 10

                width: chatView.width
                height: bubble.height + (hasTail ? tailSize * 0.6 : 0) + (extras.visible ? extras.height + 4 : 0)

                // Unwrapped text, used only to measure the natural width of the longest line.
                Text {
                    id: measure

                    visible: false
                    text: model.message
                    textFormat: Text.PlainText
                    font: messageText.font
                }

                Rectangle {
                    id: bubble

                    anchors.right: model.author === "user" ? parent.right : undefined
                    anchors.left: model.author === "user" ? undefined : parent.left
                    anchors.leftMargin: messageItem.hasTail ? messageItem.tailSize : 0
                    // Keep user bubbles clear of the scroll bar.
                    anchors.rightMargin: 16
                    color: model.author === "user" ? (widget.styles.user_bubble_color || widget.defaultValues.user_bubble_color) : (widget.styles.ai_bubble_color || widget.defaultValues.ai_bubble_color)
                    border.color: "#FFFFFF"
                    border.width: 1
                    radius: 8
                    // Leave room on the right for the regenerate button.
                    width: Math.min(measure.implicitWidth + 2, chatView.width - messageItem.tailSize - 64) + 20
                    height: messageText.implicitHeight + 20

                    TextEdit {
                        id: messageText

                        x: 10
                        y: 10
                        width: parent.width - 20
                        text: model.message
                        // Show replies verbatim: never interpret them as rich text.
                        textFormat: TextEdit.PlainText
                        // Wrap at word boundaries, but also break long URLs / JSON that have none.
                        wrapMode: TextEdit.Wrap
                        readOnly: true
                        selectByMouse: true
                        color: widget.styles.bubble_font_color || widget.defaultValues.bubble_font_color
                        font.family: widget.fontFamilyOf(widget.styles.bubble_font_family)
                        font.pixelSize: widget.styles.bubble_font_size > 0 ? widget.styles.bubble_font_size : widget.defaultValues.bubble_font_size
                    }

                }

                // Drawn over the bubble's bottom-left corner: the fill hides the corner's border and
                // only the two outer edges of the tail are stroked, so it joins the bubble seamlessly.
                Shape {
                    id: tail

                    readonly property real size: messageItem.tailSize

                    visible: messageItem.hasTail
                    x: bubble.x - size
                    y: bubble.y + bubble.height - size * 1.5
                    width: size * 3
                    height: size * 2.1
                    layer.enabled: visible
                    layer.samples: 4

                    ShapePath {
                        fillColor: bubble.color
                        strokeColor: bubble.border.color
                        strokeWidth: bubble.border.width
                        joinStyle: ShapePath.RoundJoin
                        // From the bubble's left edge, out to the tip, back to its bottom edge.
                        startX: tail.size + 0.5
                        startY: 0
                        PathQuad {
                            x: 0
                            y: tail.size * 2.05
                            controlX: tail.size * 0.9
                            controlY: tail.size * 1.4
                        }

                        PathQuad {
                            x: tail.size * 2.9
                            y: tail.size * 1.5 - 0.5
                            controlX: tail.size * 1.4
                            controlY: tail.size * 1.85
                        }

                    }

                }

                // Under an AI bubble: what Yui put into Yui's Heart, and a link / search she offers to open.
                Column {
                    id: extras

                    readonly property var action: model.action ? JSON.parse(model.action) : null

                    visible: model.note !== "" || action !== null
                    x: bubble.x + 4
                    y: bubble.y + bubble.height + messageItem.tailSize * 0.6 + 4
                    width: bubble.width
                    spacing: 4

                    Rectangle {
                        visible: model.note !== ""
                        width: Math.min(noteText.implicitWidth + 16, extras.width)
                        height: noteText.implicitHeight + 6
                        radius: 11
                        color: "#99000000"

                        Text {
                            id: noteText

                            x: 8
                            y: 3
                            width: parent.width - 16
                            text: model.note
                            color: "#FFFFFF"
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }

                    }

                    Row {
                        visible: extras.action !== null
                        spacing: 6

                        Rectangle {
                            width: actionText.width + 16
                            height: 22
                            radius: 11
                            color: "#99000000"

                            Text {
                                id: actionText

                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: widget.actionLabel(extras.action)
                                color: "#FFFFFF"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, chatView.width - 170)
                            }

                        }

                        Repeater {
                            // While pending: reopen the confirmation dialog. Afterwards: the outcome.
                            model: extras.action ? [messageItem.actionState === "pending" ? qsTr("Confirm...") : (messageItem.actionState === "done" ? qsTr("Done ✓") : qsTr("Cancelled"))] : []

                            Rectangle {
                                readonly property bool isButton: messageItem.actionState === "pending"

                                width: label.implicitWidth + 16
                                height: 22
                                radius: 11
                                color: !isButton ? "#99000000" : (actionArea.containsMouse ? "#FFFFFFFF" : "#CCFFFFFF")

                                Text {
                                    id: label

                                    anchors.centerIn: parent
                                    text: modelData
                                    color: parent.isButton ? "#333333" : "#DDDDDD"
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: actionArea

                                    anchors.fill: parent
                                    enabled: parent.isButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: widget.confirmAction(messageItem.messageIndex)
                                }

                            }

                        }

                    }

                }

                // Regenerate the last reply.
                Rectangle {
                    visible: messageItem.hasTail && !model.local && index === chatModel.count - 1 && !widget.busy
                    x: bubble.x + bubble.width + 6
                    y: bubble.y + bubble.height - height
                    width: 24
                    height: 24
                    radius: 12
                    color: regenerateArea.containsMouse ? "#FFFFFFFF" : "#CCFFFFFF"

                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        color: "#555555"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: regenerateArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: widget.regenerateReply()
                    }

                }

            }

            // Stay at the bottom when new content arrives, unless the user scrolled up to read.
            property bool stickToBottom: true

            onMovementEnded: stickToBottom = atYEnd
            onContentHeightChanged: {
                if (stickToBottom)
                    Qt.callLater(positionViewAtEnd);

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
                    ScrollBar.vertical: SaoScrollBar {
                        onLight: true
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

                // Buttons keep their natural width (it depends on the style SAO Utils applies);
                // the text field is what shrinks when space runs out.
                Layout.minimumWidth: implicitWidth
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


    // Console opened over the chat list (TEMPORARY layout, pending decision: it covers the message
    // list but not the input row; the toggle button sits at the top-right corner of the chat area).
    Console {
        id: consolePanel

        z: 20
        visible: showChat && widget.consoleOpen
        x: chatContainer.x
        y: chatContainer.y + chatView.y
        width: chatContainer.width
        height: chatView.height
        yui: widget
        onCloseRequested: widget.consoleOpen = false
    }

    Rectangle {
        z: 21
        visible: showChat
        x: chatContainer.x + chatContainer.width - width - 2
        y: chatContainer.y + 2
        width: 26
        height: 26
        radius: 13
        color: widget.consoleOpen ? "#F59B00" : (consoleToggleArea.containsMouse ? "#FFFFFFFF" : "#CCFFFFFF")
        border.color: "#55000000"

        Text {
            anchors.centerIn: parent
            text: "⬡"
            color: widget.consoleOpen ? "#FFFFFF" : "#555555"
            font.pixelSize: 15
        }

        MouseArea {
            id: consoleToggleArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: widget.consoleOpen = !widget.consoleOpen
        }

    }

    menu: Menu {
        Action {
            text: qsTr("Cardinal System") + "..."
            onTriggered: showDialog(widget.coreSettingsDialog, "coreSettingsDialogInstance")
        }

        Action {
            text: qsTr("Equipment") + "..."
            onTriggered: showDialog(widget.styleSettingsDialog, "styleSettingsDialogInstance")
        }

        Action {
            text: qsTr("Option") + "..."
            onTriggered: showDialog(widget.optionSettingsDialog, "optionSettingsDialogInstance")
        }

    }

}
