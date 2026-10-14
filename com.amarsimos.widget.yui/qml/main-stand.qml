import "."
import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Shapes 1.12

T.Widget {
    id: widget

    property Component coreSettingsDialog: Qt.createComponent("CoreSettings.qml")
    property Component styleSettingsDialog: Qt.createComponent("StyleSettings.qml")
    property var styleSettingsDialogInstance: null
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
    property int chatSession: 0
    // Messages before this index are not sent as history (e.g. written before the API was configured).
    property int historyStart: 0
    property bool showChat: true
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
        "bubble_font_color": "#000000"
    }

    function updateObject(targetObj, sourceObj) {
        for (let prop in sourceObj) {
            if (sourceObj.hasOwnProperty(prop) && sourceObj[prop] !== undefined) {
                if (typeof sourceObj[prop] === 'object' && !Array.isArray(sourceObj[prop]) && sourceObj[prop] !== null) {
                    if (!targetObj[prop])
                        targetObj[prop] = {
                    };

                    updateObject(targetObj[prop], sourceObj[prop]);
                } else {
                    targetObj[prop] = sourceObj[prop];
                }
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

    // Yui-style first line of an HTTP error message; the raw error follows it.
    function httpErrorHint(status) {
        if (status === 0)
            return "警告！结衣连接不上网络……请检查一下网络和 Endpoint 地址哦 (>_<)";

        if (status === 401 || status === 403)
            return "哔——！身份验证失败……API Key 好像不对，请在「Core Settings」里检查一下 (｀・ω・´)";

        if (status === 404)
            return "数据检索失败……找不到这个模型或地址呢 (T_T) 请检查模型名和 Endpoint 吧";

        if (status === 429)
            return "呜……请求太频繁或者额度用完了，结衣需要休息一下 (>_<) 稍后再试试吧";

        if (status >= 500)
            return "服务器那边出故障了……不是" + userTitle() + "的错哦，等一会儿再试试吧 (´・ω・`)";

        return "数据检索失败……结衣遇到了未知的错误 (T_T)";
    }

    // messages: [{ "role": "user" | "assistant", "content": "..." }]
    // onFinished(text, isError, notConfigured)
    // config: optional, defaults to activeConfig(); may carry "systemPrompt" and "userTitle" to override the saved ones.
    function requestCompletion(messages, onFinished, config) {
        config = config || activeConfig();
        var format = config.provider.format;
        var systemPrompt = config.systemPrompt !== undefined ? config.systemPrompt : widget.settings.system_prompt;
        systemPrompt = (systemPrompt || "你是ai助手").replace(/\{\{user_title\}\}/g, config.userTitle || userTitle());
        if (!config.apiKey || !config.endpoint || !config.model) {
            onFinished("警告！连接数据缺失……结衣找不到通往网络的路了 (T_T)\n请在「Core Settings」里检查 API Key、Endpoint 和模型有没有填好哦～", true, true);
            return ;
        }
        var http = new XMLHttpRequest();
        var data;
        var done = false;
        // Give up on requests that hang, so the chat never stays busy forever.
        var timer = Qt.createQmlObject("import QtQuick 2.12; Timer { interval: 120000 }", widget);
        var finish = function(text, isError) {
            if (done)
                return ;

            done = true;
            timer.stop();
            timer.destroy();
            onFinished(text, isError);
        };
        timer.triggered.connect(function() {
            finish("等了好久都没有回应……结衣和网络的连接超时了 (T_T) 请稍后再试试吧\n[Error: request timed out]", true);
            http.abort();
        });
        timer.start();
        http.onreadystatechange = function() {
            if (http.readyState !== XMLHttpRequest.DONE || done)
                return ;

            try {
                if (http.status === 200) {
                    var response = JSON.parse(http.responseText);
                    var text;
                    if (format === "gemini") {
                        var candidates = response.candidates;
                        text = candidates && candidates.length > 0 && candidates[0].content ? joinTextParts(candidates[0].content.parts) : "";
                    } else if (format === "anthropic") {
                        text = joinTextParts(response.content);
                    } else {
                        text = response.choices[0].message.content;
                    }
                    if (text)
                        finish(text, false);
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
            http.open("POST", base + config.model + ":generateContent");
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
                "system": systemPrompt,
                "messages": messages
            };
        } else {
            http.open("POST", config.endpoint);
            http.setRequestHeader("Authorization", "Bearer " + config.apiKey);
            data = {
                "model": config.model,
                "messages": [{
                    "role": "system",
                    "content": systemPrompt
                }].concat(messages)
            };
        }
        http.setRequestHeader("Content-Type", "application/json");
        http.send(JSON.stringify(data));
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

    function appendMessage(author, message, isError) {
        chatModel.append({
            "author": author,
            "message": message,
            "pending": false,
            "isError": isError
        });
        chatView.stickToBottom = true;
    }

    // Show a "..." placeholder and replace it in place once the reply arrives.
    function startReply(messages) {
        var session = widget.chatSession;
        var index = chatModel.count;
        chatModel.append({
            "author": "ai",
            "message": "...",
            "pending": true,
            "isError": false
        });
        chatView.stickToBottom = true;
        widget.busy = true;
        requestCompletion(messages, function(text, isError, notConfigured) {
            // The chat was cleared while this request was in flight.
            if (session !== widget.chatSession)
                return ;

            chatView.stickToBottom = true;
            chatModel.set(index, {
                "message": text,
                "pending": false,
                "isError": isError
            });
            // Nothing written so far reached the API; start the conversation history after it.
            if (notConfigured)
                widget.historyStart = chatModel.count;

            widget.busy = false;
        });
    }

    function getInitialMessage() {
        if (!activeConfig().apiKey) {
            appendMessage("ai", userTitle() + "，欢迎回来！(≧◡≦) 不过……结衣还连接不上网络呢 (>_<)\n请右键点击结衣，打开「Core Settings」，选好服务商并填上 API Key，结衣就能和你说话啦！", true);
            return ;
        }
        startReply([{
            "role": "user",
            "content": "Please introduce yourself briefly in one sentence."
        }]);
    }

    function sendMessage(text) {
        if (!text.trim() || widget.busy)
            return false;

        appendMessage("user", text, false);
        startReply(buildHistory());
        return true;
    }

    function clearChat() {
        widget.chatSession++;
        widget.busy = false;
        chatModel.clear();
        widget.historyStart = 0;
        chatView.stickToBottom = true;
        getInitialMessage();
    }

    // Hiding the chat shrinks the widget to the character image; showing it restores the previous width.
    function setChatVisible(visible) {
        if (visible === showChat)
            return ;

        // Never request a frame lower than the minimum height; scale the image width to match.
        var h = Math.max(widget.height, widget.minimumFrameHeight);
        var natural = widget.height > 0 ? widget.characterNaturalWidth * h / widget.height : 0;
        if (visible) {
            showChat = true;
            applyFrameSize(Math.max(widget.settings.expanded_width || 800, Math.max(natural, widget.characterMinimumWidth) + widget.chatMinimumWidth + 30), h);
        } else {
            widget.settings.expanded_width = widget.width;
            showChat = false;
            if (natural > 0)
                applyFrameSize(Math.ceil(Math.max(natural, widget.characterMinimumWidth)), h);

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
        // The frame size itself is restored by SAO Utils.
        if (widget.settings.chat_hidden)
            showChat = false;

        if (firstRun)
            applyFrameSize(800, 400); // lowers the minimum size again once applied
        else
            releaseMinimumSize();


        getInitialMessage();
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

        configuration: widget.styles.character_image_path
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
                setChatVisible(!showChat);
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

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Item {
                id: messageItem

                // AI bubbles get a comic-style tail at the bottom-left, pointing at the character.
                readonly property bool hasTail: model.author !== "user"
                readonly property real tailSize: 10

                width: chatView.width
                height: bubble.height + (hasTail ? tailSize * 0.6 : 0)

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
                    anchors.rightMargin: 4
                    color: model.author === "user" ? (widget.styles.user_bubble_color || widget.defaultValues.user_bubble_color) : (widget.styles.ai_bubble_color || widget.defaultValues.ai_bubble_color)
                    border.color: "#FFFFFF"
                    border.width: 1
                    radius: 8
                    width: Math.min(measure.implicitWidth + 2, chatView.width * 0.85) + 20
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

            TextField {
                id: textInput

                Layout.fillWidth: true
                Layout.minimumWidth: widget.inputMinimumWidth
                Layout.preferredHeight: 40
                placeholderText: qsTr("Type a message...")
                color: "black"
                leftPadding: 16
                rightPadding: 16
                selectByMouse: true
                onAccepted: {
                    if (sendMessage(textInput.text))
                        textInput.text = "";

                }

                background: Rectangle {
                    color: "#ffffffff"
                    radius: height / 2
                }

            }

            Button {
                id: sendButton

                // Buttons keep their natural width (it depends on the style SAO Utils applies);
                // the text field is what shrinks when space runs out.
                Layout.minimumWidth: implicitWidth
                Layout.preferredHeight: 40
                text: qsTr("Send")
                enabled: !widget.busy && textInput.text.trim().length > 0
                onClicked: {
                    if (sendMessage(textInput.text))
                        textInput.text = "";

                    textInput.forceActiveFocus();
                }
            }

            Button {
                id: clearButton

                Layout.minimumWidth: implicitWidth
                Layout.preferredHeight: 40
                text: qsTr("Clear")
                onClicked: clearChat()
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }

        }

    }


    menu: Menu {
        Action {
            text: qsTr("Core Settings") + "..."
            onTriggered: showDialog(widget.coreSettingsDialog, "coreSettingsDialogInstance")
        }

        Action {
            text: qsTr("Style Settings") + "..."
            onTriggered: showDialog(widget.styleSettingsDialog, "styleSettingsDialogInstance")
        }

    }

}
