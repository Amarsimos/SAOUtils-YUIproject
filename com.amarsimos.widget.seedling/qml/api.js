.pragma library

// Seedling's own connection to a model (section 11.2 of "Seedling Development Plan.md"), for when
// MHCP-YUI is not there (or Connection is Own): one system text and one user message, streamed.
// OpenAI-compatible (OpenAI, DeepSeek, Kimi, Qwen, Ollama, any compatible address), Claude, Gemini.
// Only what writing a widget needs: no tools, no history. Always asynchronous (a synchronous request
// froze SAO Utils). The caller keeps the time (a Timer: no data for a while ends it).

var PROVIDERS = [{
    "id": "openai",
    "models": ["gpt-6-sol", "gpt-6-luna", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"],
    "title": "OpenAI",
    "format": "openai",
    "endpoint": "https://api.openai.com/v1/chat/completions"
}, {
    "id": "deepseek",
    "models": ["deepseek-v4-pro", "deepseek-flash"],
    "title": "DeepSeek",
    "format": "openai",
    "endpoint": "https://api.deepseek.com/chat/completions"
}, {
    "id": "kimi",
    "models": ["kimi-k3", "kimi-k2.6"],
    "title": "Kimi (Moonshot)",
    "format": "openai",
    "endpoint": "https://api.moonshot.cn/v1/chat/completions"
}, {
    "id": "qwen",
    "models": ["qwen3-max", "qwen-plus", "qwen-flash"],
    "title": "Qwen (DashScope)",
    "format": "openai",
    "endpoint": "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
}, {
    "id": "anthropic",
    "models": ["claude-fable-5-1", "claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"],
    "title": "Anthropic Claude",
    "format": "anthropic",
    "endpoint": "https://api.anthropic.com/v1/messages"
}, {
    "id": "google",
    "models": ["gemini-4-argon", "gemini-3.1-pro-preview", "gemini-3.8-flash", "gemini-3.5-flash-lite"],
    "title": "Google Gemini",
    "format": "gemini",
    "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/"
}, {
    "id": "ollama",
    "models": ["qwen3.5:9b", "qwen3:30b-a3b", "gemma4:e4b"],
    "title": "Ollama (local)",
    "format": "openai",
    "endpoint": "http://127.0.0.1:11434/v1/chat/completions",
    "keyOptional": true
}, {
    "id": "custom",
    "models": [],
    "title": "Custom (OpenAI-compatible)",
    "format": "openai",
    "endpoint": ""
}];

function provider(id) {
    for (var i = 0; i < PROVIDERS.length; i++)
        if (PROVIDERS[i].id === id)
            return PROVIDERS[i];

    return PROVIDERS[0];
}

// The model id of a config: Manual Core ID when filled in, else the Core Program chosen.
function modelOf(config) {
    return String(config.customModel || "").trim() || String(config.model || "").trim();
}

// What is missing to make a request ("" when it can be made). config: {provider, endpoint, apiKey, model}.
function missing(config) {
    var p = provider(config.provider);
    if (!String(config.endpoint || p.endpoint).trim())
        return "Server Address";

    if (!p.keyOptional && !String(config.apiKey || "").trim())
        return "Access Key";

    if (!modelOf(config))
        return "Core Program";

    return "";
}

// {url, headers: [[name, value]], body} of a request.
function build(config, system, user, maxTokens) {
    var p = provider(config.provider);
    var endpoint = String(config.endpoint || p.endpoint).trim();
    var key = String(config.apiKey || "").trim();
    var model = modelOf(config);
    if (p.format === "gemini") {
        var base = endpoint.charAt(endpoint.length - 1) === "/" ? endpoint : endpoint + "/";
        return {
            "url": base + model + ":streamGenerateContent?alt=sse",
            "headers": [["x-goog-api-key", key]],
            "body": {
                "systemInstruction": {
                    "parts": [{
                        "text": system
                    }]
                },
                "contents": [{
                    "role": "user",
                    "parts": [{
                        "text": user
                    }]
                }],
                "generationConfig": {
                    "maxOutputTokens": maxTokens
                }
            }
        };
    }
    if (p.format === "anthropic")
        return {
        "url": endpoint,
        "headers": [["x-api-key", key], ["anthropic-version", "2023-06-01"]],
        "body": {
            "model": model,
            "stream": true,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [{
                "role": "user",
                "content": user
            }]
        }
    };

    var headers = key ? [["Authorization", "Bearer " + key]] : [];
    return {
        "url": endpoint,
        "headers": headers,
        "body": {
            "model": model,
            "stream": true,
            "max_tokens": maxTokens,
            "messages": [{
                "role": "system",
                "content": system
            }, {
                "role": "user",
                "content": user
            }]
        }
    };
}

function joinParts(parts) {
    return (parts || []).map(function(part) {
        return part && typeof part.text === "string" ? part.text : "";
    }).join("");
}

// The new text of one streamed event ("data:" payload, parsed). Throws on an error event.
function deltaOf(format, event) {
    if (event.error)
        throw new Error(event.error.message || JSON.stringify(event.error));

    if (format === "gemini") {
        var c = event.candidates;
        return c && c.length > 0 && c[0].content ? joinParts(c[0].content.parts) : "";
    }
    if (format === "anthropic")
        return event.type === "content_block_delta" && event.delta && typeof event.delta.text === "string" ? event.delta.text : "";

    var choice = event.choices && event.choices[0];
    return choice && choice.delta && typeof choice.delta.content === "string" ? choice.delta.content : "";
}

// The text of a whole (not streamed) response.
function textOf(format, response) {
    if (format === "gemini") {
        var c = response.candidates;
        return c && c.length > 0 && c[0].content ? joinParts(c[0].content.parts) : "";
    }
    if (format === "anthropic")
        return joinParts(response.content);

    var choice = response.choices && response.choices[0];
    return choice && choice.message ? (choice.message.content || "") : "";
}

// Reads the SSE lines of body from `from` (to its last full line, or the end when atEnd). Returns
// {text (new text), next (where to go on), events (how many)}.
function readStream(format, body, from, atEnd) {
    var end = atEnd ? body.length : body.lastIndexOf("\n");
    var out = {
        "text": "",
        "next": from,
        "events": 0
    };
    if (end <= from)
        return out;

    var lines = body.substring(from, end).split("\n");
    out.next = end;
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.indexOf("data:") !== 0)
            continue;

        var payload = line.slice(5).trim();
        if (!payload || payload === "[DONE]")
            continue;

        out.events++;
        out.text += deltaOf(format, JSON.parse(payload));
    }
    return out;
}

// Sends the request. onDelta(textSoFar) while it streams; onFinished(text, isError) once.
// Returns {abort()} (keeps what came so far, as an error "stopped").
function request(config, system, user, maxTokens, onDelta, onFinished) {
    var lacking = missing(config);
    if (lacking) {
        onFinished("Seedling Settings: " + lacking + " is not set", true);
        return {
            "abort": function() {
            }
        };
    }
    var format = provider(config.provider).format;
    var parts = build(config, system, user, maxTokens || 16384);
    var http = new XMLHttpRequest();
    var done = false;
    var streamed = "";
    var parsed = 0;
    var events = 0;
    var finish = function(text, isError) {
        if (done)
            return ;

        done = true;
        onFinished(text, isError);
    };
    var take = function(atEnd) {
        var got = readStream(format, http.responseText || "", parsed, atEnd);
        parsed = got.next;
        events += got.events;
        if (got.text) {
            streamed += got.text;
            onDelta(streamed);
        }
    };
    http.onreadystatechange = function() {
        if (done)
            return ;

        try {
            if (http.readyState === XMLHttpRequest.LOADING && http.status === 200) {
                take(false);
                return ;
            }
            if (http.readyState !== XMLHttpRequest.DONE)
                return ;

            if (http.status === 200) {
                take(true);
                if (events === 0)
                    streamed = textOf(format, JSON.parse(http.responseText));

                finish(streamed || "the server sent back nothing", !streamed);
            } else {
                finish("the server answered " + http.status + (http.responseText ? ": " + String(http.responseText).slice(0, 300) : ""), true);
            }
        } catch (e) {
            finish("the answer could not be read: " + e.message, true);
        }
    };
    http.open("POST", parts.url);
    http.setRequestHeader("Content-Type", "application/json");
    parts.headers.forEach(function(h) {
        http.setRequestHeader(h[0], h[1]);
    });
    http.send(JSON.stringify(parts.body));
    return {
        "abort": function() {
            if (done)
                return ;

            done = true;
            http.abort();
            onFinished(streamed, true);
        }
    };
}
