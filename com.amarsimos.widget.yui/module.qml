import QtQuick 2.7
import NERvGear 1.0 as NVG

import "qml"

NVG.Module {
    id: module

    initialize: function () {
        console.log("initializing:", module.name);
        return true;
    }

    ready: function () {
        NVG.SystemCall.messageBox(qsTr("Link Start!"));
    }

    cleanup: function () {
        console.log("cleaning up:", module.name);
    }


}
