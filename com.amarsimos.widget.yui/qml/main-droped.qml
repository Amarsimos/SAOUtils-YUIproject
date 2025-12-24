import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import "."

T.Widget {
    id: widget
    title: qsTr("YUI Assistant")
    width: 300
    height: 400
    resizable: true

    property Component settingsDialog: Qt.createComponent("Settings.qml")
    property var modelList: [
        // OpenAI
        "gpt-3.5-turbo",
        "gpt-4",
        "gpt-4-turbo",
        
        // Gemini Stable/Common
        "gemini-pro",
        "gemini-1.0-pro",
        "gemini-1.5-flash",
        "gemini-1.5-flash-latest",
        "gemini-1.5-pro",
        "gemini-1.5-pro-latest",

        // Gemini Preview/Specialized
        "gemini-3-pro-preview",
        "gemini-3-pro-image-preview",
        "gemini-3-flash-preview",
        "gemini-2.5-flash-preview-09-2025",
        "gemini-2.5-flash-image",
        "gemini-2.5-flash-native-audio-preview-12-2025",
        "gemini-2.5-flash-native-audio-preview-09-2025",
        "gemini-2.5-flash-preview-tts",
        "gemini-2.5-flash-lite-preview-09-2025",
        "gemini-2.5-pro-preview-tts",
        "gemini-2.0-flash-001",
        "gemini-2.0-flash-exp",
        "gemini-2.0-flash-preview-image-generation",
        "gemini-2.0-flash-lite-001"
    ]

    ListModel {
        id: chatModel
    }

    // Add a welcome message
    Component.onCompleted: {
        getInitialMessage();
    }

    function getInitialMessage() {
        if (!widget.settings.api_key || !widget.settings.api_endpoint) {
            chatModel.append({ "author": "ai", "message": "Hello! Please configure the API in settings." });
            return;
        }

        chatModel.append({ "author": "ai", "message": "..." });

        var http = new XMLHttpRequest();
        var isGemini = (widget.settings.api_endpoint || "").indexOf("googleapis.com") !== -1;
        var url = widget.settings.api_endpoint;
        var data = {};
        var systemPrompt = widget.settings.system_prompt || "你是ai助手";

        http.onreadystatechange = function() {
            if (http.readyState === XMLHttpRequest.DONE) {
                chatModel.remove(chatModel.count - 1);
                var responseContent = "";

                try {
                    if (http.status === 200) {
                        var response = JSON.parse(http.responseText);
                        if (isGemini) {
                            if (response.candidates && response.candidates.length > 0 && response.candidates[0].content && response.candidates[0].content.parts && response.candidates[0].content.parts.length > 0) {
                                responseContent = response.candidates[0].content.parts[0].text;
                            } else {
                                responseContent = "Received an empty or unexpected response from the API.";
                                console.log("Unexpected Gemini Response:", http.responseText);
                            }
                        } else {
                            responseContent = response.choices[0].message.content;
                        }
                    } else {
                        responseContent = "Error: " + http.statusText + (http.responseText ? ": " + http.responseText : "");
                    }
                } catch (e) {
                    responseContent = "Error parsing response: " + e.message;
                }

                chatModel.append({ "author": "ai", "message": responseContent });
            }
        }

        if (isGemini) {
            url = url + "?key=" + widget.settings.api_key;
            http.open("POST", url);
            http.setRequestHeader("Content-Type", "application/json");
            data = {
                "contents": [{ "role": "user", "parts": [{"text": systemPrompt + " Please introduce yourself briefly in one sentence."}] }]
            };
        } else { // OpenAI
            var modelIndex = typeof widget.settings.model === 'number' ? widget.settings.model : 0;
            var modelName = modelList[modelIndex];

            http.open("POST", url || "https://api.openai.com/v1/chat/completions");
            http.setRequestHeader("Content-Type", "application/json");
            http.setRequestHeader("Authorization", "Bearer " + widget.settings.api_key);
            data = {
                "model": modelName,
                "messages": [
                    { "role": "system", "content": systemPrompt },
                    { "role": "user", "content": "Hello, introduce yourself briefly in one sentence." }
                ],
                "max_tokens": 60
            };
        }

        http.send(JSON.stringify(data));
    }

    function sendMessage(text) {
        if (!text.trim()) return;

        // Add user message to model
        chatModel.append({ "author": "user", "message": text });
        chatView.positionViewAtEnd();

        // Add a "thinking" indicator
        chatModel.append({ "author": "ai", "message": "..." });
        chatView.positionViewAtEnd();

        var http = new XMLHttpRequest();
        var isGemini = (widget.settings.api_endpoint || "").indexOf("googleapis.com") !== -1;
        var url = widget.settings.api_endpoint;
        var data = {};
        var systemPrompt = widget.settings.system_prompt || "你是ai助手";

        http.onreadystatechange = function() {
            if (http.readyState === XMLHttpRequest.DONE) {
                // Remove "thinking" indicator
                chatModel.remove(chatModel.count - 1);
                var responseContent = "";

                try {
                    if (http.status === 200) {
                        var response = JSON.parse(http.responseText);
                        if (isGemini) {
                            if (response.candidates && response.candidates.length > 0 && response.candidates[0].content && response.candidates[0].content.parts && response.candidates[0].content.parts.length > 0) {
                                responseContent = response.candidates[0].content.parts[0].text;
                            } else if (response.promptFeedback && response.promptFeedback.blockReason) {
                                responseContent = "Blocked: " + response.promptFeedback.blockReason;
                                console.log(JSON.stringify(response.promptFeedback));
                            } else {
                                responseContent = "Received an empty or unexpected response from the API.";
                                console.log(http.responseText);
                            }
                        } else {
                            // OpenAI response
                            responseContent = response.choices[0].message.content;
                        }
                    } else {
                        responseContent = "Error: " + http.statusText + (http.responseText ? ": " + http.responseText : "");
                    }
                } catch (e) {
                    responseContent = "Error parsing response: " + e.message;
                }

                chatModel.append({ "author": "ai", "message": responseContent });
                chatView.positionViewAtEnd();
            }
        }

        if (isGemini) {
            url = url + "?key=" + widget.settings.api_key;
            http.open("POST", url);
            http.setRequestHeader("Content-Type", "application/json");

            var contents = [];
            // Add system prompt as the first user turn, with a boilerplate model response.
            contents.push({ "role": "user", "parts": [{"text": systemPrompt }] });
            contents.push({ "role": "model", "parts": [{"text": "OK" }] });

            for (var i = 0; i < chatModel.count; ++i) {
                var item = chatModel.get(i);
                // Skip the initial AI-generated message, as the system prompt now sets the context
                if (i === 0 && item.author === 'ai') {
                    continue;
                }
                if(item.message !== "...") {
                    var role = item.author === "user" ? "user" : "model";
                    contents.push({ "role": role, "parts": [{"text": item.message}] });
                }
            }
            data = { "contents": contents };

        } else { // OpenAI
            var modelIndex = typeof widget.settings.model === 'number' ? widget.settings.model : 0;
            var modelName = modelList[modelIndex];

            http.open("POST", url || "https://api.openai.com/v1/chat/completions");
            http.setRequestHeader("Content-Type", "application/json");
            http.setRequestHeader("Authorization", "Bearer " + widget.settings.api_key);

            var messages = [];
            messages.push({ "role": "system", "content": systemPrompt });

            for (var i = 0; i < chatModel.count; ++i) {
                var item = chatModel.get(i);
                // Skip the initial AI-generated message
                if (i === 0 && item.author === 'ai') {
                    continue;
                }
                if(item.message !== "...") {
                    messages.push({ "role": item.author === "user" ? "user" : "assistant", "content": item.message });
                }
            }

            data = {
                "model": modelName,
                "messages": messages
            };
        }

        http.send(JSON.stringify(data));
    }

    menu: Menu {
        Action {
            text: qsTr("Settings") + "..."
            onTriggered: {
                var dialog = settingsDialog.createObject(widget, { "targetWidget": widget });
                if (dialog) {
                    dialog.visible = true;
                } else {
                    console.log("Error creating/showing settings dialog:", settingsDialog.errorString());
                }
            }
        }
        Action {
            text: qsTr("Clear Chat")
            onTriggered: {
                chatModel.clear();
                getInitialMessage();
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Chat View
        ListView {
            id: chatView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: chatModel
            spacing: 10
            clip: true

            ScrollBar.vertical: ScrollBar {}

            delegate: ItemDelegate {
                width: parent.width
                height: rowLayout.implicitHeight

                TextMetrics {
                    id: textMetrics
                    font: messageLabel.font
                    text: model.message
                }

                RowLayout {
                    id: rowLayout
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Align user messages to the right, AI to the left
                    Item { Layout.fillWidth: model.author === 'user' }

                    Rectangle {
                        color: model.author === 'user' ? "#4477CC" : "#333333"
                        border.color: "#FFFFFF"
                        border.width: 1
                        radius: 8
                        width: Math.min(textMetrics.width, chatView.width * 0.7) + 20
                        height: messageLabel.implicitHeight + 20

                        Label {
                            id: messageLabel
                            text: model.message
                            wrapMode: Label.WordWrap
                            color: "white"
                            width: parent.width - 20
                            anchors.centerIn: parent
                        }
                    }

                    Item { Layout.fillWidth: model.author === 'ai' }
                }
            }
        }

        // Input Area
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#1A1A1A"
            border.color: "#555"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 10

                TextField {
                    id: textInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: qsTr("Type a message...")
                    color: "white"
                    background: Rectangle {
                        color: "#222"
                        border.color: "#777"
                        border.width: 1
                        radius: 5
                    }
                    onAccepted: {
                        sendMessage(textInput.text);
                        textInput.text = "";
                    }
                }

                Button {
                    id: sendButton
                    text: qsTr("Send")
                    Layout.preferredWidth: 80
                    Layout.fillHeight: true
                    onClicked: {
                        sendMessage(textInput.text);
                        textInput.text = "";
                    }
                }
            }
        }
    }
}
