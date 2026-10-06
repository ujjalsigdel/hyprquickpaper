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
            property string active_layout: ""
        }
    }

    Loader {
        id: layoutLoader
        active: false
        source: ""

        onStatusChanged: {
            if (status === Loader.Error) {
                console.log("hyprquickpaper: failed to load layout, falling back to classic")
                source = Qt.resolvedUrl("layouts/shell-classic.qml")
            }
        }
    }

    Timer {
        id: bootTimer
        interval: 60
        repeat: false
        onTriggered: {
            let layout = ""
            try {
                layout = configs.active_layout
            } catch (e) {
                layout = ""
            }

            if (!layout || layout.length === 0) {
                layout = "layouts/shell-classic.qml"
            } else if (layout.indexOf("/") < 0) {
                layout = "layouts/" + layout
            }

            layoutLoader.source = Qt.resolvedUrl(layout)
            layoutLoader.active = true
        }
    }

    Component.onCompleted: bootTimer.start()
}
