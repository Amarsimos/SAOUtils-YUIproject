import "."
import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

T.Widget {
    // 新的用户气泡默认颜色
    // 新的AI气泡默认颜色
    // 聊天字体默认颜色为黑色
    // 新增背景图片路径的默认值
    // 新增背景图片路径的默认值
    // NVG.BackgroundSource {
    //     id: backgroundImage
    //     height: parent.height
    //     width: parent.width
    //     fillMode: Image.PreserveAspectCrop
    //     configuration: widget.settings.styles.background_image_path
    // }

    id: widget

    property Component settingsDialog: Qt.createComponent("CoreSettings.qml")
    property Component styleSettingsDialog: Qt.createComponent("StyleSettings.qml")
    property var modelList: ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo", "gemini-pro", "gemini-1.0-pro", "gemini-1.5-flash", "gemini-1.5-flash-latest", "gemini-1.5-pro", "gemini-1.5-pro-latest", "gemini-3-pro-preview", "gemini-3-pro-image-preview", "gemini-3-flash-preview", "gemini-2.5-flash-preview-09-2025", "gemini-2.5-flash-image", "gemini-2.5-flash-native-audio-preview-12-2025", "gemini-2.5-flash-native-audio-preview-09-2025", "gemini-2.5-flash-preview-tts", "gemini-2.5-flash-lite-preview-09-2025", "gemini-2.5-pro-preview-tts", "gemini-2.0-flash-001", "gemini-2.0-flash-exp", "gemini-2.0-flash-preview-image-generation", "gemini-2.0-flash-lite-001"]
    property bool showChat: true
    readonly property var fonts: Qt.fontFamilies()
    readonly property var defaultValues: {
        "character_image_path": Qt.resolvedUrl("../Images/Yui01.png"),
        "background_image_path": Qt.resolvedUrl("../Images/scrim-dark-40.png"),
        "user_bubble_color": "#2196f3",
        "ai_bubble_color": "#f8bbd0",
        "bubble_font_family": fonts.indexOf("Microsoft YaHei UI") !== -1 ? fonts.indexOf("Microsoft Ya Hei UI") : 0,
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

    function getInitialMessage() {
        if (!widget.settings.api_key || !widget.settings.api_endpoint) {
            chatModel.append({
                "author": "ai",
                "message": "Hello! Please configure the API in settings."
            });
            return ;
        }
        chatModel.append({
            "author": "ai",
            "message": "..."
        });
        var http = new XMLHttpRequest();
        var isGemini = (widget.settings.api_endpoint || "").indexOf("googleapis.com") !== -1;
        var url = widget.settings.api_endpoint;
        var data = {
        };
        var systemPrompt = widget.settings.system_prompt || "你是ai助手";
        http.onreadystatechange = function() {
            if (http.readyState === XMLHttpRequest.DONE) {
                chatModel.remove(chatModel.count - 1);
                var responseContent = "";
                try {
                    if (http.status === 200) {
                        var response = JSON.parse(http.responseText);
                        if (isGemini) {
                            if (response.candidates && response.candidates.length > 0 && response.candidates[0].content && response.candidates[0].content.parts && response.candidates[0].content.parts.length > 0)
                                responseContent = response.candidates[0].content.parts[0].text;
                            else
                                responseContent = "Received an empty or unexpected response from the API.";
                        } else {
                            responseContent = response.choices[0].message.content;
                        }
                    } else {
                        responseContent = "Error: " + http.statusText + (http.responseText ? ": " + http.responseText : "");
                    }
                } catch (e) {
                    responseContent = "Error parsing response: " + e.message;
                }
                chatModel.append({
                    "author": "ai",
                    "message": responseContent
                });
            }
        };
        if (isGemini) {
            url = url + "?key=" + widget.settings.api_key;
            http.open("POST", url);
            http.setRequestHeader("Content-Type", "application/json");
            data = {
                "contents": [{
                    "role": "user",
                    "parts": [{
                        "text": systemPrompt + " Please introduce yourself briefly in one sentence."
                    }]
                }]
            };
        } else {
            var modelIndex = typeof widget.settings.model === 'number' ? widget.settings.model : 0;
            var modelName = modelList[modelIndex];
            http.open("POST", url || "https://api.openai.com/v1/chat/completions");
            http.setRequestHeader("Content-Type", "application/json");
            http.setRequestHeader("Authorization", "Bearer " + widget.settings.api_key);
            data = {
                "model": modelName,
                "messages": [{
                    "role": "system",
                    "content": systemPrompt
                }, {
                    "role": "user",
                    "content": "Hello, introduce yourself briefly in one sentence."
                }],
                "max_tokens": 60
            };
        }
        http.send(JSON.stringify(data));
    }

    function sendMessage(text) {
        if (!text.trim())
            return ;

        chatModel.append({
            "author": "user",
            "message": text
        });
        chatView.positionViewAtEnd(); // Scroll to bottom after user sends
        chatModel.append({
            "author": "ai",
            "message": "..."
        });
        chatView.positionViewAtEnd(); // Scroll to bottom for thinking indicator
        var http = new XMLHttpRequest();
        var isGemini = (widget.settings.api_endpoint || "").indexOf("googleapis.com") !== -1;
        var url = widget.settings.api_endpoint;
        var data = {
        };
        var systemPrompt = widget.settings.system_prompt || "你是ai助手";
        http.onreadystatechange = function() {
            if (http.readyState === XMLHttpRequest.DONE) {
                chatModel.remove(chatModel.count - 1);
                var responseContent = "";
                try {
                    if (http.status === 200) {
                        var response = JSON.parse(http.responseText);
                        if (isGemini) {
                            if (response.candidates && response.candidates.length > 0 && response.candidates[0].content && response.candidates[0].content.parts && response.candidates[0].content.parts.length > 0)
                                responseContent = response.candidates[0].content.parts[0].text;
                            else
                                responseContent = "Received an empty or unexpected response from the API.";
                        } else {
                            responseContent = response.choices[0].message.content;
                        }
                    } else {
                        responseContent = "Error: " + http.statusText + (http.responseText ? ": " + http.responseText : "");
                    }
                } catch (e) {
                    responseContent = "Error parsing response: " + e.message;
                }
                chatModel.append({
                    "author": "ai",
                    "message": responseContent
                });
                chatView.positionViewAtEnd(); // Scroll to bottom after AI replies
            }
        };
        if (isGemini) {
            url = url + "?key=" + widget.settings.api_key;
            http.open("POST", url);
            http.setRequestHeader("Content-Type", "application/json");
            data = {
                "contents": [{
                    "role": "user",
                    "parts": [{
                        "text": systemPrompt
                    }]
                }, {
                    "role": "model",
                    "parts": [{
                        "text": "OK"
                    }]
                }, {
                    "role": "user",
                    "parts": [{
                        "text": text
                    }]
                }]
            };
        } else {
            var modelIndex = typeof widget.settings.model === 'number' ? widget.settings.model : 0;
            var modelName = modelList[modelIndex];
            http.open("POST", url || "https://api.openai.com/v1/chat/completions");
            http.setRequestHeader("Content-Type", "application/json");
            http.setRequestHeader("Authorization", "Bearer " + widget.settings.api_key);
            data = {
                "model": modelName,
                "messages": [{
                    "role": "system",
                    "content": systemPrompt
                }, {
                    "role": "user",
                    "content": text
                }]
            };
        }
        http.send(JSON.stringify(data));
    }

    title: qsTr("MHCP-YUI")
    solid: true
    resizable: true
    implicitWidth: 700
    implicitHeight: 600
    visible: true
    editing: styleDialog.active
    Component.onCompleted: {
        widget.width = 800; // 强制设置初始宽度
        widget.height = 400; // 强制设置初始高度
        if (!widget.settings.styles)
            widget.settings.styles = defaultValues;
        else
            widget.settings.styles = updateObject(JSON.parse(JSON.stringify(defaultValues)), widget.settings.styles);
        getInitialMessage();
    }

    ListModel {
        id: chatModel
    }

    NVG.ImageSource {
        id: characterImage

        configuration: widget.settings.styles.character_image_path
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: parent.height
        fillMode: Image.PreserveAspectFit

        MouseArea {
            anchors.fill: parent
            onClicked: {
                showChat = !showChat;
            }
        }

    }

    ColumnLayout {
        id: chatContainer

        width: 375
        anchors.left: characterImage.right
        anchors.leftMargin: 10
        anchors.top: characterImage.top
        anchors.bottom: characterImage.bottom
        visible: showChat
        opacity: showChat ? 1 : 0

        ListView {
            // onContentHeightChanged is removed

            id: chatView

            Layout.fillWidth: true
            Layout.fillHeight: true
            model: chatModel
            spacing: 10
            clip: true // 重新启用 clip 属性

            ScrollBar.vertical: ScrollBar {
                visible: false
            }

            delegate: ItemDelegate {
                width: parent.width
                height: rowLayout.implicitHeight

                RowLayout {
                    // Use TextMetrics to get the ideal width of the text without wrapping.

                    id: rowLayout

                    width: parent.width
                    spacing: 10

                    Item {
                        Layout.fillWidth: model.author === 'user'
                    }

                    TextMetrics {
                        id: textMetrics

                        font: messageLabel.font // This is safe because font properties are defined on the label.
                        text: model.message
                    }

                    Rectangle {
                        // Bubble width is the smaller of the ideal text width or the max width, plus padding.
                        // Bubble height is determined by the label's implicit height after it has wrapped.

                        id: bubble

                        color: model.author === 'user' ? (widget.settings.styles.user_bubble_color || "#4477CC") : (widget.settings.styles.ai_bubble_color || "#333333")
                        border.color: "#FFFFFF"
                        border.width: 1
                        radius: 8
                        width: Math.min(textMetrics.width + 5, chatView.width * 0.9) + 20 // 增加 5 像素的容差
                        height: messageLabel.implicitHeight + 20

                        Label {
                            // Label fills the inside of the bubble, with 10px margins on each side.

                            id: messageLabel

                            text: model.message
                            wrapMode: Label.WordWrap
                            color: widget.settings.styles.bubble_font_color || "#FFFFFF"
                            width: parent.width - 20
                            anchors.centerIn: parent
                            font.family: (widget.fonts && widget.fonts.length > 0) ? widget.fonts[widget.settings.styles.bubble_font_family || 0] : "Microsoft YaHei UI"
                        }

                    }

                    Item {
                        Layout.fillWidth: model.author === 'ai'
                    }

                }

            }

        }

        Rectangle {
            id: inputArea

            Layout.fillWidth: true
            Layout.topMargin: 10
            Layout.alignment: Qt.AlignBottom
            height: 60
            color: "#00000000"
            border.color: "#00000000"
            border.width: 1

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                width: parent.width - 20
                spacing: 10

                TextField {
                    id: textInput

                    Layout.preferredWidth: 250
                    Layout.preferredHeight: 45
                    placeholderText: qsTr("Type a message...")
                    color: "black"
                    padding: 10
                    onAccepted: {
                        sendMessage(textInput.text);
                        textInput.text = "";
                    }

                    background: Rectangle {
                        width: parent.width
                        height: parent.height
                        color: "#ffffffff"
                        border.color: "#00000000"
                        border.width: 0
                        radius: 30
                    }

                }

                Button {
                    id: sendButton

                    text: qsTr("Send")
                    onClicked: {
                        sendMessage(textInput.text);
                        textInput.text = "";
                    }
                }

                Button {
                    id: clearButton

                    text: qsTr("Clear")
                    onClicked: {
                        chatModel.clear();
                        getInitialMessage();
                    }
                }

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
            onTriggered: {
                var dialog = settingsDialog.createObject(widget, {
                    "targetWidget": widget
                });
                if (dialog)
                    dialog.visible = true;
                else
                    console.log("Error creating/showing settings dialog:", settingsDialog.errorString());
            }
        }

        Action {
            text: qsTr("Style Settings") + "..."
            onTriggered: {
                var dialog = styleSettingsDialog.createObject(widget, {
                    "targetWidget": widget
                });
                if (dialog)
                    dialog.visible = true;
                else
                    console.log("Error creating/showing style settings dialog:", styleSettingsDialog.errorString());
            }
        }

    }

}
