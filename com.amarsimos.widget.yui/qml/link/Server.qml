pragma Singleton
import QtQml 2.12

// Shared by the widget and the resources SAO Utils loads on their own (YuiAction.qml, YuiData.qml),
// as other extensions do: a running Yui registers here, and the action and the data reach her through
// yui (the one registered last that is still running).
QtObject {
    property var yui: null
    property var instances: []

    function register(widget) {
        if (instances.indexOf(widget) === -1)
            instances = instances.concat([widget]);

        yui = widget;
    }

    function unregister(widget) {
        instances = instances.filter(function(other) {
            return other !== widget;
        });
        if (yui === widget)
            yui = instances.length > 0 ? instances[instances.length - 1] : null;

    }
}
