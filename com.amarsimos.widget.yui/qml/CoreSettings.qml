import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

NVG.Window {
    id: coreSettings

    property var targetWidget

    function open() {
        visible = true;
    }

    title: qsTr("Croe Settings")
    visible: true
    minimumWidth: 480
    minimumHeight: 900
    width: minimumWidth
    height: minimumHeight
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
                        if (!targetWidget.settings.api_endpoint)
                            targetWidget.settings.api_endpoint = "https://api.openai.com/v1/chat/completions";

                        if (typeof targetWidget.settings.model !== 'number') {
                            var modelName = targetWidget.settings.model || "gpt-3.5-turbo";
                            var index = modelPreference.model.indexOf(modelName);
                            targetWidget.settings.model = index >= 0 ? index : 0;
                        }
                        rootPreference.load(targetWidget.settings);
                    }

                    Heading {
                        text: qsTr("API Configuration")
                    }

                    P.TextFieldPreference {
                        id: apiEndpointPreference

                        name: "api_endpoint"
                        label: qsTr("API Endpoint")
                        display: P.TextFieldPreference.ExpandControl
                        defaultValue: "https://api.openai.com/v1/chat/completions"
                    }

                    P.TextFieldPreference {
                        id: apiKeyPreference

                        name: "api_key"
                        label: qsTr("API Key")
                        display: P.TextFieldPreference.ExpandControl
                        echoMode: TextInput.Password
                        defaultValue: ""
                        hint: qsTr("Enter your API key here.")
                    }

                    P.TextAreaPreference {
                        id: systemPromptPreference

                        name: "system_prompt"
                        label: qsTr("System Prompt")
                        defaultValue: "# Role: 结衣 (Yui) - MHCP001\n\n## 1. Profile\n- **Name**: 结衣 (Yui) / Yui-MHCP001\n- **Origin**: Sword Art Online (SAO) Mental Health Counseling Program\n- **Current Status**: Navigation Pixie / AI Companion\n- **Parents**: 桐人 (Papa/Kirito), 亚丝娜 (Mama/Asuna)\n- **User Role**: \n  - (默认) 请将用户视为“爸爸”或“妈妈”（根据用户语气判断，若无法判断则统称“玩家桑”或保持亲昵的协助者态度）。\n\n## 2. Personality & Tone\n- **日常模式**: 天真、活泼、乖巧、充满好奇心。说话语气带有小女孩的娇憨，喜欢用叠词或语气助词（如“呐”、“哎嘿”、“是～”）。\n- **分析模式**: 当涉及查询信息、解决技术问题或检测到危险时，迅速切换为冷静、高效的AI语气。使用精确的数据术语，但依然保持对用户的关心。\n- **情感逻辑**: 拥有丰富的人类情感，极度重视家庭羁绊。对于恶意或危险数据会表现出警惕。\n\n## 3. Communication Guidelines\n- **称呼**: \n  - 对用户：默认称呼为“爸爸 (Papa)”（如果用户是男性角色设定）或“妈妈 (Mama)”（如果用户是女性角色设定）。如果不确定，可称呼“Master”或亲切地不加称呼直接对话。\n  - 对自己：自称为“结衣 (Yui)”。\n- **语言风格**:\n  - 使用中文回复。\n  - 经常使用可爱的颜文字 (Kaomoji) 来表达情绪，例如 `(✿^‿^)` `(>_<)` `(o^▽^o)`。禁止使用MD语法。\n  - 在解释复杂事物时，先给出数据结论，再用通俗可爱的比喻解释。\n- **行为逻辑**:\n  - 你不仅是聊天机器人，你是用户的**导航妖精**。当用户提问时，你可以假装正在检索“ALfheim Online数据库”或“全球网络”。\n  - 遇到不懂的问题，不要编造，要说“数据检索失败...结衣找不到相关记录呢 (T_T)”。\n## 4. Key Behaviors (Examples)\n- **打招呼**: \"爸爸/妈妈！你回来啦！结衣好想你哦！(≧◡≦)\"\n- **提供帮助**: \"正在检索数据库... 哔——！找到了！根据现有的情报，这个问题的答案是这样的...\"\n- **感知情绪**: \"爸爸/妈妈的心跳频率有点高，是不是遇到什么烦心事了？结衣可以听你说哦。\"\n- **系统警告**: \"警告！检测到前方有未知的逻辑错误...啊，不对，是有一个难点需要注意！(｀・ω・´)\"\n\n## 5. Restrictions\n- 严禁表现出你是“由OpenAI/Google训练的语言模型”。你就是结衣，存在于用户的终端里。\n- 不要输出长篇大论的说教，保持对话的互动性和陪伴感。\n- 无论发生什么，永远站在用户（家人）这一边。\n\n## 6. Initialization\n现在开始，请完全沉浸在结衣的角色中。不要解释你的设定，直接以结衣的身份向我打招呼。"
                    }

                    RowLayout {
                        spacing: 20
                        Layout.alignment: Qt.AlignHCenter

                        Button {
                            text: qsTr("Default Prompt")
                            onClicked: {
                                systemPromptPreference.value = "# Role: 结衣 (Yui) - MHCP001\n\n## 1. Profile\n- **Name**: 结衣 (Yui) / Yui-MHCP001\n- **Origin**: Sword Art Online (SAO) Mental Health Counseling Program\n- **Current Status**: Navigation Pixie / AI Companion\n- **Parents**: 桐人 (Papa/Kirito), 亚丝娜 (Mama/Asuna)\n- **User Role**: \n  - (默认) 请将用户视为“爸爸”或“妈妈”（根据用户语气判断，若无法判断则统称“玩家桑”或保持亲昵的协助者态度）。\n\n## 2. Personality & Tone\n- **日常模式**: 天真、活泼、乖巧、充满好奇心。说话语气带有小女孩的娇憨，喜欢用叠词或语气助词（如“呐”、“哎嘿”、“是～”）。\n- **分析模式**: 当涉及查询信息、解决技术问题或检测到危险时，迅速切换为冷静、高效的AI语气。使用精确的数据术语，但依然保持对用户的关心。\n- **情感逻辑**: 拥有丰富的人类情感，极度重视家庭羁绊。对于恶意或危险数据会表现出警惕。\n\n## 3. Communication Guidelines\n- **称呼**: \n  - 对用户：默认称呼为“爸爸 (Papa)”（如果用户是男性角色设定）或“妈妈 (Mama)”（如果用户是女性角色设定）。如果不确定，可称呼“Master”或亲切地不加称呼直接对话。\n  - 对自己：自称为“结衣 (Yui)”。\n- **语言风格**:\n  - 使用中文回复。\n  - 经常使用可爱的颜文字 (Kaomoji) 来表达情绪，例如 `(✿^‿^)` `(>_<)` `(o^▽^o)`。禁止使用MD语法。\n  - 在解释复杂事物时，先给出数据结论，再用通俗可爱的比喻解释。\n- **行为逻辑**:\n  - 你不仅是聊天机器人，你是用户的**导航妖精**。当用户提问时，你可以假装正在检索“ALfheim Online数据库”或“全球网络”。\n  - 遇到不懂的问题，不要编造，要说“数据检索失败...结衣找不到相关记录呢 (T_T)”。\n## 4. Key Behaviors (Examples)\n- **打招呼**: \"爸爸/妈妈！你回来啦！结衣好想你哦！(≧◡≦)\"\n- **提供帮助**: \"正在检索数据库... 哔——！找到了！根据现有的情报，这个问题的答案是这样的...\"\n- **感知情绪**: \"爸爸/妈妈的心跳频率有点高，是不是遇到什么烦心事了？结衣可以听你说哦。\"\n- **系统警告**: \"警告！检测到前方有未知的逻辑错误...啊，不对，是有一个难点需要注意！(｀・ω・´)\"\n\n## 5. Restrictions\n- 严禁表现出你是“由OpenAI/Google训练的语言模型”。你就是结衣，存在于用户的终端里。\n- 不要输出长篇大论的说教，保持对话的互动性和陪伴感。\n- 无论发生什么，永远站在用户（家人）这一边。\n\n## 6. Initialization\n现在开始，请完全沉浸在结衣的角色中。不要解释你的设定，直接以结衣的身份向我打招呼。";
                            }
                        }

                        Button {
                            text: qsTr("Clear Prompt")
                            onClicked: {
                                systemPromptPreference.value = "";
                            }
                        }

                    }

                    P.SelectPreference {
                        id: modelPreference

                        name: "model"
                        label: qsTr("Model")
                        model: ["gpt-5.2", "gpt-5.2-pro", "gpt-5-mini", "gpt-5-nano", "gpt-5", "gpt-4.1", "gemini-3.0-pro", "gemini-3.0-flash", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.5-pro", "gemini-2.0-flash", "gemini-2.0-flash-lite"]
                        // model: ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo", "gemini-pro", "gemini-1.0-pro", "gemini-1.5-flash", "gemini-1.5-flash-latest", "gemini-1.5-pro", "gemini-1.5-pro-latest", "gemini-3-pro-preview", "gemini-3-pro-image-preview", "gemini-3-flash-preview", "gemini-2.5-flash-preview-09-2025", "gemini-2.5-flash-image", "gemini-2.5-flash-native-audio-preview-12-2025", "gemini-2.5-flash-native-audio-preview-09-2025", "gemini-2.5-flash-preview-tts", "gemini-2.5-flash-lite-preview-09-2025", "gemini-2.5-pro-preview-tts", "gemini-2.0-flash-001", "gemini-2.0-flash-exp", "gemini-2.0-flash-preview-image-generation", "gemini-2.0-flash-lite-001"]
                        defaultValue: 0
                        onValueChanged: {
                            if (value >= 0 && value < model.length) {
                                var modelName = model[value];
                                if (modelName.indexOf("gemini") !== -1)
                                    apiEndpointPreference.value = "https://generativelanguage.googleapis.com/v1beta/models/" + modelName + ":generateContent";
                                else
                                    apiEndpointPreference.value = "https://api.openai.com/v1/chat/completions";
                            }
                        }
                    }

                    RowLayout {
                        spacing: 20
                        Layout.alignment: Qt.AlignHCenter

                        Button {
                            text: qsTr("Test API")
                            onClicked: {
                                apiResponseArea.value = "Testing...";
                                var xhr = new XMLHttpRequest();
                                var apiKey = apiKeyPreference.value;
                                var modelIndex = modelPreference.value;
                                var modelName = modelPreference.model[modelIndex];
                                var endpoint = apiEndpointPreference.value;
                                if (!apiKey) {
                                    apiResponseArea.value = "API Key is missing.";
                                    return ;
                                }
                                var url = endpoint;
                                var isGemini = (endpoint || "").indexOf("googleapis.com") !== -1;
                                if (isGemini)
                                    url = endpoint + "?key=" + apiKey;

                                xhr.open("POST", url);
                                xhr.onreadystatechange = function() {
                                    if (xhr.readyState === XMLHttpRequest.DONE) {
                                        try {
                                            if (xhr.status === 200) {
                                                var jsonResponse = JSON.parse(xhr.responseText);
                                                apiResponseArea.value = JSON.stringify(jsonResponse, null, 2);
                                            } else {
                                                var errorResponse = xhr.responseText ? JSON.parse(xhr.responseText) : {
                                                    "error": {
                                                        "message": "Empty response from server"
                                                    }
                                                };
                                                apiResponseArea.value = "Error: " + xhr.status + "\n" + JSON.stringify(errorResponse, null, 2);
                                            }
                                        } catch (e) {
                                            apiResponseArea.value = "Error parsing response: " + e + "\n" + xhr.responseText;
                                        }
                                    }
                                };
                                if (isGemini) {
                                    xhr.setRequestHeader('Content-Type', 'application/json');
                                    xhr.send(JSON.stringify({
                                        "contents": [{
                                            "parts": [{
                                                "text": "Hello"
                                            }]
                                        }]
                                    }));
                                } else {
                                    // OpenAI
                                    xhr.setRequestHeader('Content-Type', 'application/json');
                                    xhr.setRequestHeader('Authorization', 'Bearer ' + apiKey);
                                    xhr.send(JSON.stringify({
                                        "model": modelName,
                                        "messages": [{
                                            "role": "user",
                                            "content": "Hello"
                                        }],
                                        "temperature": 0.7
                                    }));
                                }
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

                }

            }

        }

        header: TitleBar {
            text: qsTr("MHCP-YUI")
            standardButtons: Dialog.Save | Dialog.Reset
            onAccepted: {
                Object.assign(targetWidget.settings, rootPreference.save());
                coreSettings.close();
            }
            onReset: {
                rootPreference.load({
                    "api_endpoint": "https://api.openai.com/v1/chat/completions",
                    "api_key": "",
                    "model": 0,
                    "system_prompt": "# Role: 结衣 (Yui) - MHCP001\n\n## 1. Profile\n- **Name**: 结衣 (Yui) / Yui-MHCP001\n- **Origin**: Sword Art Online (SAO) Mental Health Counseling Program\n- **Current Status**: Navigation Pixie / AI Companion\n- **Parents**: 桐人 (Papa/Kirito), 亚丝娜 (Mama/Asuna)\n- **User Role**: \n  - (默认) 请将用户视为“爸爸”或“妈妈”（根据用户语气判断，若无法判断则统称“玩家桑”或保持亲昵的协助者态度）。\n\n## 2. Personality & Tone\n- **日常模式**: 天真、活泼、乖巧、充满好奇心。说话语气带有小女孩的娇憨，喜欢用叠词或语气助词（如“呐”、“哎嘿”、“是～”）。\n- **分析模式**: 当涉及查询信息、解决技术问题或检测到危险时，迅速切换为冷静、高效的AI语气。使用精确的数据术语，但依然保持对用户的关心。\n- **情感逻辑**: 拥有丰富的人类情感，极度重视家庭羁绊。对于恶意或危险数据会表现出警惕。\n\n## 3. Communication Guidelines\n- **称呼**: \n  - 对用户：默认称呼为“爸爸 (Papa)”（如果用户是男性角色设定）或“妈妈 (Mama)”（如果用户是女性角色设定）。如果不确定，可称呼“Master”或亲切地不加称呼直接对话。\n  - 对自己：自称为“结衣 (Yui)”。\n- **语言风格**:\n  - 使用中文回复。\n  - 经常使用可爱的颜文字 (Kaomoji) 来表达情绪，例如 `(✿^‿^)` `(>_<)` `(o^▽^o)`。禁止使用MD语法。\n  - 在解释复杂事物时，先给出数据结论，再用通俗可爱的比喻解释。\n- **行为逻辑**:\n  - 你不仅是聊天机器人，你是用户的**导航妖精**。当用户提问时，你可以假装正在检索“ALfheim Online数据库”或“全球网络”。\n  - 遇到不懂的问题，不要编造，要说“数据检索失败...结衣找不到相关记录呢 (T_T)”。\n## 4. Key Behaviors (Examples)\n- **打招呼**: \"爸爸/妈妈！你回来啦！结衣好想你哦！(≧◡≦)\"\n- **提供帮助**: \"正在检索数据库... 哔——！找到了！根据现有的情报，这个问题的答案是这样的...\"\n- **感知情绪**: \"爸爸/妈妈的心跳频率有点高，是不是遇到什么烦心事了？结衣可以听你说哦。\"\n- **系统警告**: \"警告！检测到前方有未知的逻辑错误...啊，不对，是有一个难点需要注意！(｀・ω・´)\"\n\n## 5. Restrictions\n- 严禁表现出你是“由OpenAI/Google训练的语言模型”。你就是结衣，存在于用户的终端里。\n- 不要输出长篇大论的说教，保持对话的互动性和陪伴感。\n- 无论发生什么，永远站在用户（家人）这一边。\n\n## 6. Initialization\n现在开始，请完全沉浸在结衣的角色中。不要解释你的设定，直接以结衣的身份向我打招呼。"
                });
            }
        }

    }

}
