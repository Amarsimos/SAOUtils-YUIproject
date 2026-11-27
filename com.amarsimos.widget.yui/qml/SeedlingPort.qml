import QtQuick 2.12
import "yui.js" as Yui

// What Seedling may use of MHCP-YUI (section 12 of "Seedling Development Plan.md", the Link
// interface): Seedling gets this object, never Yui herself, so her own functions can change freely.
// Only what is listed there; when it changes in a way that breaks Seedling, linkVersion goes up.
QtObject {
    id: port

    // MHCP-YUI (main-stand.qml).
    property var yui: null
    readonly property int linkVersion: 1

    // Yui's connection: {ready, provider, title, model}. No key, no address.
    function connection() {
        var config = yui.activeConfig();
        return {
            "ready": !!(config.apiKey && config.endpoint && config.model),
            "provider": config.provider ? config.provider.id : "",
            "title": config.provider ? config.provider.title : "",
            "model": config.model || ""
        };
    }

    // One request through Yui's connection (no personality, history or notes). Returns {abort()}.
    function ask(system, user, model, onDelta, onFinished) {
        return yui.seedlingConnection(system, user, model, onDelta, onFinished);
    }

    // Her server's models: {server, models: [id], scanned, chatModel}.
    function models() {
        return yui.seedlingModels();
    }

    // Scan Cores / Restore Registry on her server (the list is hers). onDone(models or null, error).
    function scanModels(onDone) {
        yui.seedlingScanModels(onDone);
    }

    function restoreModels() {
        yui.seedlingRestoreModels();
    }

    // The data a widget may read (@yui): {name: {type, text, fast}}.
    function dataKeys() {
        return Yui.SEEDLING_DATA;
    }

    // Send to Yui: the chat opens and she fixes the widget (problems: the workbench's list).
    function fixWidget(problems) {
        yui.seedlingFix(problems);
    }

    // A value of Yui's data (@yui): {current, ...}, or null (unknown, or its feature is off).
    function value(name) {
        return yui.linkValue(name);
    }

    // Text into the chat: sent at once, or written into the input box.
    function sendToChat(text) {
        yui.sendToChat(text);
    }

    function prefillChat(text) {
        yui.prefillChat(text);
    }

    // The look the workbench follows: Yui's message font and chat opacity (0 - 1).
    readonly property string font: yui ? yui.fontFamilyOf(yui.styles.bubble_font_family) : ""
    readonly property real panelAlpha: yui ? yui.chatOpacity : 0.8
}
