import Quickshell
import QtQuick

// Top-level Scope allows loading PanelWindow dynamically without rendering white artifacts
Scope {
    id: root

    // Change this string to switch layouts:
    // "shell-coverflow.qml" or "shell-classic.qml"
    // property string activeLayout: "shell-classic.qml"
    // property string activeLayout: "shell-coverflow.qml"
    // property string activeLayout: "shell-coverflow-widgets.qml"
    // property string activeLayout: "shell-widgets-noblur.qml"
    property string activeLayout: "shell-bottom-dock.qml"
    // property string activeLayout: "shell-hexagon.qml"


    Loader {
        active: true
        source: Qt.resolvedUrl(root.activeLayout)
    }
}
