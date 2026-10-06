import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    FileView {
        id: configFile
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs
            property string active_layout: "shell-classic.qml"
        }
    }

    Loader {
        id: layoutLoader
        active: false
        source: ""

        onStatusChanged: {
            if (status === Loader.Error) {
                console.log("hyprquickpaper: could not load layout '" +
                            root.wantedLayout + "', falling back to classic")
                source = Qt.resolvedUrl("shell-classic.qml")
            }
        }
    }

    readonly property string wantedLayout: {
        const v = configs.active_layout
        if (!v || v.length === 0) return "shell-classic.qml"
        return v
    }

    Timer {
        id: bootTimer
        interval: 60
        repeat: false
        onTriggered: {
            layoutLoader.source = Qt.resolvedUrl(root.wantedLayout)
            layoutLoader.active = true
        }
    }

    Component.onCompleted: bootTimer.start()
}
