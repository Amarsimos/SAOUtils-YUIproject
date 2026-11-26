.pragma library

// S2 of "Seedling Development Plan.md" (prototype): generated code created in a sandbox.
// Qt.createQmlObject(code, parent) gives the new object the context of the file parent was made in,
// and QML looks names up through that context's parents: so the code saw the workbench's and the
// widget's ids (S1, P1). Here the sandbox (Sandbox.qml, an empty item) is made from this library,
// which has no QML context of its own, and the code is created inside the sandbox: the names around
// it are only the sandbox's (none).
// sandboxUrl: Qt.resolvedUrl("Sandbox.qml") of the caller (a library cannot resolve relative paths).

var component = null;

// Returns {item, sandbox} or {error}. host: the visual parent (the preview, the widget's content).
function create(code, host, sandboxUrl, fileName) {
    if (!component || component.url !== sandboxUrl)
        component = Qt.createComponent(sandboxUrl);

    if (component.status !== 1)
        return {
            "error": "the sandbox could not be made: " + component.errorString()
        };

    var sandbox = component.createObject(host);
    if (!sandbox)
        return {
            "error": "the sandbox could not be made"
        };

    try {
        var item = Qt.createQmlObject(code, sandbox, fileName || "Seedling");
        sandbox.width = Qt.binding(function() {
            return item.width;
        });
        sandbox.height = Qt.binding(function() {
            return item.height;
        });
        return {
            "item": item,
            "sandbox": sandbox
        };
    } catch (e) {
        sandbox.destroy();
        throw e;
    }
}
