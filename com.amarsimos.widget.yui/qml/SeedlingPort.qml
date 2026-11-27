import QtQuick 2.12
import "yui.js" as Yui

// What Seedling may use of MHCP-YUI (section 12 of "Seedling Development Plan.md", the Link
// interface): Seedling gets this object, never Yui herself, so her own functions can change freely.
// Only what is listed there; when it changes in a way that breaks Seedling, linkVersion goes up.
// Every call works when Yui is gone (her widget removed while Seedling still holds this): it then
// answers as "not there" (not ready, no models, null values, a request that ends at once with an
// error) instead of throwing into Seedling.
QtObject {
    id: port

    // MHCP-YUI (main-stand.qml); null (or destroyed) once she is gone.
    property var yui: null
    readonly property int linkVersion: 1

    // Runs call(yui) while she is there, else (or when it throws) returns fallback.
    function withYui(call, fallback) {
        if (!yui)
            return fallback;

        try {
            return call(yui);
        } catch (e) {
            console.log("MHCP-YUI's Link port:", e);
            return fallback;
        }
    }

    // Yui's connection: {ready, provider, title, model}. No key, no address.
    function connection() {
        return withYui(function(her) {
            var config = her.activeConfig();
            return {
                "ready": !!(config.apiKey && config.endpoint && config.model),
                "provider": config.provider ? config.provider.id : "",
                "title": config.provider ? config.provider.title : "",
                "model": config.model || ""
            };
        }, {
            "ready": false,
            "provider": "",
            "title": "",
            "model": ""
        });
    }

    // One request through Yui's connection (no personality, history or notes). Returns {abort()}.
    // Without her: ends at once with an error.
    function ask(system, user, model, onDelta, onFinished) {
        var handle = withYui(function(her) {
            return her.seedlingConnection(system, user, model, onDelta, onFinished);
        }, null);
        if (handle)
            return handle;

        onFinished("MHCP-YUI is not there", true);
        return {
            "abort": function() {
            }
        };
    }

    // Her server's models: {server, models: [id], scanned, chatModel}.
    function models() {
        return withYui(function(her) {
            return her.seedlingModels();
        }, {
            "server": "",
            "models": [],
            "scanned": false,
            "chatModel": ""
        });
    }

    // Scan Cores / Restore Registry on her server (the list is hers). onDone(models or null, error).
    function scanModels(onDone) {
        if (!withYui(function(her) {
            her.seedlingScanModels(onDone);
            return true;
        }, false))
            onDone(null, "MHCP-YUI is not there");

    }

    function restoreModels() {
        withYui(function(her) {
            her.seedlingRestoreModels();
        });
    }

    // The data a widget may read (@yui): {name: {type, text, fast}}.
    function dataKeys() {
        return Yui.SEEDLING_DATA;
    }

    // Send to Yui: the chat opens and she fixes the widget (problems: the workbench's list).
    function fixWidget(problems) {
        withYui(function(her) {
            her.seedlingFix(problems);
        });
    }

    // A value of Yui's data (@yui): {current, ...}, or null (unknown, or its feature is off).
    function value(name) {
        return withYui(function(her) {
            return her.linkValue(name);
        }, null);
    }

    // Text into the chat: sent at once, or written into the input box.
    function sendToChat(text) {
        withYui(function(her) {
            her.sendToChat(text);
        });
    }

    function prefillChat(text) {
        withYui(function(her) {
            her.prefillChat(text);
        });
    }

    // The look the workbench follows: Yui's message font and chat opacity (0 - 1).
    readonly property string font: yui ? yui.fontFamilyOf(yui.styles.bubble_font_family) : ""
    readonly property real panelAlpha: yui ? yui.chatOpacity : 0.8
}
